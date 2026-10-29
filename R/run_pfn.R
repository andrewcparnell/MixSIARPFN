#' Fit a MixSIAR model with the prior-data fitted network
#'
#' Replaces MixSIAR's `write_JAGS_model()` and `run_model()`: takes the same data
#' objects and model options and returns the marginal posterior of every diet
#' proportion and model parameter, from the network trained for the chosen error
#' structure. There is no MCMC, so no chain length, burn-in or convergence to check.
#'
#' The network gives each quantity's *marginal* posterior, not joint draws: the
#' marginal means of one diet need not sum to exactly 1, and sums, differences or
#' ratios of proportions cannot be computed from the output.
#'
#' Data, priors and model options outside what the networks were trained for (for
#' example more than 8 sources or 4 tracers) are refused with a message saying which
#' limit was exceeded.
#'
#' @param mix,source,discr The outputs of [load_mix_data()], [load_source_data()] and
#'   [load_discr_data()].
#' @param alpha.prior Dirichlet prior on the global diet: one number for every source
#'   (MixSIAR's default 1) or one per source, in `source$source_names` order.
#' @param resid_err,process_err The error structure, as in MixSIAR: both `TRUE`
#'   (Residual * Process, MixSIAR's default), or only one of them.
#' @param seed Seed for the random level assignments the network averages over.
#' @param cont_values For a continuous effect: the values (original units) to report
#'   the diet at. By default 25 values over the observed range.
#'
#' @return An object of class `pfn_fit`: `summary` (one row per diet proportion,
#'   with MixSIAR's quantiles and row names such as `p.global.Deer`), `parameters`
#'   (random-effect SDs, residual error multipliers, covariate slopes), the bar
#'   probabilities behind each marginal (for [posterior_draws()]), and the model
#'   options. It holds only R objects, so it can be saved with [saveRDS()].
#' @examples
#' \dontrun{
#' x <- function(f) system.file("extdata", f, package = "MixSIARPFN")
#' mix <- load_mix_data(x("wolves_consumer.csv"), iso_names = c("d13C", "d15N"),
#'                      factors = c("Region", "Pack"), fac_random = c(TRUE, TRUE),
#'                      fac_nested = c(FALSE, TRUE), cont_effects = NULL)
#' source <- load_source_data(x("wolves_sources.csv"), source_factors = "Region",
#'                            conc_dep = FALSE, data_type = "means", mix)
#' discr <- load_discr_data(x("wolves_discrimination.csv"), mix)
#' fit <- run_pfn(mix, source, discr)
#' fit
#' }
#' @export
run_pfn <- function(mix, source, discr, alpha.prior = 1, resid_err = TRUE,
                     process_err = TRUE, seed = 1, cont_values = NULL) {
  stopifnot(inherits(mix, "pfn_mix"), inherits(source, "pfn_source"),
            inherits(discr, "pfn_discr"))
  error <- error_structure(resid_err, process_err)
  if (length(alpha.prior) != 1 && length(alpha.prior) != source$n.sources) {
    stop("alpha.prior must be one number or one per source (", source$n.sources, ").",
         call. = FALSE)
  }
  py <- pfn_python()

  factors <- as.character(mix$factors)
  is_random <- as.logical(mix$fac_random)
  random <- factors[is_random]
  fixed <- factors[!is_random]
  nested <- NULL
  if (length(random) == 2 && any(mix$fac_nested)) {
    inner <- which(mix$fac_nested)
    nested <- stats::setNames(list(factors[3 - inner]), factors[inner])
  }
  src <- source$data
  if (!isTRUE(source$conc_dep)) {
    src <- src[, !startsWith(colnames(src), "Conc"), drop = FALSE]
  }
  cont <- NULL
  if (!is.null(cont_values)) {
    if (mix$n.ce == 0) stop("cont_values given but the model has no continuous effect.",
                            call. = FALSE)
    cont <- stats::setNames(list(as.numeric(cont_values)), mix$cont_effects)
  }

  started <- Sys.time()
  post <- tryCatch({
    data <- py$infer$read_general_csvs(
      mix$data, src, discr$data, fixed = as.list(fixed), random = as.list(random),
      nested = nested, continuous = as.list(mix$cont_effects),
      sources_by = source$source_factors, tracers = as.list(mix$iso_names))
    py$infer$fit_general(data, alpha = alpha.prior, error = error,
                         seed = as.integer(seed), covariate_values = cont)
  }, error = function(e) {
    stop(python_message(e), call. = FALSE)
  })
  seconds <- as.numeric(difftime(Sys.time(), started, units = "secs"))

  summary <- as_plain_frame(post$summary)
  summary$name <- mixsiar_names(summary, mix)
  parameters <- as_plain_frame(post$parameters)
  if (nrow(parameters) > 0) parameters$name <- parameter_names(parameters, mix)
  structure(list(
    summary = summary,
    probs = as.matrix(post$probs),
    borders = as.numeric(post$borders),
    parameters = parameters,
    parameter_probs = lapply(post$parameter_probs, as.numeric),
    parameter_borders = lapply(post$parameter_borders, as.numeric),
    consumers = as_plain_frame(post$consumers),
    notes = unlist(post$notes),
    error = error, alpha = alpha.prior, sources = source$source_names,
    iso_names = mix$iso_names, factors = factors, cont_effects = mix$cont_effects,
    seconds = seconds
  ), class = "pfn_fit")
}

