# The loaders follow MixSIAR 3.1.12's load_mix_data(), load_source_data() and
# load_discr_data() (Stock et al. 2018, GPL-3): same arguments, checks, messages and
# main fields. They keep the data as read, which run_pfn() passes to the networks;
# MixSIAR's JAGS arrays are not built.

read_input <- function(filename) {
  if (is.data.frame(filename)) return(filename)
  if (!is.character(filename) || length(filename) != 1 || !file.exists(filename)) {
    stop("*** Error: cannot find the file '", filename, "'. ***", call. = FALSE)
  }
  utils::read.csv(filename)
}

#' Load mixture (consumer) data
#'
#' Reads the consumer data file and records the model's random, fixed and continuous
#' effects, exactly as `MixSIAR::load_mix_data()` does, with the same arguments.
#'
#' @param filename Path of the consumer `.csv` file (or a data frame with its
#'   contents): one row per consumer, one column per tracer and per effect.
#' @param iso_names Names of the tracer columns to use, e.g. `c("d13C", "d15N")`.
#' @param factors Names of the categorical effect columns (0, 1 or 2), or `NULL`.
#' @param fac_random Logical, one per factor: `TRUE` for a random effect, `FALSE`
#'   for a fixed effect.
#' @param fac_nested Logical, one per factor: `TRUE` for a factor nested within the
#'   other (only with two random effects), or `NULL`.
#' @param cont_effects Name of a continuous effect column (0 or 1), or `NULL`.
#'
#' @return A list with MixSIAR's fields (`data`, `data_iso`, `n.iso`, `n.re`, `n.fe`,
#'   `n.ce`, `n.effects`, `FAC`, `CE`, `CE_orig`, `CE_center`, `CE_scale`,
#'   `cont_effects`, `MU_names`, `SIG_names`, `iso_names`, `N`, `factors`,
#'   `fac_random`, `fac_nested`, `fere`). As in MixSIAR, a fixed effect is put before a
#'   random one.
#' @examples
#' mix <- load_mix_data(
#'   filename = system.file("extdata", "wolves_consumer.csv", package = "MixSIARPFN"),
#'   iso_names = c("d13C", "d15N"), factors = c("Region", "Pack"),
#'   fac_random = c(TRUE, TRUE), fac_nested = c(FALSE, TRUE), cont_effects = NULL)
#' @export
load_mix_data <- function(filename, iso_names, factors, fac_random, fac_nested,
                          cont_effects) {
  X <- read_input(filename)
  n.iso <- length(iso_names)
  if (n.iso == 0) {
    stop("*** Error: No isotopes/tracers selected. Please select 1 or more ",
         "isotopes/tracers, and then load your consumer/mixture data again. ***",
         call. = FALSE)
  }
  if (length(fac_random) != length(factors)) {
    stop("*** Error: You have specified factors to include without saying if they ",
         "are random or fixed effects (length of fac_random should match length of ",
         "factors). Please check your load_mix_data line and try again. ***",
         call. = FALSE)
  }
  if (length(factors) == 2 && length(fac_nested) != 2) {
    stop("*** Error: You have specified factors to include without saying if they ",
         "are nested or independent (length of fac_nested should match length of ",
         "factors). Please check your load_mix_data line and try again. ***",
         call. = FALSE)
  }
  if (length(factors) == 2 && !is.na(fac_nested[1]) && isTRUE(fac_nested[1]) &&
      isTRUE(fac_nested[2])) {
    stop("*** Error: Both factors cannot be nested within each other. Please check ",
         "the fac_nested argument in your load_mix_data line and try again. ***",
         call. = FALSE)
  }
  n.effects <- length(factors)
  n.re <- sum(fac_random)
  n.fe <- n.effects - n.re
  fere <- n.effects == 2 && n.re < 2
  if (n.effects == 1) fac_nested <- FALSE
  if (n.effects > 2) {
    stop("*** Error: More than 2 random/fixed effects selected (MixSIAR can only ",
         "currently handle 0, 1, or 2 random/fixed effects). ***", call. = FALSE)
  }
  n.ce <- length(cont_effects)
  if (n.ce > 1) {
    stop("*** Error: More than 1 continuous effect selected (MixSIAR can only ",
         "currently handle 0 or 1 continuous effects). ***", call. = FALSE)
  }
  check_cols <- function(cols, what) {
    if (any(is.na(match(cols, colnames(X))))) {
      stop("*** Error: Your '", what, "' do not match column names in your mixture ",
           "data file (case sensitive). Please check your mix .csv data file and ",
           "load_mix_data line, then try again. ***", call. = FALSE)
    }
  }
  check_cols(iso_names, "iso_names")
  check_cols(factors, "factors")
  check_cols(cont_effects, "cont_effects")
  if (n.effects == 2 && isTRUE(fac_nested[2]) && n.re < 2 ||
      n.effects == 2 && isTRUE(fac_nested[1]) && n.re < 2) {
    stop("*** Error: Only random effects can be nested (MixSIAR fits nested factors ",
         "only when both are random). ***", call. = FALSE)
  }

  N <- nrow(X)
  X_iso <- as.matrix(X[, match(iso_names, colnames(X)), drop = FALSE])
  FAC <- replicate(n.effects, NULL)
  if (n.effects > 0) {
    for (i in seq_len(n.effects)) {
      fac_values <- X[, factors[i]]
      fac_levels <- length(unique(fac_values))
      fac_labels <- if (is.numeric(fac_values)) {
        paste(factors[i], levels(factor(fac_values)))
      } else {
        levels(factor(fac_values))
      }
      FAC[[i]] <- list(values = as.numeric(factor(fac_values)), levels = fac_levels,
                       labels = fac_labels, lookup = NULL, re = fac_random[i],
                       name = factors[i])
    }
    if (n.re == 2 && !is.na(fac_nested[1])) {
      for (inner in which(fac_nested)) {
        outer <- 3 - inner
        FAC[[inner]]$lookup <- vapply(seq_len(FAC[[inner]]$levels), function(lev) {
          FAC[[outer]]$values[which(FAC[[inner]]$values == lev)][1]
        }, numeric(1))
      }
    }
    # MixSIAR puts a fixed effect before a random one
    if (n.fe == 1 && n.re == 1 && fac_random[1]) {
      FAC <- rev(FAC)
      factors <- rev(factors)
      fac_random <- rev(fac_random)
      fac_nested <- rev(fac_nested)
    }
  }
  CE_orig <- CE <- replicate(n.ce, NULL)
  CE_center <- CE_scale <- rep(NA, n.ce)
  for (i in seq_len(n.ce)) {
    CE_orig[[i]] <- X[, cont_effects[i]]
    CE[[i]] <- scale(X[, cont_effects[i]], center = TRUE, scale = TRUE)
    CE_center[i] <- attr(CE[[i]], "scaled:center")
    CE_scale[i] <- attr(CE[[i]], "scaled:scale")
  }
  structure(list(
    data = X, data_iso = X_iso, n.iso = n.iso, n.re = n.re, n.ce = n.ce, FAC = FAC,
    CE = CE, CE_orig = CE_orig, CE_center = CE_center, CE_scale = CE_scale,
    cont_effects = cont_effects, MU_names = paste0("Mean", iso_names),
    SIG_names = paste0("SD", iso_names), iso_names = iso_names, N = N, n.fe = n.fe,
    n.effects = n.effects, factors = factors, fac_random = fac_random,
    fac_nested = fac_nested, fere = fere
  ), class = c("pfn_mix", "list"))
}

