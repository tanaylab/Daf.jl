"""
View a chain of `Daf` data as a single data set. This allows creating a small `Daf` data set that contains extra (or
overriding) data on top of a larger read-only data set. In particular this allows creating several such incompatible
extra data sets (e.g., different groupings of cells to metacells), without having to duplicate the common (read only)
data.
"""
module Chains

export chain_reader
export chain_writer

using Daf.Data
using Daf.Formats
using Daf.Messages
using Daf.ReadOnly
using Daf.StorageTypes
using SparseArrays

import Daf.Data.as_read_only
import Daf.Formats.Internal
import Daf.Messages

"""
    struct ReadOnlyChain <: DafReader ... end

A wrapper for a chain of [`DafReader`](@ref) data, presenting them as a single `DafReader`. When accessing the content,
the exposed value is that provided by the last data set that contains the data, that is, later data sets can override
earlier data sets. However, if an axis exists in more than one data set in the chain, then its entries must be
identical. This isn't typically created manually; instead call [`chain_reader`](@ref).
"""
struct ReadOnlyChain <: DafReader
    internal::Internal
    dafs::Vector{DafReader}
end

"""
    struct WriteChain <: DafWriter ... end

A wrapper for a chain of [`DafReader`](@ref) data, with a final [`DafWriter`], presenting them as a single `DafWriter`.
When accessing the content, the exposed value is that provided by the last data set that contains the data, that is,
later data sets can override earlier data sets (where the writer has the final word). However, if an axis exists in more
than one data set in the chain, then its entries must be identical. This isn't typically created manually; instead call
[`chain_reader`](@ref).

Any modifications or additions to the chain are directed at the final writer. Deletions are only allowed for data that
exists only in this writer. That is, it is impossible to delete from a chain something that exists in any of the
readers; it is only possible to override it.
"""
struct WriteChain <: DafWriter
    internal::Internal
    dafs::Vector{DafReader}
    daf::DafWriter
end

"""
    chain_reader(name::AbstractString, dafs::Vector{F})::ReadOnlyChain where {F <: DafReader}

Create a read-only chain wrapper of [`DafReader`](@ref)s, presenting them as a single `DafReader`. When accessing the
content, the exposed value is that provided by the last data set that contains the data, that is, later data sets can
override earlier data sets. However, if an axis exists in more than one data set in the chain, then its entries must be
identical. This isn't typically created manually; instead call [`chain_reader`](@ref).

!!! note

    While this verifies the axes are consistent at the time of creating the chain, it's no defense against modifying the
    chained data after the fact, creating inconsistent axes. *Don't do that*.
"""
function chain_reader(name::AbstractString, dafs::Vector{F})::ReadOnlyChain where {F <: DafReader}
    if isempty(dafs)
        error("empty chain: $(name)")
    end
    axes_entries = Dict{String, Tuple{String, Vector{String}}}()
    internal_dafs = Vector{DafReader}()
    for daf in dafs
        if daf isa ReadOnlyView
            daf = daf.daf
        end
        push!(internal_dafs, daf)
        for axis in axis_names(daf)
            new_axis_entries = get_axis(daf, axis)
            old_axis_entries = get(axes_entries, axis, nothing)
            if old_axis_entries == nothing
                axes_entries[axis] = (daf.name, new_axis_entries)
            elseif new_axis_entries != old_axis_entries
                error(
                    "different entries for the axis: $(axis)\n" *
                    "in the Daf data: $(old_axis_entries[1])\n" *
                    "and the Daf data: $(daf.name)\n" *
                    "in the chain: $(name)",
                )
            end
        end
    end
    return ReadOnlyChain(Internal(name), internal_dafs)
end

