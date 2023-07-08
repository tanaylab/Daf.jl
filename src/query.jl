"""
`Daf` provides a query language that allows for convenient extraction of data from the `Storage`. This isn't a
"beautiful" query language, but it is terse, consistent, and reasonably flexible.

We use an operator precedence parser for queries. That is, one can think of a query as an expression, using specific
operators that combine into the overall query expression. For example, the query `cell @ batch` can be thought of as the
expression `@("cell", "batch")` which means "lookup the value of the property `batch` for each entry of the `cell`
axis".

We separately describe queries that produce matrix data ([`MatrixQuery`](@ref)), vector data ([`VectorQuery`](@ref)),
and scalar data ([`ScalarQuery`](@ref)).

When parsing a query, we will will properly encode escaped characters, treat any `#...<LineBreak>` characters sequence
as white space, and also condense all consecutive white space characters into a single space (which will convert the
query string to a single line). This allows using arbitrary comments, white space and line breaks in complex queries,
and also allows error messages to visually refer to the part of the query that triggered them, without having to deal
with thorny issues of visually indicating messages inside multi-line query strings. This comes at the cost that the
error messages refer to the one-line version of the query string, instead of the original.

We only reexport [`escape_query`](@ref), [`unescape_query`](@ref) and [`is_safe_query_char`](@ref) from the top-level
`Daf` module itself, as these are all you might be interested in from outside the `Daf` package. The other entities
listed here describe the syntax of a query, and give insight into how the query is computed.
"""
module Query

export AxisEntry
export AxisFilter
export AxisLookup
export canonical
export ComparisonOperator
export escape_query
export FilteredAxis
export FilterOperator
export is_safe_query_char
export MatrixAxes
export MatrixEntryAxes
export MatrixEntryLookup
export MatrixLayout
export MatrixPropertyLookup
export MatrixQuery
export MatrixSliceAxes
export MatrixSliceLookup
export ParameterAssignment
export parse_matrix_query
export parse_scalar_query
export parse_vector_query
export PropertyComparison
export PropertyLookup
export QueryContext
export QueryExpression
export QueryOperation
export QueryOperator
export QueryToken
export ReduceMatrixQuery
export ReduceVectorQuery
export ScalarDataLookup
export ScalarPropertyLookup
export ScalarQuery
export unescape_query
export VectorDataLookup
export VectorEntryLookup
export VectorPropertyLookup
export VectorQuery

using Daf.MatrixLayouts
using Daf.Oprec
using Daf.Registry
using URIs

import Base.MathConstants.e
import Daf.Registry.AbstractOperation
import Daf.Registry.ELTWISE_REGISTERED_OPERATIONS
import Daf.Registry.REDUCTION_REGISTERED_OPERATIONS
import Daf.Registry.RegisteredOperation

"""
    escape_query(token::AbstractString)::String

Given some raw `token` (name of an axis, axis entry or property, or a parameter value), which may contain special
characters, return an escaped version to be used in a query string.

We need to consider the following kinds of characters:

  - **Safe** ([`is_safe_query_char`](@ref)) characters include `a` - `z`, `A` - `Z`, `0` - `9`, `_`, `+`, `-`, and `.`,
    as well as any non-ASCII (that is, Unicode) characters. Any sequence of these characters will be considered a single
    token, used to write names (of axes, axis entries, properties, operations, parameters), and also values (for
    parameters). These cover all the common cases (including signed integer and floating point values).

  - All other ASCII characters are (at least potentially) **special**, that is, may be used to describe the query
    structure. Currently only a subset of these are actually used: `#`, `\\`, `@`, `:`, `<`, `=`, `,`, `;`, `!`, `&`,
    `|`, `^` and `%`, and, of course, white space (spaces, tabs and line breaks) which can be used for readability.
    Additional characters may be used in future version, if we choose to enhance the query language.
  - Prefixing *any* character with a `\\` allows using it inside a token. This is useful if some name or value contains
    a special character. For example, if you have a cell whose name is `ACTG:Plate1`, and you want to access the name of
    the batch of this specific cell, you will have to write `cell = ACTG\\:Plate1 : batch`.

!!! note

    The `\\` character is also used by Julia inside `"..."` string literals, to escape writing non-printable characters.
    For example, `"\\n"` is a single-character string containing a line break, and therefore `"\\\\"` is used to write a
    single `\\`. Thus the above example would have to be written as `"cell = ACTG\\\\:Plate1 : batch"`. This isn't nice.

    Luckily, Julia also has `raw"..."` string literals that work similarly to Python's `r"..."` strings (in Julia,
    `r"..."` is a regular expression, not a string). Inside raw string literals, a `\\` is a `\\` (unless it precedes a
    `"`). Therefore the above example could also be written as `raw"cell = ACTG\\:Plate1 : batch`, which is more
    readable.

Back to `escape_query` - it will prefix any (potentially) special character with a `\\`. It is useful if you want to
inject a data into a query. Often this happens when using `\$(...)` to embed values into a query string, e.g., the query
`\$(axis) @ \$(property) > \$(value)` is unsafe, as any of the embedded variables may contain unsafe characters. You
should instead write something like `\$(escape_query(axis)) @ \$(escape_query(property)) > \$(escape_query(value))`.
"""
function escape_query(token::AbstractString)::String
    return replace(token, (character -> !is_safe_query_char(character)) => s"\\\0")
end

"""
    unescape_query(escaped_token::AbstractString)::String

Undo [`escape_query`](@ref), that is, given a query token with a `\\` characters escaping special characters, drop the
`\\` to get back the original string value.
"""
function unescape_query(escaped_token::AbstractString)::String
    return replace(escaped_token, r"\\(.)" => s"\1")
end

"""
    is_safe_query_char(character::Char)::Bool

Return whether a character is safe to use inside a query token (name of an axis, axis entry or property, or a parameter
value).

The safe characters are `a` - `z`, `A` - `Z`, `0` - `9`, `_`, `+`, `-`, and `.`, as well as any non-ASCII (that is,
Unicode) characters.
"""
function is_safe_query_char(character::Char)::Bool
    return character == '_' ||
           character == '.' ||
           character == '+' ||
           character == '-' ||
           isletter(character) ||
           isdigit(character) ||
           !isascii(character)
