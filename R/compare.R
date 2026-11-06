#' MixSIAR's own fits of the example data
#'
#' MixSIAR 3.1.12 fits of MixSIAR's example datasets, made for benchmarking MixSIARPFN:
#' 1,000 posterior draws of every diet proportion (thinned from the saved chains),
#' MixSIAR's summary statistics (which also cover the random-effect SDs and residual
#' multipliers), and the run settings (chain length, burn-in, run time, largest
#' Gelman-Rubin diagnostic).
#'
#' The examples are `"killerwhale"`, `"geese"` and `"wolves"`, and MixSIAR's further
#' examples `"alligator_1"` to `"alligator_8"` (its eight alligator models), `"lake"`,
#' `"mantis"`, `"palmyra"`, `"snail"` and `"stormpetrel"`. Lake, palmyra, snail and storm
#' petrel have raw source data: their reference is MixSIAR fitted to the same source
#' summaries MixSIARPFN uses (means, SDs and sample sizes), and `"<name>_raw"` is
#' MixSIAR fitted to the raw source data, as in MixSIAR's own example script.
#'
#' For the killer whale, geese and wolves fits there is also a posterior predictive
#' check: MixSIAR's own model, rerun with replicated consumers drawn from its
#' likelihood, compared with the data group by group (each tracer's mean and SD, and
#' the correlation between tracers), on the standardised tracer scale MixSIAR's JAGS
#' model uses. The same check on six datasets simulated from the model itself, like
#' geese and like wolves, shows what a good fit looks like.
#'
#' @param vignette The example's name (see Details).
#' @return A list with `draws` (data frame: `name`, `value`; names as in MixSIAR's
#'   summary, e.g. `p.Pack 1.Deer`), `summary` (data frame: `name`, `mean`, `sd`,
#'   `q2.5`, `q97.5`), `info` (list), `ppc` (list or `NULL`: `stats`, one row per
#'   checked statistic with the observed value, the replicated mean and 95% interval
#'   and the posterior predictive p-value `ppp`; `summary` and `controls`, how many
#'   group statistics fall outside 95% and 99% of their replicates; `grouping`, the
#'   factor checked) and `pind` (data frame or `NULL`: with a continuous effect, each
#'   consumer's diet posterior mean and 95% interval from MixSIAR's `p.ind`, with the
#'   consumer's covariate and factor values; see [plot_compare_covariate()]).
#' @export
mixsiar_reference <- function(vignette) {
  ref <- readRDS(system.file("extdata", "mixsiar_reference.rds", package = "MixSIARPFN"))
  vignette <- match.arg(vignette, names(ref$draws))
  list(draws = ref$draws[[vignette]],
       summary = utils::read.csv(system.file("extdata", paste0(vignette, "_mixsiar_summary.csv"),
                                             package = "MixSIARPFN")),
       info = ref$info[[vignette]],
       ppc = ref$ppc[[vignette]],
       pind = ref$pind[[vignette]])
}

