# How MixSIARPFN works and how well it does

MixSIARPFN replaces MixSIAR’s MCMC with a neural network that has
learned, from millions of simulated datasets, what MixSIAR’s posterior
looks like. This article explains what that network is and how it was
trained, and then tests it. On 450 simulated datasets with known true
diets, MixSIARPFN is compared with fully converged MixSIAR runs on the
same data.

**In short:**

- MixSIARPFN’s accuracy (CRPS) is +5.3% against MixSIAR on geese-like
  data, +1.9% on wolves-like data with diets from MixSIAR’s prior and
  +4.1% on realistic wolves-like data: 2 to 5% behind.
- Its 95% intervals are calibrated, but 5– 11% wider than MixSIAR’s.
- A fit takes under a second; MixSIAR’s runs here took a median of 20 to
  103 minutes.

## What the network is

### The idea

MixSIAR defines a full Bayesian model: priors on the diet proportions,
the random-effect SDs and the error terms, and a likelihood for the
consumers’ tracer values given the sources. Anything we can write down
as a prior and a likelihood we can also *simulate from*: draw parameters
from the prior, then draw a dataset from the likelihood. A **prior-data
fitted network** (PFN; Müller et al. 2022) is trained on millions of
such pairs. It is shown the dataset and asked for the parameters that
made it. Trained this way, with a proper scoring rule, its best possible
answer is the Bayesian posterior itself. It learns to do Bayesian
inference for MixSIAR’s model in general, rather than fitting one
dataset.

At use, the network reads your data once and returns the posterior, with
no chains to run. Two consequences:

- **Marginal posteriors only.** The network answers one question at a
  time (“what is the posterior of Pack 3’s proportion of deer?”), so
  each proportion gets its own posterior. There are no joint draws.
- **It is an approximation.** How close it gets to the true posterior
  depends on how well it was trained. That is what the rest of this
  article measures.

### Its structure

The network is a transformer in the style of TabPFN (Hollmann et
al. 2025), with about 17 million parameters. It sees each dataset as a
table:

- **Columns** are the tracers (and any continuous covariate).
- **Rows** are of three kinds:
  - **consumers:** one row per consumer, holding its tracer values;
  - **sources:** one row per source (per source-factor level), holding
    seven numbers per tracer: the mean corrected by the discrimination
    factor, the source SD, the standard error, the discrimination SD,
    the sample size, the concentration and the Dirichlet prior α;
  - **queries:** one row per quantity wanted, such as a global
    proportion, a level’s proportion, an effect’s SD or `resid.prop`.
    Each carries a tag saying which.
- **Factor levels** get an embedding drawn at random from a pool, so the
  network treats levels as exchangeable, as MixSIAR’s model does. At
  use, the answer is averaged over 8 random draws.

The body is 8 identical layers. In each, the tracer cells of every row
exchange information, then consumers and sources exchange information
with each other while queries read from them, then a small feed-forward
network updates every cell. Each cell is 384 numbers wide. Because rows
have no positions, the answer does not depend on the order of consumers
or sources.

The output is a **bar distribution** for each query: a histogram over
1,000 bars spanning \[0, 1\] for proportions (finer near 0 and 1), and
over \[0, 20\] for SDs and `resid.prop`. It can take any shape,
including the skewed and bimodal posteriors mixing models often give.

### Training

There are three networks, one for each error structure (Residual \*
Process, Residual only, Process only). Each was trained for 450,000
steps on two NVIDIA L40S GPUs (about two days), with a fresh batch of
simulated datasets at every step, so it never sees the same dataset
twice. The simulations cover everything MixSIARPFN supports:

- 2 to 8 sources and 1 to 4 tracers;
- up to two categorical effects (fixed or random, crossed or nested) and
  one continuous effect;
- sources given by a factor, and concentration dependence;
- 1 to 1,000 consumers.

