# Plot a fit against MixSIAR's posterior

`type = "density"`: each diet proportion's posterior density from
MixSIARPFN (from its bars) and from MixSIAR (kernel density of its
draws), one panel per proportion. `type = "means"`: MixSIARPFN's
posterior mean and SD of every proportion against MixSIAR's, with the
1:1 line.

## Usage

``` r
plot_compare(fit, draws, type = c("density", "means"), block = NULL)
```

## Arguments

- fit:

  The output of
  [`run_pfn()`](https://andrewcparnell.github.io/MixSIARPFN/reference/run_pfn.md).

- draws:

  MixSIAR's draws (data frame with `name` and `value`).

- type:

  `"density"` or `"means"`.

- block:

  For `type = "density"`: which block to plot (`"global"` or an effect
  name such as `"Pack"`). Default: the global diet, or the first effect
  if MixSIAR has no global draws.

## Value

A ggplot object.
