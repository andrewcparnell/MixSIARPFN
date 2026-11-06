# Package the simulation study (MixSIARPFN-build, experiments/general/simstudy/) for the
# "How well it does" vignette: inst/extdata/simstudy.rds.
#
# Six sets of datasets with known true diets: geese-like, wolves-like with diets from
# MixSIAR's prior, and realistic wolves-like (random-effect SDs U(0.2, 2)), each in two
# batches (50 datasets, seed 2026; 100 datasets "_b", seed 2027). Every dataset was fitted
# by MixSIAR (normal and long runs; some extreme) and scored for each network version.
# Run from the package root:
#
#   Rscript dev/add_simstudy.R [path to MixSIARPFN-build, default ~/MixSIARPFN-build]

args <- commandArgs(trailingOnly = TRUE)
build <- if (length(args) >= 1) args[1] else "~/MixSIARPFN-build"
base <- file.path(path.expand(build), "experiments", "general", "simstudy")

sets <- c(geese = "geese", wolves = "wolves", wolves_realistic = "wolves_realistic")
labels <- c(v1 = "v1", v2 = "v2", q3 = "q3_best", v3 = "v3")   # network version -> score label
# v3 changed only the Residual * Process network (wolves sets); geese's Residual only
# network in v3 is v2's, so its v3 scores are v2's
same_as <- list(geese = c(v3 = "v2"))
keep <- c("dataset", "method", "converged", "psrf", "name", "block", "truth", "mean", "lo",
          "hi", "covered", "width", "crps")

rows <- list()
for (s in names(sets)) for (batch in c("a", "b")) {
  dir <- file.path(base, if (batch == "a") sets[[s]] else paste0(sets[[s]], "_b"))
  for (v in names(labels)) {
    lab <- labels[[v]]
    if (!is.null(same_as[[s]]) && v %in% names(same_as[[s]])) lab <- labels[[same_as[[s]][[v]]]]
    f <- file.path(dir, paste0("scores_", lab, ".csv"))
    if (!file.exists(f)) stop("missing ", f)
    d <- utils::read.csv(f)[, keep]
    # MixSIAR's rows are the same in every file: take them from the v2 file only
    d <- if (v == "v2") d else d[d$method == "MixSIARPFN", ]
    d$method[d$method == "MixSIARPFN"] <- paste("MixSIARPFN", v)
    d$set <- s
    d$batch <- batch
    rows[[length(rows) + 1]] <- d
  }
}
scores <- do.call(rbind, rows)
scores$converged <- as.logical(scores$converged)        # "True"/"False" from Python
scores$dataset <- paste0(scores$batch, "_", scores$dataset)
scores$batch <- NULL
scores <- scores[, c("set", "dataset", setdiff(names(scores), c("set", "dataset")))]
for (v in c("mean", "lo", "hi", "width", "crps", "truth", "psrf")) scores[[v]] <- signif(scores[[v]], 5)

# MixSIAR run times (run_model(), seconds) for each dataset and run length
times <- list()
for (s in names(sets)) for (batch in c("a", "b")) {
  dir <- file.path(base, if (batch == "a") sets[[s]] else paste0(sets[[s]], "_b"))
  for (info in Sys.glob(file.path(dir, "s*", "mixsiar_*", "run_info.json"))) {
    j <- jsonlite::fromJSON(info)
    times[[length(times) + 1]] <- data.frame(
      set = s, dataset = paste0(batch, "_", basename(dirname(dirname(info)))),
      length = sub("mixsiar_", "", basename(dirname(info))),
      seconds = j$wall_clock_seconds$run_model)
  }
}
times <- do.call(rbind, times)

# MixSIARPFN fit times through the package (dev/time_simstudy.R)
pfn_times <- utils::read.csv(file.path(base, "pfn_seconds.csv"))

simstudy <- list(scores = scores, mixsiar_seconds = times, pfn_seconds = pfn_times,
                 made = format(Sys.Date()),
                 notes = paste("Datasets a_*: seed 2026 (50 per set); b_*: seed 2027 (100 per",
                               "set). MixSIARPFN v3 = the released networks; v3 changed only the",
                               "Residual * Process network, so geese's v3 rows equal v2's."))
saveRDS(simstudy, "inst/extdata/simstudy.rds", compress = "xz")
message("simstudy.rds: ", nrow(scores), " score rows, ", nrow(times), " MixSIAR runs, ",
        round(file.size("inst/extdata/simstudy.rds") / 1e6, 2), " MB")
