# MixSIAR's own fits of the example data

MixSIAR 3.1.12 fits of the killer whale, geese and wolves vignettes,
made for benchmarking MixSIARPFN: 1,000 posterior draws of every diet
proportion (thinned from the saved chains), MixSIAR's summary statistics
table (which also covers the random-effect SDs and residual multipliers,
whose draws were not saved), and the run settings (chain length,
burn-in, run time, largest Gelman-Rubin diagnostic).

## Usage

``` r
mixsiar_reference(vignette = c("killerwhale", "geese", "wolves"))
```

## Arguments

- vignette:

  `"killerwhale"`, `"geese"` or `"wolves"`.

## Value

A list with `draws` (data frame: `name`, `value`; names as in MixSIAR's
summary, e.g. `p.Pack 1.Deer`), `summary` (data frame: `name`, `mean`,
`sd`, `q2.5`, `q97.5`), `info` (list) and `ppc` (list: `stats`, one row
per checked statistic with the observed value, the replicated mean and
95% interval and the posterior predictive p-value `ppp`; `summary` and
`controls`, how many group statistics fall outside 95% and 99% of their
replicates; `grouping`, the factor checked).

## Details

Also a posterior predictive check of each MixSIAR fit: MixSIAR's own
model, rerun with replicated consumers drawn from its likelihood,
compared with the data group by group (each tracer's mean and SD, and
the correlation between tracers), on the standardised tracer scale
MixSIAR's JAGS model uses. The same check on six datasets simulated from
the model itself, like geese and like wolves, shows what a good fit
looks like.
