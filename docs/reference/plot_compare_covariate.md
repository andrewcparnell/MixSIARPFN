# Compare diets along a continuous effect with MixSIAR's

Each consumer's diet posterior (mean and 95% interval) from MixSIARPFN
against MixSIAR's (`p.ind`), plotted against the consumer's value of the
continuous effect, one panel per source.

## Usage

``` r
plot_compare_covariate(fit, pind, cont = fit$cont_effects[1], by = NULL)
```

## Arguments

- fit:

  The output of
  [`run_pfn()`](https://andrewcparnell.github.io/MixSIARPFN/reference/run_pfn.md),
  for a model with a continuous effect.

- pind:

  MixSIAR's per-consumer diets: `mixsiar_reference(...)$pind`, or a data
  frame with columns `consumer`, `source`, `mean`, `q2.5`, `q97.5` and
  the covariate.

- cont:

  The continuous effect (default: the model's first).

- by:

  Optional: a factor of the model (a column of `pind`) to split the
  panels by, when the diet depends on it as well as on the covariate.

## Value

A ggplot.