In version 3, the Residual \* Process network was trained for a further
150,000 steps on a second task as well: predicting a diet one source at
a time, each source’s share of what the earlier sources leave. This
teaches the network how sources trade off against each other (where the
data fix the sum of two sources but not how it splits), and it made the
network’s ordinary marginal posteriors more accurate too, by 1 to 2% on
the wolves-like data below. The other two networks are version 2’s.

Data outside this range are refused with a message. The networks are on
Zenodo
([doi:10.5281/zenodo.24002247](https://doi.org/10.5281/zenodo.24002247))
and are downloaded on first use.

## How it was tested

The test uses datasets where the true diet is known:

1.  **The datasets.** Each set copies a MixSIAR example’s design exactly
    (its sources, discrimination factors, concentrations, groups and
    consumers per group) and simulates new consumers from MixSIAR’s
    model. Of 200,000 simulations, the ones whose spread of consumers
    looks most like the real data are kept. There are three sets of 150
    datasets each:
    - **geese-like:** a fixed effect of group, concentration dependence,
      Residual only error;
    - **wolves-like, diets from the prior:** random region and pack
      effects, pack nested in region, sources by region, Residual \*
      Process error. MixSIAR’s prior on the random-effect SDs (uniform
      on 0 to 20) makes many packs’ diets almost entirely one source;
    - **realistic wolves-like:** the same design with SDs between 0.2
      and 2, so diets vary between packs as they do in real data.
2.  **The fits.** MixSIAR fitted every dataset at its “normal” and
    “long” run lengths, three chains each. A run counts as converged
    when its largest Gelman–Rubin diagnostic is at most 1.1. MixSIARPFN
    fitted the same files.
3.  **The comparison.** On the datasets where MixSIAR’s long run
    converged, every diet proportion (global and per group) is scored
    against its true value:
    - **CRPS** (continuous ranked probability score): the main measure.
      It rewards a posterior that is both centred on the truth and tight
      around it. Lower is better, and it is in the units of the
      proportion;
    - **95% coverage:** how often the 95% interval contains the truth;
    - **width** of the 95% interval;
    - **RMSE** of the posterior mean.

A converged MixSIAR run is, up to Monte Carlo error, the exact
posterior. So it is the best any method can do with these data, and the
gap to it is the network’s approximation error.

## Results

### Accuracy against MixSIAR

![](performance_files/figure-html/gap-plot-1.png)

Each point is MixSIARPFN’s mean CRPS relative to MixSIAR’s on the same
datasets, with a bootstrap 95% interval over datasets. 0 means as
accurate as MixSIAR; the shaded band is within 5%. The released networks
(v3) are +1.9% to +5.3% behind. The first release (v1) was +8% to +14%
behind. Training further on the most common designs (q3) did not help.
v3 differs from v2 only in the Residual \* Process network (see
Training), so for the geese-like data, which use Residual only error, v2
and v3 are the same.

| Data | Datasets | Method | 95% coverage | Width | RMSE | CRPS |
|:---|:---|:---|---:|---:|---:|---:|
| Geese-like | 144 | MixSIARPFN | 0.955 | 0.349 | 0.127 | 0.0568 |
|  |  | MixSIAR long | 0.936 | 0.313 | 0.123 | 0.0539 |
| Wolves-like, diets from the prior | 58 | MixSIARPFN | 0.971 | 0.415 | 0.151 | 0.0580 |
|  |  | MixSIAR long | 0.969 | 0.396 | 0.149 | 0.0570 |
| Realistic wolves-like | 90 | MixSIARPFN | 0.973 | 0.445 | 0.130 | 0.0631 |
|  |  | MixSIAR long | 0.963 | 0.419 | 0.126 | 0.0606 |

Over every diet proportion, on the datasets where MixSIAR’s long run
converged.

MixSIARPFN’s intervals contain the truth at least as often as they
should; it is calibrated but a little cautious. Its posterior means are
nearly as close to the truth as MixSIAR’s (RMSE), so much of the CRPS
gap comes from its wider intervals.

### Dataset by dataset

![](performance_files/figure-html/scatter-1.png)

Each point is one dataset (its mean CRPS over all proportions). Points
above the line are datasets where MixSIAR did better. The two track each
other closely, and MixSIARPFN is better on 34–36% of datasets. On half
the datasets its CRPS is within 4% of MixSIAR’s. It falls furthest
behind where MixSIAR is most precise (the lower left of the geese-like
panel): on the worst 6 of 292 datasets its CRPS is close to twice
MixSIAR’s.

### Posterior means against the truth

![](performance_files/figure-html/truth-1.png)

Every diet proportion in every dataset. The two methods make the same
kind of errors: both pull proportions the data cannot pin down towards
the middle, as the prior says they should.

### Interval widths

![](performance_files/figure-html/widths-1.png)

Most points sit a little above the line: MixSIARPFN’s intervals are
typically 5–11% wider. This is the main thing that separates it from
MixSIAR. The network is unsure of its own approximation and hedges,
which keeps it calibrated.

### Where the gap comes from

![](performance_files/figure-html/by-truth-1.png)

The gap is spread across all true values, not confined to one range.
Proportions near 0 are a known weak spot: where the data cannot rule a
source out, MixSIARPFN tends to put more probability close to 0 than
MixSIAR does (see the geese example).

### MixSIAR’s own convergence and run time

| Data | Converged, normal | Converged, long | Minutes, normal | Minutes, long |
|:---|---:|---:|---:|---:|
| Geese-like | 0.79 | 0.96 | 31 | 103 |
| Wolves-like, diets from the prior | 0.25 | 0.39 | 20 | 61 |
| Realistic wolves-like | 0.49 | 0.60 | 20 | 59 |

Share of MixSIAR runs that converged, and median run time (three
chains).

The comparison above uses only datasets where MixSIAR’s long run
converged, which is the fairest test for MixSIAR. In practice MixSIAR’s
“normal” run often fails to converge on data like these, especially with
nested random effects. MixSIARPFN takes under a second for any of them
and has nothing to converge.

Against MixSIAR’s normal run, on the datasets where it converged:

| Data | Datasets | MixSIARPFN CRPS relative to MixSIAR normal |
|:---|---:|:---|
| Geese-like | 114 | +1.9% |
| Wolves-like, diets from the prior | 27 | +3.5% |
| Realistic wolves-like | 51 | +4.6% |

## What this means for use

- For data like MixSIAR’s examples, MixSIARPFN gives posteriors close to
  a fully converged MixSIAR run, with intervals a little wider, in a
  second instead of hours. That makes it practical to fit many models,
  many datasets or many what-if versions of one.
- Its intervals are honest: they cover the truth at least as often as
  they claim.
- Being marginal-only, it cannot give posteriors of sums or differences
  of proportions, or posterior predictive checks of the model. For a
  final analysis, or where small differences in a proportion matter,
  confirm with a MixSIAR run.

## References

- Hollmann, N., Müller, S., Purucker, L., et al. (2025). Accurate
  predictions on small data with a tabular foundation model. *Nature*
  637, 319–326.
- Müller, S., Hollmann, N., Pineda Arango, S., Grabocka, J. and
  Hutter, F. (2022). Transformers can do Bayesian inference. *ICLR*.
- Stock, B. C., Jackson, A. L., Ward, E. J., Parnell, A. C.,
  Phillips, D. L. and Semmens, B. X. (2018). Analyzing mixing systems
  using a new generation of Bayesian tracer mixing models. *PeerJ*
  6:e5096.

The simulation study’s results are in
`system.file("extdata", "simstudy.rds", package = "MixSIARPFN")`;
Datasets a\_*: seed 2026 (50 per set); b\_*: seed 2027 (100 per set).
MixSIARPFN v3 = the released networks; v3 changed only the Residual \*
Process network, so geese’s v3 rows equal v2’s.
