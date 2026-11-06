# MixSIAR's further examples, as in its example scripts (system.file("example_scripts",
# package = "MixSIAR")): the arguments to load_mix_data(), load_source_data() and
# load_discr_data(), the error structure and the prior. Used by
# dev/run_example_references.R; the vignettes write the same calls out in full.
#
# mix:    filename, iso_names, factors, fac_random, fac_nested, cont_effects
# source: filename, source_factors, conc_dep, data_type
x <- system.file("extdata", package = "MixSIAR")
f <- function(n) file.path(x, n)

gator_models <- list(
  list(factors = NULL, cont = NULL), list(factors = "habitat", cont = NULL),
  list(factors = "sex", cont = NULL), list(factors = "sclass", cont = NULL),
  list(factors = NULL, cont = "Length"), list(factors = c("sex", "sclass"), cont = NULL),
  list(factors = "sex", cont = "Length"), list(factors = "sex_sclass", cont = NULL))

example_specs <- c(
  stats::setNames(lapply(gator_models, function(g) list(
    mix = list(f("alligator_consumer.csv"), c("d13C", "d15N"), g$factors,
               rep(FALSE, length(g$factors)), rep(FALSE, length(g$factors)), g$cont),
    source = list(f("alligator_sources_simplemean.csv"), NULL, FALSE, "means"),
    discr = f("alligator_TEF.csv"), resid = TRUE, process = TRUE, alpha = 1)),
    paste0("alligator_", seq_along(gator_models))),
  list(
    lake = list(
      mix = list(f("lake_consumer.csv"), c("d13C", "d15N"), NULL, NULL, NULL, "Secchi.Mixed"),
      source = list(f("lake_sources.csv"), NULL, FALSE, "raw"),
      discr = f("lake_discrimination.csv"), resid = TRUE, process = FALSE, alpha = 1),
    mantis = list(
      mix = list(f("mantis_consumer.csv"), c("d13C", "d15N"), "Habitat", FALSE, FALSE, NULL),
      source = list(f("mantis_source.csv"), "Habitat", TRUE, "means"),
      discr = f("mantis_discrimination.csv"), resid = TRUE, process = TRUE,
      alpha = {a <- c(1, 1, 4, 4, 1, 4); a * length(a) / sum(a)}),
    palmyra = list(
      mix = list(f("palmyra_consumer.csv"), c("d13C", "d15N"), "Taxa", FALSE, FALSE, NULL),
      source = list(f("palmyra_sources.csv"), NULL, FALSE, "raw"),
      discr = f("palmyra_discrimination.csv"), resid = TRUE, process = TRUE, alpha = 1),
    snail = list(
      mix = list(f("snail_consumer.csv"), "d13C", NULL, NULL, NULL, NULL),
      source = list(f("snail_sources.csv"), NULL, FALSE, "raw"),
      discr = f("snail_discrimination.csv"), resid = TRUE, process = TRUE, alpha = 1),
    stormpetrel = list(
      mix = list(f("stormpetrel_consumer.csv"), c("d13C", "d15N"), "Region", FALSE, FALSE, NULL),
      source = list(f("stormpetrel_sources.csv"), NULL, FALSE, "raw"),
      discr = f("stormpetrel_discrimination.csv"), resid = TRUE, process = TRUE, alpha = 1)))

# Raw-source examples also fitted by MixSIAR on the summaries MixSIARPFN uses
for (n in names(example_specs)) {
  if (identical(example_specs[[n]]$source[[4]], "raw")) {
    example_specs[[paste0(n, "_means")]] <- c(example_specs[[n]], list(summarise = TRUE))
  }
}
