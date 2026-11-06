# MixSIARPFN

Fit [MixSIAR](https://github.com/brianstock/MixSIAR) stable isotope
mixing models in about a second, without JAGS: thousands of times faster
than MixSIAR, with nearly the same answers. MixSIARPFN reads the same
files with the same function calls as MixSIAR, but takes the posterior
from a *prior-data fitted network*: a transformer trained on simulations
from MixSIAR’s own model, one network per error structure.

``` r
library(MixSIARPFN)
mix <- load_mix_data(filename = "consumer.csv", iso_names = c("d13C", "d15N"),
                     factors = c("Region", "Pack"), fac_random = c(TRUE, TRUE),
                     fac_nested = c(FALSE, TRUE), cont_effects = NULL)
source <- load_source_data(filename = "sources.csv", source_factors = "Region",
                           conc_dep = FALSE, data_type = "means", mix)
discr <- load_discr_data(filename = "discrimination.csv", mix)

fit <- run_pfn(mix, source, discr)   # in place of write_JAGS_model() + run_model()
output_pfn(fit, mix, source)         # in place of output_JAGS()
```

## What it fits

The models MixSIAR fits with isotope data: up to two categorical effects
(fixed or random, crossed or nested), one continuous effect,
concentration dependence, sources given by a factor, informative priors,
and Residual \* Process, Residual only or Process only error. Up to 8
sources and 4 tracers. Source data can be summary statistics or raw
samples (summarised to means, SDs and sample sizes). Data outside what
the networks were trained for are refused with a message.

Not yet: fatty acid data with more than 4 tracers.

## How well it does

Tested against MixSIAR on 492 simulated datasets with known diets, and
on all nine of MixSIAR’s isotope examples:

- **Thousands of times faster.** A fit takes about half a second;
  MixSIAR’s runs on the same simulated data took a median of 20 minutes
  to almost 2 hours.
- **Nearly the same answers.** Its accuracy (CRPS) is within 2 to 5% of
  fully converged MixSIAR runs (geese-like 5.3%, wolves-like 1.9% and
  4.1%), and on about a third of datasets it is *more* accurate than
  converged MixSIAR.
- **Calibrated.** Its 95% intervals contain the true diet proportion 95
  to 97% of the time; they are 5 to 11% wider than MixSIAR’s.
- **Always an answer.** Nothing to converge: MixSIAR’s standard run
  failed its convergence check on half of the simulated datasets.
- **On MixSIAR’s examples** the two give close answers. Where they
  differ most (geese and wolves), a posterior predictive check shows
  MixSIAR’s own model does not fit those data well.
- **Weakly identified sources.** Where the data cannot pin a source
  down, MixSIARPFN tends to put a little more probability near 0 than
  MixSIAR does.

The articles *How MixSIARPFN works and how well it does*
([`vignette("performance", package = "MixSIARPFN")`](articles/performance.md))
and *MixSIARPFN on every simulated dataset*
([`vignette("simulations", package = "MixSIARPFN")`](articles/simulations.md))
give the details, and there is a vignette for each MixSIAR example:
killer whale, geese, wolves, alligator, lake, mantis shrimp, Palmyra,
snail and storm petrel.

## What is different from MixSIAR

- **Marginal posteriors only.** Each proportion and parameter gets its
  own posterior distribution, but there are no joint draws: the marginal
  means of one diet need not sum to exactly 1, and sums, differences or
  ratios of proportions cannot be computed.
- **No MCMC**, so no chain lengths, burn-in or convergence diagnostics.
- **No model checks.** Without joint draws, MixSIARPFN cannot run
  posterior predictive checks; for an important analysis, check the
  model with a MixSIAR run.

## Installation

``` r
# install.packages("remotes")
remotes::install_github("andrewcparnell/MixSIARPFN")
```

The first fit sets up a small Python environment (numpy, pandas, ONNX
Runtime) through reticulate and downloads the network it needs (about 70
MB); both are cached. No Python knowledge is needed.

## Licence and credit

GPL (\>= 3). The data loaders follow MixSIAR’s, and the example data are
MixSIAR’s killer whale, geese and wolves vignettes: Stock, B. C.,
Jackson, A. L., Ward, E. J., Parnell, A. C., Phillips, D. L. and
Semmens, B. X. (2018). Analyzing mixing systems using a new generation
of Bayesian tracer mixing models. *PeerJ* 6:e5096.

The networks: Parnell, A. (2026). MixSIARPFN networks, version 3.
Zenodo. <https://doi.org/10.5281/zenodo.24002247>

`citation("MixSIARPFN")` gives both references.