end

function prepare_query_string(query_string::AbstractString)::String
    query_string = encode_expression(query_string)
    query_string = replace(query_string, r"#[^\n\r]*([\r\n]|$)"sm => " ")
    query_string = strip(replace(query_string, r"\s+" => " "))
    return query_string
end

"""
The operators that can be used in a `Daf` query.

| Operator  | Associativity | Precedence | Description                                                                                |
|:---------:|:-------------:|:----------:|:------------------------------------------------------------------------------------------ |
| `%>`      | Left          | 0          | Reduction operation (matrix to vector, vector to scalar), e.g. `cell , gene @ UMIs %> Sum` |
| `%`       | Right         | 1          | Element-wise operation (e.g., `cell , gene @ UMIs % Log`)                                  |
| `@`       | Right         | 2          | Lookup (e.g., `cell , gene @ UMIs`)                                                        |
| `;`       | Right         | 3          | 1. Column-major layout (e.g., `cell ; gene @ UMIs`)                                        |
|           |               |            | 2. Parameters separator (e.g., `Log; base = 2`)                                            |
| `,`       | Right         | 3          | Row-major layout (e.g., `cell , gene`)                                                     |
|           |               | 3          | Parameter assignment separator (e.g., `Log; base = 2, eps = 1`)                            |
| `&`       | Right         | 4          | AND filter (e.g., `gene & marker`)                                                         |
| `\\|`     | Right         | 4          | OR filter (e.g., `gene & marker \\| noisy`)                                                |
| `^`       | Right         | 4          | XOR filter (e.g., `gene & marker ^ noisy`)                                                 |
| `<`       | Right         | 5          | Less than (e.g., `batch : age < 1`)                                                        |
| `<=`, `≤` | Right         | 5          | Less or equal (e.g., `batch : age <= 1`)                                                   |
| `!=`, `≠` | Right         | 5          | Not equal (e.g., `batch : age != 1`)                                                       |
| `=`       | Right         | 5          | 1. Is equal (e.g., `batch : age = 1`)                                                      |
|           |               |            | 2. Select axis entry (e.g., `cell , gene = FOX1 @ UMIs`)                                   |
|           |               |            | 3. Parameter assignment (e.g., `Log; base = 2`)                                            |
| `>=`, `≥` | Right         | 5          | Greater or equal (e.g., `batch : age >= 1`)                                                |
| `>`       | Right         | 5          | Greater than (e.g., `batch : age > 1`)                                                     |
| `!~`, `≁` | Right         | 5          | Not match (e.g., `gene !~ MT-.\\*`                                                         |
| `~`       | Right         | 5          | 1. Match (e.g., `gene ~ MT-.\\*`)                                                          |
|           |               |            | 2. Invert mask (prefix; e.g., `gene & ~noisy`)                                             |
| `:`       | Right         | 6          | Chained property lookup (e.g., `batch : age`)                                              |
"""
@enum QueryOperators OpAnd OpChain OpEltwise OpEqual OpGreaterOrEqual OpGreaterThan OpLessOrEqual OpLessThan OpLookup OpMatch OpNotEqual OpNotMatch OpOr OpPrimarySeparator OpReduce OpSecondarySeparator OpValue OpXor

const OpParameterSeparator = OpPrimarySeparator
const OpParametersSeparator = OpSecondarySeparator
const OpRowMajorSeparator = OpPrimarySeparator
const OpColumnMajorSeparator = OpSecondarySeparator
const OpInvert = OpMatch

"""
    QueryContext = Context{QueryOperators}

Context for reporting errors while parsing a query.
"""
const QueryContext = Context{QueryOperators}

"""
    QueryExpression = Expression{QueryOperators}

An expression tree for a `Daf` query.
"""
const QueryExpression = Expression{QueryOperators}

"""
    QueryOperation = Operation{QueryOperators}

A non-leaf node in a [`QueryExpression`](@ref) tree.
"""
const QueryOperation = Operation{QueryOperators}

"""
    QueryToken = Token{QueryOperators}

A leaf node in a [`QueryExpression`](@ref) tree.

This will capture any sequence of [`safe`](@ref is_safe_query_char) or [`escaped`](@ref escape_query) characters.
"""
const QueryToken = Token{QueryOperators}

"""
    QueryOperator = Operator{QueryOperators}

A description of one of the [`QueryOperators`](@ref).
"""
const QueryOperator = Operator{QueryOperators}

const QuerySyntax = Syntax{QueryOperators}

QUERY_SYNTAX = QuerySyntax(
    r"^\s+",                             # Spaces
    r"^[0-9a-zA-Z_.+-]+",                # Operand
    r"^(?:[<!>]=|!~|%>|[%@;,:&|^<=~>])", # Operators
    Dict(
        "%>" => Operator(OpReduce, false, LeftAssociative, 0),
        "%" => Operator(OpEltwise, false, RightAssociative, 1),
        "@" => Operator(OpLookup, false, RightAssociative, 2),
        ";" => Operator(OpSecondarySeparator, false, RightAssociative, 3),
        "," => Operator(OpPrimarySeparator, false, RightAssociative, 3),
        "&" => Operator(OpAnd, false, RightAssociative, 4),
        "|" => Operator(OpOr, false, RightAssociative, 4),
        "^" => Operator(OpXor, false, RightAssociative, 4),
        "<" => Operator(OpLessThan, false, RightAssociative, 5),
        "<=" => Operator(OpLessOrEqual, false, RightAssociative, 5),
        "≤" => Operator(OpLessOrEqual, false, RightAssociative, 5),
        "!=" => Operator(OpNotEqual, false, RightAssociative, 5),
        "≠" => Operator(OpNotEqual, false, RightAssociative, 5),
        "=" => Operator(OpEqual, false, RightAssociative, 5),
        ">=" => Operator(OpGreaterOrEqual, false, RightAssociative, 5),
        "≥" => Operator(OpGreaterOrEqual, false, RightAssociative, 5),
        ">" => Operator(OpGreaterThan, false, RightAssociative, 5),
        "!~" => Operator(OpNotMatch, false, RightAssociative, 5),
        "≁" => Operator(OpNotMatch, false, RightAssociative, 5),
        "~" => Operator(OpMatch, true, RightAssociative, 5),
        ":" => Operator(OpChain, false, RightAssociative, 6),
    ),
)

