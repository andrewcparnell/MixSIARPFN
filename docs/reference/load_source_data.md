# Load source data

Reads the source data file (means, SDs and sample sizes), exactly as
[`MixSIAR::load_source_data()`](https://rdrr.io/pkg/MixSIAR/man/load_source_data.html)
does, with the same arguments. Only source summary statistics
(`data_type = "means"`) are supported in this version.

## Usage

``` r
load_source_data(filename, source_factors = NULL, conc_dep, data_type, mix)
```

## Arguments

- filename:

  Path of the source `.csv` file (or a data frame): source names in the
  first column, then `Mean<tracer>`, `SD<tracer>`, `n` and, with
  concentration dependence, `Conc<tracer>`.

- source_factors:

  Name of the categorical effect the sources are given by (one row per
  source and level), or `NULL`.

- conc_dep:

  Logical: use concentration dependence?

- data_type:

  `"means"` (source means and SDs). `"raw"` is not supported yet.

- mix:

  The output of [`load_mix_data()`](load_mix_data.md).

## Value

A list with `data`, `source_names` (MixSIAR's alphabetical order),
`n.sources`, `source_factors`, `by_factor`, `conc_dep`, `conc`,
`data_type`, `S_factor1` and `S_factor_levels`.
