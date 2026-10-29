# Geese: a fixed effect and concentration dependence

This follows MixSIAR’s geese example (Inger et al. 2006 data, as
analysed in Stock et al. 2018): 251 geese in 8 groups, two tracers (δ¹³C
and δ¹⁵N) and four food sources (grass and three algae: Enteromorpha,
*Ulva lactuca* and *Zostera*). Group is a fixed effect, the sources’
elemental concentrations differ (concentration dependence), and the
error structure is Residual only. Only the fitting call differs from
MixSIAR’s vignette: [`run_pfn()`](../reference/run_pfn.md) in place of
`write_JAGS_model()` and `run_model()`.

## The data

``` r
mix <- load_mix_data(
  filename = system.file("extdata", "geese_consumer.csv", package = "MixSIARPFN"),
  iso_names = c("d13C", "d15N"), factors = "Group", fac_random = FALSE,
  fac_nested = FALSE, cont_effects = NULL)
source <- load_source_data(
  filename = system.file("extdata", "geese_sources.csv", package = "MixSIARPFN"),
  source_factors = NULL, conc_dep = TRUE, data_type = "means", mix)
discr <- load_discr_data(
  filename = system.file("extdata", "geese_discrimination.csv", package = "MixSIARPFN"),
  mix)
mix
#> Consumer data: 251 consumers, 2 tracer(s): d13C, d15N 
#>    Fixed effect Group with 8 levels
source
#> Source data: 4 sources: Enteromorpha, Grass, U.lactuca, Zostera 
#>   With concentration dependence
```

The isospace plot shows the geese, coloured by group, and the source
means after discrimination, with ±1 SD. With four sources and two
tracers the data cannot pin down every proportion (that needs at most
one more source than tracers), so some of the diet is set by the prior
and the sources’ spread:

``` r
plot_data(mix = mix, source = source, discr = discr)
#> `height` was translated to `width`.
```

![](geese_files/figure-html/isospace-1.png)

## Fitting the model

As in MixSIAR’s vignette, Residual only error (`process_err = FALSE`)
and the uninformative prior:

``` r
time <- system.time(
  fit <- run_pfn(mix, source, discr, alpha.prior = 1,
                 resid_err = TRUE, process_err = FALSE)
)
fit
#> MixSIARPFN fit (Residual only error), 4 sources, in 0.8 s
#> Marginal posteriors (no joint draws). Global diet:
#>        source  mean    sd  2.5% 97.5%
#>  Enteromorpha 0.228 0.156 0.011 0.574
#>         Grass 0.127 0.034 0.068 0.200
#>     U.lactuca 0.209 0.144 0.009 0.526
#>       Zostera 0.519 0.159 0.125 0.761
#> Use output_pfn() for every proportion and parameter.
```

The fit took 0.8 seconds.

## Results

``` r
out <- output_pfn(fit, mix, source,
                  output_options = list(summary_save = FALSE, plot_post_save_pdf = FALSE))
```

``` r
knitr::kable(round(summary_table(fit), 3))
```