"""
`ParameterAssignment` = [`QueryToken`](@ref)(*parameter name*) `=` [`QueryToken`](@ref)(*parameter value*)

    struct ParameterAssignment
        assignment::QueryOperation
    end

Assignment of a value to a single parameter of an element-wise or reduction operation. This is provided to the
constructors of [`EltwiseOperation`](@ref)s and [`ReductionOperation`](@ref)s. The constructors will convert the string
parameter value to the appropriate parameter type, and will generate error messages in context if the value is invalid.
"""
struct ParameterAssignment
    assignment::QueryOperation
end

function ParameterAssignment(
    context::QueryContext,
    operator::Union{QueryToken, Nothing},
    query_tree::QueryExpression,
)::ParameterAssignment
    return parse_operation_in_context(
        context,
        query_tree;
        expression_name = "parameter_assignment",
        operator_name = "assignment operator",
        operators = [OpEqual],
    ) do parameter_name, assignment_operator, parameter_value
        parse_string_in_context(context, parameter_name; name = "parameter name")
        parse_string_in_context(context, parameter_value; name = "parameter value")
        return ParameterAssignment(query_tree)
    end
end

function parse_operation_type(
    context::QueryContext,
    query_tree::QueryExpression,
    kind::String,
    registered_operations::Dict{String, RegisteredOperation},
)::Type
    return parse_operand_in_context(context, query_tree; name = "$(kind) type") do operation_type_name
        if !(operation_type_name.string in keys(registered_operations))
            error_in_context(context, "unknown $(kind) type: $(operation_type_name.string)")
        end
        return registered_operations[operation_type_name.string].type
    end
end

function parse_query_operation(
    context::QueryContext,
    query_tree::QueryExpression,
    kind::String,
    registered_operations::Dict{String, RegisteredOperation},
)::AbstractOperation
    return parse_with_list_in_context(
        context,
        query_tree;
        expression_name = "$(kind) operation",
        separator_name = "parameters separator",
        separator_operators = [OpParametersSeparator],
        list_name = "parameters assignments",
        element_type = ParameterAssignment,
        operators = [OpParameterSeparator],
    ) do operation_type_name, parameters_assignments
        operation_type = parse_operation_type(context, operation_type_name, kind, registered_operations)

        parameters_dict = Dict{String, QueryOperation}()
        parameter_symbols = fieldnames(operation_type)
        for parameter_assignment in parameters_assignments
            if !(Symbol(parameter_assignment.assignment.left.string) in parameter_symbols)
                parse_in_context(context, parameter_assignment.assignment; name = "parameter assignment") do
                    parse_in_context(context, parameter_assignment.assignment.left; name = "parameter name") do
                        return error_in_context(
                            context,
                            "unknown parameter: $(parameter_assignment.assignment.left.string)\n" *
                            "for the $(kind) type: $(operation_type)",
                        )
                    end
                end
            end

            previous_assignment = get(parameters_dict, parameter_assignment.assignment.left.string, nothing)
            if previous_assignment != nothing
                parse_in_context(context, previous_assignment; name = "first parameter assignment") do
                    parse_in_context(context, parameter_assignment.assignment; name = "second parameter assignment") do
                        parse_in_context(context, parameter_assignment.assignment.left; name = "parameter name") do
                            return error_in_context(
                                context,
                                "repeated parameter: $(parameter_assignment.assignment.left.string)\n" *
                                "for the $(kind) type: $(operation_type)",
                            )
                        end
                    end
                end
            end

            parameters_dict[parameter_assignment.assignment.left.string] = parameter_assignment.assignment
        end

        return operation_type(context, parameters_dict)
    end
end

"""
`EltwiseOperation` = [`QueryToken`](@ref)([`EltwiseOperation`](@ref)) ( `;` [`ParameterAssignment`](@ref) ( `,` [`ParameterAssignment`](@ref) )* )?

Parse a [`EltwiseOperation`](@ref).
"""
function parse_eltwise_operation(
    context::QueryContext,
    operator::Union{QueryToken, Nothing},
    query_tree::QueryExpression,
)::EltwiseOperation
    return parse_query_operation(context, query_tree, "eltwise", ELTWISE_REGISTERED_OPERATIONS)
end

"""
`ReductionOperation` = [`QueryToken`](@ref)([`ReductionOperation`](@ref)) ( `;` [`ParameterAssignment`](@ref) ( `,` [`ParameterAssignment`](@ref) )* )?

Parse a [`ReductionOperation`](@ref).
"""
function parse_reduction_operation(
    context::QueryContext,
    operator::Union{QueryToken, Nothing},
    query_tree::QueryExpression,
)::ReductionOperation
    return parse_query_operation(context, query_tree, "reduction", REDUCTION_REGISTERED_OPERATIONS)
end

"""
    function canonical(query::Union{MatrixQuery, VectorQuery, ScalarQuery})::String

Return a canonical form for a query. This strips away any comments, uses a standard white space policy between tokens,
and even reorders [`AxisFilter`](@ref)s in a [`FilteredAxis`](@ref) where possible, so that if two queries are "the
same", they will have the same `canonical` form.
"""
function canonical(operation::AbstractOperation)::String
    return "$(typeof(operation))" *
           " ; " *
           join(
               [
                   (String(field_name) *
                    " = " * #
                    if field_name == :dtype && getfield(operation, :dtype) == nothing
                        "auto"
                    elseif getfield(operation, field_name) == Float64(e)
                        "e"
                    else
                        escape_query("$(getfield(operation, field_name))")
                    end) for field_name in fieldnames(typeof(operation))
               ],
               " , ",
           )
end

"""
`PropertyLookup` = [`QueryToken`](@ref)(*property name*) ( `:` [`QueryToken`](@ref)(*property name*) )*

Lookup the value of some property for a single axis (for vector data) or a pair of axes (for matrix data).

This is typically just the name of the property to lookup. However, we commonly find that a property of one axis
contains names of entries in another axis. For example, we may have a `batch` property per `cell`, and an `age` property
per `batch`. In such cases, we allow a chained lookup of the color of the type of each cell by writing `batch : age`.
The chain can be as long as necessary (e.g., `batch : donor : sex`).
"""
struct PropertyLookup
    property_names::Vector{String}
