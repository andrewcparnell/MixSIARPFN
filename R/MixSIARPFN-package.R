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
#' @importFrom rlang .data
#' @keywords internal
"_PACKAGE"