#' Compare diets along a continuous effect with MixSIAR's
#'
#' Each consumer's diet posterior (mean and 95% interval) from MixSIARPFN against
#' MixSIAR's (`p.ind`), plotted against the consumer's value of the continuous effect,
#' one panel per source.
#'
#' @param fit The output of [run_pfn()], for a model with a continuous effect.
#' @param pind MixSIAR's per-consumer diets: `mixsiar_reference(...)$pind`, or a data
#'   frame with columns `consumer`, `source`, `mean`, `q2.5`, `q97.5` and the
#'   covariate.
#' @param cont The continuous effect (default: the model's first).
#' @param by Optional: a factor of the model (a column of `pind`) to split the panels by,
#'   when the diet depends on it as well as on the covariate.
#' @return A ggplot.
#' @export
plot_compare_covariate <- function(fit, pind, cont = fit$cont_effects[1], by = NULL) {
  s <- fit$summary[fit$summary$block == "consumer", ]
  key <- fit$consumers
  pfn <- merge(key[, c("consumer", "level")], s[, c("level", "source", "mean", "q2.5", "q97.5")],
               by = "level")
  pfn <- merge(pfn, unique(pind[, c("consumer", cont, by), drop = FALSE]), by = "consumer")
  pfn$method <- "MixSIARPFN"
  mx <- pind
  mx$method <- "MixSIAR"
  keep <- c("consumer", "source", "mean", "q2.5", "q97.5", cont, by, "method")
  d <- rbind(pfn[, keep], mx[, keep])
  d$x <- d[[cont]]
  d <- d[order(d$method, d$source, d$x), ]
  ggplot2::ggplot(d, ggplot2::aes(x = .data$x, y = .data$mean, colour = .data$method,
                                  fill = .data$method)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = .data$q2.5, ymax = .data$q97.5), alpha = 0.15,
                         colour = NA) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::scale_colour_manual(values = c(MixSIAR = "grey35", MixSIARPFN = "#D55E00"), name = NULL) +
    ggplot2::scale_fill_manual(values = c(MixSIAR = "grey35", MixSIARPFN = "#D55E00"), name = NULL) +
    (if (is.null(by)) ggplot2::facet_wrap(~source) else
      ggplot2::facet_grid(stats::as.formula(paste("`", by, "` ~ source", sep = "")))) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(x = cont, y = "Diet proportion (consumer posterior mean and 95% interval)") +
    ggplot2::theme_bw() + ggplot2::theme(legend.position = "top")
}

# The vignettes' posterior predictive check plot: for each group, the observed mean, SD
# and correlation between tracers (points) against what MixSIAR's fitted model generates
# (95% intervals of the replicates). Points outside their interval are highlighted.
plot_ppc <- function(ppc) {
  d <- ppc$stats[ppc$stats$stat %in% c("mean", "sd", "cor"), ]
  d$panel <- ifelse(d$stat == "cor", "Correlation between tracers",
                    paste(ifelse(d$stat == "mean", "Mean", "SD"), d$tracer))
  d$panel <- factor(d$panel, levels = unique(d$panel[order(d$stat != "mean", d$stat == "cor")]))
  d$group <- factor(d$group, levels = unique(d$group))
  d$fit <- ifelse(d$ppp < 0.025 | d$ppp > 0.975, "outside 95%", "inside")
  ggplot2::ggplot(d, ggplot2::aes(x = .data$group)) +
    ggplot2::geom_linerange(ggplot2::aes(ymin = .data$rep_q025, ymax = .data$rep_q975),
                            colour = "grey60", linewidth = 2.5, alpha = 0.6) +
    ggplot2::geom_point(ggplot2::aes(y = .data$obs, colour = .data$fit), size = 2.2) +
    ggplot2::scale_colour_manual(values = c(inside = "black", `outside 95%` = "#D55E00"),
                                 name = "Data") +
    ggplot2::facet_wrap(~panel, scales = "free_y", ncol = 1) +
    ggplot2::labs(x = NULL, y = "Standardised tracer scale",
                  caption = "Grey: 95% of datasets generated by MixSIAR's fitted model") +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "top",
                   axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
}