#' Summarise raw source data to means, SDs and sample sizes
#'
#' @param SOURCE Raw source data: source names in the first column, one row per sample.
#' @param iso_names Tracer column names.
#' @param source_factors Name of the source factor column, or `NULL`.
#' @param conc_dep Logical: keep mean `Conc<tracer>` columns?
#' @return A data frame in MixSIAR's "means" format.
#' @noRd
summarise_raw_sources <- function(SOURCE, iso_names, source_factors, conc_dep) {
  missing <- setdiff(iso_names, colnames(SOURCE))
  if (length(missing)) {
    stop("Raw source data must have one column per tracer, named as in iso_names; ",
         "missing: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  }
  conc_names <- if (isTRUE(conc_dep)) paste0("Conc", iso_names) else character(0)
  if (length(setdiff(conc_names, colnames(SOURCE)))) {
    stop("Concentration dependence column names mislabeled. Should be 'Conc' + ",
         "iso_names, e.g. 'Concd13C' if iso_names = 'd13C'.", call. = FALSE)
  }
  keys <- list(source = as.character(SOURCE[, 1]))
  if (length(source_factors) == 1) keys[[source_factors]] <- as.character(SOURCE[, source_factors])
  groups <- split(SOURCE, keys, drop = TRUE, sep = "\r")
  out <- do.call(rbind, lapply(groups, function(g) {
    row <- data.frame(Source = as.character(g[1, 1]), stringsAsFactors = FALSE)
    if (length(source_factors) == 1) row[[source_factors]] <- g[1, source_factors]
    for (t in iso_names) {
      row[[paste0("Mean", t)]] <- mean(g[[t]], na.rm = TRUE)
      row[[paste0("SD", t)]] <- stats::sd(g[[t]], na.rm = TRUE)
    }
    for (cn in conc_names) row[[cn]] <- mean(g[[cn]], na.rm = TRUE)
    row$n <- nrow(g)
    row
  }))
  if (any(out$n < 2)) {
    stop("Every source needs at least 2 raw samples to estimate its SD; too few for: ",
         paste(unique(out$Source[out$n < 2]), collapse = ", "), ".", call. = FALSE)
  }
  rownames(out) <- NULL
  message("Raw source data summarised to means, SDs and sample sizes (",
          paste0(out$Source, if (length(source_factors) == 1)
            paste0(" (", out[[source_factors]], ")"), ": n = ", out$n, collapse = "; "), ").")
  out
}

#' Load source data
#'
#' Reads the source data file, exactly as `MixSIAR::load_source_data()` does, with the
#' same arguments: either source summary statistics (`data_type = "means"`) or raw
#' source samples (`data_type = "raw"`), which are summarised to means, SDs and sample
#' sizes.
#'
#' @param filename Path of the source `.csv` file (or a data frame): source names in
#'   the first column, then `Mean<tracer>`, `SD<tracer>`, `n` and, with
#'   concentration dependence, `Conc<tracer>`.
#' @param source_factors Name of the categorical effect the sources are given by
#'   (one row per source and level), or `NULL`.
#' @param conc_dep Logical: use concentration dependence?
#' @param data_type `"means"` (source means, SDs and sample sizes) or `"raw"` (one row
#'   per source sample, columns named by the tracers). Raw data are summarised to each
#'   source's mean, SD and sample size (per level of `source_factors`, if given; with
#'   mean concentrations if `conc_dep`), which is what the networks use. MixSIAR's raw
#'   data model instead estimates each source's mean and variance in the fit, so
#'   results can differ a little from MixSIAR's for small source samples.
#' @param mix The output of [load_mix_data()].
#'
#' @return A list with `data`, `source_names` (MixSIAR's alphabetical order),
#'   `n.sources`, `source_factors`, `by_factor`, `conc_dep`, `conc`, `data_type`,
#'   `S_factor1` and `S_factor_levels`.
#' @export
load_source_data <- function(filename, source_factors = NULL, conc_dep, data_type,
                             mix) {
  SOURCE <- read_input(filename)
  if (!data_type %in% c("means", "raw")) {
    stop("*** Error: data_type must be 'means' or 'raw'. ***", call. = FALSE)
  }
  if (identical(data_type, "raw")) {
    SOURCE <- summarise_raw_sources(SOURCE, mix$iso_names, source_factors, conc_dep)
  }
  if (length(source_factors) > 1) {
    stop("More than one source factor. MixSIAR can only fit source data by up to ",
         "ONE factor. Please specify 0 or 1 source factor and try again.",
         call. = FALSE)
  }
  if (any(is.na(match(source_factors, colnames(SOURCE))))) {
    stop("Your 'source_factors' do not match column names in your source data file ",
         "(case sensitive). Please check your source .csv data file and ",
         "load_source_data line, then try again. ***", call. = FALSE)
  }
  by_factor <- NA
  if (length(source_factors) == 1) {
    by_factor <- match(source_factors, mix$factors)
    if (is.na(by_factor)) {
      stop("Source factor not in mix$factors. You cannot model a source random effect ",
           "that is not included as a random/fixed effect for the mixture/consumer.",
           call. = FALSE)
    }
  }
  source_names <- levels(as.factor(SOURCE[, 1]))
  if (any(is.na(match(mix$MU_names, colnames(SOURCE))))) {
    stop("Source mean column names mislabeled. Should be 'Mean' + iso_names from mix ",
         "data file, e.g. 'Meand13C' if mix$iso_names = 'd13C'.", call. = FALSE)
  }
  if (any(is.na(match(mix$SIG_names, colnames(SOURCE))))) {
    stop("Source SD column names mislabeled. Should be 'SD' + iso_names from mix ",
         "data file, e.g. 'SDd13C' if mix$iso_names = 'd13C'.", call. = FALSE)
  }
  if (!"n" %in% colnames(SOURCE)) {
    stop("Source sample sizes missing or entered incorrectly. Check your sources ",
         ".csv data file to be sure you have a column titled \"n\" with the sample ",
         "sizes for each source isotope estimate.", call. = FALSE)
  }
  conc <- NULL
  if (conc_dep) {
    conc_names <- paste0("Conc", mix$iso_names)
    if (any(is.na(match(conc_names, colnames(SOURCE))))) {
      stop("Concentration dependence column names mislabeled. Should be 'Conc' + ",
           "iso_names, e.g. 'Concd13C' if iso_names = 'd13C'. Alternatively, you may ",
           "have set conc_dep = TRUE by mistake.", call. = FALSE)
    }
    conc <- do.call(rbind, lapply(split(SOURCE[, conc_names, drop = FALSE],
                                        factor(SOURCE[, 1], source_names)), colMeans))
  }
  S_factor1 <- S_factor_levels <- NULL
  if (!is.na(by_factor)) {
    levs <- levels(as.factor(SOURCE[, source_factors]))
    S_factor_levels <- length(levs)
    by_level <- lapply(levs, function(l) sort(SOURCE[SOURCE[, source_factors] == l, 1]))
    if (length(unique(by_level)) != 1) {
      stop("Sources for each level of *", source_factors, "* do not match. If you ",
           "have different sources (or # of sources) for levels of *", source_factors,
           "*, you must fit separate models for each level.", call. = FALSE)
    }
    if (nrow(SOURCE) != length(source_names) * S_factor_levels) {
      stop("Source sample sizes missing or entered incorrectly: expected one row per ",
           "source and level of ", source_factors, ".", call. = FALSE)
    }
    S_factor1 <- factor(SOURCE[, source_factors])
  }
  structure(list(
    data = SOURCE, source_names = source_names, n.sources = length(source_names),
    source_factors = source_factors, by_factor = by_factor, conc_dep = conc_dep,
    conc = conc, data_type = data_type, S_factor1 = S_factor1,
    S_factor_levels = S_factor_levels
  ), class = c("pfn_source", "list"))
}

#' Load discrimination (TDF) data
#'
#' Reads the trophic discrimination factor file, as `MixSIAR::load_discr_data()`.
#'
#' @param filename Path of the discrimination `.csv` file (or a data frame): source
#'   names in the first column, then `Mean<tracer>` and `SD<tracer>`.
#' @param mix The output of [load_mix_data()].
#'
#' @return A list with `data`, `mu` and `sig2` (sources in MixSIAR's order).
#' @export
load_discr_data <- function(filename, mix) {
  DISCR <- read_input(filename)
  if (any(is.na(match(c(mix$MU_names, mix$SIG_names), colnames(DISCR))))) {
    stop("Discrimination column names mislabeled. Should be 'Mean' + iso_names and ",
         "'SD' + iso_names, e.g. 'Meand13C' and 'SDd13C' if iso_names = 'd13C'.",
         call. = FALSE)
  }
  DISCR <- DISCR[order(DISCR[, 1]), , drop = FALSE]
  mu <- as.matrix(DISCR[, mix$MU_names, drop = FALSE])
  sig2 <- as.matrix(DISCR[, mix$SIG_names, drop = FALSE])^2
  rownames(mu) <- rownames(sig2) <- DISCR[, 1]
  structure(list(data = DISCR, mu = mu, sig2 = sig2),
            class = c("pfn_discr", "list"))
}

#' @export
print.pfn_mix <- function(x, ...) {
  cat("Consumer data:", x$N, "consumers,", x$n.iso, "tracer(s):",
      paste(x$iso_names, collapse = ", "), "\n")
  for (f in x$FAC) {
    cat("  ", if (f$re) "Random" else "Fixed", "effect", f$name, "with", f$levels,
        "levels\n")
  }
  if (x$n.ce > 0) cat("  Continuous effect", x$cont_effects, "\n")
  invisible(x)
}

#' @export
print.pfn_source <- function(x, ...) {
  cat("Source data:", x$n.sources, "sources:", paste(x$source_names, collapse = ", "),
      "\n")
  if (!is.na(x$by_factor)) cat("  Given by", x$source_factors, "\n")
  if (isTRUE(x$conc_dep)) cat("  With concentration dependence\n")
  invisible(x)
}
