x <- function(f) system.file("extdata", f, package = "MixSIARPFN")

wolves_mix <- function() {
  load_mix_data(x("wolves_consumer.csv"), iso_names = c("d13C", "d15N"),
                factors = c("Region", "Pack"), fac_random = c(TRUE, TRUE),
                fac_nested = c(FALSE, TRUE), cont_effects = NULL)
}

test_that("load_mix_data reads the wolves data as MixSIAR does", {
  mix <- wolves_mix()
  expect_s3_class(mix, "pfn_mix")
  expect_equal(mix$N, 66)
  expect_equal(mix$n.iso, 2)
  expect_equal(mix$n.re, 2)
  expect_equal(mix$FAC[[1]]$labels, paste("Region", 1:3))
  expect_equal(mix$FAC[[2]]$levels, 8)
  # Pack is nested in Region: each pack's region
  expect_equal(mix$FAC[[2]]$lookup, c(1, 1, 1, 2, 2, 2, 2, 3))
  expect_equal(mix$MU_names, c("Meand13C", "Meand15N"))
})

test_that("load_mix_data puts a fixed effect before a random one, as MixSIAR", {
  df <- data.frame(d13C = rnorm(12), Site = rep(c("a", "b", "c"), 4),
                   Sex = rep(c("F", "M"), 6))
  mix <- load_mix_data(df, iso_names = "d13C", factors = c("Site", "Sex"),
                       fac_random = c(TRUE, FALSE), fac_nested = c(FALSE, FALSE),
                       cont_effects = NULL)
  expect_equal(mix$factors, c("Sex", "Site"))
  expect_equal(mix$fac_random, c(FALSE, TRUE))
  expect_true(mix$fere)
})

test_that("load_mix_data scales a continuous effect like R's scale()", {
  df <- data.frame(d13C = rnorm(10), Length = 1:10)
  mix <- load_mix_data(df, iso_names = "d13C", factors = NULL, fac_random = NULL,
                       fac_nested = NULL, cont_effects = "Length")
  expect_equal(mix$CE_center, 5.5)
  expect_equal(mix$CE_scale, sd(1:10))
})

test_that("load_mix_data stops on MixSIAR's errors", {
  f <- x("wolves_consumer.csv")
  expect_error(load_mix_data(f, iso_names = NULL, factors = NULL, fac_random = NULL,
                             fac_nested = NULL, cont_effects = NULL), "No isotopes")
  expect_error(load_mix_data(f, iso_names = "d34S", factors = NULL, fac_random = NULL,
                             fac_nested = NULL, cont_effects = NULL), "iso_names")
  expect_error(load_mix_data(f, iso_names = "d13C", factors = "Region",
                             fac_random = NULL, fac_nested = NULL, cont_effects = NULL),
               "fac_random")
  expect_error(load_mix_data(f, iso_names = "d13C", factors = c("Region", "Pack"),
                             fac_random = c(TRUE, TRUE), fac_nested = c(TRUE, TRUE),
                             cont_effects = NULL), "Both factors")
  expect_error(load_mix_data("no_such_file.csv", "d13C", NULL, NULL, NULL, NULL),
               "cannot find")
})

test_that("load_source_data reads sources by factor and checks them", {
  mix <- wolves_mix()
  src <- load_source_data(x("wolves_sources.csv"), source_factors = "Region",
                          conc_dep = FALSE, data_type = "means", mix)
  expect_equal(src$source_names, c("Deer", "Marine Mammals", "Salmon"))
  expect_equal(src$S_factor_levels, 3)
  expect_error(load_source_data(x("wolves_sources.csv"), source_factors = NULL,
                                conc_dep = FALSE, data_type = "raw", mix),
               "one column per tracer")
  expect_error(load_source_data(x("wolves_sources.csv"), source_factors = "Lake",
                                conc_dep = FALSE, data_type = "means", mix),
               "do not match")
  expect_error(load_source_data(x("wolves_sources.csv"), source_factors = NULL,
                                conc_dep = TRUE, data_type = "means", mix),
               "Concentration")
})

test_that("load_source_data reads concentrations (geese)", {
  mix <- load_mix_data(x("geese_consumer.csv"), iso_names = c("d13C", "d15N"),
                       factors = "Group", fac_random = FALSE, fac_nested = FALSE,
                       cont_effects = NULL)
  src <- load_source_data(x("geese_sources.csv"), source_factors = NULL,
                          conc_dep = TRUE, data_type = "means", mix)
  expect_equal(dim(src$conc), c(4, 2))
  expect_equal(rownames(src$conc), src$source_names)
})

test_that("load_discr_data checks column names", {
  mix <- wolves_mix()
  discr <- load_discr_data(x("wolves_discrimination.csv"), mix)
  expect_equal(rownames(discr$mu), c("Deer", "Marine Mammals", "Salmon"))
  bad <- utils::read.csv(x("wolves_discrimination.csv"))[, 1:3]
  expect_error(load_discr_data(bad, mix), "mislabeled")
})

test_that("the error structure follows resid_err and process_err", {
  expect_equal(MixSIARPFN:::error_structure(TRUE, TRUE), "mult")
  expect_equal(MixSIARPFN:::error_structure(TRUE, FALSE), "resid")
  expect_equal(MixSIARPFN:::error_structure(FALSE, TRUE), "process")
  expect_error(MixSIARPFN:::error_structure(FALSE, FALSE), "At least one")
})

test_that("the mix object has MixSIAR's fields and values", {
  skip_if_not_installed("MixSIAR")
  ours <- wolves_mix()
  theirs <- suppressMessages(MixSIAR::load_mix_data(
    x("wolves_consumer.csv"), iso_names = c("d13C", "d15N"),
    factors = c("Region", "Pack"), fac_random = c(TRUE, TRUE),
    fac_nested = c(FALSE, TRUE), cont_effects = NULL))
  expect_setequal(names(ours), names(theirs))
  for (k in names(theirs)) expect_equal(ours[[k]], theirs[[k]], ignore_attr = TRUE, label = k)
})

test_that("raw source data are summarised to means, SDs and sample sizes", {
  x <- system.file("extdata", package = "MixSIARPFN")
  mix <- load_mix_data(file.path(x, "palmyra_consumer.csv"), iso_names = c("d13C", "d15N"),
                       factors = "Taxa", fac_random = FALSE, fac_nested = FALSE,
                       cont_effects = NULL)
  expect_message(source <- load_source_data(file.path(x, "palmyra_sources.csv"),
                                            source_factors = NULL, conc_dep = FALSE,
                                            data_type = "raw", mix), "summarised")
  raw <- utils::read.csv(file.path(x, "palmyra_sources.csv"))
  reef <- raw[raw[, 1] == "Reef", ]
  row <- source$data[source$data$Source == "Reef", ]
  expect_equal(row$Meand13C, mean(reef$d13C))
  expect_equal(row$SDd15N, stats::sd(reef$d15N))
  expect_equal(row$n, nrow(reef))
  expect_equal(source$source_names, c("Lagoon", "Pelagic", "Reef"))
  expect_error(load_source_data(file.path(x, "palmyra_sources.csv"), source_factors = NULL,
                                conc_dep = FALSE, data_type = "other", mix), "means' or 'raw")
})
