"""
The [`ReadDaf`](@ref) and [`WriteDaf`](@ref) interfaces specify a high-level API for accessing `Daf` data. This API is
implemented here, on top of the low-level [`ReadFormat`](@ref) and [`WriteFormat`](@ref) API.

Data properties are identified by a unique name given the axes they are based on. That is, there is a separate namespace
for scalar properties, vector properties for each specific axis, and matrix properties for each *unordered* pair of
axes.

For matrices, we keep careful track of their [`MatrixLayouts`](@ref). Returned matrices are always in column-major
layout, using [`relayout!`](@ref) if necessary. As this is an expensive operation, we'll cache the result in memory.
Similarly, we cache the results of applying a query to the data. We allow clearing the cache to reduce memory usage, if
necessary.

The data API is the high-level API intended to be used from outside the package, and is therefore re-exported from the
top-level `Daf` namespace. It provides additional functionality on top of the low-level [`ReadFormat`](@ref) and
[`WriteFormat`](@ref) implementations, accepting more general data types, automatically dealing with [`relayout!`](@ref)
when needed, and even providing a language for [`Queries`](@ref) for flexible extraction of data from the container.
"""
module Data

export add_axis!
export axis_length
export axis_names
export delete_axis!
export delete_matrix!
export delete_scalar!
export delete_vector!
export description
export empty_dense_matrix!
export empty_dense_vector!
export empty_sparse_matrix!
export empty_sparse_vector!
export get_axis
export get_matrix
export get_scalar
export get_vector
export has_axis
export has_matrix
export has_scalar
export has_vector
export matrix_names
export matrix_query
export scalar_names
export scalar_query
export set_matrix!
export set_scalar!
export set_vector!
export vector_names
export vector_query

using Daf.Formats
using Daf.MatrixLayouts
using Daf.Messages
using Daf.Queries
using Daf.Registry
using Daf.StorageTypes
using NamedArrays
using SparseArrays

import Daf.Formats
import Daf.Formats.ReadFormat
import Daf.Formats.WriteFormat
import Daf.Queries.CmpEqual
import Daf.Queries.CmpGreaterOrEqual
import Daf.Queries.CmpGreaterThan
import Daf.Queries.CmpLessOrEqual
import Daf.Queries.CmpLessThan
import Daf.Queries.CmpMatch
import Daf.Queries.CmpNotEqual
import Daf.Queries.CmpNotMatch
import Daf.Queries.FilterAnd
import Daf.Queries.FilterOr
import Daf.Queries.FilterXor

function Base.getproperty(daf::ReadDaf, property::Symbol)::Any
    if property == :name
        return daf.internal.name
    else
        return getfield(daf, property)
    end
end

"""
    has_scalar(daf::ReadDaf, name::AbstractString)::Bool

Check whether a scalar property with some `name` exists in `daf`.
"""
function has_scalar(daf::ReadDaf, name::AbstractString)::Bool
    return Formats.format_has_scalar(daf, name)
end

"""
    set_scalar!(
        daf::WriteDaf,
        name::AbstractString,
        value::StorageScalar
        [; overwrite::Bool]
    )::Nothing

Set the `value` of a scalar property with some `name` in `daf`.

If `overwrite` is `false` (the default), this first verifies the `name` scalar property does not exist.
"""
function set_scalar!(daf::WriteDaf, name::AbstractString, value::StorageScalar; overwrite::Bool = false)::Nothing
    if !overwrite
        require_no_scalar(daf, name)
    end

    Formats.format_set_scalar!(daf, name, value)
    return nothing
end

"""
    delete_scalar!(
        daf::WriteDaf,
        name::AbstractString;
        must_exist::Bool = true,
    )::Nothing

Delete a scalar property with some `name` from `daf`.

If `must_exist` is `true` (the default), this first verifies the `name` scalar property exists in `daf`.
"""
function delete_scalar!(daf::WriteDaf, name::AbstractString; must_exist::Bool = true)::Nothing
    if must_exist
        require_scalar(daf, name)
    elseif !has_scalar(daf, name)
        return nothing
    end

    Formats.format_delete_scalar!(daf, name)
    return nothing
end

"""
    scalar_names(daf::ReadDaf)::Set{String}

The names of the scalar properties in `daf`.
"""
function scalar_names(daf::ReadDaf)::AbstractSet{String}
    return Formats.format_scalar_names(daf)
end

"""
    get_scalar(
        daf::ReadDaf,
        name::AbstractString[; default::StorageScalar]
    )::StorageScalar

Get the value of a scalar property with some `name` in `daf`.

If `default` is not specified, this first verifies the `name` scalar property exists in `daf`.
"""
function get_scalar(daf::ReadDaf, name::AbstractString; default::Union{StorageScalar, Nothing} = nothing)::StorageScalar
    if default == nothing
        require_scalar(daf, name)
    elseif !has_scalar(daf, name)
        return default
    end

    return Formats.format_get_scalar(daf, name)
end

function require_scalar(daf::ReadDaf, name::AbstractString)::Nothing
    if !has_scalar(daf, name)
        error("missing scalar property: $(name)\nin the daf data: $(daf.name)")
    end
    return nothing
end

function require_no_scalar(daf::ReadDaf, name::AbstractString)::Nothing
    if has_scalar(daf, name)
        error("existing scalar property: $(name)\nin the daf data: $(daf.name)")
    end
    return nothing
end

"""
    has_axis(daf::ReadDaf, axis::AbstractString)::Bool

Check whether some `axis` exists in `daf`.
"""
function has_axis(daf::ReadDaf, axis::AbstractString)::Bool
    return Formats.format_has_axis(daf, axis)
end

"""
    add_axis!(
        daf::WriteDaf,
        axis::AbstractString,
        entries::DenseVector{String}
    )::Nothing

Add a new `axis` `daf`.

This first verifies the `axis` does not exist and that the `entries` are unique.
"""
function add_axis!(daf::WriteDaf, axis::AbstractString, entries::DenseVector{String})::Nothing
    require_no_axis(daf, axis)

    if !allunique(entries)
        error("non-unique entries for new axis: $(axis)\nin the daf data: $(daf.name)")
    end

    Formats.format_add_axis!(daf, axis, entries)
    return nothing
end