end

function PropertyLookup(context::QueryContext, query_tree::QueryExpression)::PropertyLookup
    return PropertyLookup(
        parse_list_in_context(
            context,
            query_tree;
            list_name = "property lookup",
            element_type = String,
            operators = [OpChain],
        ) do context, operator, property_name
            return parse_string_in_context(context, property_name; name = "property name")
        end,
    )
end

function canonical(property_lookup::PropertyLookup)::String
    return (join([escape_query(property_name) for property_name in property_lookup.property_names], " : "))
end

function Base.isless(left::PropertyLookup, right::PropertyLookup)::Bool
    return left.property_names < right.property_names
end

function Base.:(==)(left::PropertyLookup, right::PropertyLookup)::Bool
    return left.property_names == right.property_names
end

"""
`ComparisonOperator` = `<` | `<=` | `≤` | `=` | `!=` | `≠` | `>=` | `≥` | `>` | `~` | `!~` | `≁`

How to compare a each value of a property with some constant value to generate a filter mask.

!!! note

    For matching (using `~` or `!~`), you will have to [`escape`](@ref escape_query) any special characters used in
    regexp; for example, you will need to write `raw"gene ~ RP\\[LS\\].\\*"` to match all the ribosomal gene names.
"""
@enum ComparisonOperator CmpLessThan CmpLessOrEqual CmpEqual CmpNotEqual CmpGreaterOrEqual CmpGreaterThan CmpMatch CmpNotMatch

PARSE_COMPARISON_OPERATOR = Dict(
    OpLessThan => CmpLessThan,
    OpLessOrEqual => CmpLessOrEqual,
    OpNotEqual => CmpNotEqual,
    OpEqual => CmpEqual,
    OpMatch => CmpMatch,
    OpNotMatch => CmpNotMatch,
    OpGreaterThan => CmpGreaterThan,
    OpGreaterOrEqual => CmpGreaterOrEqual,
)

CANONICAL_COMPARISON_OPERATOR = Dict(
    CmpLessThan => "<",
    CmpLessOrEqual => "<=",
    CmpNotEqual => "!=",
    CmpEqual => "=",
    CmpMatch => "~",
    CmpNotMatch => "!~",
    CmpGreaterThan => ">",
    CmpGreaterOrEqual => ">=",
)

"""
`PropertyComparison` = [`ComparisonOperator`](@ref) [`QueryToken`](@ref)(*property value*)

Compare a (non-Boolean) property to a constant value.

This is used to convert any set of non-Boolean property values for the axis entries into a Boolean mask which we can
then use to filter the axis entries, e.g. `> 1` will create a mask of all the entries whose value is larger than one.
"""
struct PropertyComparison
    comparison_operator::ComparisonOperator
    property_value::String
end

function PropertyComparison(
    context::QueryContext,
    comparison_operator::QueryToken,
    property_value::QueryExpression,
)::PropertyComparison
    return PropertyComparison(
        PARSE_COMPARISON_OPERATOR[comparison_operator.operator.id],
        parse_string_in_context(context, property_value; name = "property value"),
    )
end

function canonical(property_comparison::PropertyComparison)::String
    return CANONICAL_COMPARISON_OPERATOR[property_comparison.comparison_operator] *
           " " *
           escape_query(property_comparison.property_value)
end

function Base.isless(left::PropertyComparison, right::PropertyComparison)::Bool
    return (left.property_value, left.comparison_operator) < (right.property_value, right.comparison_operator)
end

function Base.:(==)(left::PropertyComparison, right::PropertyComparison)::Bool
    return (left.property_value, left.comparison_operator) == (right.property_value, right.comparison_operator)
end

"""
`AxisLookup` = `~` [`PropertyLookup`](@ref) | [`PropertyLookup`](@ref) [`PropertyComparison`](@ref)?

Lookup some value for each entry of an axis.

This can simply lookup the value of some property of the axis, e.g., `batch : age`. In addition, we allow extra features
for dealing with Boolean masks. First, if looking up a Boolean property, then prefixing it with a `~` will invert the
result, e.g. `~ marker`. Second, when looking up a non-Boolean property, it is possible to convert it into Boolean
values by comparing it with a constant value, e.g., `batch : age > 1`. This allows us to use the result as a mask, e.g.,
when filtering which entries of an axis we want to fetch results for.
"""
struct AxisLookup
    is_inverse::Bool
    property_lookup::PropertyLookup
    property_comparison::Union{PropertyComparison, Nothing}
end

function AxisLookup(context::QueryContext, query_tree::QueryExpression)::AxisLookup
    if check_operation(query_tree, [OpInvert]) != nothing && query_tree.left == nothing
        return parse_in_context(context, query_tree; name = "inverted filter mask") do
            return AxisLookup(true, PropertyLookup(context, query_tree.right), nothing)
        end

    elseif check_operation(
        query_tree,
        [OpLessThan, OpLessOrEqual, OpNotEqual, OpEqual, OpMatch, OpNotMatch, OpGreaterThan, OpGreaterOrEqual],
    ) != nothing
        return parse_operation_in_context(
            context,
            query_tree;
            expression_name = "filter mask",
            operator_name = "comparison operator",
            operators = [
                OpLessThan,
                OpLessOrEqual,
                OpNotEqual,
                OpEqual,
                OpMatch,
                OpNotMatch,
                OpGreaterThan,
                OpGreaterOrEqual,
            ],
        ) do property_lookup, comparison_operator, property_value
            return AxisLookup(
                false,
                PropertyLookup(context, property_lookup),
                PropertyComparison(context, comparison_operator, property_value),
            )
        end

    else
        return parse_in_context(context, query_tree; name = "filter mask, no comparison operator") do
            return AxisLookup(false, PropertyLookup(context, query_tree), nothing)
        end
    end
end

function canonical(axis_lookup::AxisLookup)::String
    result = canonical(axis_lookup.property_lookup)
    if axis_lookup.is_inverse
        result = "~ " * result
    end
    if axis_lookup.property_comparison != nothing
        result *= " " * canonical(axis_lookup.property_comparison)
    end
    return result
