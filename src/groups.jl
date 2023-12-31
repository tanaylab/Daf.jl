"""
A common data pattern is for entries of one axis to be grouped together. When this happens, we can associate with each
entry a data property of the group, or we can aggregate a data property of the entries into a data property of the
group. For example, if we group cells into types, we can obtain a cell color by looking up the color of the type of each
cell; or if each cell has an age, we can compute the mean cell age of each type.

The following functions implement these lookup and aggregation operations.
"""
module Groups

export aggregate_group_vector
export count_groups_matrix
export get_chained_vector

using Daf.Data
using Daf.DataQueries
using Daf.Formats
using Daf.StorageTypes
using NamedArrays

import Daf.DataQueries.axis_of_property
import Daf.DataQueries.collect_counts_axis
import Daf.DataQueries.compute_counts_matrix
import Daf.DataQueries.compute_property_lookup

"""
    get_chained_vector(
        daf::DafReader,
        axis::AbstractString,
        names::Vector[S];
        [default::Union{StorageScalar, UndefInitializer} = undef]
    ) -> StorageVector where {S <: AbstractString}

Given an `axis` and a series of `names` properties, expect each property value to be a string, used to lookup its value
in a property axis of the same name, until the last property that is actually returned. For example, if the `axis` is
`cell` and the `names` are `["batch", "donor", "sex"]`, then fetch the sex of the donor of the batch of each cell.

The group axis is assumed to have the same name as the named property (e.g., there would be `batch` and `donor` axes).
It is also possible to have the property name begin with the axis name followed by a `.suffix`, for example, fetching
`["type.manual", "color"]` will fetch the `color` from the `type` axis, based on the value of the `type.manual` of each
cell.

If, at any place along the chain, the group property value is the empty string, then `default` must be specified, and
will be used for the final result.
"""
function get_chained_vector(
    daf::DafReader,
    axis::AbstractString,
    names::Vector{S};
    default::Union{StorageScalar, UndefInitializer} = undef,
)::NamedArray where {S <: AbstractString}
    if isempty(names)
        error("empty names for get_chained_vector")
    end

    values, missing_mask = compute_property_lookup(daf, axis, names, Set{String}(), nothing, default != undef)

    if default != undef
        @assert missing_mask != nothing
        values[missing_mask] .= default
    else
        @assert missing_mask == nothing
    end

    return values
end

"""
    function aggregate_group_vector(
        aggregate::Function,
        daf::DafReader;
        axis::AbstractString,
        names::Vector{N},
        groups::Vector{G};
        [default::Union{StorageScalar, UndefInitializer} = undef,
        empty::Union{StorageScalar, UndefInitializer} = undef]
    )::NamedArray where {S <: AbstractString, G <: AbstractString}

Given an `axis` of the `daf` data (e.g., cell), a `name` vector property of this axis (e.g., age) and a `group` vector
property of this axis (e.g., type), whose value is the name of an entry of a group axis, then return a vector assigning a
value for each entry of the group axis, which is the `aggregate` of the values of all the original axis entries grouped
into that entry (e.g., the mean age of the cells in each type).

By default, the `group_axis` is assumed to have the same name as the `group` property (e.g., there would be a type
property per cell, and a type axis). It is possible to override this by specifying an explicit `group_axis` if the
actual name is different.

The `group` property must have a string element type. An empty string means that the entry belongs to no group (e.g., we
don't have a type assignment for some cell), so its value will not be aggregated into any group. In addition, a group
may be empty (e.g., no cell is assigned to some type). In this case, `default` must be specified, and is used for the
empty groups.
"""
function aggregate_group_vector(
    aggregate::Function,
    daf::DafReader,
    axis::AbstractString,
    names::Vector{N},
    groups::Vector{G};
    default::Union{StorageScalar, UndefInitializer} = undef,
    empty::Union{StorageScalar, UndefInitializer} = undef,
)::NamedArray where {N <: AbstractString, G <: AbstractString}
    value_of_entries = get_chained_vector(daf, axis, names)

    group_axis, group_of_entries, all_group_values =
        collect_counts_axis(daf, axis, groups, Set{String}(), nothing, default)

    if has_axis(daf, group_axis)
        named_groups = get_vector(daf, group_axis, "name")
    else
        named_groups = NamedArray(all_group_values; names = (all_group_values,), dimnames = (group_axis,))
    end

    value_of_groups = [
        aggregate_group_value(
            aggregate,
            daf,
            axis,
            value_of_entries.array,
            group_axis,
            group_of_entries,
            group_index,
            group_name,
            empty,
        ) for (group_index, group_name) in enumerate(all_group_values)
    ]

    return NamedArray(value_of_groups, named_groups.dicts, named_groups.dimnames)