"""
    delete_axis!(
        daf::WriteDaf,
        axis::AbstractString;
        must_exist::Bool = true,
    )::Nothing

Delete an `axis` from the `daf`. This will also delete any vector or matrix properties that are based on this axis.

If `must_exist` is `true` (the default), this first verifies the `axis` exists in the `daf`.
"""
function delete_axis!(daf::WriteDaf, axis::AbstractString; must_exist::Bool = true)::Nothing
    if must_exist
        require_axis(daf, axis)
    elseif !has_axis(daf, axis)
        return nothing
    end

    for name in vector_names(daf, axis)
        Formats.format_delete_vector!(daf, axis, name)
    end

    for other_axis in axis_names(daf)
        for name in matrix_names(daf, axis, other_axis)
            Formats.format_delete_matrix!(daf, axis, other_axis, name)
        end
    end

    Formats.format_delete_axis!(daf, axis)
    return nothing
end

"""
    axis_names(daf::ReadDaf)::AbstractSet{String}

The names of the axes of `daf`.
"""
function axis_names(daf::ReadDaf)::AbstractSet{String}
    return Formats.format_axis_names(daf)
end

"""
    get_axis(daf::ReadDaf, axis::AbstractString)::DenseVector{String}

The unique names of the entries of some `axis` of `daf`. This is similar to doing [`get_vector`](@ref) for the special
`name` property, except that it returns a simple vector of strings instead of a `NamedVector`.

This first verifies the `axis` exists in `daf`.
"""
function get_axis(daf::ReadDaf, axis::AbstractString)::AbstractVector{String}
    require_axis(daf, axis)
    return as_read_only(Formats.format_get_axis(daf, axis))
end

"""
    axis_length(daf::ReadDaf, axis::AbstractString)::Int64

The number of entries along the `axis` in `daf`.

This first verifies the `axis` exists in `daf`.
"""
function axis_length(daf::ReadDaf, axis::AbstractString)::Int64
    require_axis(daf, axis)
    return Formats.format_axis_length(daf, axis)
end

function require_axis(daf::ReadDaf, axis::AbstractString)::Nothing
    if !has_axis(daf, axis)
        error("missing axis: $(axis)\nin the daf data: $(daf.name)")
    end
    return nothing
end

function require_no_axis(daf::ReadDaf, axis::AbstractString)::Nothing
    if has_axis(daf, axis)
        error("existing axis: $(axis)\nin the daf data: $(daf.name)")
    end
    return nothing
end

"""
    has_vector(daf::ReadDaf, axis::AbstractString, name::AbstractString)::Bool

Check whether a vector property with some `name` exists for the `axis` in `daf`. This is always true for the special
`name` property.

This first verifies the `axis` exists in `daf`.
"""
function has_vector(daf::ReadDaf, axis::AbstractString, name::AbstractString)::Bool
    require_axis(daf, axis)
    return name == "name" || Formats.format_has_vector(daf, axis, name)
end

"""
    set_vector!(
        daf::WriteDaf,
        axis::AbstractString,
        name::AbstractString,
        vector::Union{StorageScalar, StorageVector}
        [; overwrite::Bool]
    )::Nothing

Set a vector property with some `name` for some `axis` in `daf`.

If the `vector` specified is actually a [`StorageScalar`](@ref), the stored vector is filled with this value.

This first verifies the `axis` exists in `daf`, that the property name isn't `name`, and that the `vector` has the
appropriate length. If `overwrite` is `false` (the default), this also verifies the `name` vector does not exist for the
`axis`.
"""
function set_vector!(
    daf::WriteDaf,
    axis::AbstractString,
    name::AbstractString,
    vector::Union{StorageScalar, StorageVector};
    overwrite::Bool = false,
)::Nothing
    require_not_name(daf, axis, name)
    require_axis(daf, axis)

    if vector isa StorageVector
        require_axis_length(daf, "vector length", length(vector), axis)
        if vector isa NamedVector
            require_axis_names(daf, axis, "entry names of the: vector", names(vector, 1))
        end
    end

    if !overwrite
        require_no_vector(daf, axis, name)
    end

    Formats.format_set_vector!(daf, axis, name, vector)
    return nothing
end

"""
    empty_dense_vector!(
        daf::WriteDaf,
        axis::AbstractString,
        name::AbstractString,
        eltype::Type{T}
        [; overwrite::Bool]
    )::NamedVector{T, DenseVector{T}} where {T <: Number}

Create an empty dense vector property with some `name` for some `axis` in `daf`.

The returned vector will be uninitialized; the caller is expected to fill it with values. This saves creating a copy of
the vector before setting it in the data, which makes a huge difference when creating vectors on disk (using memory
mapping). For this reason, this does not work for strings, as they do not have a fixed size.

This first verifies the `axis` exists in `daf` and that the property name isn't `name`. If `overwrite` is `false` (the
default), this also verifies the `name` vector does not exist for the `axis`.
"""
function empty_dense_vector!(
    daf::WriteDaf,
    axis::AbstractString,
    name::AbstractString,
    eltype::Type{T};
    overwrite::Bool = false,
)::NamedVector{T} where {T <: Number}
    require_not_name(daf, axis, name)
    require_axis(daf, axis)

    if !overwrite
        require_no_vector(daf, axis, name)
    end

    return as_named_vector(daf, axis, Formats.format_empty_dense_vector!(daf, axis, name, eltype))
end

"""
    empty_sparse_vector!(
        daf::WriteDaf,
        axis::AbstractString,
        name::AbstractString,
        eltype::Type{T},
        nnz::Integer,
        indtype::Type{I}
        [; overwrite::Bool]
    )::NamedVector{T, SparseVector{T, I}} where {T <: Number, I <: Integer}

Create an empty dense vector property with some `name` for some `axis` in `daf`.

The returned vector will be uninitialized; the caller is expected to fill it with values. This means manually filling
the `nzind` and `nzval` vectors. Specifying the `nnz` makes their sizes known in advance, to allow pre-allocating disk
data. For this reason, this does not work for strings, as they do not have a fixed size.

This severely restricts the usefulness of this function, because typically `nnz` is only know after fully computing the
matrix. Still, in some cases a large sparse vector is created by concatenating several smaller ones; this function
allows doing so directly into the data vector, avoiding a copy in case of memory-mapped disk formats.

!!! warning

    It is the caller's responsibility to fill the three vectors with valid data. **There's no safety net if you mess
    this up**. Specifically, you must ensure:

      - `nzind[1] == 1`
      - `nzind[i] <= nzind[i + 1]`
      - `nzind[end] == nnz`

This first verifies the `axis` exists in `daf` and that the property name isn't `name`. If `overwrite` is `false` (the
default), this also verifies the `name` vector does not exist for the `axis`.
"""
function empty_sparse_vector!(
    daf::WriteDaf,
    axis::AbstractString,
    name::AbstractString,
    eltype::Type{T},
    nnz::Integer,
    indtype::Type{I};
    overwrite::Bool = false,
)::NamedVector{T, SparseVector{T, I}} where {T <: Number, I <: Integer}
    require_not_name(daf, axis, name)
    require_axis(daf, axis)

    if !overwrite
        require_no_vector(daf, axis, name)
    end

    return as_named_vector(daf, axis, Formats.format_empty_sparse_vector!(daf, axis, name, eltype, nnz, indtype))
