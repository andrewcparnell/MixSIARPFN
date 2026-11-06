# Isospace plot of the data, as MixSIAR's plot_data()

Plots the consumers and the source means corrected for discrimination,
with error bars of +/- 1 SD (source and discrimination SDs combined, as
MixSIAR does), for each pair of tracers. With sources given by a factor,
each source has one point per level.

## Usage

``` r
plot_data(
  filename = "isospace_plot",
  plot_save_pdf = FALSE,
  plot_save_png = FALSE,
  mix,
  source,
  discr,
  return_obj = FALSE
)
```

## Arguments

- filename:

  Stem of the file names to save to.

- plot_save_pdf, plot_save_png:

  Save each plot as PDF or PNG?

- mix, source, discr:

  The outputs of
  [`load_mix_data()`](https://andrewcparnell.github.io/MixSIARPFN/reference/load_mix_data.md),
  [`load_source_data()`](https://andrewcparnell.github.io/MixSIARPFN/reference/load_source_data.md)
  and
  [`load_discr_data()`](https://andrewcparnell.github.io/MixSIARPFN/reference/load_discr_data.md).

- return_obj:

  Return the plots (a list of ggplot objects) instead of printing them?

## Value

Invisibly (or, with `return_obj = TRUE`, visibly) a list of ggplot
objects, one per pair of tracers (one plot for a single tracer).
