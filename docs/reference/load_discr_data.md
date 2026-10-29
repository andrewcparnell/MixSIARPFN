# Load discrimination (TDF) data

Reads the trophic discrimination factor file, as
[`MixSIAR::load_discr_data()`](https://rdrr.io/pkg/MixSIAR/man/load_discr_data.html).

## Usage

``` r
load_discr_data(filename, mix)
```

## Arguments

- filename:

  Path of the discrimination `.csv` file (or a data frame): source names
  in the first column, then `Mean<tracer>` and `SD<tracer>`.

- mix:

  The output of [`load_mix_data()`](load_mix_data.md).

## Value

A list with `data`, `mu` and `sig2` (sources in MixSIAR's order).
