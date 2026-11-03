# Changelog

## MixSIARPFN 0.1.0

First release.

- MixSIAR’s loaders, [`load_mix_data()`](../reference/load_mix_data.md),
  [`load_source_data()`](../reference/load_source_data.md) and
  [`load_discr_data()`](../reference/load_discr_data.md), with the same
  arguments and checks, and [`plot_data()`](../reference/plot_data.md).
- [`run_pfn()`](../reference/run_pfn.md) in place of
  `write_JAGS_model()` and `run_model()`: marginal posteriors of every
  diet proportion and parameter from prior-data fitted networks, one per
  error structure (Residual \* Process, Residual only, Process only), in
  about a second. Isotope data with source summary statistics
  (`data_type = "means"`).
- [`output_pfn()`](../reference/output_pfn.md) in place of
  `output_JAGS()`, with
  [`summary_table()`](../reference/summary_table.md),
  [`posterior_draws()`](../reference/posterior_draws.md) and
  [`pfn_networks()`](../reference/pfn_networks.md).
- Comparison with MixSIAR:
  [`mixsiar_reference()`](../reference/mixsiar_reference.md) (MixSIAR’s
  own fits of the three examples, with a posterior predictive check of
  each), [`mixsiar_draws()`](../reference/mixsiar_draws.md),
  [`compare_mixsiar()`](../reference/compare_mixsiar.md) and
  [`plot_compare()`](../reference/plot_compare.md).
- Networks version 2, downloaded from Zenodo on first use and checked by
  SHA-256.
- Vignettes: MixSIAR’s killer whale, geese and wolves examples, each
  compared with MixSIAR’s fit.
- Article “How MixSIARPFN works and how well it does”: the network, its
  training, and a simulation study of 450 datasets with known diets
  against converged MixSIAR.