end

function Base.isless(left::AxisLookup, right::AxisLookup)::Bool
    left_property_comparison =
        left.property_comparison == nothing ? PropertyComparison(CmpLessThan, "") : left.property_comparison
    right_property_comparison =
        right.property_comparison == nothing ? PropertyComparison(CmpLessThan, "") : right.property_comparison
    return (left.property_lookup, left_property_comparison, left.is_inverse) <
           (right.property_lookup, right_property_comparison, right.is_inverse)
end

"""
`FilterOperator` = `&` | `|` | `^`

A Boolean operator for updating the mask of a filter.
"""
@enum FilterOperator FilterAnd FilterOr FilterXor

PARSE_FILTER_OPERATOR = Dict(OpAnd => FilterAnd, OpOr => FilterOr, OpXor => FilterXor)

CANONICAL_FILTER_OPERATOR = Dict(FilterAnd => "&", FilterOr => "|", FilterXor => "^")

"""
`AxisFilter` = [`FilterOperator`](@ref) [`AxisLookup`](@ref)

A filter to apply to an axis.

By default we fetch results for each entry of each axis. We can restrict the set of entries we fetch results for by
applying filters. Each filter applies a Boolean mask to the set of entries we'll return results for. Filters are applied
in a strict left to right order. Each filter can restrict the set of entries (`&`, AND), increase it (`|`, OR) or flip
entries (`^`, XOR). For example, `gene & noisy | lateral & ~ marker` will start with all the genes, restrict the set to
just the noisy genes, increase the set to also include lateral genes, and finally decrease the set to exclude marker
genes. That is, it will return the set of non-marker genes that are also either noisy or lateral.
"""
struct AxisFilter
    filter_operator::FilterOperator
    axis_lookup::AxisLookup
end

function AxisFilter(context::QueryContext, filter_operator::QueryToken, axis_lookup::QueryExpression)::AxisFilter
    return AxisFilter(PARSE_FILTER_OPERATOR[filter_operator.operator.id], AxisLookup(context, axis_lookup))
end

function canonical(axis_filter::AxisFilter)::String
    return CANONICAL_FILTER_OPERATOR[axis_filter.filter_operator] * " " * canonical(axis_filter.axis_lookup)
end

function Base.isless(left::AxisFilter, right::AxisFilter)::Bool
    @assert left.filter_operator == right.filter_operator
    return left.axis_lookup < right.axis_lookup
end

"""
`FilteredAxis` = [`QueryToken`](@ref)(*axis name*) [`AxisFilter`](@ref)*

(Possibly filtered) axis to lookup a property for.

By default, all the axis entries will be used. Applying a filter will restrict the results just to the axis entries that
match the result of the filter.
"""
struct FilteredAxis
    axis_name::String
    axis_filters::Vector{AxisFilter}
end

function FilteredAxis(context::QueryContext, query_tree::QueryExpression)::FilteredAxis
    return parse_with_list_in_context(
        context,
        query_tree;
        expression_name = "filtered axis",
        separator_name = "filter operator",
        separator_operators = [OpAnd, OpOr, OpXor],
        list_name = "axis filters",
        element_type = AxisFilter,
        first_operator = true,
        operators = [OpAnd, OpOr, OpXor],
    ) do axis_name, axis_filters
        return FilteredAxis(
            parse_string_in_context(context, axis_name; name = "axis name"),
            sorted_axis_filters(axis_filters),
        )
    end
end

function sorted_axis_filters(axis_filters::Vector{AxisFilter})::Vector{AxisFilter}
    first_index = 1
    while first_index < length(axis_filters)
        last_index = first_index
        while last_index + 1 <= length(axis_filters) &&
            axis_filters[last_index].filter_operator == axis_filters[last_index + 1].filter_operator
            last_index += 1
        end
        sortable_filters = @view axis_filters[first_index:last_index]
        sort!(sortable_filters)
        first_index = last_index + 1
    end
    return axis_filters
end

function canonical(filtered_axis::FilteredAxis)::String
    result = escape_query(filtered_axis.axis_name)
    for axis_filter in filtered_axis.axis_filters
        result *= " " * canonical(axis_filter)
    end
    return result
end

"""
`MatrixLayout` = `,` | `;`

The layout of the matrix result (`,` for `RowMajor` and `;` for `ColumnMajor`).

Julia "likes" the column-major [`MatrixLayouts`](@ref), where each column is consecutive in memory. Numpy "likes" the
row-major layouts, where each row is consecutive in memory. This doesn't matter much. What *really* matters is that you
will perform operations "with the grain" of the data.
"""
@enum MatrixLayout RowMajor ColumnMajor

PARSE_MATRIX_LAYOUT = Dict(OpRowMajorSeparator => RowMajor, OpColumnMajorSeparator => ColumnMajor)

CANONICAL_MATRIX_LAYOUT = Dict(RowMajor => ",", ColumnMajor => ";")

"""
`MatrixAxes` = [`FilteredAxis`](@ref) [`MatrixLayout`](@ref) [`FilteredAxis`](@ref)

(Possibly filtered) axes of matrix to lookup a property for.

The first axis specifies the matrix rows, the second axis specifies the matrix columns. The separator specifies whether
the matrix will be in row-major layout (`,`) or column-major layout (`;`).
"""
struct MatrixAxes
    rows_axis::FilteredAxis
    matrix_layout::MatrixLayout
    columns_axis::FilteredAxis
end

function MatrixAxes(context::QueryContext, query_tree::QueryExpression)::MatrixAxes
    return parse_operation_in_context(
        context,
        query_tree;
        expression_name = "matrix axes",
        operator_name = "matrix layout separator",
        operators = [OpRowMajorSeparator, OpColumnMajorSeparator],
    ) do rows_axis, matrix_layout, columns_axis
        return MatrixAxes(
            FilteredAxis(context, rows_axis),
            PARSE_MATRIX_LAYOUT[matrix_layout.operator.id],
            FilteredAxis(context, columns_axis),
        )
    end
end

