# MixSIAR's own fits of the example data

MixSIAR 3.1.12 fits of MixSIAR's example datasets, made for benchmarking
MixSIARPFN: 1,000 posterior draws of every diet proportion (thinned from
the saved chains), MixSIAR's summary statistics (which also cover the
random-effect SDs and residual multipliers), and the run settings (chain
length, burn-in, run time, largest Gelman-Rubin diagnostic).

## Usage

``` r
mixsiar_reference(vignette)
```

## Arguments

- vignette:

  The example's name (see Details).

## Value

A list with `draws` (data frame: `name`, `value`; names as in MixSIAR's
summary, e.g. `p.Pack 1.Deer`), `summary` (data frame: `name`, `mean`,
`sd`, `q2.5`, `q97.5`), `info` (list), `ppc` (list or `NULL`: `stats`,
one row per checked statistic with the observed value, the replicated
mean and 95% interval and the posterior predictive p-value `ppp`;
`summary` and `controls`, how many group statistics fall outside 95% and
99% of their replicates; `grouping`, the factor checked) and `pind`
(data frame or `NULL`: with a continuous effect, each consumer's diet
posterior mean and 95% interval from MixSIAR's `p.ind`, with the
consumer's covariate and factor values; see
[`plot_compare_covariate()`](plot_compare_covariate.md)).

## Details

The examples are `"killerwhale"`, `"geese"` and `"wolves"`, and
MixSIAR's further examples `"alligator_1"` to `"alligator_8"` (its eight
alligator models), `"lake"`, `"mantis"`, `"palmyra"`, `"snail"` and
`"stormpetrel"`. Lake, palmyra, snail and storm petrel have raw source
data: their reference is MixSIAR fitted to the same source summaries
MixSIARPFN uses (means, SDs and sample sizes), and `"<name>_raw"` is
MixSIAR fitted to the raw source data, as in MixSIAR's own example
script.

For the killer whale, geese and wolves fits there is also a posterior
predictive check: MixSIAR's own model, rerun with replicated consumers
drawn from its likelihood, compared with the data group by group (each
tracer's mean and SD, and the correlation between tracers), on the
standardised tracer scale MixSIAR's JAGS model uses. The same check on
six datasets simulated from the model itself, like geese and like
wolves, shows what a good fit looks like.
