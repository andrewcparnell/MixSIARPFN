# Add the posterior predictive checks of MixSIAR's fits to inst/extdata/mixsiar_reference.rds.
#
# The checks were run in MixSIARPFN-build (r/ppc_reference.R, results in
# experiments/general/ppc/): MixSIAR's own JAGS model and data with replicated consumers
# drawn from the likelihood, "very long" runs. Six model-generated datasets each like
# geese and wolves are the controls. Run from the package root:
#
#   Rscript dev/add_ppc_reference.R [path to MixSIARPFN-build, default ~/simmr-pfn]

args <- commandArgs(trailingOnly = TRUE)
build <- if (length(args) >= 1) args[1] else "~/simmr-pfn"
ppc_dir <- file.path(build, "experiments", "general", "ppc")
pkgload::load_all(quiet = TRUE)
x <- "inst/extdata"

# Group labels and tracer names in MixSIAR's order, from the loaders
mixes <- list(
  killerwhale = load_mix_data(file.path(x, "killerwhale_consumer.csv"), iso_names = c("d13C", "d15N"),
                              factors = NULL, fac_random = NULL, fac_nested = NULL, cont_effects = NULL),
  geese = load_mix_data(file.path(x, "geese_consumer.csv"), iso_names = c("d13C", "d15N"),
                        factors = "Group", fac_random = FALSE, fac_nested = FALSE, cont_effects = NULL),
  wolves = load_mix_data(file.path(x, "wolves_consumer.csv"), iso_names = c("d13C", "d15N"),
                         factors = c("Region", "Pack"), fac_random = c(TRUE, TRUE),
                         fac_nested = c(FALSE, TRUE), cont_effects = NULL))
controls <- c(geese = "sim_geese_", wolves = "sim_wolves_realistic_")

summary_row <- function(dir) {
  s <- jsonlite::fromJSON(file.path(dir, "ppc_summary.json"))
  data.frame(dataset = basename(dir), group_stats = s$group_stats,
             extreme_95 = s$group_stats_extreme_05, extreme_99 = s$group_stats_extreme_01,
             loglik_p = s$loglik_ppp)
}

ref <- readRDS(file.path(x, "mixsiar_reference.rds"))
ref$ppc <- list()
for (v in names(mixes)) {
  mix <- mixes[[v]]
  stats <- utils::read.csv(file.path(ppc_dir, v, "ppc_stats.csv"))
  labels <- if (mix$n.effects == 0) "all" else mix$FAC[[mix$n.effects]]$labels
  stats$group <- ifelse(is.na(stats$group), NA, as.character(labels[stats$group]))
  stats$tracer <- ifelse(is.na(stats$tracer), NA, mix$iso_names[stats$tracer])
  if (mix$n.effects == 0) stats$group[stats$stat %in% c("mean", "sd", "cor")] <- "all"
  ctrl <- if (v %in% names(controls))
    do.call(rbind, lapply(sort(Sys.glob(file.path(ppc_dir, paste0(controls[[v]], "s*")))), summary_row))
  ref$ppc[[v]] <- list(
    stats = stats,
    summary = summary_row(file.path(ppc_dir, v)),
    controls = ctrl,
    grouping = if (mix$n.effects == 0) NA_character_ else mix$factors[mix$n.effects])
}
saveRDS(ref, file.path(x, "mixsiar_reference.rds"), compress = "xz")
message("Added ppc for ", paste(names(ref$ppc), collapse = ", "))
