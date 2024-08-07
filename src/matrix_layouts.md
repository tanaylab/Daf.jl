# Matrix layouts

```@docs
Daf.MatrixLayouts
```

## Symbolic names for axes

```@docs
Daf.MatrixLayouts.Rows
Daf.MatrixLayouts.Columns
Daf.MatrixLayouts.axis_name
```

## Checking layout

```@docs
Daf.MatrixLayouts.major_axis
Daf.MatrixLayouts.require_major_axis
Daf.MatrixLayouts.minor_axis
Daf.MatrixLayouts.require_minor_axis
Daf.MatrixLayouts.other_axis
```

## Changing layout

```@docs
Daf.MatrixLayouts.relayout!
Daf.MatrixLayouts.relayout
Daf.MatrixLayouts.transposer
Daf.MatrixLayouts.copy_array
```

## Changing format

```@docs
Daf.MatrixLayouts.bestify
Daf.MatrixLayouts.densify
Daf.MatrixLayouts.sparsify
```

## Assertions

```@docs
Daf.MatrixLayouts.@assert_vector
Daf.MatrixLayouts.@assert_matrix
Daf.MatrixLayouts.check_efficient_action
Daf.MatrixLayouts.inefficient_action_handler
```

## Index

```@index
Pages = ["matrix_layouts.md"]
```