function canonical(matrix_axes::MatrixAxes)::String
    return canonical(matrix_axes.rows_axis) *
           " " *
           CANONICAL_MATRIX_LAYOUT[matrix_axes.matrix_layout] *
           " " *
           canonical(matrix_axes.columns_axis)
end

"""
`MatrixPropertyLookup` = [`MatrixAxes`](@ref) `@` [`QueryToken`](@ref)(*property name*)

Lookup a matrix property (that is, a property that gives a value to each combination of entries of two axes).
"""
struct MatrixPropertyLookup
    matrix_axes::MatrixAxes
    property_name::String
end

function MatrixPropertyLookup(context::QueryContext, query_tree::QueryExpression)::MatrixPropertyLookup
    return parse_operation_in_context(
        context,
        query_tree;
        expression_name = "matrix property lookup",
        operator_name = "lookup operator",
        operators = [OpLookup],
    ) do matrix_axes, lookup_operator, property_name
        return MatrixPropertyLookup(
            MatrixAxes(context, matrix_axes),
            parse_string_in_context(context, property_name; name = "property name"),
        )
    end
end

function canonical(matrix_lookup::MatrixPropertyLookup)::String
    return canonical(matrix_lookup.matrix_axes) * " @ " * escape_query(matrix_lookup.property_name)
end

"""
`MatrixQuery` = [`MatrixPropertyLookup`](@ref) ( `%` [`EltwiseOperation`](@ref parse_eltwise_operation) )*

A query that returns matrix data.

There's only one variant of this: looking up a matrix property and optionally passing it through a sequence of
element-wise operations.
"""
struct MatrixQuery
    matrix_lookup::MatrixPropertyLookup
    eltwise_operations::Vector{EltwiseOperation}
end

function MatrixQuery(context::QueryContext, query_tree::QueryExpression)::MatrixQuery
    return parse_with_list_in_context(
        context,
        query_tree;
        expression_name = "matrix query",
        separator_name = "eltwise operator",
        separator_operators = [OpEltwise],
        list_name = "eltwise operations",
        parse_element = parse_eltwise_operation,
        element_type = EltwiseOperation,
        operators = [OpEltwise],
    ) do matrix_lookup, eltwise_operations
        return MatrixQuery(MatrixPropertyLookup(context, matrix_lookup), eltwise_operations)
    end
end

"""
    parse_matrix_query(query_string::AbstractString)::MatrixQuery

Parse a [`MatrixQuery`](@ref) from a query string.
"""
function parse_matrix_query(query_string::AbstractString)::MatrixQuery
    query_string = prepare_query_string(query_string)
    if isempty(query_string)
        error("empty query")
    end
    query_tree = build_encoded_expression(query_string, QUERY_SYNTAX)
    context = Context(query_string, QueryOperators)
    return MatrixQuery(context, query_tree)
end

function canonical(matrix_query::MatrixQuery)::String
    result = canonical(matrix_query.matrix_lookup)
    for eltwise_operation in matrix_query.eltwise_operations
        result *= " % " * canonical(eltwise_operation)
    end
    return result
end

"""
`VectorPropertyLookup` = [`FilteredAxis`](@ref) `@` [`AxisLookup`](@ref)

Lookup a vector property (that is, a property that gives a value to each entry of an axis).
"""
struct VectorPropertyLookup
    filtered_axis::FilteredAxis
    axis_lookup::AxisLookup
end

function VectorPropertyLookup(context::QueryContext, query_tree::QueryExpression)::VectorPropertyLookup
    return parse_operation_in_context(
        context,
        query_tree;
        expression_name = "vector property lookup",
        operator_name = "lookup operator",
        operators = [OpLookup],
    ) do filtered_axis, lookup_operator, axis_lookup
        return VectorPropertyLookup(FilteredAxis(context, filtered_axis), AxisLookup(context, axis_lookup))
    end
end

function canonical(vector_lookup::VectorPropertyLookup)::String
    return canonical(vector_lookup.filtered_axis) * " @ " * canonical(vector_lookup.axis_lookup)
end

"""
`AxisEntry` = [`QueryToken`](@ref)(*axis name*) `=` [`QueryToken`](@ref)(*entry name*)

Slice a single entry from an axis.
"""
struct AxisEntry
    axis_name::String
    entry_name::String
end

function AxisEntry(context::QueryContext, query_tree::QueryExpression)::AxisEntry
    return parse_operation_in_context(
        context,
        query_tree;
        expression_name = "axis entry",
        operator_name = "equality operator",
        operators = [OpEqual],
    ) do axis_name, assignment_operator, entry_name
        return AxisEntry(
            parse_string_in_context(context, axis_name; name = "axis name"),
            parse_string_in_context(context, entry_name; name = "entry name"),
        )
    end
end

function canonical(axis_entry::AxisEntry)::String
    return escape_query(axis_entry.axis_name) * " = " * escape_query(axis_entry.entry_name)
end

"""
`MatrixSliceAxes` = [`FilteredAxis`](@ref) `,` [`AxisEntry`](@ref)

(Possibly filtered) axes of a slice of a matrix to lookup a property for.

The first axis specifies the result entries, and the second specifies the specific entry of an axis to slice.
"""
struct MatrixSliceAxes
    filtered_axis::FilteredAxis
    axis_entry::AxisEntry
end

function MatrixSliceAxes(context::QueryContext, query_tree::QueryExpression)::MatrixSliceAxes
    return parse_operation_in_context(
        context,
        query_tree;
        expression_name = "matrix slice axes",
        operator_name = "axes operator",
        operators = [OpParameterSeparator],
    ) do filtered_axis, axes_separator, axis_entry
        return MatrixSliceAxes(FilteredAxis(context, filtered_axis), AxisEntry(context, axis_entry))
    end
end

function canonical(matrix_slice_axes::MatrixSliceAxes)::String
    return canonical(matrix_slice_axes.filtered_axis) * " , " * canonical(matrix_slice_axes.axis_entry)
end

"""
`MatrixSliceLookup` = [`MatrixSliceAxes`](@ref) `@` [`QueryToken`](@ref)(*property name*)

Lookup a vector slice of a matrix property.
"""
struct MatrixSliceLookup
    matrix_slice_axes::MatrixSliceAxes
    property_name::String
