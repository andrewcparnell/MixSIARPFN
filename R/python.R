# The bridge to the bundled Python inference code (inst/python/mixsiarpfn: numpy and
# ONNX Runtime, no PyTorch). reticulate builds a small isolated Python environment
# from the requirements declared in .onLoad the first time it is needed.

the <- new.env(parent = emptyenv())

python_requirements <- c("numpy>=2.0", "pandas>=2.2", "onnxruntime>=1.20")

.onLoad <- function(libname, pkgname) {
  reticulate::py_require(python_requirements, python_version = ">=3.10")
  # Networks are cached where R keeps package caches, unless the user chose a place
  if (!nzchar(Sys.getenv("MIXSIARPFN_CACHE"))) {
    Sys.setenv(MIXSIARPFN_CACHE = tools::R_user_dir("MixSIARPFN", "cache"))
  }
}

# The bundled Python package, imported once per session
pfn_python <- function() {
  if (is.null(the$py)) {
    path <- system.file("python", package = "MixSIARPFN")
    the$py <- list(
      infer = reticulate::import_from_path("mixsiarpfn.infer_general", path = path),
      weights = reticulate::import_from_path("mixsiarpfn.runtime.weights", path = path),
      data_io = reticulate::import_from_path("mixsiarpfn.data_io", path = path)
    )
  }
  the$py
}

#' Where the networks are cached, and whether they are there
#'
#' The three networks (one per error structure, about 36 MB each) are downloaded the
#' first time they are needed, checked by checksum, and kept in this folder. Set the
#' environment variable `MIXSIARPFN_CACHE` before loading the package to use another
#' folder.
#'
#' @param download Download any network that is missing?
#' @return A data frame: error structure, file, whether it is in the cache.
#' @export
pfn_networks <- function(download = FALSE) {
  w <- pfn_python()$weights
  manifest <- w$read_manifest()
  errors <- c(mult = "Residual * Process", resid = "Residual only",
              process = "Process only")
  rows <- lapply(names(errors), function(e) {
    entry <- manifest[[e]]
    if (is.null(entry)) {
      return(data.frame(error = errors[[e]], file = NA_character_, cached = FALSE))
    }
    path <- file.path(Sys.getenv("MIXSIARPFN_CACHE"), entry$file)
    if (download && !file.exists(path)) w$network_path(e)
    data.frame(error = errors[[e]], file = entry$file, cached = file.exists(path))
  })
  out <- do.call(rbind, rows)
  attr(out, "cache") <- Sys.getenv("MIXSIARPFN_CACHE")
  out
}

# TRUE when all three networks are in the cache (vignettes and examples run only then)
networks_ready <- function() {
  tryCatch(all(pfn_networks()$cached), error = function(e) FALSE)
}
