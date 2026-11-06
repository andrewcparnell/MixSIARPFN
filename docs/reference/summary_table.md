# The summary statistics table of a fit

One row per parameter and proportion, columns Mean, SD and the quantiles
MixSIAR reports, with MixSIAR's row names (`Epsilon.1`, `Region.SD`,
`p.global.Deer`, `p.Region 1.Deer`, ...).

## Usage

``` r
summary_table(fit)
```

## Arguments

- fit:

  The output of
  [`run_pfn()`](https://andrewcparnell.github.io/MixSIARPFN/reference/run_pfn.md).

## Value

A numeric matrix.
