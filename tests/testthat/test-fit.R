# End-to-end fits of MixSIAR's three isotope vignettes. The reference values come from
# the Python package in MixSIARPFN-build with the same networks (fixtures/*_python.csv),
# so these check the R side: loading, options passed on, and labels.

x <- function(f) system.file("extdata", f, package = "MixSIARPFN")
fixture <- function(name) {
  utils::read.csv(test_path("fixtures", paste0(name, "_python.csv")),
                  colClasses = c(level = "character"))
}

skip_if_no_networks <- function() {
  skip_on_cran()
  ok <- tryCatch(all(pfn_networks()$cached), error = function(e) FALSE)
  if (!ok) skip("networks not in the cache (see pfn_networks())")
}

check_against_python <- function(fit, name) {
  ref <- fixture(name)
  got <- fit$summary
  key <- function(d) paste(d$block, d$level, d$source)
  expect_setequal(key(got), key(ref))
  got <- got[match(key(ref), key(got)), ]
  expect_equal(got$mean, ref$mean, tolerance = 1e-5)
  expect_equal(got$sd, ref$sd, tolerance = 1e-5)
  expect_equal(got$q97.5, ref$q97.5, tolerance = 1e-5)
}

test_that("killer whale (no effects, Residual * Process) matches the Python package", {
  skip_if_no_networks()
  mix <- load_mix_data(x("killerwhale_consumer.csv"), iso_names = c("d13C", "d15N"),
                       factors = NULL, fac_random = NULL, fac_nested = NULL,
                       cont_effects = NULL)
  source <- load_source_data(x("killerwhale_sources.csv"), source_factors = NULL,
                             conc_dep = FALSE, data_type = "means", mix)
  discr <- load_discr_data(x("killerwhale_discrimination.csv"), mix)
  fit <- run_pfn(mix, source, discr, alpha.prior = 1)
  check_against_python(fit, "killerwhale")
  expect_equal(fit$error, "mult")
  expect_true(all(c("Epsilon.1", "Epsilon.2", "p.global.Chinook") %in%
                    rownames(summary_table(fit))))
})

test_that("geese (fixed effect, concentrations, Residual only) matches the Python package", {
  skip_if_no_networks()
  mix <- load_mix_data(x("geese_consumer.csv"), iso_names = c("d13C", "d15N"),
                       factors = "Group", fac_random = FALSE, fac_nested = FALSE,
                       cont_effects = NULL)
  source <- load_source_data(x("geese_sources.csv"), source_factors = NULL,
                             conc_dep = TRUE, data_type = "means", mix)
  discr <- load_discr_data(x("geese_discrimination.csv"), mix)
  fit <- run_pfn(mix, source, discr, resid_err = TRUE, process_err = FALSE)
  check_against_python(fit, "geese")
  expect_true("p.Group 1.Grass" %in% fit$summary$name)
})

test_that("wolves (nested random effects, sources by Region) matches the Python package", {
  skip_if_no_networks()
  mix <- load_mix_data(x("wolves_consumer.csv"), iso_names = c("d13C", "d15N"),
                       factors = c("Region", "Pack"), fac_random = c(TRUE, TRUE),
                       fac_nested = c(FALSE, TRUE), cont_effects = NULL)
  source <- load_source_data(x("wolves_sources.csv"), source_factors = "Region",
                             conc_dep = FALSE, data_type = "means", mix)
  discr <- load_discr_data(x("wolves_discrimination.csv"), mix)
  fit <- run_pfn(mix, source, discr)
  check_against_python(fit, "wolves")
  tab <- summary_table(fit)
  expect_equal(rownames(tab)[1:4], c("Epsilon.1", "Epsilon.2", "Region.SD", "Pack.SD"))
  expect_true("p.Pack 8.Salmon" %in% rownames(tab))

  # Draws follow the marginals; a fit survives saveRDS() without Python
  d <- posterior_draws(fit, n = 4000, seed = 1)
  g <- d[d$name == "p.global.Deer", "value"]
  ref <- fit$summary[fit$summary$name == "p.global.Deer", ]
  expect_equal(mean(g), ref$mean, tolerance = 0.03)
  f <- tempfile(fileext = ".rds")
  saveRDS(fit, f)
  expect_equal(summary_table(readRDS(f)), tab)

  utils::capture.output(out <- withr::with_dir(tempdir(), output_pfn(
    fit, mix, source, list(summary_save = FALSE, sup_post = TRUE,
                           plot_post_save_pdf = FALSE))))
  expect_true(all(c("global", "Region", "Pack", "Region.SD") %in% names(out$plots)))
})

test_that("data outside the envelope are refused with a message", {
  skip_if_no_networks()
  mix <- load_mix_data(x("killerwhale_consumer.csv"), iso_names = c("d13C", "d15N"),
                       factors = NULL, fac_random = NULL, fac_nested = NULL,
                       cont_effects = NULL)
  source <- load_source_data(x("killerwhale_sources.csv"), source_factors = NULL,
                             conc_dep = FALSE, data_type = "means", mix)
  discr <- load_discr_data(x("killerwhale_discrimination.csv"), mix)
  expect_error(run_pfn(mix, source, discr, alpha.prior = 1000), "alpha")
})
