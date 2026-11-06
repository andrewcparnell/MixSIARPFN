# MixSIARPFN 0.1.0

First release.

* MixSIAR's loaders, `load_mix_data()`, `load_source_data()` and `load_discr_data()`,
  with the same arguments and checks, and `plot_data()`. Source data can be summary
  statistics or raw samples (`data_type = "raw"`, summarised to means, SDs and sample
  sizes).
* `run_pfn()` in place of `write_JAGS_model()` and `run_model()`: marginal posteriors
  of every diet proportion and parameter from prior-data fitted networks, one per
  error structure (Residual * Process, Residual only, Process only), in about a
  second. Isotope data with source summary statistics (`data_type = "means"`).
* `output_pfn()` in place of `output_JAGS()`, with `summary_table()`,
  `posterior_draws()` and `pfn_networks()`.
* Comparison with MixSIAR: `mixsiar_reference()` (MixSIAR's own fits of all nine of
  its isotope examples, with a posterior predictive check for killer whale, geese and
  wolves), `mixsiar_draws()`, `compare_mixsiar()`, `plot_compare()` and
  `plot_compare_covariate()`.
* Networks version 3, downloaded from Zenodo on first use and checked by SHA-256.
* Vignettes: MixSIAR's nine isotope examples (killer whale, geese, wolves, alligator,
  lake, mantis shrimp, Palmyra, snail and storm petrel), each compared with MixSIAR's
  fit.
* Article "How MixSIARPFN works and how well it does": the network, its training, its
  speed, and a simulation study of 450 datasets with known diets against converged
  MixSIAR.
* Article "MixSIARPFN on every simulated dataset": all 492 simulated datasets with
  MixSIAR fits, including 42 benchmark designs covering the supported models.