#' Diet proportion draws from a MixSIAR fit
#'
#' Turns the output of `MixSIAR::run_model()` into the long data frame that
#' [compare_mixsiar()] and [plot_compare()] take, named as in MixSIAR's summary
#' statistics (`p.global.<source>`, `p.<level label>.<source>`).
#'
#' @param jags.1 The output of `MixSIAR::run_model()`.
#' @param mix,source The `mix` and `source` objects used for that fit (from
#'   MixSIAR's or this package's loaders).
#' @return A data frame with columns `name` and `value`.
#' @export
mixsiar_draws <- function(jags.1, mix, source) {
  sims <- jags.1$BUGSoutput$sims.list
  src <- source$source_names
  out <- list()
  if (!is.null(sims$p.global)) {
    for (k in seq_along(src)) {
      out[[length(out) + 1]] <- data.frame(name = paste0("p.global.", src[k]),
                                           value = sims$p.global[, k])
    }
  }
  for (f in seq_len(mix$n.effects)) {
    p <- sims[[paste0("p.fac", f)]]
    if (is.null(p)) next
    labels <- mix$FAC[[f]]$labels
    for (l in seq_along(labels)) for (k in seq_along(src)) {
      out[[length(out) + 1]] <- data.frame(name = paste0("p.", labels[l], ".", src[k]),
                                           value = p[, l, k])
    }
  }
  do.call(rbind, out)
}

# P(p <= y) of a bar distribution at each y
bar_cdf <- function(probs, borders, y) {
  cum <- c(0, cumsum(probs))
  i <- pmin(pmax(findInterval(y, borders), 1), length(probs))
  frac <- pmin(pmax((y - borders[i]) / (borders[i + 1] - borders[i]), 0), 1)
  cum[i] + frac * probs[i]
}

# Wasserstein-1 distance between a bar distribution and draws, on [0, 1]
wasserstein1 <- function(probs, borders, draws, grid = seq(0, 1, length.out = 4001)) {
  gap <- abs(bar_cdf(probs, borders, grid) - stats::ecdf(draws)(grid))
  sum((gap[-1] + gap[-length(gap)]) / 2 * diff(grid))
}

#' Compare a fit with MixSIAR's posterior
#'
#' For every diet proportion both have, the two posteriors' means, SDs and 95%
#' intervals, the ratio of SDs (above 1: MixSIARPFN is wider) and the Wasserstein-1
#' distance between them (the average distance one posterior's mass has to move to
#' match the other; on the proportion scale). Parameters (random-effect SDs, residual
#' multipliers) are added from MixSIAR's summary when given, without a distance.
#'
#' @param fit The output of [run_pfn()].
#' @param draws MixSIAR's draws: a data frame with `name` and `value`, from
#'   [mixsiar_draws()] or [mixsiar_reference()].
#' @param summary Optional: MixSIAR's summary (data frame with `name`, `mean`, `sd`,
#'   `q2.5`, `q97.5`), to compare the parameters as well.
#' @return A data frame, one row per quantity.
#' @export
compare_mixsiar <- function(fit, draws, summary = NULL) {
  s <- fit$summary
  rows <- intersect(s$name, unique(draws$name))
  diet <- do.call(rbind, lapply(rows, function(n) {
    i <- match(n, s$name)
    d <- draws$value[draws$name == n]
    data.frame(name = n, block = s$block[i], level = s$level[i], source = s$source[i],
               pfn_mean = s$mean[i], mixsiar_mean = mean(d),
               pfn_sd = s$sd[i], mixsiar_sd = stats::sd(d),
               pfn_q2.5 = s$q2.5[i], mixsiar_q2.5 = unname(stats::quantile(d, 0.025)),
               pfn_q97.5 = s$q97.5[i], mixsiar_q97.5 = unname(stats::quantile(d, 0.975)),
               w1 = wasserstein1(fit$probs[i, ], fit$borders, d))
  }))
  if (!is.null(summary) && nrow(fit$parameters) > 0) {
    par <- fit$parameters
    keep <- intersect(par$name, summary$name)
    if (length(keep) > 0) {
      p <- par[match(keep, par$name), ]
      m <- summary[match(keep, summary$name), ]
      diet <- rbind(data.frame(
        name = keep, block = p$parameter, level = NA_character_, source = p$label,
        pfn_mean = p$mean, mixsiar_mean = m$mean, pfn_sd = p$sd, mixsiar_sd = m$sd,
        pfn_q2.5 = p$q2.5, mixsiar_q2.5 = m$q2.5, pfn_q97.5 = p$q97.5,
        mixsiar_q97.5 = m$q97.5, w1 = NA_real_), diet)
    }
  }
  diet$sd_ratio <- diet$pfn_sd / diet$mixsiar_sd
  rownames(diet) <- NULL
  diet
}