end

"""
    delete_vector!(
        daf::WriteDaf,
        axis::AbstractString,
        name::AbstractString;
        must_exist::Bool = true,
    )::Nothing

Delete a vector property with some `name` for some `axis` from `daf`.

This first verifies the `axis` exists in `daf` and that the property name isn't `name`. If `must_exist` is `true` (the
default), this also verifies the `name` vector exists for the `axis`.
"""
function delete_vector!(daf::WriteDaf, axis::AbstractString, name::AbstractString; must_exist::Bool = true)::Nothing
    require_not_name(daf, axis, name)
    require_axis(daf, axis)

    if must_exist
        require_vector(daf, axis, name)
    elseif !has_vector(daf, axis, name)
        return nothing
    end

    Formats.format_delete_vector!(daf, axis, name)
    return nothing
end

"""
    vector_names(daf::ReadDaf, axis::AbstractString)::Set{String}

The names of the vector properties for the `axis` in `daf`, **not** including the special `name` property.

This first verifies the `axis` exists in `daf`.
"""
function vector_names(daf::ReadDaf, axis::AbstractString)::AbstractSet{String}
    require_axis(daf, axis)
    return Formats.format_vector_names(daf, axis)
end

"""
    get_vector(
        daf::ReadDaf,
        axis::AbstractString,
        name::AbstractString
        [; default::Union{StorageScalar, StorageVector}]
    )::NamedVector

Get the vector property with some `name` for some `axis` in `daf`. The names of the result are the names of the vector
entries (same as returned by [`get_axis`](@ref)). The special property `name` returns an array whose values are also the
(read-only) names of the entries of the axis.

This first verifies the `axis` exists in `daf`. If `default` is not specified, this first verifies the `name` vector
exists in `daf`. Otherwise, if `default` is a `StorageVector`, it has to be of the same size as the `axis`, and is
returned. Otherwise, a new `Vector` is created of the correct size containing the `default`, and is returned.
"""
function get_vector(
    daf::ReadDaf,
    axis::AbstractString,
    name::AbstractString;
    default::Union{StorageScalar, StorageVector, Nothing} = nothing,
)::NamedArray
    require_axis(daf, axis)

    if name == "name"
        return as_named_vector(daf, axis, as_read_only(Formats.format_get_axis(daf, axis)))
    end

    if default isa StorageVector
        require_axis_length(daf, "default length", length(default), axis)
        if default isa NamedVector
            require_axis_names(daf, axis, "entry names of the: default vector", names(default, 1))
        end
    end

    vector = nothing
    if !has_vector(daf, axis, name)
        if default isa StorageVector
            vector = default
        elseif default isa StorageScalar
            vector = fill(default, axis_length(daf, axis))
        end
    end

    if vector == nothing
        require_vector(daf, axis, name)
        vector = Formats.format_get_vector(daf, axis, name)
        if !(vector isa StorageVector)
            error(  # untested
                "format_get_vector for daf format: $(typeof(daf))\n" *
                "returned invalid Daf.StorageVector: $(typeof(vector))",
            )
        end
        if length(vector) != axis_length(daf, axis)
            error( # untested
                "format_get_vector for daf format: $(typeof(daf))\n" *
                "returned vector length: $(length(vector))\n" *
                "instead of axis: $(axis)\n" *
                "length: $(axis_length(daf, axis))\n" *
                "in the daf data: $(daf.name)",
            )
        end
    end

    return as_named_vector(daf, axis, vector)
end

function require_vector(daf::ReadDaf, axis::AbstractString, name::AbstractString)::Nothing
    if !has_vector(daf, axis, name)
        error("missing vector property: $(name)\nfor the axis: $(axis)\nin the daf data: $(daf.name)")
    end
    return nothing
end

function require_no_vector(daf::ReadDaf, axis::AbstractString, name::AbstractString)::Nothing
    if has_vector(daf, axis, name)
        error("existing vector property: $(name)\nfor the axis: $(axis)\nin the daf data: $(daf.name)")
    end
    return nothing
end

"""
    has_matrix(
        daf::ReadDaf,
        rows_axis::AbstractString,
        columns_axis::AbstractString,
        name::AbstractString,
    )::Bool

Check whether a matrix property with some `name` exists for the `rows_axis` and the `columns_axis` in `daf`. Since this
is Julia, this means a column-major matrix. A daf may contain two copies of the same data, in which case it would report
the matrix under both axis orders.

This first verifies the `rows_axis` and `columns_axis` exists in `daf`.
"""
function has_matrix(daf::ReadDaf, rows_axis::AbstractString, columns_axis::AbstractString, name::AbstractString)::Bool
    require_axis(daf, rows_axis)
    require_axis(daf, columns_axis)
    return Formats.format_has_matrix(daf, rows_axis, columns_axis, name)
end

