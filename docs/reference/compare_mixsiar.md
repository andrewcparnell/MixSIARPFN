# Compare a fit with MixSIAR's posterior

For every diet proportion both have, the two posteriors' means, SDs and
95% intervals, the ratio of SDs (above 1: MixSIARPFN is wider) and the
Wasserstein-1 distance between them (the average distance one
posterior's mass has to move to match the other; on the proportion
scale). Parameters (random-effect SDs, residual multipliers) are added
from MixSIAR's summary when given, without a distance.

## Usage

``` r
compare_mixsiar(fit, draws, summary = NULL)
```

## Arguments

- fit:

  The output of [`run_pfn()`](run_pfn.md).

- draws:

  MixSIAR's draws: a data frame with `name` and `value`, from
  [`mixsiar_draws()`](mixsiar_draws.md) or
  [`mixsiar_reference()`](mixsiar_reference.md).

- summary:

  Optional: MixSIAR's summary (data frame with `name`, `mean`, `sd`,
  `q2.5`, `q97.5`), to compare the parameters as well.

## Value

A data frame, one row per quantity.
