"""
Matrices (typically) have a well-defined layout which dictates which types of processing is (much!) more efficient.

This is different from the more general `ArrayLayouts` package. Instead, in `Daf` we restrict ourselves to vectors and
matrices (as opposed to N-dimensional arrays). In addition, we typically store `DenseArray` data (with special handling
of `SparseMatrixCSC`, which is basically just a combination of three `DenseVector`). This makes the memory layout
question simpler - is the matrix in row-major or column-major format>

Running algorithms on the wrong matrix layout can be (silently) orders of magnitude slower - for example, summing the
values in each row on a column-major matrix. Alas, Julia's type system does not allow us to easily add `MatrixInColumns`
and `MatrixInRows` or anything like that (in general Julia's type system is a mess when dealing with arrays because of
"reasons").

We therefore settle for providing functions to detect the matrix memory layout, and efficiently convert a matrix between
these layouts (the default implementation of this conversion is horribly inefficient for some unknown reason).
"""
module MatrixLayouts

export Column
export count_nnz
export Error
export inefficient_policy
export inefficient_action
export major_axis
export MatrixAxis
export minor_axis
export naxis
export ncolumns
export nrows
export InefficientPolicy
export other_axis
export relayout
export Row
export view_axis
export view_column
export view_row
export Warn

using ArrayLayouts
using Base.Threads
using Distributed
using LinearAlgebra
using SparseArrays

"""
Identify a matrix axis to use.

Valid values are: `Column` - access the matrix one column at a time or `Row` - access the matrix one row at a time. Yes,
one could use `1` and `2` as axis indices but symbolic names make the code much more readable and less error-prone.
"""
@enum MatrixAxis Column Row

"""
    major_axis(matrix::AbstractMatrix)::Union{MatrixAxis,Nothing}

Return the major axis of a matrix, that is, the axis one should use for the outer loop for the most efficient access
to the matrix elements. This extends the `MemoryLayout` provided by the `ArrayLayouts` package to also deal with
`SparseArrays`, and focuses just on the narrow question of the efficient access patterns rather than trying to fully
describe the memory layout of the array. If the matrix doesn't support any efficient access axis, returns `nothing`.
"""
@inline major_axis(::SparseMatrixCSC) = Column
@inline major_axis(matrix::Transpose) = other_axis(major_axis(matrix.parent))
@inline major_axis(matrix::AbstractMatrix) = axis_of_layout(MemoryLayout(matrix))

@inline axis_of_layout(::AbstractColumnMajor) = Column
@inline axis_of_layout(::AbstractRowMajor) = Row
@inline axis_of_layout(::MemoryLayout) = nothing  # untested

"""
    minor_axis(matrix::AbstractMatrix)::Union{MatrixAxis,Nothing}

Return the minor axis of a matrix, that is, the axis one should use for the inner loop for the most efficient access
to the matrix elements. This extends the `MemoryLayout` provided by the `ArrayLayouts` package to also deal with
`SparseArrays`, and focuses just on the narrow question of the efficient access patterns rather than trying to fully
describe the memory layout of the array. If the matrix doesn't support any efficient access axis, return `nothing`.
"""
@inline minor_axis(matrix::AbstractMatrix) = other_axis(major_axis(matrix))

"""
    other_axis(axis::Union{MatrixAxis,Nothing})::Union{MatrixAxis,Nothing}

Return the other `matrix` `axis`.
"""
function other_axis(axis::Union{MatrixAxis, Nothing})::Union{MatrixAxis, Nothing}
    if axis == Column
        return Row
    elseif axis == Row
        return Column
    else
        return nothing
    end
end

"""
    naxis(matrix::AbstractMatrix, axis:MatrixAxis)::Int

Return the number of elements of an `axis` of a `matrix`. Yes, one could use `size` and `1` and `2` as axis indices but
symbolic names make the code much more readable and less error-prone.
"""
function naxis(matrix::AbstractMatrix, axis::MatrixAxis)::Int
    if axis == Column
        return size(matrix, 2)
    else
        return size(matrix, 1)
    end
end

"""
    nrows(matrix::AbstractMatrix)::Int

Return the number of rows of a `matrix`. Yes, one could use `size` of `1` but `nrows` is much more readable and less
error-prone.
"""
function nrows(matrix::AbstractMatrix)::Int
    return size(matrix, 1)
end

"""
    ncolumns(matrix::AbstractMatrix)::Int

Return the number of columns of a `matrix`. Yes, one could use `size` of `1` but `ncolumns` is much more readable and
less error-prone.
"""
function ncolumns(matrix::AbstractMatrix)::Int
    return size(matrix, 2)
end

"""
    The action to take on a suspect action.

Valid values are `nothing` - do nothing special, just execute the code and hope for the best, `Warn` - emit a warning
using `@warn`, and `Error` - abort the program with an error message.
"""
@enum InefficientPolicy Warn Error

global_inefficient_policy = Warn

