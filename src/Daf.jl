"""
The `Daf.jl` package provides a uniform generic interface for accessing 1D and 2D data arranged along some set of axes.
This is a much-needed generalization of the [AnnData](https://pypi.org/project/anndata) functionality. The key
features are:

  - The data model is based on (1) some axes with named entries, (2) vector data indexed by a single axis, (3) matrix
    data indexed by a pair of axes, and also (4) scalar data (anything not tied to some axis).

  - There is explicit control over 2D data layout (row or column major), and support for both dense and sparse matrices,
    both of which are crucial for performance.
  - A simple query language makes it easy to access the data, providing features such as slicing, aggregation, and
    filtering.
  - Support both in-memory and persistent data storage of "any" format (given an adapter implementation).
  - Out of the box, allow storing the data in memory, in `AnnData` objects (e.g., using `h5ad` files), directly inside
    [H5FS](https://hdfgroup.org/) files (i.e., using `h5df` files), or as a collection of simple memory-mapped files in
    a directory (which works nicely with tools like `make` for automating computation pipelines).

The top-level `Daf` module re-exports all(most) everything from the sub-modules, so you can directly access any exported
symbol by `using Daf` (or `import Daf: MemoryStorage`), instead of having to import or use qualified names (such as
`Daf.Storage.MemoryStorage`).
"""
module Daf

using Reexport

include("matrix_layouts.jl")
@reexport using Daf.MatrixLayouts

include("data_types.jl")
@reexport using Daf.DataTypes

include("messages.jl")
@reexport using Daf.Messages

include("oprec.jl")

include("registry.jl")

include("queries.jl")
@reexport using Daf.Queries

include("operations.jl")
@reexport using Daf.Operations

include("formats.jl")

include("containers.jl")
@reexport using Daf.Containers

include("memory_format.jl")
@reexport using Daf.MemoryFormat

include("example_data.jl")
@reexport using Daf.ExampleData

end # module