"""
    set_matrix!(
        daf::WriteDaf,
        rows_axis::AbstractString,
        columns_axis::AbstractString,
        name::AbstractString,
        matrix::StorageMatrix
        [; overwrite::Bool]
    )::Nothing

Set the matrix property with some `name` for some `rows_axis` and `columns_axis` in `daf`. Since this is Julia, this
should be a column-major `matrix`.

If the `matrix` specified is actually a [`StorageScalar`](@ref), the stored matrix is filled with this value.

This first verifies the `rows_axis` and `columns_axis` exist in `daf`, that the `matrix` is column-major of the
appropriate size. If `overwrite` is `false` (the default), this also verifies the `name` matrix does not exist for the
`rows_axis` and `columns_axis`.
"""
function set_matrix!(
    daf::WriteDaf,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
    matrix::Union{StorageScalar, StorageMatrix};
    overwrite::Bool = false,
)::Nothing
    require_axis(daf, rows_axis)
    require_axis(daf, columns_axis)

    if matrix isa StorageMatrix
        require_column_major(matrix)
        require_axis_length(daf, "matrix rows", size(matrix, Rows), rows_axis)
        require_axis_length(daf, "matrix columns", size(matrix, Columns), columns_axis)
        if matrix isa NamedMatrix
            require_axis_names(daf, rows_axis, "row names of the: matrix", names(matrix, 1))
            require_axis_names(daf, columns_axis, "column names of the: matrix", names(matrix, 2))
        end
    end

    if !overwrite
        require_no_matrix(daf, rows_axis, columns_axis, name)
    end

    Formats.format_set_matrix!(daf, rows_axis, columns_axis, name, matrix)
    return nothing
end

"""
    empty_dense_matrix!(
        daf::WriteDaf,
        rows_axis::AbstractString,
        columns_axis::AbstractString,
        name::AbstractString,
        eltype::Type{T}
        [; overwrite::Bool]
    )::NamedMatrix{T, DenseMatrix{T}} where {T <: Number}

Create an empty dense matrix property with some `name` for some `rows_axis` and `columns_axis` in `daf`. Since this is
Julia, this will be a column-major `matrix`.

The returned matrix will be uninitialized; the caller is expected to fill it with values. This saves creating a copy of
the matrix before setting it in `daf`, which makes a huge difference when creating matrices on disk (using memory
mapping). For this reason, this does not work for strings, as they do not have a fixed size.

This first verifies the `rows_axis` and `columns_axis` exist in `daf`, that the `matrix` is column-major of the
appropriate size. If `overwrite` is `false` (the default), this also verifies the `name` matrix does not exist for the
`rows_axis` and `columns_axis`.
"""
function empty_dense_matrix!(
    daf::WriteDaf,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
    eltype::Type{T};
    overwrite::Bool = false,
)::NamedMatrix{T} where {T <: Number}
    require_axis(daf, rows_axis)
    require_axis(daf, columns_axis)

    if !overwrite
        require_no_matrix(daf, rows_axis, columns_axis, name)
    end

    return as_named_matrix(
        daf,
        rows_axis,
        columns_axis,
        Formats.format_empty_dense_matrix!(daf, rows_axis, columns_axis, name, eltype),
    )
end

"""
    empty_sparse_matrix!(
        daf::WriteDaf,
        rows_axis::AbstractString,
        columns_axis::AbstractString,
        name::AbstractString,
        eltype::Type{T},
        nnz::Integer,
        intdype::Type{I}
        [; overwrite::Bool]
    )::NamedMatrix{T, SparseMatrixCSC{T, I}} where {T <: Number, I <: Integer}

Create an empty sparse matrix property with some `name` for some `rows_axis` and `columns_axis` in `daf`.

The returned matrix will be uninitialized; the caller is expected to fill it with values. This means manually filling
the `colptr`, `rowval` and `nzval` vectors. Specifying the `nnz` makes their sizes known in advance, to allow
pre-allocating disk space. For this reason, this does not work for strings, as they do not have a fixed size.

This severely restricts the usefulness of this function, because typically `nnz` is only know after fully computing the
matrix. Still, in some cases a large sparse matrix is created by concatenating several smaller ones; this function
allows doing so directly into the data, avoiding a copy in case of memory-mapped disk formats.

!!! warning

    It is the caller's responsibility to fill the three vectors with valid data. **There's no safety net if you mess
    this up**. Specifically, you must ensure:

      - `colptr[1] == 1`
      - `colptr[end] == nnz + 1`
      - `colptr[i] <= colptr[i + 1]`
      - for all `j`, for all `i` such that `colptr[j] <= i` and `i + 1 < colptr[j + 1]`, `1 <= rowptr[i] < rowptr[i + 1] <= nrows`

This first verifies the `rows_axis` and `columns_axis` exist in `daf`. If `overwrite` is `false` (the default), this
also verifies the `name` matrix does not exist for the `rows_axis` and `columns_axis`.
"""
function empty_sparse_matrix!(
    daf::WriteDaf,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
    eltype::Type{T},
    nnz::Integer,
    indtype::Type{I};
    overwrite::Bool = false,
)::NamedMatrix{T, SparseMatrixCSC{T, I}} where {T <: Number, I <: Integer}
    require_axis(daf, rows_axis)
    require_axis(daf, columns_axis)

    if !overwrite
        require_no_matrix(daf, rows_axis, columns_axis, name)
    end

    return as_named_matrix(
        daf,
        rows_axis,
        columns_axis,
        Formats.format_empty_sparse_matrix!(daf, rows_axis, columns_axis, name, eltype, nnz, indtype),
    )
end

"""
    delete_matrix!(
        daf::WriteDaf,
        rows_axis::AbstractString,
        columns_axis::AbstractString,
        name::AbstractString;
        must_exist::Bool = true,
    )::Nothing

Delete a matrix property with some `name` for some `rows_axis` and `columns_axis` from `daf`.

This first verifies the `rows_axis` and `columns_axis` exist in `daf`. If `must_exist` is `true` (the default), this
also verifies the `name` matrix exists for the `rows_axis` and `columns_axis`.
"""
function delete_matrix!(
    daf::WriteDaf,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString;
    must_exist::Bool = true,
)::Nothing
    require_axis(daf, rows_axis)
    require_axis(daf, columns_axis)

    if must_exist
        require_matrix(daf, rows_axis, columns_axis, name)
    elseif !has_matrix(daf, rows_axis, columns_axis, name)
        return nothing
    end

    Formats.format_delete_matrix!(daf, rows_axis, columns_axis, name)
    return nothing
end

"""
    matrix_names(
        daf::ReadDaf,
        rows_axis::AbstractString,
        columns_axis::AbstractString,
    )::Set{String}

The names of the matrix properties for the `rows_axis` and `columns_axis` in `daf`.

This first verifies the `rows_axis` and `columns_axis` exist in `daf`.
"""
function matrix_names(daf::ReadDaf, rows_axis::AbstractString, columns_axis::AbstractString)::AbstractSet{String}
    require_axis(daf, rows_axis)
    require_axis(daf, columns_axis)
    return Formats.format_matrix_names(daf, rows_axis, columns_axis)