"""
    inefficient_policy(
        policy::Union{InefficientPolicy,Nothing}
    )::Union{InefficientPolicy,Nothing}

Specify the `policy` to take when accessing a matrix in an inefficient way. Returns the previous policy.
"""
function inefficient_policy(policy::Union{InefficientPolicy, Nothing})::Union{InefficientPolicy, Nothing}
    global global_inefficient_policy
    previous_policy = global_inefficient_policy

    @sync for process in 1:nprocs()
        @spawnat process begin
            global global_inefficient_policy
            global_inefficient_policy = policy
        end
    end

    return previous_policy
end

"""
    inefficient_action(action::AbstractString)::Nothing

Report accessing a matrix in an inefficient way for during some `action`, by applying the current
`inefficient_policy`.
"""
function inefficient_action(action::AbstractString)::Nothing
    if global_inefficient_policy == Warn
        @warn "Inefficient access to matrix elements when $(action)"  # untested

    elseif global_inefficient_policy == Error
        error("Inefficient access to matrix elements when $(action)")
    end
end

function count_nnz(vector::SparseVector; structural::Bool = true)::Int
    if structural
        return length(vector.nzval)
    else
        return count_nnz(vector.nzval)
    end
end

function count_nnz(vector::AbstractVector; structural::Bool = true)::Int
    count = 0
    @simd for value in vector
        count += (value != 0)
    end
    return count
end

"""
    count_nnz(
        matrix::AbstractMatrix;
        per::MatrixAxis,
        structural::Bool=true
    )::AbstractVector

Return the number of non-zero elements `per` each `matrix` axis entry. If:

  - This is a (possibly transposed) `SparseMatrixCSC`;

  - The `major_axis` of the matrix matches the per-axis (that is, `Column` for `SparseMatrixCSC` and `Row` for its
    transpose);
  - The `structural` parameter is `true` (the default);

Then this returns the number of structural zeros rather than actual non-zero elements. Otherwise, this actually counts
the number of non-zero elements, which can be slow.

If actually counting the elements of the `minor_axis` of a matrix, this is subject to the `inefficient_policy`.
"""
function count_nnz(matrix::Transpose; per::MatrixAxis, structural::Bool = true)::AbstractVector
    return count_nnz(matrix.parent; per = other_axis(per), structural = structural)
end

function count_nnz(matrix::SparseMatrixCSC; per::MatrixAxis, structural::Bool = true)::AbstractVector
    if per == Row
        inefficient_action("counting non-zero matrix elements")
        type = eltype(matrix.colptr)
        return [type(count_nnz(matrix[row_index, :])) for row_index in 1:nrows(matrix)]

    elseif structural
        return diff(matrix.colptr)

    else
        type = eltype(matrix.colptr)
        return [type(count_nnz(matrix[:, column_index].nzval)) for column_index in 1:ncolumns(matrix)]
    end
end

function count_nnz(matrix::AbstractMatrix; per::MatrixAxis, structural::Bool = true)::AbstractVector
    efficient_per = major_axis(matrix)
    if efficient_per != nothing && efficient_per != per
        inefficient_action("counting non-zero matrix elements")
    end

    if per == Column
        return [count_nnz(matrix[:, column_index]) for column_index in 1:ncolumns(matrix)]
    else
        return [count_nnz(matrix[row_index, :]) for row_index in 1:nrows(matrix)]
    end
end

"""
    relayout(
        matrix::AbstractMatrix,
        to_major_axis::MatrixAxis;
        copy::Bool=false
    )::AbstractMatrix

Return a version of the `matrix` which has the requested `major_axis`. If `copy`, a new copy of the matrix is returned
even if its major axis already matches the requested one.
"""
function relayout(matrix::AbstractMatrix, to_major_axis::MatrixAxis; copy::Bool = false)::AbstractMatrix
    from_major_axis = major_axis(matrix)
    if to_major_axis == from_major_axis
        if !copy
            return matrix
        else
            return deepcopy(matrix)
        end
    end

    transpose_result = true
    while matrix isa Transpose
        transpose_result = !transpose_result
        matrix = matrix.parent
    end

    if matrix isa SparseMatrixCSC
        result = sparse(transpose(matrix))
    else
        result = Array(transpose(matrix))
    end

    if transpose_result
        result = transpose(result)
    end

    return result
end

"""
    view_axis(matrix::AbstractMatrix, axis::MatrixAxis, index::Int)::AbstractVector

Return a view of a slice of the `matrix` at some `index` along the specified `axis`.
"""
function view_axis(matrix::AbstractMatrix, axis::MatrixAxis, index::Int)::AbstractVector
    if axis == Row
        return view_row(matrix, index)
    else
        return view_column(matrix, index)
    end
end

"""
    view_row(matrix::AbstractMatrix, index::Int)::AbstractVector

Return a view of a row with some `index` of a `matrix`.
"""
function view_row(matrix::AbstractMatrix, index::Int)::AbstractVector
    return selectdim(matrix, 1, index)
end

"""
    view_column(matrix::AbstractMatrix, index::Int)::AbstractVector

Return a view of a column with some `index` of a `matrix`.
"""
function view_column(matrix::AbstractMatrix, index::Int)::AbstractVector
    return selectdim(matrix, 2, index)
end

end # module