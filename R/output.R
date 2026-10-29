#' Summaries and plots of a fit, like MixSIAR's output_JAGS()
#'
#' Takes the same `output_options` list as `MixSIAR::output_JAGS()`. It prints the
#' summary statistics table (mean, SD and quantiles of every proportion and
#' parameter, with MixSIAR's row names) and saves it if asked, and draws a posterior
#' density plot for the global diet, each effect and each parameter, shown and/or
#' saved as PDF or PNG. Options that concern MCMC (convergence diagnostics, DIC,
#' pairs plots of joint draws) do not apply and are ignored.
#'
#' @param fit The output of [run_pfn()].
#' @param mix,source The outputs of [load_mix_data()] and [load_source_data()]
#'   (accepted for compatibility with `output_JAGS()`; the fit holds what is needed).
#' @param output_options A list as for `MixSIAR::output_JAGS()`. Used here:
#'   `summary_save`, `summary_name`, `sup_post`, `plot_post_save_pdf`,
#'   `plot_post_save_png`, `plot_post_name`. Missing entries take MixSIAR's defaults.
#'
#' @return Invisibly, a list with `summary` (the table as a data frame) and `plots`
#'   (the ggplot objects).
#' @export
output_pfn <- function(fit, mix = NULL, source = NULL, output_options = list()) {
  stopifnot(inherits(fit, "pfn_fit"))
  defaults <- list(summary_save = TRUE, summary_name = "summary_statistics",
                   sup_post = FALSE, plot_post_save_pdf = TRUE,
                   plot_post_name = "posterior_density", plot_post_save_png = FALSE)
  opt <- utils::modifyList(defaults, output_options)

  stats <- summary_table(fit)
  cat("\n#################################################################\n",
      "# Summary Statistics (MixSIARPFN: marginal posteriors)\n",
      "#################################################################\n\n", sep = "")
  print(round(stats, 3))
  cat("\nEach row is a marginal posterior. The marginal means of one diet need not sum",
      "\nto exactly 1, and sums or ratios of proportions are not available.\n")
  if (isTRUE(opt$summary_save)) {
    file <- paste0(opt$summary_name, ".txt")
    utils::capture.output(print(round(stats, 3)), file = file)
    message("Summary statistics saved to ", file)
  }

  plots <- posterior_plots(fit)
  for (name in names(plots)) {
    if (!isTRUE(opt$sup_post)) print(plots[[name]])
    stem <- paste0(opt$plot_post_name, "_", gsub("[^A-Za-z0-9]+", "_", name))
    if (isTRUE(opt$plot_post_save_pdf)) {
      ggplot2::ggsave(paste0(stem, ".pdf"), plots[[name]], width = 7, height = 5)
    }
    if (isTRUE(opt$plot_post_save_png)) {
      ggplot2::ggsave(paste0(stem, ".png"), plots[[name]], width = 7, height = 5,
                      dpi = 150)
    }
  }
  invisible(list(summary = stats, plots = plots))
}

#' The summary statistics table of a fit
#'
#' One row per parameter and proportion, columns Mean, SD and the quantiles MixSIAR
#' reports, with MixSIAR's row names (`Epsilon.1`, `Region.SD`, `p.global.Deer`,
#' `p.Region 1.Deer`, ...).
#'
#' @param fit The output of [run_pfn()].
#' @return A numeric matrix.
#' @export
summary_table <- function(fit) {
  qcols <- c("mean", "sd", "q2.5", "q5", "q25", "q50", "q75", "q95", "q97.5")
  heads <- c("Mean", "SD", "2.5%", "5%", "25%", "50%", "75%", "95%", "97.5%")
  # MixSIAR's order: residual multipliers, SDs, then the diets
  par <- fit$parameters
  if (nrow(par) > 0) {
    rank <- c(resid.prop = 1, sd = 2)[par$parameter]
    par <- par[order(ifelse(is.na(rank), 3, rank)), , drop = FALSE]
  }
  rows <- rbind(as.matrix(par[, qcols, drop = FALSE]),
                as.matrix(fit$summary[, qcols, drop = FALSE]))
  rownames(rows) <- c(par$name, fit$summary$name)
  colnames(rows) <- heads
  rows
}

#' @export
summary.pfn_fit <- function(object, ...) summary_table(object)