|                        |  Mean |    SD |  2.5% |    5% |   25% |   50% |   75% |   95% | 97.5% |
|:-----------------------|------:|------:|------:|------:|------:|------:|------:|------:|------:|
| p.global.Enteromorpha  | 0.228 | 0.156 | 0.011 | 0.021 | 0.100 | 0.204 | 0.333 | 0.519 | 0.574 |
| p.global.Grass         | 0.127 | 0.034 | 0.068 | 0.076 | 0.103 | 0.124 | 0.148 | 0.186 | 0.200 |
| p.global.U.lactuca     | 0.209 | 0.144 | 0.009 | 0.019 | 0.091 | 0.187 | 0.305 | 0.476 | 0.526 |
| p.global.Zostera       | 0.519 | 0.159 | 0.125 | 0.212 | 0.430 | 0.545 | 0.634 | 0.732 | 0.761 |
| p.Group 1.Enteromorpha | 0.229 | 0.155 | 0.011 | 0.022 | 0.102 | 0.206 | 0.333 | 0.518 | 0.572 |
| p.Group 1.Grass        | 0.125 | 0.034 | 0.066 | 0.074 | 0.101 | 0.122 | 0.146 | 0.184 | 0.198 |
| p.Group 1.U.lactuca    | 0.210 | 0.143 | 0.010 | 0.019 | 0.092 | 0.188 | 0.306 | 0.476 | 0.526 |
| p.Group 1.Zostera      | 0.528 | 0.159 | 0.131 | 0.220 | 0.440 | 0.556 | 0.643 | 0.740 | 0.768 |
| p.Group 2.Enteromorpha | 0.396 | 0.289 | 0.004 | 0.010 | 0.101 | 0.388 | 0.675 | 0.819 | 0.847 |
| p.Group 2.Grass        | 0.179 | 0.044 | 0.089 | 0.105 | 0.150 | 0.180 | 0.208 | 0.250 | 0.264 |
| p.Group 2.U.lactuca    | 0.254 | 0.216 | 0.002 | 0.005 | 0.051 | 0.198 | 0.445 | 0.629 | 0.665 |
| p.Group 2.Zostera      | 0.107 | 0.078 | 0.011 | 0.017 | 0.049 | 0.089 | 0.146 | 0.258 | 0.301 |
| p.Group 3.Enteromorpha | 0.242 | 0.204 | 0.003 | 0.006 | 0.055 | 0.185 | 0.420 | 0.602 | 0.636 |
| p.Group 3.Grass        | 0.409 | 0.045 | 0.319 | 0.335 | 0.380 | 0.410 | 0.439 | 0.482 | 0.496 |
| p.Group 3.U.lactuca    | 0.260 | 0.175 | 0.004 | 0.010 | 0.089 | 0.270 | 0.415 | 0.521 | 0.547 |
| p.Group 3.Zostera      | 0.077 | 0.054 | 0.007 | 0.011 | 0.036 | 0.067 | 0.107 | 0.181 | 0.208 |
| p.Group 4.Enteromorpha | 0.321 | 0.216 | 0.009 | 0.018 | 0.125 | 0.308 | 0.498 | 0.681 | 0.725 |
| p.Group 4.Grass        | 0.117 | 0.042 | 0.040 | 0.051 | 0.088 | 0.116 | 0.145 | 0.188 | 0.203 |
| p.Group 4.U.lactuca    | 0.194 | 0.156 | 0.004 | 0.009 | 0.058 | 0.160 | 0.305 | 0.489 | 0.536 |
| p.Group 4.Zostera      | 0.419 | 0.174 | 0.057 | 0.104 | 0.299 | 0.431 | 0.546 | 0.687 | 0.728 |
| p.Group 5.Enteromorpha | 0.475 | 0.321 | 0.005 | 0.011 | 0.134 | 0.527 | 0.780 | 0.893 | 0.914 |
| p.Group 5.Grass        | 0.119 | 0.041 | 0.041 | 0.053 | 0.091 | 0.118 | 0.146 | 0.187 | 0.201 |
| p.Group 5.U.lactuca    | 0.262 | 0.236 | 0.001 | 0.004 | 0.042 | 0.190 | 0.473 | 0.674 | 0.711 |
| p.Group 5.Zostera      | 0.095 | 0.069 | 0.009 | 0.014 | 0.043 | 0.079 | 0.130 | 0.229 | 0.267 |
| p.Group 6.Enteromorpha | 0.290 | 0.225 | 0.004 | 0.008 | 0.073 | 0.251 | 0.501 | 0.654 | 0.685 |
| p.Group 6.Grass        | 0.369 | 0.051 | 0.267 | 0.285 | 0.336 | 0.369 | 0.403 | 0.451 | 0.467 |
| p.Group 6.U.lactuca    | 0.269 | 0.184 | 0.004 | 0.010 | 0.091 | 0.269 | 0.432 | 0.552 | 0.581 |
| p.Group 6.Zostera      | 0.096 | 0.070 | 0.008 | 0.014 | 0.044 | 0.081 | 0.133 | 0.231 | 0.267 |
| p.Group 7.Enteromorpha | 0.108 | 0.078 | 0.006 | 0.011 | 0.045 | 0.092 | 0.156 | 0.255 | 0.288 |
| p.Group 7.Grass        | 0.742 | 0.049 | 0.641 | 0.659 | 0.711 | 0.744 | 0.776 | 0.818 | 0.832 |
| p.Group 7.U.lactuca    | 0.097 | 0.066 | 0.007 | 0.011 | 0.044 | 0.086 | 0.138 | 0.219 | 0.246 |
| p.Group 7.Zostera      | 0.064 | 0.040 | 0.008 | 0.012 | 0.033 | 0.057 | 0.087 | 0.138 | 0.157 |
| p.Group 8.Enteromorpha | 0.065 | 0.052 | 0.005 | 0.008 | 0.026 | 0.052 | 0.091 | 0.167 | 0.196 |
| p.Group 8.Grass        | 0.828 | 0.048 | 0.728 | 0.746 | 0.798 | 0.831 | 0.861 | 0.902 | 0.915 |
| p.Group 8.U.lactuca    | 0.054 | 0.041 | 0.005 | 0.007 | 0.023 | 0.043 | 0.074 | 0.135 | 0.158 |
| p.Group 8.Zostera      | 0.048 | 0.032 | 0.006 | 0.008 | 0.023 | 0.041 | 0.065 | 0.109 | 0.126 |