"""
    chain_writer(name::AbstractString, dafs::Vector{F})::WriteChain where {F <: DafReader}

Create a chain wrapper for a chain of [`DafReader`](@ref) data, presenting them as a single `DafWriter`. This acts
similarly to [`chain_reader`](@ref), but requires the final entry to be a [`DafWriter`](@ref). Any modifications or
additions to the chain are directed at this final writer.

!!! note

    Deletions are only allowed for data that exists only in the final writer. That is, it is impossible to delete from a
    chain something that exists in any of the readers; it is only possible to override it.
"""
function chain_writer(name::AbstractString, dafs::Vector{F})::WriteChain where {F <: DafReader}
    reader = chain_reader(name, dafs)
    if !(dafs[end] isa DafWriter)
        error("read-only final data: $(dafs[end].name)\n" * "in write chain: $(reader.name)")
    end
    return WriteChain(reader.internal, reader.dafs, dafs[end])
end

AnyChain = Union{ReadOnlyChain, WriteChain}

function Formats.format_has_scalar(chain::AnyChain, name::AbstractString)::Bool
    for daf in chain.dafs
        if Formats.format_has_scalar(daf, name)
            return true
        end
    end
    return false
end

function Formats.format_set_scalar!(chain::WriteChain, name::AbstractString, value::StorageScalar)::Nothing
    Formats.format_set_scalar!(chain.daf, name, value)
    return nothing
end

function Formats.format_delete_scalar!(chain::WriteChain, name::AbstractString; for_set::Bool)::Nothing
    if !for_set
        for daf in chain.dafs[1:(end - 1)]
            if Formats.format_has_scalar(daf, name)
                error(
                    "failed to delete the scalar: $(name)\n" *
                    "from the daf data: $(chain.daf.name)\n" *
                    "of the chain: $(chain.name)\n" *
                    "because it exists in the earlier: $(daf.name)",
                )
            end
        end
    end
    Formats.format_delete_scalar!(chain.daf, name; for_set = for_set)
    return nothing
end

function Formats.format_get_scalar(chain::AnyChain, name::AbstractString)::StorageScalar
    for daf in reverse(chain.dafs)
        if Formats.format_has_scalar(daf, name)
            return Formats.format_get_scalar(daf, name)
        end
    end
    @assert false  # untested
end

function Formats.format_scalar_names(chain::AnyChain)::AbstractSet{String}
    return reduce(union, [Formats.format_scalar_names(daf) for daf in chain.dafs])
end

function Formats.format_has_axis(chain::AnyChain, axis::AbstractString)::Bool
    for daf in chain.dafs
        if Formats.format_has_axis(daf, axis)
            return true
        end
    end
    return false
end

function Formats.format_add_axis!(chain::WriteChain, axis::AbstractString, entries::AbstractVector{String})::Nothing
    Formats.format_add_axis!(chain.daf, axis, entries)
    return nothing
end

function Formats.format_delete_axis!(chain::WriteChain, axis::AbstractString)::Nothing
    for daf in chain.dafs[1:(end - 1)]
        if Formats.format_has_axis(daf, axis)
            error(
                "failed to delete the axis: $(axis)\n" *
                "from the daf data: $(chain.daf.name)\n" *
                "of the chain: $(chain.name)\n" *
                "because it exists in the earlier: $(daf.name)",
            )
        end
    end
    Formats.format_delete_axis!(chain.daf, axis)
    return nothing
end

function Formats.format_axis_names(chain::AnyChain)::AbstractSet{String}
    return reduce(union, [Formats.format_axis_names(daf) for daf in chain.dafs])
end

function Formats.format_get_axis(chain::AnyChain, axis::AbstractString)::AbstractVector{String}
    for daf in reverse(chain.dafs)
        if Formats.format_has_axis(daf, axis)
            return Formats.format_get_axis(daf, axis)
        end
    end
    @assert false  # untested
end

function Formats.format_axis_length(chain::AnyChain, axis::AbstractString)::Int64
    for daf in chain.dafs
        if Formats.format_has_axis(daf, axis)
            return Formats.format_axis_length(daf, axis)
        end
    end
    @assert false  # untested
end

function Formats.format_has_vector(chain::AnyChain, axis::AbstractString, name::AbstractString)::Bool
    for daf in chain.dafs
        if Formats.format_has_axis(daf, axis) && Formats.format_has_vector(daf, axis, name)
            return true
        end
    end
    return false
end