error_structure <- function(resid_err, process_err) {
  if (isTRUE(resid_err) && isTRUE(process_err)) return("mult")
  if (isTRUE(resid_err)) return("resid")
  if (isTRUE(process_err)) return("process")
  stop("At least one of resid_err and process_err must be TRUE, as in MixSIAR.",
       call. = FALSE)
}

# The message of a Python error, without reticulate's traceback
python_message <- function(e) {
  msg <- conditionMessage(e)
  py_err <- tryCatch(reticulate::py_last_error(), error = function(...) NULL)
  if (!is.null(py_err) && !is.null(py_err$value)) msg <- py_err$value
  sub("^EnvelopeError: ", "", msg)
}

# A pandas frame converted by reticulate, with list columns (mixed types) made text
as_plain_frame <- function(x) {
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  for (col in names(df)) {
    if (is.list(df[[col]])) {
      df[[col]] <- vapply(df[[col]], function(v) {
        if (is.null(v) || length(v) == 0) NA_character_ else as.character(v)
      }, character(1))
    }
  }
  rownames(df) <- NULL
  df
}

# MixSIAR's level label for an effect level as the networks report it ("1" -> "Region 1")
level_label <- function(mix, effect, level) {
  values <- mix$data[, effect]
  if (is.numeric(values)) paste(effect, level) else as.character(level)
}

# Row names as in MixSIAR's summary statistics: p.global.<source>,
# p.<level label>.<source>; other blocks: p.<block> <level>.<source>
mixsiar_names <- function(summary, mix) {
  vapply(seq_len(nrow(summary)), function(i) {
    block <- summary$block[i]
    level <- summary$level[i]
    src <- summary$source[i]
    if (block == "global") return(paste0("p.global.", src))
    if (block %in% mix$factors) return(paste0("p.", level_label(mix, block, level), ".", src))
    paste0("p.", block, " ", level, ".", src)
  }, character(1))
}

# Parameter names as in MixSIAR: <factor>.SD, Epsilon.<tracer number>, and CLR slopes
parameter_names <- function(parameters, mix) {
  vapply(seq_len(nrow(parameters)), function(i) {
    switch(parameters$parameter[i],
           "sd" = paste0(parameters$label[i], ".SD"),
           "resid.prop" = paste0("Epsilon.", match(parameters$label[i], mix$iso_names)),
           paste0("slope.CLR.", sub(": ", ".", parameters$label[i], fixed = TRUE)))
  }, character(1))
}

#' @export
print.pfn_fit <- function(x, ...) {
  labels <- c(mult = "Residual * Process", resid = "Residual only",
              process = "Process only")
  cat("MixSIARPFN fit (", labels[[x$error]], " error), ", length(x$sources),
      " sources, in ", format(round(x$seconds, 1)), " s\n", sep = "")
  cat("Marginal posteriors (no joint draws). Global diet:\n")
  g <- x$summary[x$summary$block == "global", ]
  print(data.frame(source = g$source, mean = round(g$mean, 3), sd = round(g$sd, 3),
                   `2.5%` = round(g$q2.5, 3), `97.5%` = round(g$q97.5, 3),
                   check.names = FALSE), row.names = FALSE)
  cat("Use output_pfn() for every proportion and parameter.\n")
  for (note in x$notes) cat("Note:", note, "\n")
  invisible(x)
}
