#' Isospace plot of the data, as MixSIAR's plot_data()
#'
#' Plots the consumers and the source means corrected for discrimination, with error
#' bars of +/- 1 SD (source and discrimination SDs combined, as MixSIAR does), for
#' each pair of tracers. With sources given by a factor, each source has one point
#' per level.
#'
#' @param filename Stem of the file names to save to.
#' @param plot_save_pdf,plot_save_png Save each plot as PDF or PNG?
#' @param mix,source,discr The outputs of [load_mix_data()], [load_source_data()] and
#'   [load_discr_data()].
#' @param return_obj Return the plots (a list of ggplot objects) instead of printing
#'   them?
#'
#' @return Invisibly (or, with `return_obj = TRUE`, visibly) a list of ggplot
#'   objects, one per pair of tracers (one plot for a single tracer).
#' @export
plot_data <- function(filename = "isospace_plot", plot_save_pdf = FALSE,
                      plot_save_png = FALSE, mix, source, discr, return_obj = FALSE) {
  iso <- mix$iso_names
  src <- source$data
  names(src)[1] <- "Source"
  # Source means and SDs after discrimination (TDF mean added, variances added)
  tdf_mu <- discr$mu[as.character(src$Source), , drop = FALSE]
  tdf_sig2 <- discr$sig2[as.character(src$Source), , drop = FALSE]
  s <- data.frame(Source = src$Source)
  if (!is.na(source$by_factor)) {
    s$Source <- paste0(src$Source, " (", source$source_factors, " ",
                       src[[source$source_factors]], ")")
  }
  for (j in seq_along(iso)) {
    s[[paste0("mu", j)]] <- src[[paste0("Mean", iso[j])]] + tdf_mu[, j]
    s[[paste0("sd", j)]] <- sqrt(src[[paste0("SD", iso[j])]]^2 + tdf_sig2[, j])
  }
  cons <- mix$data
  group <- if (mix$n.effects > 0) factor(cons[[mix$factors[1]]]) else NULL
  group_name <- if (mix$n.effects > 0) mix$factors[1] else NULL

  pairs <- if (length(iso) == 1) list(c(1, NA)) else utils::combn(length(iso), 2, simplify = FALSE)
  plots <- lapply(pairs, function(pr) {
    if (is.na(pr[2])) {
      d <- data.frame(x = cons[[iso[1]]], y = 0, group = if (is.null(group)) "Consumer" else group)
      p <- ggplot2::ggplot() +
        ggplot2::geom_jitter(data = d, ggplot2::aes(x = .data$x, y = .data$y,
                                                    colour = .data$group),
                             height = 0.1, width = 0) +
        ggplot2::geom_pointrange(data = s, ggplot2::aes(
          x = .data$mu1, xmin = .data$mu1 - .data$sd1, xmax = .data$mu1 + .data$sd1,
          y = -0.5), colour = "black") +
        ggplot2::geom_text(data = s, ggplot2::aes(x = .data$mu1, y = -0.7,
                                                  label = .data$Source), size = 3) +
        ggplot2::labs(x = iso[1], y = NULL, colour = group_name) +
        ggplot2::theme_bw() +
        ggplot2::theme(axis.text.y = ggplot2::element_blank(),
                       axis.ticks.y = ggplot2::element_blank())
      return(p)
    }
    a <- pr[1]
    b <- pr[2]
    d <- data.frame(x = cons[[iso[a]]], y = cons[[iso[b]]])
    sd <- data.frame(Source = s$Source, x = s[[paste0("mu", a)]], y = s[[paste0("mu", b)]],
                     sx = s[[paste0("sd", a)]], sy = s[[paste0("sd", b)]])
    p <- ggplot2::ggplot() +
      ggplot2::geom_errorbar(data = sd, ggplot2::aes(x = .data$x, ymin = .data$y - .data$sy,
                                                     ymax = .data$y + .data$sy),
                             width = 0, colour = "grey30") +
      ggplot2::geom_errorbarh(data = sd, ggplot2::aes(y = .data$y, xmin = .data$x - .data$sx,
                                                      xmax = .data$x + .data$sx),
                              height = 0, colour = "grey30") +
      ggplot2::geom_point(data = sd, ggplot2::aes(x = .data$x, y = .data$y), shape = 15,
                          size = 2.5) +
      ggplot2::geom_text(data = sd, ggplot2::aes(x = .data$x, y = .data$y, label = .data$Source),
                         vjust = -0.8, size = 3) +
      ggplot2::labs(x = iso[a], y = iso[b]) +
      ggplot2::theme_bw()
    if (is.null(group)) {
      p <- p + ggplot2::geom_point(data = d, ggplot2::aes(x = .data$x, y = .data$y),
                                   colour = "steelblue", alpha = 0.7)
    } else {
      d$group <- group
      p <- p + ggplot2::geom_point(data = d, ggplot2::aes(x = .data$x, y = .data$y,
                                                          colour = .data$group), alpha = 0.7) +
        ggplot2::labs(colour = group_name)
    }
    p
  })
  names(plots) <- vapply(pairs, function(pr) {
    paste(stats::na.omit(iso[pr]), collapse = "_")
  }, character(1))
  for (nm in names(plots)) {
    if (plot_save_pdf) ggplot2::ggsave(paste0(filename, "_", nm, ".pdf"), plots[[nm]],
                                       width = 7, height = 5)
    if (plot_save_png) ggplot2::ggsave(paste0(filename, "_", nm, ".png"), plots[[nm]],
                                       width = 7, height = 5, dpi = 150)
  }
  if (return_obj) return(plots)
  for (p in plots) print(p)
  invisible(plots)
}
