# MixSIAR reference fits of MixSIAR's further examples (alligator, lake, mantis, palmyra,
# snail, storm petrel), as in MixSIAR's own example scripts, for the package's example
# vignettes. Examples with raw source data are fitted twice: as MixSIAR's script does
# (data_type = "raw") and on the source summaries MixSIARPFN uses ("<name>_means").
#
# Each fit is a "long" run (3 chains of 300,000, burn-in 200,000, thinning 100), in
# parallel, one core each. Results go to <out>/<name>/ (draws.rds, summary.csv, pind.csv
# with continuous effects, info.json). Run from the package root:
#
#   Rscript dev/run_example_references.R [out dir, default ~/MixSIARPFN-build/reference/examples] [run]
#
# then add them to the package with dev/add_example_references.R.

args <- commandArgs(trailingOnly = TRUE)
out <- path.expand(if (length(args) >= 1) args[1] else "~/MixSIARPFN-build/reference/examples")
run <- if (length(args) >= 2) args[2] else "long"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
pkgload::load_all(quiet = TRUE)
source("dev/example_specs.R")

fit_one <- function(name) {
  e <- example_specs[[name]]
  dir <- file.path(out, name)
  dir.create(dir, showWarnings = FALSE)
  if (file.exists(file.path(dir, "info.json"))) return(paste(name, "done already"))
  log <- file(file.path(dir, "log.txt"), open = "wt")
  sink(log); sink(log, type = "message")
  on.exit({ sink(type = "message"); sink(); close(log) })
  set.seed(1)
  wd <- setwd(dir); on.exit(setwd(wd), add = TRUE)
  src <- e$source
  if (isTRUE(e$summarise)) {
    # The same summaries MixSIARPFN fits, as a MixSIAR "means" file
    m0 <- MixSIAR::load_mix_data(filename = e$mix[[1]], iso_names = e$mix[[2]],
                                 factors = e$mix[[3]], fac_random = e$mix[[4]],
                                 fac_nested = e$mix[[5]], cont_effects = e$mix[[6]])
    raw <- read.csv(src[[1]], check.names = FALSE)
    sm <- summarise_raw_sources(raw, m0$iso_names, src[[2]], src[[3]])
    write.csv(sm, file.path(dir, "sources_summarised.csv"), row.names = FALSE)
    src[[1]] <- file.path(dir, "sources_summarised.csv")
    src[[4]] <- "means"
  }
  mix <- MixSIAR::load_mix_data(filename = e$mix[[1]], iso_names = e$mix[[2]],
                                factors = e$mix[[3]], fac_random = e$mix[[4]],
                                fac_nested = e$mix[[5]], cont_effects = e$mix[[6]])
  source <- MixSIAR::load_source_data(filename = src[[1]], source_factors = src[[2]],
                                      conc_dep = src[[3]], data_type = src[[4]], mix)
  discr <- MixSIAR::load_discr_data(filename = e$discr, mix)
  MixSIAR::write_JAGS_model("MixSIAR_model.txt", e$resid, e$process, mix, source)
  t0 <- Sys.time()
  jags.1 <- MixSIAR::run_model(run = run, mix, source, discr, "MixSIAR_model.txt",
                               alpha.prior = e$alpha)
  minutes <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

  draws <- mixsiar_draws(jags.1, mix, source)
  saveRDS(draws, file.path(dir, "draws.rds"), compress = "xz")
  # Summary of the diets and parameters, named as in MixSIAR's output_JAGS()
  sims <- jags.1$BUGSoutput$sims.list
  summ <- function(name, x) data.frame(name = name, mean = mean(x), sd = stats::sd(x),
                                       q2.5 = unname(stats::quantile(x, 0.025)),
                                       q97.5 = unname(stats::quantile(x, 0.975)))
  rows <- lapply(split(draws$value, factor(draws$name, unique(draws$name))), identity)
  s <- do.call(rbind, Map(summ, names(rows), rows))
  for (f in seq_len(mix$n.effects)) {
    if (!is.null(sims[[paste0("fac", f, ".sig")]]))
      s <- rbind(s, summ(paste0(mix$factors[f], ".SD"), sims[[paste0("fac", f, ".sig")]]))
  }
  if (!is.null(sims$resid.prop)) for (j in seq_len(ncol(sims$resid.prop)))
    s <- rbind(s, summ(paste0("Epsilon.", j), sims$resid.prop[, j]))
  write.csv(s, file.path(dir, "summary.csv"), row.names = FALSE)
  # Per-consumer diets with continuous effects (MixSIAR monitors p.ind then)
  if (!is.null(sims$p.ind)) {
    pind <- do.call(rbind, lapply(seq_len(dim(sims$p.ind)[2]), function(i)
      do.call(rbind, lapply(seq_along(source$source_names), function(k) {
        x <- sims$p.ind[, i, k]
        data.frame(consumer = i, source = source$source_names[k], mean = mean(x),
                   q2.5 = unname(stats::quantile(x, 0.025)),
                   q97.5 = unname(stats::quantile(x, 0.975)))
      }))))
    for (c in mix$cont_effects) pind[[c]] <- mix$data[[c]][pind$consumer]
    for (f in mix$factors) pind[[f]] <- as.character(mix$data[[f]][pind$consumer])
    write.csv(pind, file.path(dir, "pind.csv"), row.names = FALSE)
  }
  mc <- jags.1$BUGSoutput
  psrf <- max(mc$summary[, "Rhat"], na.rm = TRUE)
  jsonlite::write_json(list(
    run = run, chain_length = jags.1$BUGSoutput$n.iter, burn = jags.1$BUGSoutput$n.burnin,
    thin = jags.1$BUGSoutput$n.thin, chains = jags.1$BUGSoutput$n.chains,
    minutes = minutes, max_psrf = psrf, data_type = src[[4]],
    mixsiar = as.character(utils::packageVersion("MixSIAR"))),
    file.path(dir, "info.json"), auto_unbox = TRUE, digits = NA)
  paste(name, "done:", round(minutes, 1), "min, max PSRF", round(psrf, 3))
}

names_to_run <- names(example_specs)
res <- parallel::mclapply(names_to_run, function(n) tryCatch(fit_one(n), error = function(e)
  paste(n, "ERROR:", conditionMessage(e))), mc.cores = length(names_to_run),
  mc.preschedule = FALSE)
writeLines(unlist(res))
