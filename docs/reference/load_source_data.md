# Load source data

Reads the source data file, exactly as
[`MixSIAR::load_source_data()`](https://rdrr.io/pkg/MixSIAR/man/load_source_data.html)
does, with the same arguments: either source summary statistics
(`data_type = "means"`) or raw source samples (`data_type = "raw"`),
which are summarised to means, SDs and sample sizes.

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

  `"means"` (source means, SDs and sample sizes) or `"raw"` (one row per
  source sample, columns named by the tracers). Raw data are summarised
  to each source's mean, SD and sample size (per level of
  `source_factors`, if given; with mean concentrations if `conc_dep`),
  which is what the networks use. MixSIAR's raw data model instead
  estimates each source's mean and variance in the fit, so results can
  differ a little from MixSIAR's for small source samples.

- mix:

  The output of [`load_mix_data()`](load_mix_data.md).

## Value

A list with `data`, `source_names` (MixSIAR's alphabetical order),
`n.sources`, `source_factors`, `by_factor`, `conc_dep`, `conc`,
`data_type`, `S_factor1` and `S_factor_levels`.
