# Where the networks are cached, and whether they are there

The three networks (one per error structure, about 36 MB each) are
downloaded the first time they are needed, checked by checksum, and kept
in this folder. Set the environment variable `MIXSIARPFN_CACHE` before
loading the package to use another folder.

## Usage

``` r
pfn_networks(download = FALSE)
```

## Arguments

- download:

  Download any network that is missing?

## Value

A data frame: error structure, file, whether it is in the cache.
