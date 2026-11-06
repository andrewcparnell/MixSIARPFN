# Draws from the marginal posteriors

Independent draws from each proportion's (and parameter's) marginal
posterior. These are marginal draws: draw `i` of one proportion and draw
`i` of another do not come from one joint posterior draw, so do not add,
subtract or divide them.

## Usage

``` r
posterior_draws(fit, n = 3000, seed = NULL)
```

## Arguments

- fit:

  The output of
  [`run_pfn()`](https://andrewcparnell.github.io/MixSIARPFN/reference/run_pfn.md).

- n:

  Number of draws per quantity.

- seed:

  Optional seed.

## Value

A long data frame: `name` (MixSIAR's row name), `block`, `level`,
`source` (or parameter), `draw`, `value`.