end

function MatrixSliceLookup(context::QueryContext, query_tree::QueryExpression)::MatrixSliceLookup
    return parse_operation_in_context(
        context,
        query_tree;
        expression_name = "matrix slice lookup",
        operator_name = "lookup operator",
        operators = [OpLookup],
    ) do matrix_slice_axes, lookup_operator, property_name
        return MatrixSliceLookup(
            MatrixSliceAxes(context, matrix_slice_axes),
            parse_string_in_context(context, property_name; name = "property name"),
        )
    end
end

function canonical(matrix_slice_lookup::MatrixSliceLookup)::String
    return canonical(matrix_slice_lookup.matrix_slice_axes) * " @ " * escape_query(matrix_slice_lookup.property_name)
end

"""
`ReduceMatrixQuery` = [`MatrixQuery`](@ref) `%>` [`ReductionOperation`](@ref parse_reduction_operation)

Query for matrix data and reduce it to a vector.
"""
struct ReduceMatrixQuery
    matrix_query::MatrixQuery
    reduction_operation::ReductionOperation
end

function canonical(reduce_matrix_query::ReduceMatrixQuery)::String
    return canonical(reduce_matrix_query.matrix_query) * " %> " * canonical(reduce_matrix_query.reduction_operation)
end

"""
`VectorDataLookup` = [`VectorPropertyLookup`](@ref) | [`MatrixSliceLookup`](@ref) | [`ReduceMatrixQuery`](@ref)

Lookup vector data. This can be looking up a vector property, looking up a slice of a matrix property, or reducing the
results of matrix query to a vector.
"""
const VectorDataLookup = Union{VectorPropertyLookup, MatrixSliceLookup, ReduceMatrixQuery}

function parse_vector_data_lookup(context::QueryContext, query_tree::QueryExpression)::VectorDataLookup
    if check_operation(query_tree, [OpLookup]) != nothing &&
       check_operation(query_tree.left, [OpPrimarySeparator]) != nothing
        return MatrixSliceLookup(context, query_tree)
    else
        return VectorPropertyLookup(context, query_tree)
    end
end

"""
`VectorQuery` = [`VectorDataLookup`](@ref) ( `%` [`EltwiseOperation`](@ref parse_eltwise_operation) )*

A query that returns vector data. This looks up some vector data and optionally applies a series of element-wise
operations to it.
"""
struct VectorQuery
    vector_data_lookup::VectorDataLookup
    eltwise_operations::Vector{EltwiseOperation}
end

function VectorQuery(context::QueryContext, query_tree::QueryExpression)::VectorQuery
    if check_operation(query_tree, [OpReduce]) != nothing
        return parse_operation_in_context(
            context,
            query_tree;
            expression_name = "reduce matrix query",
            operator_name = "reduction operator",
            operators = [OpReduce],
        ) do matrix_query, reduction_operator, reduction_to_vector
            reduction_operation, eltwise_operations = parse_with_list_in_context(
                context,
                reduction_to_vector;
                expression_name = "reduction to vector",
                separator_name = "eltwise operator",
                separator_operators = [OpEltwise],
                list_name = "eltwise operations",
                parse_element = parse_eltwise_operation,
                element_type = EltwiseOperation,
                operators = [OpEltwise],
            ) do reduction_operation, eltwise_operations
                return parse_reduction_operation(context, reduction_operator, reduction_operation), eltwise_operations
            end
            return VectorQuery(
                ReduceMatrixQuery(MatrixQuery(context, matrix_query), reduction_operation),
                eltwise_operations,
            )
        end

    else
        return parse_with_list_in_context(
            context,
            query_tree;
            expression_name = "vector query",
            separator_name = "eltwise operator",
            separator_operators = [OpEltwise],
            list_name = "eltwise operations",
            parse_element = parse_eltwise_operation,
            element_type = EltwiseOperation,
            operators = [OpEltwise],
        ) do vector_data_lookup, eltwise_operations
            return VectorQuery(parse_vector_data_lookup(context, vector_data_lookup), eltwise_operations)
        end
    end
end

"""
    parse_vector_query(query_string::AbstractString)::VectorQuery

Parse a [`VectorQuery`](@ref) from a query string.
"""
function parse_vector_query(query_string::AbstractString)::VectorQuery
    query_string = prepare_query_string(query_string)
    if isempty(query_string)
        error("empty query")
    end
    query_tree = build_encoded_expression(query_string, QUERY_SYNTAX)
    context = Context(query_string, QueryOperators)
    return VectorQuery(context, query_tree)
end

function canonical(vector_query::VectorQuery)::String
    result = canonical(vector_query.vector_data_lookup)
    for eltwise_operation in vector_query.eltwise_operations
        result *= " % " * canonical(eltwise_operation)
    end
    return result
end

"""
`ScalarPropertyLookup` = [`QueryToken`](@ref)(*property name*)

Lookup a scalar property.
"""
struct ScalarPropertyLookup
    property_name::String
end

function ScalarPropertyLookup(context::QueryContext, query_tree::QueryExpression)::ScalarPropertyLookup
    return ScalarPropertyLookup(parse_string_in_context(context, query_tree; name = "property name"))
end

function canonical(scalar_lookup::ScalarPropertyLookup)::String
    return escape_query(scalar_lookup.property_name)
end

"""
`VectorEntryLookup` = [`AxisEntry`](@ref) `@` [`AxisLookup`](@ref)

Lookup an entry of a vector property.
"""
struct VectorEntryLookup
    axis_entry::AxisEntry
    axis_lookup::AxisLookup
end

function VectorEntryLookup(context::QueryContext, query_tree::QueryExpression)::VectorEntryLookup
    return parse_operation_in_context(
        context,
        query_tree;
        expression_name = "vector entry lookup",
        operator_name = "lookup operator",
        operators = [OpLookup],
    ) do axis_entry, lookup_operator, axis_lookup
        return VectorEntryLookup(AxisEntry(context, axis_entry), AxisLookup(context, axis_lookup))
    end
end

function canonical(vector_entry_lookup::VectorEntryLookup)::String
    return canonical(vector_entry_lookup.axis_entry) * " @ " * canonical(vector_entry_lookup.axis_lookup)
