# Package the off-vignette benchmark (MixSIARPFN-build experiments/general/evaluate.py)
# for the "Every simulated dataset" article: inst/extdata/benchmark.rds.
#
# These are simulated datasets with known truths, of designs other than the simulation
# study's: 24 general designs (every error structure, fixed/random/crossed/nested effects,
# covariates, concentration dependence, sources by factor), 10 like geese and 12 like
# killer whale. Each was fitted by MixSIAR (long, or extreme where a rerun finished), and
# compared with the released (v3) networks:
#   Residual * Process: general_mult_joint best (v3)
#   Residual only:      general_resid_q2 best (v2 = v3)
#   Process only:       general_process_q2 best (v2 = v3)
# Run from the package root:
#
#   Rscript dev/add_benchmark.R [path to MixSIARPFN-build, default ~/MixSIARPFN-build]

args <- commandArgs(trailingOnly = TRUE)
build <- path.expand(if (length(args) >= 1) args[1] else "~/MixSIARPFN-build")
res <- file.path(build, "experiments", "general", "results")
runs <- c(mult = "general_mult_joint_best", resid = "general_resid_q2_best",
          process = "general_process_q2_best")
real <- c("killerwhale_inf", "killerwhale_uninf", "wolves", "wolves_extreme", "geese")

dataset_dir <- function(d) {
  parts <- strsplit(d, "/", fixed = TRUE)[[1]]
  file.path(build, "experiments", parts[1], "offvignette", parts[2])
}

design <- function(d) {
  dir <- dataset_dir(d)
  s <- jsonlite::fromJSON(file.path(dir, "spec.json"))
  n_cons <- nrow(utils::read.csv(file.path(dir, s$mix_file)))
  eff <- if (length(s$factors) == 0) "none" else paste0(
    ifelse(s$fac_random, "R", "F"), collapse = "")
  if (length(s$fac_nested) == 2 && any(s$fac_nested)) eff <- paste0(eff, " nested")
  mix_dir <- if (file.exists(file.path(dir, "mixsiar_extreme", "run_info.json")))
    "mixsiar_extreme" else "mixsiar"
  info <- jsonlite::fromJSON(file.path(dir, mix_dir, "run_info.json"))
  data.frame(
    dataset = d, family = c(general = "General", geese = "Geese-like",
                            killerwhale = "Killer-whale-like")[[strsplit(d, "/")[[1]][1]]],
    error = if (isTRUE(s$resid_err) && isTRUE(s$process_err)) "Residual * Process" else
      if (isTRUE(s$resid_err)) "Residual only" else "Process only",
    sources = length(s$alpha_prior), tracers = length(s$iso_names), consumers = n_cons,
    effects = eff, covariate = length(s$cont_effects) > 0, conc_dep = isTRUE(s$conc_dep),
    sources_by_factor = length(s$source_factors) > 0,
    informative_prior = length(unique(unlist(s$alpha_prior))) > 1,
    mixsiar_run = info$run, mixsiar_minutes = info$wall_clock_seconds$run_model / 60,
    mixsiar_psrf = info$max_psrf_point)
}

rows <- list()
for (e in names(runs)) {
  cmp <- utils::read.csv(file.path(res, runs[[e]], "comparison.csv"))
  cmp <- cmp[!cmp$dataset %in% real, ]
  rows[[e]] <- cmp
}
comparison <- do.call(rbind, rows)
rownames(comparison) <- NULL
designs <- do.call(rbind, lapply(unique(comparison$dataset), design))
keep <- c("dataset", "quantity", "kind", "block", "level", "label", "pfn_mean", "pfn_sd",
          "mixsiar_mean", "mixsiar_sd", "mixsiar_q2.5", "mixsiar_q97.5", "wasserstein1",
          "p_true", "pfn_truth_in_95", "mixsiar_truth_in_95", "sd_ratio")
comparison <- comparison[, keep]
num <- vapply(comparison, is.numeric, logical(1))
comparison[num] <- lapply(comparison[num], signif, 5)

# Benchmark datasets left out, and why
excluded <- data.frame(
  dataset = c("general/ov08_resid_none_cont_K4_J2_N50", "general/ov09_resid_FR_srcbyHabitat_K4_J2_L3x5_N150",
              "general/ov13_process_R_K5_J2_L6_N100", "general/ov15_process_RR_conc_K4_J2_L3x4_N120",
              "general/ov25_mult_RRn_srcbyLake_K8_J2_L4x9_N500"),
  reason = c("MixSIAR cannot fit it (its inverse ILR overflows)",
             "MixSIAR did not converge, even at extreme length (largest PSRF 1.14)",
             "MixSIAR did not converge, even at extreme length (largest PSRF 1.15)",
             "MixSIAR did not converge, even at extreme length (largest PSRF 1.31)",
             "MixSIAR's long run did not converge (largest PSRF 1.12) and its extreme run had not finished"))

benchmark <- list(comparison = comparison, designs = designs, excluded = excluded,
                  networks = runs, made = format(Sys.Date()))
saveRDS(benchmark, "inst/extdata/benchmark.rds", compress = "xz")
message("benchmark.rds: ", nrow(designs), " datasets, ", nrow(comparison), " rows, ",
        round(file.size("inst/extdata/benchmark.rds") / 1e6, 2), " MB")
print(table(designs$family, designs$error))