# Density of one marginal for plotting: the probability in each of n even cells from
# the lowest border to the 99.9% quantile, divided by the cell width. (The bars
# themselves are very narrow near 0 and 1, which would show as tall spikes.)
bar_density <- function(probs, borders, n = 120) {
  lo <- borders[1]
  hi <- min(borders[length(borders)], bar_quantile(probs, borders, 0.999) * 1.05 + 1e-9)
  edges <- seq(lo, hi, length.out = n + 1)
  dens <- diff(bar_cdf(probs, borders, edges)) / diff(edges)
  data.frame(x = (edges[-1] + edges[-length(edges)]) / 2, density = dens)
}

bar_quantile <- function(probs, borders, q) {
  cum <- cumsum(probs)
  i <- min(which(cum >= q), length(probs))
  before <- cum[i] - probs[i]
  frac <- if (probs[i] > 0) min(max((q - before) / probs[i], 0), 1) else 0
  borders[i] + frac * (borders[i + 1] - borders[i])
}

posterior_plots <- function(fit) {
  s <- fit$summary
  plots <- list()
  for (block in unique(s$block)) {
    rows <- which(s$block == block)
    curves <- do.call(rbind, lapply(rows, function(i) {
      # Kernel density of draws, as plot_compare() (the bars are very narrow near 0
      # and 1, which would show as tall spikes)
      k <- stats::density(bar_draws(fit$probs[i, ], fit$borders, 4000),
                          from = 0, to = 1, n = 256)
      data.frame(x = k$x, density = k$y, source = s$source[i],
                 level = if (block == "global") "" else paste(block, s$level[i]))
    }))
    p <- ggplot2::ggplot(curves, ggplot2::aes(x = .data$x, y = .data$density,
                                              colour = .data$source)) +
      ggplot2::geom_line() +
      ggplot2::scale_x_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1),
                                  labels = c("0", "0.5", "1")) +
      ggplot2::labs(x = "Proportion of diet", y = "Posterior density", colour = "Source",
                    title = if (block == "global") "Global diet" else block) +
      ggplot2::theme_bw()
    if (length(unique(curves$level)) > 1) {
      p <- p + ggplot2::facet_wrap(~level, scales = "free_y")
    }
    plots[[if (block == "global") "global" else block]] <- p
  }
  par <- fit$parameters
  for (i in seq_len(nrow(par))) {
    d <- bar_density(fit$parameter_probs[[i]], fit$parameter_borders[[i]])
    plots[[par$name[i]]] <- ggplot2::ggplot(d, ggplot2::aes(x = .data$x, y = .data$density)) +
      ggplot2::geom_line() +
      ggplot2::labs(x = par$name[i], y = "Posterior density", title = par$name[i]) +
      ggplot2::theme_bw()
  }
  plots
}

# Independent draws from one bar distribution
bar_draws <- function(probs, borders, n) {
  i <- sample.int(length(probs), n, replace = TRUE, prob = probs)
  borders[i] + stats::runif(n) * (borders[i + 1] - borders[i])
}

#' Draws from the marginal posteriors
#'
#' Independent draws from each proportion's (and parameter's) marginal posterior.
#' These are marginal draws: draw `i` of one proportion and draw `i` of another do
#' not come from one joint posterior draw, so do not add, subtract or divide them.
#'
#' @param fit The output of [run_pfn()].
#' @param n Number of draws per quantity.
#' @param seed Optional seed.
#' @return A long data frame: `name` (MixSIAR's row name), `block`, `level`,
#'   `source` (or parameter), `draw`, `value`.
#' @export
posterior_draws <- function(fit, n = 3000, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  one <- function(probs, borders) bar_draws(probs, borders, n)
  s <- fit$summary
  diets <- do.call(rbind, lapply(seq_len(nrow(s)), function(i) {
    data.frame(name = s$name[i], block = s$block[i], level = s$level[i],
               source = s$source[i], draw = seq_len(n),
               value = one(fit$probs[i, ], fit$borders))
  }))
  par <- fit$parameters
  pars <- do.call(rbind, lapply(seq_len(nrow(par)), function(i) {
    data.frame(name = par$name[i], block = par$parameter[i], level = NA_character_,
               source = par$label[i], draw = seq_len(n),
               value = one(fit$parameter_probs[[i]], fit$parameter_borders[[i]]))
  }))
  rbind(diets, pars)
}
