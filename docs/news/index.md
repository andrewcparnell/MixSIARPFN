# Changelog

## MixSIARPFN 0.1.0

First release.

- MixSIAR’s loaders,
  [`load_mix_data()`](https://andrewcparnell.github.io/MixSIARPFN/reference/load_mix_data.md),
  [`load_source_data()`](https://andrewcparnell.github.io/MixSIARPFN/reference/load_source_data.md)
  and
  [`load_discr_data()`](https://andrewcparnell.github.io/MixSIARPFN/reference/load_discr_data.md),
  with the same arguments and checks, and
  [`plot_data()`](https://andrewcparnell.github.io/MixSIARPFN/reference/plot_data.md).
  Source data can be summary statistics or raw samples
  (`data_type = "raw"`, summarised to means, SDs and sample sizes).
- [`run_pfn()`](https://andrewcparnell.github.io/MixSIARPFN/reference/run_pfn.md)
  in place of `write_JAGS_model()` and `run_model()`: marginal
  posteriors of every diet proportion and parameter from prior-data
  fitted networks, one per error structure (Residual \* Process,
  Residual only, Process only), in about a second. Isotope data with
  source summary statistics (`data_type = "means"`).
- [`output_pfn()`](https://andrewcparnell.github.io/MixSIARPFN/reference/output_pfn.md)
  in place of `output_JAGS()`, with
  [`summary_table()`](https://andrewcparnell.github.io/MixSIARPFN/reference/summary_table.md),
  [`posterior_draws()`](https://andrewcparnell.github.io/MixSIARPFN/reference/posterior_draws.md)
  and
  [`pfn_networks()`](https://andrewcparnell.github.io/MixSIARPFN/reference/pfn_networks.md).
- Comparison with MixSIAR:
  [`mixsiar_reference()`](https://andrewcparnell.github.io/MixSIARPFN/reference/mixsiar_reference.md)
  (MixSIAR’s own fits of all nine of its isotope examples, with a
  posterior predictive check for killer whale, geese and wolves),
  [`mixsiar_draws()`](https://andrewcparnell.github.io/MixSIARPFN/reference/mixsiar_draws.md),
  [`compare_mixsiar()`](https://andrewcparnell.github.io/MixSIARPFN/reference/compare_mixsiar.md),
  [`plot_compare()`](https://andrewcparnell.github.io/MixSIARPFN/reference/plot_compare.md)
  and
  [`plot_compare_covariate()`](https://andrewcparnell.github.io/MixSIARPFN/reference/plot_compare_covariate.md).
- Networks version 3, downloaded from Zenodo on first use and checked by
  SHA-256.
- Vignettes: MixSIAR’s nine isotope examples (killer whale, geese,
  wolves, alligator, lake, mantis shrimp, Palmyra, snail and storm
  petrel), each compared with MixSIAR’s fit.
- Article “How MixSIARPFN works and how well it does”: the network, its
  training, its speed, and a simulation study of 450 datasets with known
  diets against converged MixSIAR.
- Article “MixSIARPFN on every simulated dataset”: all 492 simulated
  datasets with MixSIAR fits, including 42 benchmark designs covering
  the supported models.
