# Load mixture (consumer) data

Reads the consumer data file and records the model's random, fixed and
continuous effects, exactly as
[`MixSIAR::load_mix_data()`](https://rdrr.io/pkg/MixSIAR/man/load_mix_data.html)
does, with the same arguments.

## Usage

``` r
load_mix_data(
  filename,
  iso_names,
  factors,
  fac_random,
  fac_nested,
  cont_effects
)
```

## Arguments

- filename:

  Path of the consumer `.csv` file (or a data frame with its contents):
  one row per consumer, one column per tracer and per effect.

- iso_names:

  Names of the tracer columns to use, e.g. `c("d13C", "d15N")`.

- factors:

  Names of the categorical effect columns (0, 1 or 2), or `NULL`.

- fac_random:

  Logical, one per factor: `TRUE` for a random effect, `FALSE` for a
  fixed effect.

- fac_nested:

  Logical, one per factor: `TRUE` for a factor nested within the other
  (only with two random effects), or `NULL`.

- cont_effects:

  Name of a continuous effect column (0 or 1), or `NULL`.

## Value

A list with MixSIAR's fields (`data`, `data_iso`, `n.iso`, `n.re`,
`n.fe`, `n.ce`, `n.effects`, `FAC`, `CE`, `CE_orig`, `CE_center`,
`CE_scale`, `cont_effects`, `MU_names`, `SIG_names`, `iso_names`, `N`,
`factors`, `fac_random`, `fac_nested`, `fere`). As in MixSIAR, a fixed
effect is put before a random one.

## Examples

``` r
mix <- load_mix_data(
  filename = system.file("extdata", "wolves_consumer.csv", package = "MixSIARPFN"),
  iso_names = c("d13C", "d15N"), factors = c("Region", "Pack"),
  fac_random = c(TRUE, TRUE), fac_nested = c(FALSE, TRUE), cont_effects = NULL)
```