function Formats.format_set_vector!(
    chain::WriteChain,
    axis::AbstractString,
    name::AbstractString,
    vector::Union{Number, String, StorageVector},
)::Nothing
    if !Formats.format_has_axis(chain.daf, axis)
        Formats.format_add_axis!(chain.daf, axis, Formats.format_get_axis(chain, axis))
    end
    Formats.format_set_vector!(chain.daf, axis, name, vector)
    return nothing
end

function Formats.format_empty_dense_vector!(
    chain::WriteChain,
    axis::AbstractString,
    name::AbstractString,
    eltype::Type{T},
)::DenseVector{T} where {T <: Number}
    if !Formats.format_has_axis(chain.daf, axis)
        Formats.format_add_axis!(chain.daf, axis, Formats.format_get_axis(chain, axis))
    end
    return Formats.format_empty_dense_vector!(chain.daf, axis, name, eltype)
end

function Formats.format_empty_sparse_vector!(
    chain::WriteChain,
    axis::AbstractString,
    name::AbstractString,
    eltype::Type{T},
    nnz::Integer,
    indtype::Type{I},
)::SparseVector{T, I} where {T <: Number, I <: Integer}
    if !Formats.format_has_axis(chain.daf, axis)
        Formats.format_add_axis!(chain.daf, axis, Formats.format_get_axis(chain, axis))
    end
    return Formats.format_empty_sparse_vector!(chain.daf, axis, name, eltype, nnz, indtype)
end

function Formats.format_delete_vector!(
    chain::WriteChain,
    axis::AbstractString,
    name::AbstractString;
    for_set::Bool,
)::Nothing
    if !for_set
        for daf in chain.dafs[1:(end - 1)]
            if Formats.format_has_axis(daf, axis) && Formats.format_has_vector(daf, axis, name)
                error(
                    "failed to delete the vector: $(name)\n" *
                    "for the axis: $(axis)\n" *
                    "from the daf data: $(chain.daf.name)\n" *
                    "of the chain: $(chain.name)\n" *
                    "because it exists in the earlier: $(daf.name)",
                )
            end
        end
    end
    if Formats.format_has_axis(chain.daf, axis) && Formats.format_has_vector(chain.daf, axis, name)
        Formats.format_delete_vector!(chain.daf, axis, name; for_set = for_set)
    end
    return nothing
end

function Formats.format_vector_names(chain::AnyChain, axis::AbstractString)::AbstractSet{String}
    return reduce(
        union,
        [Formats.format_vector_names(daf, axis) for daf in chain.dafs if Formats.format_has_axis(daf, axis)],
    )
end

function Formats.format_get_vector(chain::AnyChain, axis::AbstractString, name::AbstractString)::StorageVector
    for daf in reverse(chain.dafs)
        if Formats.format_has_axis(daf, axis) && Formats.format_has_vector(daf, axis, name)
            return as_read_only(Formats.format_get_vector(daf, axis, name))
        end
    end
    @assert false  # untested
end

function Formats.format_has_matrix(
    chain::AnyChain,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
)::Bool
    for daf in chain.dafs
        if Formats.format_has_axis(daf, rows_axis) &&
           Formats.format_has_axis(daf, columns_axis) &&
           Formats.format_has_matrix(daf, rows_axis, columns_axis, name)
            return true
        end
    end
    return false
end

function Formats.format_set_matrix!(
    chain::WriteChain,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
    matrix::Union{Number, String, StorageMatrix},
)::Nothing
    for axis in (rows_axis, columns_axis)
        if !Formats.format_has_axis(chain.daf, axis)
            Formats.format_add_axis!(chain.daf, axis, Formats.format_get_axis(chain, axis))
        end
    end
    Formats.format_set_matrix!(chain.daf, rows_axis, columns_axis, name, matrix)
    return nothing
end

function Formats.format_empty_dense_matrix!(
    chain::WriteChain,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
    eltype::Type{T},
)::DenseMatrix{T} where {T <: Number}
    for axis in (rows_axis, columns_axis)
        if !Formats.format_has_axis(chain.daf, axis)
            Formats.format_add_axis!(chain.daf, axis, Formats.format_get_axis(chain, axis))
        end
    end
    return Formats.format_empty_dense_matrix!(chain.daf, rows_axis, columns_axis, name, eltype)