#' Plot a fit against MixSIAR's posterior
#'
#' `type = "density"`: each diet proportion's posterior density from MixSIARPFN
#' (from its bars) and from MixSIAR (kernel density of its draws), one panel per
#' proportion. `type = "means"`: MixSIARPFN's posterior mean and SD of every
#' proportion against MixSIAR's, with the 1:1 line.
#'
#' @param fit The output of [run_pfn()].
#' @param draws MixSIAR's draws (data frame with `name` and `value`).
#' @param type `"density"` or `"means"`.
#' @param block For `type = "density"`: which block to plot (`"global"` or an effect
#'   name such as `"Pack"`). Default: the global diet, or the first effect if MixSIAR
#'   has no global draws.
#' @return A ggplot object.
#' @export
plot_compare <- function(fit, draws, type = c("density", "means"), block = NULL) {
  type <- match.arg(type)
  if (type == "means") {
    cmp <- compare_mixsiar(fit, draws)
    d <- rbind(data.frame(what = "Posterior mean", pfn = cmp$pfn_mean, mixsiar = cmp$mixsiar_mean,
                          block = cmp$block),
               data.frame(what = "Posterior SD", pfn = cmp$pfn_sd, mixsiar = cmp$mixsiar_sd,
                          block = cmp$block))
    return(ggplot2::ggplot(d, ggplot2::aes(x = .data$mixsiar, y = .data$pfn,
                                           colour = .data$block)) +
             ggplot2::geom_abline(slope = 1, intercept = 0, colour = "grey50") +
             ggplot2::geom_point() +
             ggplot2::facet_wrap(~what, scales = "free") +
             ggplot2::labs(x = "MixSIAR", y = "MixSIARPFN", colour = NULL) +
             ggplot2::theme_bw())
  }
  s <- fit$summary
  rows <- which(s$name %in% draws$name)
  if (is.null(block)) block <- if ("global" %in% s$block[rows]) "global" else s$block[rows][1]
  rows <- rows[s$block[rows] == block]
  if (length(rows) == 0) stop("No proportions of block '", block, "' in both fits.", call. = FALSE)
  # Both curves are kernel densities of draws (the network's drawn from its bars), so
  # they are smoothed the same way; the bars themselves are very narrow near 0 and 1
  curves <- do.call(rbind, lapply(rows, function(i) {
    n <- s$name[i]
    mixsiar <- draws$value[draws$name == n]
    pfn <- bar_draws(fit$probs[i, ], fit$borders, 4000)
    kde <- function(v, method) {
      k <- stats::density(v, from = 0, to = 1, n = 256)
      data.frame(panel = sub("^p\\.", "", n), x = k$x, density = k$y, method = method)
    }
    rbind(kde(pfn, "MixSIARPFN"), kde(mixsiar, "MixSIAR"))
  }))
  curves$panel <- factor(curves$panel, levels = unique(curves$panel))
  ggplot2::ggplot(curves, ggplot2::aes(x = .data$x, y = .data$density,
                                       colour = .data$method)) +
    ggplot2::geom_line() +
    ggplot2::facet_wrap(~panel, scales = "free_y",
                        labeller = ggplot2::label_wrap_gen(width = 18)) +
    ggplot2::scale_x_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1),
                                labels = c("0", "0.5", "1")) +
    ggplot2::scale_colour_manual(values = c(MixSIAR = "grey35", MixSIARPFN = "#D55E00")) +
    ggplot2::labs(x = "Proportion of diet", y = "Posterior density", colour = NULL,
                  title = if (block == "global") "Global diet" else block) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom", strip.text = ggplot2::element_text(size = 7))
}
