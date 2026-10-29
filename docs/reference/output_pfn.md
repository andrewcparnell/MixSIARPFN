# Summaries and plots of a fit, like MixSIAR's output_JAGS()

Takes the same `output_options` list as
[`MixSIAR::output_JAGS()`](https://rdrr.io/pkg/MixSIAR/man/output_JAGS.html).
It prints the summary statistics table (mean, SD and quantiles of every
proportion and parameter, with MixSIAR's row names) and saves it if
asked, and draws a posterior density plot for the global diet, each
effect and each parameter, shown and/or saved as PDF or PNG. Options
that concern MCMC (convergence diagnostics, DIC, pairs plots of joint
draws) do not apply and are ignored.

## Usage

``` r
output_pfn(fit, mix = NULL, source = NULL, output_options = list())
```

## Arguments

- fit:

  The output of [`run_pfn()`](run_pfn.md).

- mix, source:

  The outputs of [`load_mix_data()`](load_mix_data.md) and
  [`load_source_data()`](load_source_data.md) (accepted for
  compatibility with `output_JAGS()`; the fit holds what is needed).

- output_options:

  A list as for
  [`MixSIAR::output_JAGS()`](https://rdrr.io/pkg/MixSIAR/man/output_JAGS.html).
  Used here: `summary_save`, `summary_name`, `sup_post`,
  `plot_post_save_pdf`, `plot_post_save_png`, `plot_post_name`. Missing
  entries take MixSIAR's defaults.

## Value

Invisibly, a list with `summary` (the table as a data frame) and `plots`
(the ggplot objects).
