x <- function(f) system.file("extdata", f, package = "MixSIARPFN")

wolves <- function() {
  mix <- load_mix_data(x("wolves_consumer.csv"), iso_names = c("d13C", "d15N"),
                       factors = c("Region", "Pack"), fac_random = c(TRUE, TRUE),
                       fac_nested = c(FALSE, TRUE), cont_effects = NULL)
  source <- load_source_data(x("wolves_sources.csv"), source_factors = "Region",
                             conc_dep = FALSE, data_type = "means", mix)
  discr <- load_discr_data(x("wolves_discrimination.csv"), mix)
  list(mix = mix, source = source, discr = discr)
}

test_that("mixsiar_reference() has draws and summaries named like the fits", {
  for (v in c("killerwhale", "geese", "wolves")) {
    ref <- mixsiar_reference(v)
    expect_true(all(table(ref$draws$name) == 1000))
    expect_true(all(ref$draws$value >= 0 & ref$draws$value <= 1))
    expect_true(all(c("name", "mean", "sd", "q2.5", "q97.5") %in% names(ref$summary)))
  }
  expect_true("p.Pack 8.Salmon" %in% mixsiar_reference("wolves")$draws$name)
})

test_that("mixsiar_draws() names a MixSIAR fit's proportions as its summary does", {
  w <- wolves()
  n <- 5
  fake <- list(BUGSoutput = list(sims.list = list(
    p.global = matrix(1 / 3, n, 3),
    p.fac1 = array(1 / 3, c(n, 3, 3)),
    p.fac2 = array(1 / 3, c(n, 8, 3)))))
  d <- mixsiar_draws(fake, w$mix, w$source)
  expect_equal(nrow(d), n * (3 + 9 + 24))
  expect_true(all(c("p.global.Deer", "p.Region 2.Salmon", "p.Pack 8.Marine Mammals") %in% d$name))
})

test_that("the W1 distance is 0 for the same distribution and grows with a shift", {
  borders <- seq(0, 1, length.out = 101)
  probs <- stats::dbeta((borders[-1] + borders[-101]) / 2, 4, 6)
  probs <- probs / sum(probs)
  same <- MixSIARPFN:::bar_draws(probs, borders, 20000)
  expect_lt(MixSIARPFN:::wasserstein1(probs, borders, same), 0.01)
  expect_equal(MixSIARPFN:::wasserstein1(probs, borders, pmin(same + 0.1, 1)), 0.1,
               tolerance = 0.02)
})

test_that("plot_data() draws one plot per pair of tracers", {
  w <- wolves()
  p <- plot_data(mix = w$mix, source = w$source, discr = w$discr, return_obj = TRUE)
  expect_length(p, 1)
  expect_s3_class(p[[1]], "ggplot")
})

test_that("compare_mixsiar() and plot_compare() work on a fit", {
  skip_on_cran()
  ok <- tryCatch(all(pfn_networks()$cached), error = function(e) FALSE)
  if (!ok) skip("networks not in the cache")
  w <- wolves()
  fit <- run_pfn(w$mix, w$source, w$discr)
  ref <- mixsiar_reference("wolves")
  cmp <- compare_mixsiar(fit, ref$draws, ref$summary)
  expect_equal(sum(!is.na(cmp$w1)), 36)
  expect_true(all(c("Region.SD", "Epsilon.1") %in% cmp$name))
  expect_true(all(cmp$w1 >= 0, na.rm = TRUE))
  expect_s3_class(plot_compare(fit, ref$draws, block = "Pack"), "ggplot")
  expect_s3_class(plot_compare(fit, ref$draws, type = "means"), "ggplot")
})