end

function require_matrix(
    daf::ReadDaf,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
)::Nothing
    if !has_matrix(daf, rows_axis, columns_axis, name)
        error(
            "missing matrix property: $(name)\n" *
            "for the rows axis: $(rows_axis)\n" *
            "and the columns axis: $(columns_axis)\n" *
            "in the daf data: $(daf.name)",
        )
    end
    return nothing
end

function require_no_matrix(
    daf::ReadDaf,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
)::Nothing
    if has_matrix(daf, rows_axis, columns_axis, name)
        error(
            "existing matrix property: $(name)\n" *
            "for the rows axis: $(rows_axis)\n" *
            "and the columns axis: $(columns_axis)\n" *
            "in the daf data: $(daf.name)",
        )
    end
    return nothing
end

"""
    get_matrix(
        daf::ReadDaf,
        rows_axis::AbstractString,
        columns_axis::AbstractString,
        name::AbstractString
        [; default::Union{StorageScalar, StorageMatrix}]
    )::NamedMatrix

Get the matrix property with some `name` for some `rows_axis` and `columns_axis` in `daf`. The names of the result axes
are the names of the relevant axes entries (same as returned by [`get_axis`](@ref)).

This first verifies the `rows_axis` and `columns_axis` exist in `daf`. If `default` is not specified, this first
verifies the `name` matrix exists in `daf`. Otherwise, if `default` is a `StorageMatrix`, it has to be of the same size
as the `rows_axis` and `columns_axis`, and is returned. Otherwise, a new `Matrix` is created of the correct size
containing the `default`, and is returned.
"""
function get_matrix(
    daf::ReadDaf,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString;
    default::Union{StorageScalar, StorageMatrix, Nothing} = nothing,
)::NamedArray
    require_axis(daf, rows_axis)
    require_axis(daf, columns_axis)

    if default isa StorageMatrix
        require_column_major(default)
        require_axis_length(daf, "default rows", size(default, Rows), rows_axis)
        require_axis_length(daf, "default columns", size(default, Columns), columns_axis)
        if default isa NamedMatrix
            require_axis_names(daf, rows_axis, "row names of the: default matrix", names(default, 1))
            require_axis_names(daf, columns_axis, "column names of the: default matrix", names(default, 2))
        end
    end

    matrix = nothing
    if !has_matrix(daf, rows_axis, columns_axis, name)
        if default isa StorageMatrix
            matrix = default
        elseif default isa StorageScalar
            matrix = fill(default, axis_length(daf, rows_axis), axis_length(daf, columns_axis))
        end
    end

    if matrix == nothing
        require_matrix(daf, rows_axis, columns_axis, name)
        matrix = Formats.format_get_matrix(daf, rows_axis, columns_axis, name)
        if !(matrix isa StorageMatrix)
            error( # untested
                "format_get_matrix for daf format: $(typeof(daf))\n" *
                "returned invalid Daf.StorageMatrix: $(typeof(matrix))",
            )
        end

        if size(matrix, Rows) != axis_length(daf, rows_axis)
            error( # untested
                "format_get_matrix for daf format: $(typeof(daf))\n" *
                "returned matrix rows: $(size(matrix, Rows))\n" *
                "instead of axis: $(axis)\n" *
                "length: $(axis_length(daf, rows_axis))\n" *
                "in the daf data: $(daf.name)",
            )
        end

        if size(matrix, Columns) != axis_length(daf, columns_axis)
            error( # untested
                "format_get_matrix for daf format: $(typeof(daf))\n" *
                "returned matrix columns: $(size(matrix, Columns))\n" *
                "instead of axis: $(axis)\n" *
                "length: $(axis_length(daf, columns_axis))\n" *
                "in the daf data: $(daf.name)",
            )
        end

        if major_axis(matrix) != Columns
            error( # untested
                "format_get_matrix for daf format: $(typeof(daf))\n" *
                "returned non column-major matrix: $(typeof(matrix))",
            )
        end
    end

    return as_named_matrix(daf, rows_axis, columns_axis, matrix)
end

function require_column_major(matrix::StorageMatrix)::Nothing
    if major_axis(matrix) != Columns
        error("type: $(typeof(matrix)) is not in column-major layout")
    end
end

function require_axis_length(
    daf::ReadDaf,
    what_name::AbstractString,
    what_length::Integer,
    axis::AbstractString,
)::Nothing
    if what_length != axis_length(daf, axis)
        error(
            "$(what_name): $(what_length)\n" *
            "is different from the length: $(axis_length(daf, axis))\n" *
            "of the axis: $(axis)\n" *
            "in the daf data: $(daf.name)",
        )
    end
    return nothing
end

function require_not_name(daf::ReadDaf, axis::AbstractString, name::AbstractString)::Nothing
    if name == "name"
        error("setting the reserved property: name\n" * "for the axis: $(axis)\n" * "in the daf data: $(daf.name)")
    end
    return nothing
end

function as_read_only(array::SparseArrays.ReadOnly)::SparseArrays.ReadOnly  # untested
    return array
end

function as_read_only(array::NamedArray)::NamedArray  # untested
    if array.array isa SparseArrays.ReadOnly
        return array
    else
        return NamedArray(as_read_only(array.array), array.dicts, array.dimnames)
    end
end

function as_read_only(array::AbstractArray)::SparseArrays.ReadOnly
    return SparseArrays.ReadOnly(array)
end

function require_axis_names(daf::ReadDaf, axis::AbstractString, what::String, names::Vector{String})::Nothing
    expected_names = get_axis(daf, axis)
    if names != expected_names
        error("$(what)\nmismatch the entry names of the axis: $(axis)\nin the daf data: $(daf.name)")
    end
end

function as_named_vector(daf::ReadDaf, axis::AbstractString, vector::NamedVector)::NamedVector
    return vector
end

function as_named_vector(daf::ReadDaf, axis::AbstractString, vector::AbstractVector)::NamedArray
    axis_names_dict = get(daf.internal.axes, axis, nothing)
    if axis_names_dict == nothing
        named_array = NamedArray(vector, (get_axis(daf, axis),), (axis,))
        daf.internal.axes[axis] = named_array.dicts[1]
        return named_array

    else
        return NamedArray(vector, (axis_names_dict,), (axis,))
    end
end

function as_named_matrix(
    daf::ReadDaf,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    matrix::NamedMatrix,
)::NamedMatrix
    return matrix
