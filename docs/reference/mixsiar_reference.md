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
`sd`, `q2.5`, `q97.5`) and `info` (list).