end

function Formats.format_empty_sparse_matrix!(
    chain::WriteChain,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
    eltype::Type{T},
    nnz::Integer,
    indtype::Type{I},
)::SparseMatrixCSC{T, I} where {T <: Number, I <: Integer}
    for axis in (rows_axis, columns_axis)
        if !Formats.format_has_axis(chain.daf, axis)
            Formats.format_add_axis!(chain.daf, axis, Formats.format_get_axis(chain, axis))
        end
    end
    return Formats.format_empty_sparse_matrix!(chain.daf, rows_axis, columns_axis, name, eltype, nnz, indtype)
end

function Formats.format_relayout_matrix!(
    chain::WriteChain,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
)::Nothing
    Formats.format_relayout_matrix!(chain.daf, rows_axis, columns_axis, name)
    return nothing
end

function Formats.format_delete_matrix!(
    chain::WriteChain,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString;
    for_set::Bool,
)::Nothing
    if !for_set
        for daf in chain.dafs[1:(end - 1)]
            if Formats.format_has_axis(daf, rows_axis) &&
               Formats.format_has_axis(daf, columns_axis) &&
               Formats.format_has_matrix(daf, rows_axis, columns_axis, name)
                error(
                    "failed to delete the matrix: $(name)\n" *
                    "for the rows axis: $(rows_axis)\n" *
                    "and the columns axis: $(columns_axis)\n" *
                    "from the daf data: $(chain.daf.name)\n" *
                    "of the chain: $(chain.name)\n" *
                    "because it exists in the earlier: $(daf.name)",
                )
            end
        end
    end
    if Formats.format_has_axis(chain.daf, rows_axis) &&
       Formats.format_has_axis(chain.daf, columns_axis) &&
       Formats.format_has_matrix(chain.daf, rows_axis, columns_axis, name)
        Formats.format_delete_matrix!(chain.daf, rows_axis, columns_axis, name; for_set = for_set)
    end
    return nothing
end

function Formats.format_matrix_names(
    chain::AnyChain,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
)::AbstractSet{String}
    return reduce(
        union,
        [
            Formats.format_matrix_names(daf, rows_axis, columns_axis) for
            daf in chain.dafs if Formats.format_has_axis(daf, rows_axis) && Formats.format_has_axis(daf, columns_axis)
        ],
    )
end

function Formats.format_get_matrix(
    chain::AnyChain,
    rows_axis::AbstractString,
    columns_axis::AbstractString,
    name::AbstractString,
)::StorageMatrix
    for daf in reverse(chain.dafs)
        if Formats.format_has_axis(daf, rows_axis) &&
           Formats.format_has_axis(daf, columns_axis) &&
           Formats.format_has_matrix(daf, rows_axis, columns_axis, name)
            return as_read_only(Formats.format_get_matrix(daf, rows_axis, columns_axis, name))
        end
    end
    @assert false  # untested
end

function Formats.format_description_header(chain::ReadOnlyChain, indent::String, lines::Array{String})::Nothing
    push!(lines, "$(indent)type: ReadOnly Chain")
    return nothing
end

function Formats.format_description_header(chain::WriteChain, indent::String, lines::Array{String})::Nothing
    push!(lines, "$(indent)type: Write Chain")
    return nothing
end

function Formats.format_description_footer(chain::AnyChain, indent::String, lines::Array{String}, deep::Bool)::Nothing
    if deep
        push!(lines, "$(indent)chain:")
        for daf in chain.dafs
            description(daf, indent * "  ", lines, deep)
        end
    end
    return nothing
end

function Messages.present(value::ReadOnlyChain)::String
    return "ReadOnly Chain $(value.name)"
end

function Messages.present(value::WriteChain)::String
    return "Write Chain $(value.name)"
end

function ReadOnly.read_only(daf::ReadOnlyChain)::ReadOnlyChain
    return daf
end

function ReadOnly.read_only(daf::WriteChain)::ReadOnlyView
    return ReadOnlyView(daf)
end

end # module