end

function as_named_matrix(
    daf::ReadDaf,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    matrix::AbstractMatrix,
)::NamedArray
    rows_axis_names_dict = get(daf.internal.axes, rows_axis, nothing)
    columns_axis_names_dict = get(daf.internal.axes, columns_axis, nothing)
    if rows_axis_names_dict == nothing || columns_axis_names_dict == nothing
        named_array =
            NamedArray(matrix, (get_axis(daf, rows_axis), get_axis(daf, columns_axis)), (rows_axis, columns_axis))
        daf.internal.axes[rows_axis] = named_array.dicts[1]
        daf.internal.axes[columns_axis] = named_array.dicts[2]
        return named_array

    else
        return NamedArray(matrix, (rows_axis_names_dict, columns_axis_names_dict), (rows_axis, columns_axis))
    end
end

function base_array(array::AbstractArray)::AbstractArray
    return array
end

function base_array(array::SparseArrays.ReadOnly)::AbstractArray  # untested
    return base_array(parent(array))
end

function base_array(array::NamedArray)::AbstractArray
    return base_array(array.array)
end

"""
    description(daf::ReadDaf)::AbstractString

Return a (multi-line) description of the contents of `daf`. This tries to hit a sweet spot between usefulness and
terseness.
"""
function description(daf::ReadDaf)::AbstractString
    lines = String[]

    push!(lines, "type: $(typeof(daf))")
    push!(lines, "name: $(daf.name)")

    Formats.format_description_header(daf, lines)

    scalars_description(daf, lines)

    axes = collect(axis_names(daf))
    sort!(axes)
    if !isempty(axes)
        axes_description(daf, axes, lines)
        vectors_description(daf, axes, lines)
        matrices_description(daf, axes, lines)
    end

    Formats.format_description_footer(daf, lines)

    push!(lines, "")
    return join(lines, "\n")
end

function scalars_description(daf::ReadDaf, lines::Vector{String})::Nothing
    scalars = collect(scalar_names(daf))
    if !isempty(scalars)
        sort!(scalars)
        push!(lines, "scalars:")
        for scalar in scalars
            push!(lines, "  $(scalar): $(present(get_scalar(daf, scalar)))")
        end
    end
    return nothing
end

function axes_description(daf::ReadDaf, axes::Vector{String}, lines::Vector{String})::Nothing
    push!(lines, "axes:")
    for axis in axes
        push!(lines, "  $(axis): $(axis_length(daf, axis)) entries")
    end
    return nothing
end

function vectors_description(daf::ReadDaf, axes::Vector{String}, lines::Vector{String})::Nothing
    is_first = true
    for axis in axes
        vectors = collect(vector_names(daf, axis))
        if !isempty(vectors)
            if is_first
                push!(lines, "vectors:")
                is_first = false
            end
            sort!(vectors)
            push!(lines, "  $(axis):")
            for vector in vectors
                push!(lines, "    $(vector): $(present(base_array(get_vector(daf, axis, vector))))")
            end
        end
    end
    return nothing
end

function matrices_description(daf::ReadDaf, axes::Vector{String}, lines::Vector{String})::Nothing
    is_first = true
    for rows_axis in axes
        for columns_axis in axes
            matrices = collect(matrix_names(daf, rows_axis, columns_axis))
            if !isempty(matrices)
                if is_first
                    push!(lines, "matrices:")
                    is_first = false
                end
                sort!(matrices)
                push!(lines, "  $(rows_axis),$(columns_axis):")
                for matrix in matrices
                    push!(
                        lines,
                        "    $(matrix): $(present(base_array(get_matrix(daf, rows_axis, columns_axis, matrix))))",
                    )
                end
            end
        end
    end
    return nothing
end

"""
    matrix_query(daf::ReadDaf, query::AbstractString)::Union{NamedMatrix, Nothing}

Query `daf` for some matrix results. See [`MatrixQuery`](@ref) for the possible queries that return matrix results. The
names of the axes of the result are the names of the axis entries. This is especially useful when the query applies
masks to the axes. Will return `nothing` if any of the masks is empty.
"""
function matrix_query(daf::ReadDaf, query::AbstractString)::Union{NamedArray, Nothing}
    return matrix_query(daf, parse_matrix_query(query))
end

function matrix_query(daf::ReadDaf, matrix_query::MatrixQuery)::Union{NamedArray, Nothing}
    result = compute_matrix_lookup(daf, matrix_query.matrix_property_lookup)
    result = compute_eltwise_result(matrix_query.eltwise_operations, result)
    return result
end

function compute_matrix_lookup(daf::ReadDaf, matrix_property_lookup::MatrixPropertyLookup)::Union{NamedArray, Nothing}
    result = get_matrix(
        daf,
        matrix_property_lookup.matrix_axes.rows_axis.axis_name,
        matrix_property_lookup.matrix_axes.columns_axis.axis_name,
        matrix_property_lookup.property_name,
    )

    rows_mask = compute_filtered_axis_mask(daf, matrix_property_lookup.matrix_axes.rows_axis)
    columns_mask = compute_filtered_axis_mask(daf, matrix_property_lookup.matrix_axes.columns_axis)

    if (rows_mask != nothing && !any(rows_mask)) || (columns_mask != nothing && !any(columns_mask))
        return nothing
    end

    if rows_mask != nothing && columns_mask != nothing
        result = result[rows_mask, columns_mask]
    elseif rows_mask != nothing
        result = result[rows_mask, :]  # untested
    elseif columns_mask != nothing
        result = result[:, columns_mask]  # untested
    end

    return result
end

function compute_filtered_axis_mask(daf::ReadDaf, filtered_axis::FilteredAxis)::Union{Vector{Bool}, Nothing}
    if isempty(filtered_axis.axis_filters)
        return nothing
    end

    mask = fill(true, axis_length(daf, filtered_axis.axis_name))
    for axis_filter in filtered_axis.axis_filters
        mask = compute_axis_filter(daf, mask, filtered_axis.axis_name, axis_filter)
    end

    return mask
end

