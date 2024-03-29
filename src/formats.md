# Formats

```@docs
Daf.Formats
Daf.Formats.DataKey
```

## Read API

```@docs
Daf.Formats.DafReader
Daf.Formats.FormatReader
Daf.Formats.Internal
Daf.Formats.CacheType
```

### Description

```@docs
Daf.Formats.format_description_header
Daf.Formats.format_description_footer
```

### Scalar properties

```@docs
Daf.Formats.format_has_scalar
Daf.Formats.format_scalar_names
Daf.Formats.format_get_scalar
```

### Data axes

```@docs
Daf.Formats.format_has_axis
Daf.Formats.format_axis_names
Daf.Formats.format_get_axis
Daf.Formats.format_axis_length
```

### Vector properties

```@docs
Daf.Formats.format_has_vector
Daf.Formats.format_vector_names
Daf.Formats.format_get_vector
```

### Matrix properties

```@docs
Daf.Formats.format_has_matrix
Daf.Formats.format_matrix_names
Daf.Formats.format_get_matrix
```

## Write API

```@docs
Daf.Formats.DafWriter
Daf.Formats.FormatWriter
```

### Scalar properties

```@docs
Daf.Formats.format_set_scalar!
Daf.Formats.format_delete_scalar!
```

### Data axes

```@docs
Daf.Formats.format_add_axis!
Daf.Formats.format_delete_axis!
```

### Vector properties

```@docs
Daf.Formats.format_set_vector!
Daf.Formats.format_delete_vector!
```

### Matrix properties

```@docs
Daf.Formats.format_set_matrix!
Daf.Formats.format_relayout_matrix!
Daf.Formats.format_delete_matrix!
```

### Creating properties

```@docs
Daf.Formats.format_empty_dense_vector!
Daf.Formats.format_empty_sparse_vector!
Daf.Formats.format_filled_sparse_vector!
Daf.Formats.format_empty_dense_matrix!
Daf.Formats.format_empty_sparse_matrix!
Daf.Formats.format_filled_sparse_matrix!
```

## Index

```@index
Pages = ["formats.md"]
```
