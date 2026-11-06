# Killer whale: no effects

This follows MixSIAR’s killer whale example (Semmens et al. 2013 data,
as analysed in Stock et al. 2018): 12 killer whales, two tracers (δ¹³C
and δ¹⁵N) and five salmon prey sources, with no random, fixed or
continuous effects. It is the simplest MixSIAR model, and a good first
check. Only the fitting call differs from MixSIAR’s vignette:
[`run_pfn()`](https://andrewcparnell.github.io/MixSIARPFN/reference/run_pfn.md)
in place of `write_JAGS_model()` and `run_model()`.

## The data

``` r
mix <- load_mix_data(
  filename = system.file("extdata", "killerwhale_consumer.csv", package = "MixSIARPFN"),
  iso_names = c("d13C", "d15N"), factors = NULL, fac_random = NULL,
  fac_nested = NULL, cont_effects = NULL)
source <- load_source_data(
  filename = system.file("extdata", "killerwhale_sources.csv", package = "MixSIARPFN"),
  source_factors = NULL, conc_dep = FALSE, data_type = "means", mix)
discr <- load_discr_data(
  filename = system.file("extdata", "killerwhale_discrimination.csv", package = "MixSIARPFN"),
  mix)
mix
#> Consumer data: 12 consumers, 2 tracer(s): d13C, d15N
source
#> Source data: 5 sources: Chinook, Chum, Coho, Sockeye, Steelhead
```

``` r
plot_data(mix = mix, source = source, discr = discr)
```

![](killerwhale_files/figure-html/isospace-1.png)

## Fitting the model

Residual \* Process error and MixSIAR’s uninformative Dirichlet prior
(all `alpha.prior` equal to 1), as in MixSIAR’s vignette. The network
for this error structure is downloaded the first time it is needed
(about 70 MB) and cached.

``` r
time <- system.time(
  fit <- run_pfn(mix, source, discr, alpha.prior = 1,
                 resid_err = TRUE, process_err = TRUE)
)
fit
#> MixSIARPFN fit (Residual * Process error), 5 sources, in 0.2 s
#> Marginal posteriors (no joint draws). Global diet:
#>     source  mean    sd  2.5% 97.5%
#>    Chinook 0.360 0.120 0.087 0.539
#>       Chum 0.125 0.101 0.004 0.374
#>       Coho 0.189 0.140 0.009 0.526
#>    Sockeye 0.090 0.070 0.003 0.254
#>  Steelhead 0.238 0.106 0.024 0.414
#> Use output_pfn() for every proportion and parameter.
```

The fit took 0.2 seconds.

## Results

``` r
out <- output_pfn(fit, mix, source,
                  output_options = list(summary_save = FALSE, plot_post_save_pdf = FALSE))
```

``` r
knitr::kable(round(summary_table(fit), 3))
```

|                    |  Mean |    SD |  2.5% |    5% |   25% |   50% |   75% |   95% | 97.5% |
|:-------------------|------:|------:|------:|------:|------:|------:|------:|------:|------:|
| Epsilon.1          | 1.081 | 0.843 | 0.311 | 0.366 | 0.604 | 0.874 | 1.295 | 2.423 | 3.048 |
| Epsilon.2          | 2.425 | 1.715 | 0.691 | 0.812 | 1.351 | 1.970 | 2.937 | 5.537 | 6.911 |
| p.global.Chinook   | 0.360 | 0.120 | 0.087 | 0.130 | 0.284 | 0.381 | 0.451 | 0.520 | 0.539 |
| p.global.Chum      | 0.125 | 0.101 | 0.004 | 0.008 | 0.045 | 0.101 | 0.181 | 0.325 | 0.374 |
| p.global.Coho      | 0.189 | 0.140 | 0.009 | 0.017 | 0.078 | 0.159 | 0.271 | 0.468 | 0.526 |
| p.global.Sockeye   | 0.090 | 0.070 | 0.003 | 0.006 | 0.034 | 0.075 | 0.133 | 0.225 | 0.254 |
| p.global.Steelhead | 0.238 | 0.106 | 0.024 | 0.046 | 0.161 | 0.251 | 0.320 | 0.393 | 0.414 |

``` r
out$plots$global
```

![](killerwhale_files/figure-html/result-plots-1.png)

``` r
out$plots$Epsilon.1
out$plots$Epsilon.2
```

![](killerwhale_files/figure-html/eps-plots-1.png)![](killerwhale_files/figure-html/eps-plots-2.png)

Each is a **marginal** posterior: the network does not give joint draws,
so the marginal means need not sum to exactly 1, and sums or ratios of
proportions cannot be computed from the output.

## Comparison with MixSIAR

``` r
ref <- mixsiar_reference("killerwhale")
cmp <- compare_mixsiar(fit, ref$draws, ref$summary)
```

MixSIAR 3.1.12 fitted the same model with 3 chains of 1,000,000
iterations (burn-in 500,000), which took about 23 minutes (largest
Gelman-Rubin diagnostic 1.005). MixSIARPFN took 0.2 seconds.

Means, SDs, 95% intervals and the Wasserstein-1 distance (W1: how far,
on average, one posterior’s mass has to move to match the other, on the
proportion scale; the residual multipliers’ draws were not saved, so
they have no W1):

``` r
knitr::kable(data.frame(
  quantity = cmp$name,
  `MixSIARPFN mean` = round(cmp$pfn_mean, 3), `MixSIAR mean` = round(cmp$mixsiar_mean, 3),
  `MixSIARPFN SD` = round(cmp$pfn_sd, 3), `MixSIAR SD` = round(cmp$mixsiar_sd, 3),
  `MixSIARPFN 95% CI` = sprintf("%.2f to %.2f", cmp$pfn_q2.5, cmp$pfn_q97.5),
  `MixSIAR 95% CI` = sprintf("%.2f to %.2f", cmp$mixsiar_q2.5, cmp$mixsiar_q97.5),
  W1 = round(cmp$w1, 3), check.names = FALSE))
```

| quantity | MixSIARPFN mean | MixSIAR mean | MixSIARPFN SD | MixSIAR SD | MixSIARPFN 95% CI | MixSIAR 95% CI | W1 |
|:---|---:|---:|---:|---:|:---|:---|---:|
| Epsilon.1 | 1.081 | 1.082 | 0.843 | 0.802 | 0.31 to 3.05 | 0.33 to 3.10 | NA |
| Epsilon.2 | 2.425 | 2.585 | 1.715 | 1.997 | 0.69 to 6.91 | 0.72 to 8.28 | NA |
| p.global.Chinook | 0.360 | 0.369 | 0.120 | 0.111 | 0.09 to 0.54 | 0.09 to 0.52 | 0.011 |
| p.global.Chum | 0.125 | 0.106 | 0.101 | 0.092 | 0.00 to 0.37 | 0.00 to 0.32 | 0.019 |
| p.global.Coho | 0.189 | 0.172 | 0.140 | 0.136 | 0.01 to 0.53 | 0.01 to 0.51 | 0.018 |
| p.global.Sockeye | 0.090 | 0.067 | 0.070 | 0.056 | 0.00 to 0.25 | 0.00 to 0.20 | 0.023 |
| p.global.Steelhead | 0.238 | 0.286 | 0.106 | 0.089 | 0.02 to 0.41 | 0.08 to 0.43 | 0.048 |

``` r
plot_compare(fit, ref$draws, block = "global")
```

![](killerwhale_files/figure-html/compare-global-1.png)

``` r
plot_compare(fit, ref$draws, type = "means")
```

![](killerwhale_files/figure-html/compare-means-1.png)

**What this shows.** The two posteriors are close. MixSIARPFN’s means
differ from MixSIAR’s by 0.02 on average (MixSIAR’s posterior SDs are
about 0.10), and its SDs are about the same (median SD ratio 1.09). The
largest difference is for Steelhead (0.24 against 0.29).

## Does MixSIAR’s model fit these data?

The comparison takes MixSIAR as the reference, which is fair where
MixSIAR’s model describes the data. A posterior predictive check tests
that: MixSIAR’s fitted model generates new datasets, one per posterior
draw, and the real data are compared with them. MixSIARPFN gives
marginal posteriors only, so it cannot run this check itself; the
results come from a separate MixSIAR run with the same model and data,
shipped with the package (`mixsiar_reference("killerwhale")$ppc`). Each
tracer’s mean and SD and the correlation between the tracers, on the
standardised scale MixSIAR’s model uses:

![](killerwhale_files/figure-html/ppc-plot-1.png)

0 of the 5 statistics fall outside the 95% range of the model’s
datasets: the twelve killer whales look like data MixSIAR’s model
generates, so its posterior is a fair reference here, and MixSIARPFN
agrees with it closely. The geese and wolves vignettes show what happens
when the check fails.