function compute_axis_filter(
    daf::ReadDaf,
    mask::AbstractVector{Bool},
    axis::AbstractString,
    axis_filter::AxisFilter,
)::AbstractVector{Bool}
    filter = compute_axis_lookup(daf, axis, axis_filter.axis_lookup)
    if eltype(filter) != Bool
        error(
            "non-Bool data type: $(eltype(filter))\n" *
            "for the axis filter: $(canonical(axis_filter))\n" *
            "in the daf data: $(daf.name)",
        )
    end

    if axis_filter.axis_lookup.is_inverse
        filter = .!filter
    end

    if axis_filter.filter_operator == FilterAnd
        return .&(mask, filter)
    elseif axis_filter.filter_operator == FilterOr   # untested
        return .|(mask, filter)                      # untested
    elseif axis_filter.filter_operator == FilterXor  # untested
        return @. xor(mask, filter)                  # untested
    else
        @assert false  # untested
    end
end

function compute_axis_lookup(daf::ReadDaf, axis::AbstractString, axis_lookup::AxisLookup)::NamedArray
    values = compute_property_lookup(daf, axis, axis_lookup.property_lookup)

    if axis_lookup.property_comparison == nothing
        return values
    end

    mask =
        if axis_lookup.property_comparison.comparison_operator == CmpMatch ||
           axis_lookup.property_comparison.comparison_operator == CmpNotMatch
            compute_axis_lookup_match_mask(daf, axis, axis_lookup, values)
        else
            compute_axis_lookup_compare_mask(daf, axis, axis_lookup, values)
        end

    return NamedArray(mask, values.dicts, values.dimnames)
end

function compute_axis_lookup_match_mask(
    daf::ReadDaf,
    axis::AbstractString,
    axis_lookup::AxisLookup,
    values::AbstractVector,
)::Vector{Bool}
    if eltype(values) != String
        error(
            "non-String data type: $(eltype(values))\n" *
            "for the match axis lookup: $(canonical(axis_lookup))\n" *
            "for the axis: $(axis)\n" *
            "in the daf data: $(daf.name)",
        )
    end

    regex = nothing
    try
        regex = Regex("^(?:" * axis_lookup.property_comparison.property_value * ")\$")
    catch
        error(
            "invalid Regex: \"$(escape_string(axis_lookup.property_comparison.property_value))\"\n" *
            "for the axis lookup: $(canonical(axis_lookup))\n" *
            "for the axis: $(axis)\n" *
            "in the daf data: $(daf.name)",
        )
    end

    if axis_lookup.property_comparison.comparison_operator == CmpMatch
        return [match(regex, value) != nothing for value in values]
    elseif axis_lookup.property_comparison.comparison_operator == CmpNotMatch  # untested
        return [match(regex, value) == nothing for value in values]                        # untested
    else
        @assert false  # untested
    end
end

function compute_axis_lookup_compare_mask(
    daf::ReadDaf,
    axis::AbstractString,
    axis_lookup::AxisLookup,
    values::AbstractVector,
)::Vector{Bool}
    value = axis_lookup.property_comparison.property_value
    if eltype(values) != String
        try
            value = parse(eltype(values), value)
        catch
            error(
                "invalid $(eltype) value: \"$(escape_string(axis_lookup.property_comparison.property_value))\"\n" *
                "for the axis lookup: $(canonical(axis_lookup))\n" *
                "for the axis: $(axis)\n" *
                "in the daf data: $(daf.name)",
            )
        end
    end

    if axis_lookup.property_comparison.comparison_operator == CmpLessThan
        return values .< value
    elseif axis_lookup.property_comparison.comparison_operator == CmpLessOrEqual
        return values .<= value  # untested
    elseif axis_lookup.property_comparison.comparison_operator == CmpEqual
        return values .== value
    elseif axis_lookup.property_comparison.comparison_operator == CmpNotEqual
        return values .!= value                                                      # untested
    elseif axis_lookup.property_comparison.comparison_operator == CmpGreaterThan
        return values .> value
    elseif axis_lookup.property_comparison.comparison_operator == CmpGreaterOrEqual  # untested
        return values .>= value                                                      # untested
    else
        @assert false  # untested
    end
end

function compute_property_lookup(daf::ReadDaf, axis::AbstractString, property_lookup::PropertyLookup)::NamedArray
    last_property_name = property_lookup.property_names[1]
    values = get_vector(daf, axis, last_property_name)

    for next_property_name in property_lookup.property_names[2:end]
        if eltype(values) != String
            error(
                "non-String data type: $(eltype(values))\n" *
                "for the chained property: $(last_property_name)\n" *
                "for the axis: $(axis)\n" *
                "in the daf data: $(daf.name)",
            )
        end
        values, axis = compute_chained_property(daf, axis, last_property_name, values, next_property_name)
        last_property_name = next_property_name
    end

    return values
end

function compute_chained_property(
    daf::ReadDaf,
    last_axis::AbstractString,
    last_property_name::AbstractString,
    last_property_values::NamedVector{String},
    next_property_name::AbstractString,
)::Tuple{NamedArray, String}
    if has_axis(daf, last_property_name)
        next_axis = last_property_name
    else
        next_axis = split(last_property_name, "."; limit = 2)[1]
    end

    next_axis_entries = get_axis(daf, next_axis)
    next_axis_values = get_vector(daf, next_axis, next_property_name)

    next_property_values = [
        find_axis_value(
            daf,
            last_axis,
            last_property_name,
            property_value,
            next_axis,
            next_axis_entries,
            next_axis_values,
        ) for property_value in last_property_values
    ]

    return (NamedArray(next_property_values, last_property_values.dicts, last_property_values.dimnames), next_axis)
end

function find_axis_value(
    daf::ReadDaf,
    last_axis::AbstractString,
    last_property_name::AbstractString,
    last_property_value::AbstractString,
    next_axis::AbstractString,
    next_axis_entries::AbstractVector{String},
    next_axis_values::AbstractVector,
)::Any
    index = findfirst(==(last_property_value), next_axis_entries)
    if index == nothing
        error(
            "invalid value: $(last_property_value)\n" *
            "of the chained property: $(last_property_name)\n" *
            "of the axis: $(last_axis)\n" *
            "is missing from the next axis: $(next_axis)\n" *
            "in the daf data: $(daf.name)",
        )
    end
    return next_axis_values[index]
end

"""
    vector_query(daf::ReadDaf, query::AbstractString)::Union{NamedVector, Nothing}

Query `daf` for some vector results. See [`VectorQuery`](@ref) for the possible queries that return vector results. The
names of the results are the names of the axis entries. This is especially useful when the query applies a mask to the
axis. Will return `nothing` if any of the masks is empty.
"""
function vector_query(daf::ReadDaf, query::AbstractString)::Union{NamedArray, Nothing}
    return vector_query(daf, parse_vector_query(query))
