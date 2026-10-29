# Diet proportion draws from a MixSIAR fit

Turns the output of
[`MixSIAR::run_model()`](https://rdrr.io/pkg/MixSIAR/man/run_model.html)
into the long data frame that [`compare_mixsiar()`](compare_mixsiar.md)
and [`plot_compare()`](plot_compare.md) take, named as in MixSIAR's
summary statistics (`p.global.<source>`, `p.<level label>.<source>`).

## Usage

``` r
mixsiar_draws(jags.1, mix, source)
```

## Arguments

- jags.1:

  The output of
  [`MixSIAR::run_model()`](https://rdrr.io/pkg/MixSIAR/man/run_model.html).

- mix, source:

  The `mix` and `source` objects used for that fit (from MixSIAR's or
  this package's loaders).

## Value

A data frame with columns `name` and `value`.
