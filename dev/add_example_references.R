# Add the MixSIAR reference fits of MixSIAR's further examples (dev/run_example_references.R)
# to inst/extdata/mixsiar_reference.rds and <name>_mixsiar_summary.csv. Run from the
# package root:
#
#   Rscript dev/add_example_references.R [dir, default ~/MixSIARPFN-build/reference/examples]
#
# For examples with raw source data, the main reference ("<name>") is MixSIAR fitted to the
# source summaries MixSIARPFN uses; "<name>_raw" is MixSIAR's own raw-data fit.

args <- commandArgs(trailingOnly = TRUE)
dir <- path.expand(if (length(args) >= 1) args[1] else "~/MixSIARPFN-build/reference/examples")
ref <- readRDS("inst/extdata/mixsiar_reference.rds")
if (is.null(ref$pind)) ref$pind <- list()

thin <- function(draws, n = 1000) {
  do.call(rbind, lapply(split(draws, factor(draws$name, unique(draws$name))), function(d) {
    d[unique(round(seq(1, nrow(d), length.out = n))), ]
  }))
}

raw_examples <- c("lake", "palmyra", "snail", "stormpetrel")
for (run in sort(list.files(dir))) {
  path <- file.path(dir, run)
  if (!file.exists(file.path(path, "info.json"))) {
    message(run, ": not finished, skipped")
    next
  }
  name <- if (run %in% raw_examples) paste0(run, "_raw") else sub("_means$", "", run)
  info <- jsonlite::fromJSON(file.path(path, "info.json"))
  d <- thin(readRDS(file.path(path, "draws.rds")))
  rownames(d) <- NULL
  ref$draws[[name]] <- d
  ref$info[[name]] <- info[c("run", "chain_length", "burn", "thin", "chains", "minutes",
                             "max_psrf", "mixsiar", "data_type")]
  if (file.exists(file.path(path, "pind.csv")))
    ref$pind[[name]] <- utils::read.csv(file.path(path, "pind.csv"), check.names = FALSE)
  file.copy(file.path(path, "summary.csv"),
            file.path("inst/extdata", paste0(name, "_mixsiar_summary.csv")), overwrite = TRUE)
  message(sprintf("%-18s -> %-17s %s run, %.0f min, max PSRF %.3f", run, name, info$run,
                  info$minutes, info$max_psrf))
}
saveRDS(ref, "inst/extdata/mixsiar_reference.rds", compress = "xz")
message("mixsiar_reference.rds: ", round(file.size("inst/extdata/mixsiar_reference.rds") / 1e6, 2), " MB")
