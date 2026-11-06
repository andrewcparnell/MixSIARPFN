# Time MixSIARPFN on every simulation-study dataset, through the installed package as a
# user would run it (loaders + run_pfn), for the "How MixSIARPFN works" article.
# Writes <build>/experiments/general/simstudy/pfn_seconds.csv; dev/add_simstudy.R adds it
# to inst/extdata/simstudy.rds. Run from the package root after installing it:
#
#   Rscript dev/time_simstudy.R [path to MixSIARPFN-build, default ~/MixSIARPFN-build]

args <- commandArgs(trailingOnly = TRUE)
build <- path.expand(if (length(args) >= 1) args[1] else "~/MixSIARPFN-build")
base <- file.path(build, "experiments", "general", "simstudy")
library(MixSIARPFN)
null_if_empty <- function(x) if (length(x) == 0) NULL else unlist(x)

rows <- list()
first <- TRUE
for (s in c("geese", "wolves", "wolves_realistic")) for (batch in c("a", "b")) {
  dir <- file.path(base, if (batch == "a") s else paste0(s, "_b"))
  for (d in sort(Sys.glob(file.path(dir, "s[0-9]*")))) {
    spec <- jsonlite::fromJSON(file.path(d, "spec.json"), simplifyVector = FALSE)
    t <- system.time({
      mix <- load_mix_data(file.path(d, spec$mix_file), iso_names = unlist(spec$iso_names),
                           factors = null_if_empty(spec$factors),
                           fac_random = null_if_empty(spec$fac_random),
                           fac_nested = null_if_empty(spec$fac_nested),
                           cont_effects = null_if_empty(spec$cont_effects))
      source <- load_source_data(file.path(d, spec$source_file),
                                 source_factors = null_if_empty(spec$source_factors),
                                 conc_dep = isTRUE(spec$conc_dep), data_type = spec$data_type, mix)
      discr <- load_discr_data(file.path(d, spec$discr_file), mix)
      alpha <- unlist(spec$alpha_prior)[source$source_names]
      fit <- run_pfn(mix, source, discr, alpha.prior = unname(alpha),
                     resid_err = isTRUE(spec$resid_err), process_err = isTRUE(spec$process_err))
    })[["elapsed"]]
    # The first fit also starts Python and loads the network: time it again
    if (first) { first <- FALSE; next }
    rows[[length(rows) + 1]] <- data.frame(set = s, dataset = paste0(batch, "_", basename(d)),
                                           seconds = t)
  }
  message(s, " ", batch, " done")
}
out <- do.call(rbind, rows)
utils::write.csv(out, file.path(base, "pfn_seconds.csv"), row.names = FALSE)
print(tapply(out$seconds, out$set, stats::median))