end

"""
`MatrixEntryAxes` = [`AxisEntry`](@ref) `,` [`AxisEntry`](@ref)

Locate a single entry of both axes of a matrix.
"""
struct MatrixEntryAxes
    rows_entry::AxisEntry
    columns_entry::AxisEntry
end

function MatrixEntryAxes(context::QueryContext, query_tree::QueryExpression)::MatrixEntryAxes
    return parse_operation_in_context(
        context,
        query_tree;
        expression_name = "matrix entry axes",
        operator_name = "lookup operator",
        operators = [OpPrimarySeparator],
    ) do rows_entry, axes_operator, columns_entry
        return MatrixEntryAxes(AxisEntry(context, rows_entry), AxisEntry(context, columns_entry))
    end
end

function canonical(matrix_entry_axes::MatrixEntryAxes)::String
    return canonical(matrix_entry_axes.rows_entry) * " , " * canonical(matrix_entry_axes.columns_entry)
end

"""
`MatrixEntryLookup` = [`MatrixEntryAxes`](@ref) `@` [`QueryToken`](@ref)(*property name*)

Lookup an entry of a matrix property.
"""
struct MatrixEntryLookup
    matrix_entry_axes::MatrixEntryAxes
    property_name::String
end

function MatrixEntryLookup(context::QueryContext, query_tree::QueryExpression)::MatrixEntryLookup
    return parse_operation_in_context(
        context,
        query_tree;
        expression_name = "matrix entry lookup",
        operator_name = "lookup operator",
        operators = [OpLookup],
    ) do matrix_entry_axes, lookup_operator, property_name
        return MatrixEntryLookup(
            MatrixEntryAxes(context, matrix_entry_axes),
            parse_string_in_context(context, property_name; name = "property name"),
        )
    end
end

function canonical(matrix_entry_lookup::MatrixEntryLookup)::String
    return canonical(matrix_entry_lookup.matrix_entry_axes) * " @ " * escape_query(matrix_entry_lookup.property_name)
end

"""
`ReduceVectorQuery` = [`VectorQuery`](@ref) `%>` [`ReductionOperation`](@ref parse_reduction_operation)

Query for vector data and reduce it to a scalar. The vector query may itself be a reduction of a matrix to a vector,
allowing reducing a matrix to a scalar (in two reduction steps).
"""
struct ReduceVectorQuery
    vector_query::VectorQuery
    reduction_operation::ReductionOperation
end

function canonical(reduce_vector_query::ReduceVectorQuery)::String
    return canonical(reduce_vector_query.vector_query) * " %> " * canonical(reduce_vector_query.reduction_operation)
end

"""
`ScalarDataLookup` = [`ScalarPropertyLookup`](@ref) | [`ReduceVectorQuery`](@ref) | [`VectorEntryLookup`](@ref) | [`MatrixEntryLookup`](@ref)

Lookup scalar data.
"""
const ScalarDataLookup = Union{ScalarPropertyLookup, ReduceVectorQuery, VectorEntryLookup, MatrixEntryLookup}

function parse_scalar_data_lookup(context::QueryContext, query_tree::QueryExpression)::ScalarDataLookup
    if check_operation(query_tree, [OpLookup]) == nothing
        return ScalarPropertyLookup(context, query_tree)
    elseif check_operation(query_tree.left, [OpPrimarySeparator]) != nothing
        return MatrixEntryLookup(context, query_tree)
    else
        return VectorEntryLookup(context, query_tree)
    end
end

"""
`ScalarQuery` = [`ScalarDataLookup`](@ref) ( `%` [`EltwiseOperation`](@ref parse_eltwise_operation) )*

A query that returns scalar data.
"""
struct ScalarQuery
    scalar_data_lookup::ScalarDataLookup
    eltwise_operations::Vector{EltwiseOperation}
end

function canonical(scalar_query::ScalarQuery)::String
    result = canonical(scalar_query.scalar_data_lookup)
    for eltwise_operation in scalar_query.eltwise_operations
        result *= " % " * canonical(eltwise_operation)
    end
    return result
end

"""
    parse_scalar_query(query_string::AbstractString)::ScalarQuery

Parse a [`ScalarQuery`](@ref) from a query string.
"""
function parse_scalar_query(query_string::AbstractString)::ScalarQuery
    query_string = prepare_query_string(query_string)
    if isempty(query_string)
        error("empty query")
    end
    query_tree = build_encoded_expression(query_string, QUERY_SYNTAX)
    context = Context(query_string, QueryOperators)

    if check_operation(query_tree, [OpReduce]) != nothing
        return parse_operation_in_context(
            context,
            query_tree;
            expression_name = "reduce vector query",
            operator_name = "reduction operator",
            operators = [OpReduce],
        ) do matrix_query, reduction_operator, reduction_to_vector
            reduction_operation, eltwise_operations = parse_with_list_in_context(
                context,
                reduction_to_vector;
                expression_name = "reduction to scalar",
                separator_name = "eltwise operator",
                separator_operators = [OpEltwise],
                list_name = "eltwise operations",
                parse_element = parse_eltwise_operation,
                element_type = EltwiseOperation,
                operators = [OpEltwise],
            ) do reduction_operation, eltwise_operations
                return parse_reduction_operation(context, reduction_operator, reduction_operation), eltwise_operations
            end
            return ScalarQuery(
                ReduceVectorQuery(VectorQuery(context, matrix_query), reduction_operation),
                eltwise_operations,
            )
        end

    elseif check_operation(query_tree, [OpEltwise]) != nothing
        return parse_with_list_in_context(
            context,
            query_tree;
            expression_name = "scalar data lookup",
            separator_name = "eltwise operator",
            separator_operators = [OpEltwise],
            list_name = "eltwise operations",
            parse_element = parse_eltwise_operation,
            element_type = EltwiseOperation,
            operators = [OpEltwise],
        ) do scalar_data_lookup, eltwise_operations
            return ScalarQuery(parse_scalar_data_lookup(context, scalar_data_lookup), eltwise_operations)
        end

    else
        return ScalarQuery(parse_scalar_data_lookup(context, query_tree), EltwiseOperation[])
    end
end

end  # module