# Fit a MixSIAR model with the prior-data fitted network

Replaces MixSIAR's `write_JAGS_model()` and `run_model()`: takes the
same data objects and model options and returns the marginal posterior
of every diet proportion and model parameter, from the network trained
for the chosen error structure. There is no MCMC, so no chain length,
burn-in or convergence to check.

## Usage

``` r
run_pfn(
  mix,
  source,
  discr,
  alpha.prior = 1,
  resid_err = TRUE,
  process_err = TRUE,
  seed = 1,
  cont_values = NULL
)
```

## Arguments

- mix, source, discr:

  The outputs of
  [`load_mix_data()`](https://andrewcparnell.github.io/MixSIARPFN/reference/load_mix_data.md),
  [`load_source_data()`](https://andrewcparnell.github.io/MixSIARPFN/reference/load_source_data.md)
  and
  [`load_discr_data()`](https://andrewcparnell.github.io/MixSIARPFN/reference/load_discr_data.md).

- alpha.prior:

  Dirichlet prior on the global diet: one number for every source
  (MixSIAR's default 1) or one per source, in `source$source_names`
  order.

- resid_err, process_err:

  The error structure, as in MixSIAR: both `TRUE` (Residual \* Process,
  MixSIAR's default), or only one of them.

- seed:

  Seed for the random level assignments the network averages over.

- cont_values:

  For a continuous effect: the values (original units) to report the
  diet at. By default 25 values over the observed range.

## Value

An object of class `pfn_fit`: `summary` (one row per diet proportion,
with MixSIAR's quantiles and row names such as `p.global.Deer`),
`parameters` (random-effect SDs, residual error multipliers, covariate
slopes), the bar probabilities behind each marginal (for
[`posterior_draws()`](https://andrewcparnell.github.io/MixSIARPFN/reference/posterior_draws.md)),
and the model options. It holds only R objects, so it can be saved with
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html).

## Details

The network gives each quantity's *marginal* posterior, not joint draws:
the marginal means of one diet need not sum to exactly 1, and sums,
differences or ratios of proportions cannot be computed from the output.

Data, priors and model options outside what the networks were trained
for (for example more than 8 sources or 4 tracers) are refused with a
message saying which limit was exceeded.

## Examples

``` r
if (FALSE) { # \dontrun{
x <- function(f) system.file("extdata", f, package = "MixSIARPFN")
mix <- load_mix_data(x("wolves_consumer.csv"), iso_names = c("d13C", "d15N"),
                     factors = c("Region", "Pack"), fac_random = c(TRUE, TRUE),
                     fac_nested = c(FALSE, TRUE), cont_effects = NULL)
source <- load_source_data(x("wolves_sources.csv"), source_factors = "Region",
                           conc_dep = FALSE, data_type = "means", mix)
discr <- load_discr_data(x("wolves_discrimination.csv"), mix)
fit <- run_pfn(mix, source, discr)
fit
} # }
```