With a fixed effect, MixSIAR’s global diet is the diet of the first
group, so the plots below show the eight groups:

``` r
out$plots$Group
```

![](geese_files/figure-html/group-plot-1.png)

Each is a **marginal** posterior: the network does not give joint draws,
so the marginal means of one group’s diet need not sum to exactly 1, and
sums or ratios of proportions cannot be computed from the output.

## Comparison with MixSIAR

``` r
ref <- mixsiar_reference("geese")
cmp <- compare_mixsiar(fit, ref$draws, ref$summary)
```

MixSIAR 3.1.12 fitted the same model with 3 chains of 1,000,000
iterations (burn-in 500,000), which took about 2.9 hours (largest
Gelman-Rubin diagnostic 1.004). MixSIARPFN took 0.8 seconds.

Means, SDs, 95% intervals and the Wasserstein-1 distance (W1: how far,
on average, one posterior’s mass has to move to match the other, on the
proportion scale):

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
| p.Group 1.Enteromorpha | 0.229 | 0.092 | 0.155 | 0.082 | 0.01 to 0.57 | 0.00 to 0.29 | 0.137 |
| p.Group 1.Grass | 0.125 | 0.122 | 0.034 | 0.021 | 0.07 to 0.20 | 0.08 to 0.17 | 0.010 |
| p.Group 1.U.lactuca | 0.210 | 0.209 | 0.143 | 0.073 | 0.01 to 0.53 | 0.07 to 0.35 | 0.061 |
| p.Group 1.Zostera | 0.528 | 0.577 | 0.159 | 0.069 | 0.13 to 0.77 | 0.44 to 0.71 | 0.070 |
| p.Group 2.Enteromorpha | 0.396 | 0.198 | 0.289 | 0.224 | 0.00 to 0.85 | 0.00 to 0.74 | 0.198 |
| p.Group 2.Grass | 0.179 | 0.200 | 0.044 | 0.030 | 0.09 to 0.26 | 0.13 to 0.24 | 0.024 |
| p.Group 2.U.lactuca | 0.254 | 0.442 | 0.216 | 0.173 | 0.00 to 0.67 | 0.04 to 0.64 | 0.191 |
| p.Group 2.Zostera | 0.107 | 0.160 | 0.078 | 0.044 | 0.01 to 0.30 | 0.07 to 0.24 | 0.061 |
| p.Group 3.Enteromorpha | 0.242 | 0.109 | 0.204 | 0.137 | 0.00 to 0.64 | 0.00 to 0.53 | 0.134 |
| p.Group 3.Grass | 0.409 | 0.430 | 0.045 | 0.027 | 0.32 to 0.50 | 0.36 to 0.47 | 0.025 |
| p.Group 3.U.lactuca | 0.260 | 0.399 | 0.175 | 0.107 | 0.00 to 0.55 | 0.08 to 0.52 | 0.143 |
| p.Group 3.Zostera | 0.077 | 0.063 | 0.054 | 0.024 | 0.01 to 0.21 | 0.02 to 0.11 | 0.023 |
| p.Group 4.Enteromorpha | 0.321 | 0.136 | 0.216 | 0.143 | 0.01 to 0.73 | 0.00 to 0.48 | 0.186 |
| p.Group 4.Grass | 0.117 | 0.133 | 0.042 | 0.028 | 0.04 to 0.20 | 0.08 to 0.19 | 0.018 |
| p.Group 4.U.lactuca | 0.194 | 0.234 | 0.156 | 0.111 | 0.00 to 0.54 | 0.02 to 0.43 | 0.063 |
| p.Group 4.Zostera | 0.419 | 0.498 | 0.174 | 0.088 | 0.06 to 0.73 | 0.34 to 0.68 | 0.090 |
| p.Group 5.Enteromorpha | 0.475 | 0.205 | 0.321 | 0.246 | 0.00 to 0.91 | 0.00 to 0.80 | 0.269 |
| p.Group 5.Grass | 0.119 | 0.153 | 0.041 | 0.029 | 0.04 to 0.20 | 0.09 to 0.19 | 0.036 |
| p.Group 5.U.lactuca | 0.262 | 0.505 | 0.236 | 0.197 | 0.00 to 0.71 | 0.03 to 0.71 | 0.244 |
| p.Group 5.Zostera | 0.095 | 0.137 | 0.069 | 0.040 | 0.01 to 0.27 | 0.06 to 0.22 | 0.049 |
| p.Group 6.Enteromorpha | 0.290 | 0.129 | 0.225 | 0.155 | 0.00 to 0.69 | 0.00 to 0.56 | 0.161 |
| p.Group 6.Grass | 0.369 | 0.388 | 0.051 | 0.032 | 0.27 to 0.47 | 0.31 to 0.44 | 0.024 |
| p.Group 6.U.lactuca | 0.269 | 0.399 | 0.184 | 0.125 | 0.00 to 0.58 | 0.06 to 0.55 | 0.134 |
| p.Group 6.Zostera | 0.096 | 0.085 | 0.070 | 0.034 | 0.01 to 0.27 | 0.03 to 0.15 | 0.026 |
| p.Group 7.Enteromorpha | 0.108 | 0.058 | 0.078 | 0.056 | 0.01 to 0.29 | 0.00 to 0.20 | 0.050 |
| p.Group 7.Grass | 0.742 | 0.769 | 0.049 | 0.030 | 0.64 to 0.83 | 0.71 to 0.83 | 0.028 |
| p.Group 7.U.lactuca | 0.097 | 0.108 | 0.066 | 0.051 | 0.01 to 0.25 | 0.02 to 0.20 | 0.019 |
| p.Group 7.Zostera | 0.064 | 0.064 | 0.040 | 0.028 | 0.01 to 0.16 | 0.02 to 0.13 | 0.009 |
| p.Group 8.Enteromorpha | 0.065 | 0.024 | 0.052 | 0.023 | 0.00 to 0.20 | 0.00 to 0.08 | 0.042 |
| p.Group 8.Grass | 0.828 | 0.875 | 0.048 | 0.023 | 0.73 to 0.91 | 0.83 to 0.92 | 0.047 |
| p.Group 8.U.lactuca | 0.054 | 0.033 | 0.041 | 0.022 | 0.00 to 0.16 | 0.00 to 0.09 | 0.020 |
| p.Group 8.Zostera | 0.048 | 0.068 | 0.032 | 0.021 | 0.01 to 0.13 | 0.03 to 0.11 | 0.023 |

``` r
plot_compare(fit, ref$draws, block = "Group")
```

![](geese_files/figure-html/compare-group-1.png)

``` r
plot_compare(fit, ref$draws, type = "means")
```

![](geese_files/figure-html/compare-means-1.png)

**What this shows.** Grass, the source the data pin down best, is close
in every group: MixSIARPFN’s means differ from MixSIAR’s by 0.02 on
average, though its posteriors are wider (median SD ratio 1.59). The
three algae trade off against each other, since four sources cannot all
be determined from two tracers, and there the two fits differ more: mean
difference 0.09, median SD ratio 1.53, and the largest difference is
Group 5.Enteromorpha (0.47 against 0.21). For data like these, where
sources overlap, MixSIARPFN gives a quick first answer and a MixSIAR run
the more precise one.
