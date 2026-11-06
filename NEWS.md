# MixSIARPFN 0.1.0

First release.

* MixSIAR's loaders, `load_mix_data()`, `load_source_data()` and `load_discr_data()`,
  with the same arguments and checks, and `plot_data()`.
* `run_pfn()` in place of `write_JAGS_model()` and `run_model()`: marginal posteriors
  of every diet proportion and parameter from prior-data fitted networks, one per
  error structure (Residual * Process, Residual only, Process only), in about a
  second. Isotope data with source summary statistics (`data_type = "means"`).
* `output_pfn()` in place of `output_JAGS()`, with `summary_table()`,
  `posterior_draws()` and `pfn_networks()`.
* Comparison with MixSIAR: `mixsiar_reference()` (MixSIAR's own fits of the three
  examples, with a posterior predictive check of each), `mixsiar_draws()`,
  `compare_mixsiar()` and `plot_compare()`.
* Networks version 3, downloaded from Zenodo on first use and checked by SHA-256.
* Vignettes: MixSIAR's killer whale, geese and wolves examples, each compared with
  MixSIAR's fit.
* Article "How MixSIARPFN works and how well it does": the network, its training, and
  a simulation study of 450 datasets with known diets against converged MixSIAR.
