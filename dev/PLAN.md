# MixSIARPFN: plan for the first release (stage 2)

Written 29 October 2026 for the owner's review. The owner asked for the work to start
straight away; anything changed here gets redone.

## What it is

An R package that fits the same models as MixSIAR, from the same files and with the
same function calls, but gets the posterior from a prior-data fitted network instead
of JAGS: no JAGS, no GPU, results in seconds. Isotope data with source summary
statistics only (MixSIAR's `data_type = "means"`). GPL-3, as MixSIAR.

## Interface: MixSIAR's functions, one call changed

```r
library(MixSIARPFN)
mix <- load_mix_data(filename = mix.filename, iso_names = c("d13C", "d15N"),
                     factors = c("Region", "Pack"), fac_random = c(TRUE, TRUE),
                     fac_nested = c(FALSE, TRUE), cont_effects = NULL)
source <- load_source_data(filename = source.filename, source_factors = "Region",
                           conc_dep = FALSE, data_type = "means", mix)
discr <- load_discr_data(filename = discr.filename, mix)
fit <- run_pfn(mix, source, discr, alpha.prior = 1, resid_err = TRUE, process_err = TRUE)
output_pfn(fit, mix, source, output_options)   # like output_JAGS()
```

- `load_mix_data()`, `load_source_data()`, `load_discr_data()`: same names and
  arguments as MixSIAR 3.1.12. They check the files the way MixSIAR does and return
  lists with MixSIAR's main fields (`data`, `iso_names`, `n.iso`, `n.effects`,
  `FAC`, `N`, `source_names`, ...), plus the options. `data_type = "raw"` stops with
  a clear message (later release).
- `run_pfn()` replaces `write_JAGS_model()` + `run_model()`. Same `alpha.prior`,
  `resid_err`, `process_err` meanings (both TRUE: Residual * Process; one of them:
  that one alone). Data outside the networks' envelope are refused with a message
  saying which limit was exceeded.
- `output_pfn()` follows `output_JAGS()`'s `output_options` list: the summary
  statistics table in MixSIAR's format and row names (`p.global.Deer`,
  `p.Region 1.Deer`, `Region.SD`, `Epsilon.1`, ...), saved to a file if asked, and
  posterior density plots (ggplot2) saved as PDF or PNG. MCMC diagnostics, DIC/LOO and
  pairs plots do not apply and are skipped with a note.
- Extras: `posterior_draws(fit, n)` (marginal draws, long data frame) and
  `summary(fit)`. A fit holds plain R matrices (bar probabilities and borders), so it
  can be saved with `saveRDS()` and used without Python.

**Marginal posteriors only.** The networks give each proportion's marginal
posterior, not joint draws: sums, differences or ratios of proportions are not
available, and the marginal means of one diet need not sum to exactly 1. Every
output function and the documentation say so.

## How the networks run

- The numpy and ONNX Runtime inference code from MixSIARPFN-build
  (`src/mixsiarpfn/`: `infer_general`, `data_io`, `options`, `queries`, `runtime/`)
  is bundled in `inst/python/mixsiarpfn/`, copied by a sync script in the build repo
  (the build repo stays the one source of truth).
- reticulate (>= 1.41) runs it: `.onLoad` declares the Python requirements with
  `reticulate::py_require()` (numpy, pandas, onnxruntime), so reticulate creates a
  small, isolated environment on first use. Users do not install Python themselves.
- Networks: three ONNX files (one per error structure, float16 weights, 36 MB each)
  are downloaded on first use from Zenodo, checked by SHA-256 and cached in
  `tools::R_user_dir("MixSIARPFN", "cache")`. Largest change from float16 against the
  PyTorch networks: 0.0077 (mult), 0.0036 (resid), 0.0023 (process) in any posterior
  mean, SD, quantile or CDF.
- **Needs the owner:** the Zenodo upload (their account). Until then, the manifest
  holds the checksums and the files can be placed in the cache by hand.

## Contents

- `R/`: loaders, `run_pfn()`, `output_pfn()`, draws, print and summary methods, the
  Python bridge.
- `inst/extdata/`: the killer whale, geese and wolves files from MixSIAR (Stock et al.
  2018), so the examples and vignettes run.
- `tests/testthat/`: loaders and argument checks (no Python needed); end-to-end fits of
  the three vignettes against the Python package's results (skipped when the networks
  are not available).
- `vignettes/`: killer whale, geese and wolves, following MixSIAR's own vignettes
  with `run_pfn()` in place of `run_model()`, plus how it compares with MixSIAR.

## Order of work

1. Package skeleton, loaders and their tests.
2. Python bridge, bundled code, `run_pfn()`, end-to-end tests on the three vignettes
   (networks from the local cache).
3. `output_pfn()`, draws, methods.
4. Vignettes, README, `R CMD check` clean.
5. After the owner's review and the Zenodo upload: manifest URLs, GitHub repo
   (private first), then release.

## Not in this release

Raw source data, fatty acids (isopod, cladocera, lake), joint posteriors, MixSIAR's
`plot_data()` and `plot_prior()` (possible later additions).
