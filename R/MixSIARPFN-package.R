#' MixSIARPFN: MixSIAR models fitted by prior-data fitted networks
#'
#' Load data with [load_mix_data()], [load_source_data()] and [load_discr_data()] as
#' in MixSIAR, fit with [run_pfn()] (in place of `write_JAGS_model()` and
#' `run_model()`), and summarise with [output_pfn()] (in place of `output_JAGS()`).
#' The posteriors come from networks trained on simulations from MixSIAR's model, one
#' per error structure, downloaded on first use (see [pfn_networks()]).
#'
#' The example data are from MixSIAR (Stock et al. 2018, PeerJ 6:e5096): the killer
#' whale, geese and wolves vignettes.
#'
#' @section Limitations:
#' * **Marginal posteriors only.** Each proportion and parameter has its own posterior,
#'   but there are no joint draws: the marginal means of one diet need not sum to
#'   exactly 1, and sums, differences or ratios of proportions cannot be computed.
#' * **Accuracy.** On data simulated from MixSIAR's model the 95% intervals are
#'   calibrated but 5 to 11% wider than MixSIAR's, and the posteriors a little less
#'   accurate (CRPS 2 to 5% higher than fully converged MixSIAR; see
#'   `vignette("performance")`).
#' * **Weakly identified sources.** Where the data cannot pin a source down, the
#'   network tends to put more probability near 0 than MixSIAR does.
#' * **No model checks.** Without joint draws, posterior predictive checks cannot be
#'   run; where it matters, check the model with a MixSIAR run. The geese and wolves
#'   vignettes show MixSIAR's model failing such a check, and the two fits differing
#'   most where it fails.
#' * **Envelope.** Up to 8 sources, 4 tracers, two categorical effects and one
#'   continuous effect, with source summary statistics only; data outside what the
#'   networks were trained for are refused.
#'
#' @importFrom rlang .data
#' @keywords internal
"_PACKAGE"