end

function aggregate_group_value(
    aggregate::Function,
    daf::DafReader,
    axis::AbstractString,
    value_of_entries::StorageVector,
    group_axis::AbstractString,
    group_of_entries::AbstractVector{String},
    group_index::Int,
    group_name::AbstractString,
    empty::Union{StorageScalar, UndefInitializer} = undef,
)::StorageScalar
    mask_of_entries_of_groups = group_of_entries .== group_name
    value_of_entries_of_groups = value_of_entries[mask_of_entries_of_groups]
    if !isempty(value_of_entries_of_groups)
        return aggregate(value_of_entries_of_groups)
    elseif empty == undef
        error(
            "empty group: $(group_name)\n" *
            "with the index: $(group_index)\n" *
            "in the group: $(group_axis)\n" *
            "for the axis: $(axis)\n" *
            "in the daf data: $(daf.name)",
        )
    else
        return empty
    end
end

"""
    function count_groups_matrix(
        daf::DafReader,
        axis::AbstractString,
        rows_names::Vector{R},
        columns_names::Vector{C};
        type::Type = UInt32,
        rows_default::Union{StorageScalar, Nothing},
        columns_default::Union{StorageScalar, Nothing},
    )::NamedMatrix

Given an `axis` of the `daf` data (e.g., cell), fetch two chained vector properties for it using
[`get_chained_vector`](@ref), and generate a matrix where each entry is the number of instances which have each specific
combination of the values. For example, if `axis` is `cell`, `rows_names` is `["batch", "age"]`, and `columns_names` is
`["type", "color"]`, then the matrix will have the different ages as rows, different colors as columns, and each entry
will count the number of cells with a specific age and a specific color.

If there exists an axis with the same name as the final row and/or column name, it is used to determine the set of valid
values and their order. Otherwise, the entries are sorted in ascending order.

By default, the data type of the matrix is `UInt32`, which is a reasonable trade-off between expressiveness (up to 4G)
and size (only 4 bytes per entry). You can override this using the `type` parameter.

!!! note

    The typically the chained value type is a string; in this case, entries with an empty string values (ungrouped
    entries) are not counted. However, the values can also be numeric. In either case, it is expected that the set of
    actually present values will be small, otherwise the resulting matrix will be very large.
"""
function count_groups_matrix(
    daf::DafReader,
    axis::AbstractString,
    rows_names::Vector{R},
    columns_names::Vector{C};
    type::Type = UInt32,
    rows_default::Union{StorageScalar, UndefInitializer} = undef,
    columns_default::Union{StorageScalar, UndefInitializer} = undef,
)::NamedMatrix where {R <: AbstractString, C <: AbstractString}
    rows_axis, row_value_of_entries, all_row_values =
        collect_counts_axis(daf, axis, rows_names, Set{String}(), nothing, rows_default)
    columns_axis, column_value_of_entries, all_column_values =
        collect_counts_axis(daf, axis, columns_names, Set{String}(), nothing, columns_default)

    return compute_counts_matrix(
        rows_axis,
        row_value_of_entries,
        all_row_values,
        columns_axis,
        column_value_of_entries,
        all_column_values,
        UInt32,
    )
end

end # module