end

function vector_query(daf::ReadDaf, vector_query::VectorQuery)::Union{NamedArray, Nothing}
    result = compute_vector_data_lookup(daf, vector_query.vector_data_lookup)
    result = compute_eltwise_result(vector_query.eltwise_operations, result)
    return result
end

function compute_vector_data_lookup(
    daf::ReadDaf,
    vector_property_lookup::VectorPropertyLookup,
)::Union{NamedArray, Nothing}
    result =
        compute_axis_lookup(daf, vector_property_lookup.filtered_axis.axis_name, vector_property_lookup.axis_lookup)
    mask = compute_filtered_axis_mask(daf, vector_property_lookup.filtered_axis)

    if mask == nothing
        return result
    end

    if !any(mask)
        return nothing
    end

    return result[mask]
end

function compute_vector_data_lookup(daf::ReadDaf, matrix_slice_lookup::MatrixSliceLookup)::Union{NamedArray, Nothing}
    result = get_matrix(
        daf,
        matrix_slice_lookup.matrix_slice_axes.filtered_axis.axis_name,
        matrix_slice_lookup.matrix_slice_axes.axis_entry.axis_name,
        matrix_slice_lookup.property_name,
    )

    index = find_axis_entry_index(daf, matrix_slice_lookup.matrix_slice_axes.axis_entry)
    result = result[:, index]

    rows_mask = compute_filtered_axis_mask(daf, matrix_slice_lookup.matrix_slice_axes.filtered_axis)
    if rows_mask != nothing
        result = result[rows_mask]
    end

    return result
end

function compute_vector_data_lookup(daf::ReadDaf, reduce_matrix_query::ReduceMatrixQuery)::Union{NamedArray, Nothing}
    result = matrix_query(daf, reduce_matrix_query.matrix_query)
    if result == nothing
        return nothing
    end
    return compute_reduction_result(reduce_matrix_query.reduction_operation, result)
end

"""
    scalar_query(daf::ReadDaf, query::AbstractString)::Union{StorageScalar, Nothing}

Query `daf` for some scalar results. See [`ScalarQuery`](@ref) for the possible queries that return scalar results.
"""
function scalar_query(daf::ReadDaf, query::AbstractString)::Union{StorageScalar, Nothing}
    return scalar_query(daf, parse_scalar_query(query))
end

function scalar_query(daf::ReadDaf, scalar_query::ScalarQuery)::Union{StorageScalar, Nothing}
    result = compute_scalar_data_lookup(daf, scalar_query.scalar_data_lookup)
    result = compute_eltwise_result(scalar_query.eltwise_operations, result)
    return result
end

function compute_scalar_data_lookup(
    daf::ReadDaf,
    scalar_property_lookup::ScalarPropertyLookup,
)::Union{StorageScalar, Nothing}
    return get_scalar(daf, scalar_property_lookup.property_name)
end

function compute_scalar_data_lookup(daf::ReadDaf, reduce_vector_query::ReduceVectorQuery)::Union{StorageScalar, Nothing}
    result = vector_query(daf, reduce_vector_query.vector_query)
    return compute_reduction_result(reduce_vector_query.reduction_operation, result)
end

function compute_scalar_data_lookup(daf::ReadDaf, vector_entry_lookup::VectorEntryLookup)::Union{StorageScalar, Nothing}
    result = compute_axis_lookup(daf, vector_entry_lookup.axis_entry.axis_name, vector_entry_lookup.axis_lookup)
    index = find_axis_entry_index(daf, vector_entry_lookup.axis_entry)
    return result[index]
end

function compute_scalar_data_lookup(daf::ReadDaf, matrix_entry_lookup::MatrixEntryLookup)::Union{StorageScalar, Nothing}
    result = get_matrix(
        daf,
        matrix_entry_lookup.matrix_entry_axes.rows_entry.axis_name,
        matrix_entry_lookup.matrix_entry_axes.columns_entry.axis_name,
        matrix_entry_lookup.property_name,
    )
    row_index = find_axis_entry_index(daf, matrix_entry_lookup.matrix_entry_axes.rows_entry)
    column_index = find_axis_entry_index(daf, matrix_entry_lookup.matrix_entry_axes.columns_entry)
    return result[row_index, column_index]
end

function find_axis_entry_index(daf::ReadDaf, axis_entry::AxisEntry)::Int
    axis_entries = get_axis(daf, axis_entry.axis_name)
    index = findfirst(==(axis_entry.entry_name), axis_entries)
    if index == nothing
        error(
            "the entry: $(axis_entry.entry_name)\n" *
            "is missing from the axis: $(axis_entry.axis_name)\n" *
            "in the daf data: $(daf.name)",
        )
    end
    return index
end

function compute_eltwise_result(
    eltwise_operations::Vector{EltwiseOperation},
    input::Union{NamedArray, StorageScalar, Nothing},
)::Union{NamedArray, StorageScalar, Nothing}
    if input == nothing
        return nothing
    end

    result = input
    for eltwise_operation in eltwise_operations
        named_result = result
        if result isa StorageScalar
            check_type = typeof(result)
            error_type = typeof(result)
        else
            check_type = eltype(result)
            error_type = typeof(base_array(result))
        end

        if !(check_type <: Number)
            error("non-numeric input: $(error_type)\n" * "for the eltwise operation: $(canonical(eltwise_operation))\n")
        end

        if result isa StorageScalar
            result = compute_eltwise(eltwise_operation, result)
        else
            result = NamedArray(compute_eltwise(eltwise_operation, result.array), result.dicts, result.dimnames)
        end
    end
    return result
end

function compute_reduction_result(
    reduction_operation::ReductionOperation,
    input::Union{NamedArray, Nothing},
)::Union{NamedArray, StorageScalar, Nothing}
    if input == nothing
        return nothing
    end

    if !(eltype(input) <: Number)
        error(
            "non-numeric input: $(typeof(base_array(input)))\n" *
            "for the reduction operation: $(canonical(reduction_operation))\n",
        )
    end
    if ndims(input) == 2
        return NamedArray(compute_reduction(reduction_operation, input.array), (input.dicts[2],), (input.dimnames[2],))
    else
        return compute_reduction(reduction_operation, input.array)
    end
end

end # module