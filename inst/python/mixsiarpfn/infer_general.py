"""Inference with the general model: any MixSIAR summary-data configuration.

The user describes the model by its options, with their own column names::

    from mixsiarpfn.infer_general import read_general_csvs, fit_general

    data = read_general_csvs("mix.csv", "sources.csv", "discr.csv",
                             random=["Region", "Pack"], nested={"Pack": "Region"},
                             sources_by="Region")
    post = fit_general(data, alpha=1, error="mult")   # downloads the network once
    post.summary          # one row per (block, level, source)
    post.draws(3000)      # marginal draws

Steps: read the MixSIAR-format files; put the effects in MixSIAR's internal order
(``load_mix_data()``: a fixed effect before a random one; here also a nested effect
after the one it is nested in, which only relabels the factors); standardise exactly
as ``run_model()`` does (pooled over the consumers and every source cell; covariates
centred and scaled as R's ``scale()``); check the envelope; encode; average the
network's predictions over random level assignments.

No PyTorch: the network runs on ONNX Runtime (:mod:`mixsiarpfn.runtime`).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pandas as pd

from mixsiarpfn.data_io import (
    QUANTILES,
    EnvelopeError,
    alpha_vector,
    mixsiar_level_order,
    mixsiar_order,
    pooled_standardisation,
)
from mixsiarpfn.data_io import read_table as _read
from mixsiarpfn.options import Effect, ModelConfig
from mixsiarpfn.runtime import bars
from mixsiarpfn.runtime.encode import Design, encode


@dataclass
class GeneralData:
    """A dataset and its model options, in MixSIAR's internal order."""

    tracers: list[str]
    sources: list[str]
    effect_names: list[str]
    effects: tuple                  # of Effect
    levels: list[list]              # labels of each effect's levels, MixSIAR order
    level_index: np.ndarray         # [N, E], 0-based
    parents: tuple                  # per effect: outer level of each level, if nested
    continuous: list[str]
    cont_raw: np.ndarray            # [N, C]
    source_factor: int | None
    consumers: np.ndarray           # [N, J]
    source_mean: np.ndarray         # [K, J, S]
    source_sd: np.ndarray           # [K, J, S]
    source_n: np.ndarray            # [K, S]
    tdf_mean: np.ndarray            # [K, J]
    tdf_sd: np.ndarray              # [K, J]
    conc: np.ndarray | None         # [K, J]
    notes: list[str] = field(default_factory=list)


def read_general_csvs(consumer, sources, discrimination, fixed=(), random=(), nested=None,
                      continuous=(), sources_by=None, tracers=None) -> GeneralData:
    """Read MixSIAR input files for any summary-data configuration.

    Args:
        fixed, random: consumer columns that are fixed and random categorical effects.
        nested: ``{inner: outer}`` when one random effect is nested in the other.
        continuous: consumer columns that are continuous effects.
        sources_by: the categorical effect the sources are given by (the source file
            then has a column of that name and one row per source and level).
        tracers: tracer names (default: every Mean<tracer> column of the source file).
    """
    cons, src, tdf = _read(consumer), _read(sources), _read(discrimination)
    fixed, random, continuous = list(fixed), list(random), list(continuous)
    nested = dict(nested or {})
    problems = []
    src_tracers = [c[4:] for c in src.columns if c.startswith("Mean")]
    if not src_tracers:
        raise EnvelopeError("The source file has no Mean<tracer> columns; raw source data "
                            "are not supported yet.")
    tracers = list(tracers or src_tracers)

    # MixSIAR's internal order: a fixed effect first; for nesting, the outer effect first
    names = fixed + random
    if nested:
        (inner, outer), = nested.items()
        if inner not in random or outer not in random:
            problems.append("Nesting is only possible between two random effects.")
        else:
            names = [outer, inner]
    kinds = {n: (n in random) for n in names}
    for col in names + continuous + tracers:
        if col not in cons.columns:
            problems.append(f"The consumer file has no column '{col}'.")
    if sources_by is not None and sources_by not in names:
        problems.append(f"sources_by '{sources_by}' must be one of the categorical effects.")
    if sources_by is not None and sources_by not in src.columns:
        problems.append(f"The source file has no column '{sources_by}'.")
    for t in tracers:
        for col, frame, label in [(f"Mean{t}", src, "source"), (f"SD{t}", src, "source"),
                                  (f"Mean{t}", tdf, "discrimination"), (t, cons, "consumer")]:
            if col not in frame.columns:
                problems.append(f"The {label} file has no column '{col}'.")
    if "n" not in src.columns:
        problems.append("The source file has no 'n' column.")
    conc_cols = [f"Conc{t}" for t in tracers]
    has_conc = any(c.startswith("Conc") for c in src.columns)
    if has_conc and not all(c in src.columns for c in conc_cols):
        problems.append(f"Concentration columns must be {', '.join(conc_cols)}.")
    if problems:
        raise EnvelopeError("Cannot read these data:\n  - " + "\n  - ".join(problems))

    levels, index = [], []
    for n in names:
        labels = mixsiar_level_order(cons[n].tolist())
        lookup = {(v if not isinstance(labels[0], str) else str(v)): i for i, v in enumerate(labels)}
        levels.append(labels)
        index.append([lookup[v if not isinstance(labels[0], str) else str(v)] for v in cons[n].tolist()])
    level_index = np.array(index, dtype=int).T if names else np.zeros((len(cons), 0), dtype=int)
    parents = [None] * len(names)
    effects = [Effect(random=kinds[n]) for n in names]
    if nested:
        inner_i, outer_i = 1, 0
        par = []
        for q in range(len(levels[inner_i])):
            outs = sorted(set(level_index[level_index[:, inner_i] == q, outer_i].tolist()))
            if len(outs) != 1:
                problems.append(f"Level {levels[inner_i][q]} of {names[inner_i]} is in more than "
                                f"one level of {names[outer_i]}; it cannot be nested.")
            par.append(outs[0] if outs else 0)
        parents[inner_i] = np.array(par)
        effects[inner_i] = Effect(random=True, nested_in=outer_i)
    if problems:
        raise EnvelopeError("Cannot read these data:\n  - " + "\n  - ".join(problems))

    source_names = mixsiar_order(sorted(set(src[src.columns[0]].astype(str))))
    k, j = len(source_names), len(tracers)
    sf = None if sources_by is None else names.index(sources_by)
    s_levels = [None] if sf is None else levels[sf]
    n_s = len(s_levels)
    mean, sd, nn = np.full((k, j, n_s), np.nan), np.full((k, j, n_s), np.nan), np.full((k, n_s), np.nan)
    conc_rows = {name: [] for name in source_names} if has_conc else None
    for _, row in src.iterrows():
        a = source_names.index(str(row[src.columns[0]]))
        if sf is None:
            b = 0
        else:
            key = row[sources_by] if not isinstance(s_levels[0], str) else str(row[sources_by])
            if key not in s_levels:
                problems.append(f"Source rows for {sources_by} = {key}, which has no consumers.")
                continue
            b = s_levels.index(key)
        mean[a, :, b] = [row[f"Mean{t}"] for t in tracers]
        sd[a, :, b] = [row[f"SD{t}"] for t in tracers]
        nn[a, b] = row["n"]
        if has_conc:
            conc_rows[source_names[a]].append([row[c] for c in conc_cols])
    # Like MixSIAR's load_source_data(): a source's concentrations are the mean over its
    # rows (one row per level when sources are by factor)
    conc = (np.array([np.mean(conc_rows[name], axis=0) for name in source_names])
            if has_conc else None)
    if np.isnan(nn).any():
        problems.append("Every source needs a row for every level"
                        + (f" of {sources_by}." if sources_by else "."))
    tdf = tdf.set_index(tdf[tdf.columns[0]].astype(str))
    missing = [s for s in source_names if s not in tdf.index]
    if missing:
        problems.append(f"No discrimination values for sources: {', '.join(missing)}.")
    if problems:
        raise EnvelopeError("Cannot read these data:\n  - " + "\n  - ".join(problems))
    tdf = tdf.loc[source_names]
    tdf_sd = (tdf[[f"SD{t}" for t in tracers]].to_numpy(dtype=float)
              if all(f"SD{t}" in tdf.columns for t in tracers) else np.zeros((k, j)))
    used = set(names) | set(continuous) | set(tracers)
    notes = [f"Consumer columns not used: {', '.join(c for c in cons.columns if c not in used)}."] \
        if any(c not in used for c in cons.columns) else []
    return GeneralData(
        tracers=tracers, sources=source_names, effect_names=names, effects=tuple(effects),
        levels=levels, level_index=level_index, parents=tuple(parents), continuous=continuous,
        cont_raw=cons[continuous].to_numpy(dtype=float) if continuous else np.zeros((len(cons), 0)),
        source_factor=sf, consumers=cons[tracers].to_numpy(dtype=float), source_mean=mean,
        source_sd=sd, source_n=nn, tdf_mean=tdf[[f"Mean{t}" for t in tracers]].to_numpy(dtype=float),
        tdf_sd=tdf_sd, conc=conc, notes=notes)


def standardise(data: GeneralData) -> dict:
    """MixSIAR's ``run_model()`` standardisation: per tracer, the pooled mean and SD of the
    consumers and ``n`` notional observations from every (source, level) cell;
    covariates centred and scaled (SD with N - 1)."""
    k, j, s = data.source_mean.shape
    f64 = lambda a: np.array(a, dtype=np.float64)                   # noqa: E731 (copies)
    cells = lambda a: f64(a).transpose(0, 2, 1).reshape(k * s, j)   # noqa: E731 [K, J, S] -> [K S, J]
    mean_pool, sd_pool = pooled_standardisation(f64(data.consumers), cells(data.source_mean),
                                                cells(data.source_sd), f64(data.source_n).reshape(-1))
    cont = f64(data.cont_raw)
    if cont.shape[1] and len(cont) > 1:
        centre, scale = cont.mean(axis=0), cont.std(axis=0, ddof=1)   # R's scale(): SD with N - 1
    else:
        centre, scale = np.zeros(cont.shape[1]), np.ones(cont.shape[1])
    return {
        "X_iso": (f64(data.consumers) - mean_pool) / sd_pool,
        "MU_array": (f64(data.source_mean) - mean_pool[None, :, None]) / sd_pool[None, :, None],
        "SIG2_array": f64(data.source_sd) ** 2 / sd_pool[None, :, None] ** 2,
        "frac_mu": f64(data.tdf_mean) / sd_pool,
        "frac_sig2": f64(data.tdf_sd) ** 2 / sd_pool ** 2,
        "cont": (cont - centre) / scale, "cont_centre": centre, "cont_scale": scale,
        "mean_pool": mean_pool, "sd_pool": sd_pool,
    }


def check_general_envelope(data: GeneralData, alpha: np.ndarray, error: str, envelope: dict,
                           x_std: np.ndarray, x_max: float, cont_std: np.ndarray | None = None,
                           cont_range: tuple | None = None) -> None:
    """Raise EnvelopeError listing every way the data or model leave the envelope
    (including covariate values further from their mean than ``cont_range``, in SDs:
    the network was trained on standard normal covariates)."""
    problems = []
    k, j, _ = data.source_mean.shape
    n = data.consumers.shape[0]

    def outside(value, key, label):
        lo, hi = envelope[key]
        if not lo <= value <= hi:
            problems.append(f"{label} is {value}; supported range is {lo} to {hi}.")

    outside(k, "n_sources", "Number of sources")
    outside(j, "n_tracers", "Number of tracers")
    outside(n, "total_n", "Number of consumers")
    if len(data.effects) > 2:
        problems.append("At most 2 categorical effects are supported (as in MixSIAR).")
    if len(data.continuous) > envelope["continuous_effects"][1]:
        problems.append("At most 1 continuous effect is supported (as in MixSIAR).")
    if error != "process" and n < 2:
        problems.append("With one consumer MixSIAR (and this tool) needs Process-only error.")
    if error == "process" and data.source_factor is not None:
        problems.append("Process-only error with sources by factor cannot be fitted: MixSIAR's "
                        "own model for this does not compile.")
    nested = any(e.nested_in is not None for e in data.effects)
    for e, name in enumerate(data.effect_names):
        n_lev = len(data.levels[e])
        sizes = np.bincount(data.level_index[:, e], minlength=n_lev)
        if nested and e == 0:
            outside(n_lev, "n_outer", f"Number of levels of {name}")
        elif nested and e == 1:
            if n_lev > envelope["max_inner"]:
                problems.append(f"Number of levels of {name} is {n_lev}; at most "
                                f"{envelope['max_inner']} are supported.")
            per = np.bincount(data.parents[1], minlength=len(data.levels[0]))
            lo, hi = envelope["inner_per_outer"]
            if per.min() < lo or per.max() > hi:
                problems.append(f"Levels of {name} within each level of {data.effect_names[0]} "
                                f"must be {lo} to {hi}.")
        elif len(data.effects) == 2:
            outside(n_lev, "n_levels_crossed", f"Number of levels of {name}")
        else:
            outside(n_lev, "n_levels", f"Number of levels of {name}")
        lo, hi = envelope["level_n"]
        if sizes.min() < lo or sizes.max() > hi:
            problems.append(f"Consumers per level of {name} must be {lo} to {hi}.")
        if not data.effects[e].random and error != "process" and len(data.effects) == 1 \
                and sizes.max() == 1:
            problems.append(f"One consumer per level of the fixed effect {name} needs Process-only "
                            "error (as in MixSIAR).")
    for label, values in {"consumer values": data.consumers, "source means": data.source_mean,
                          "source SDs": data.source_sd, "source n": data.source_n,
                          "TDF means": data.tdf_mean, "TDF SDs": data.tdf_sd, "alpha": alpha,
                          "covariates": data.cont_raw}.items():
        if not np.isfinite(values).all():
            problems.append(f"Some {label} are missing or not finite.")
    if (data.source_sd <= 0).any():
        problems.append("Every source SD must be positive.")
    if (data.tdf_sd < 0).any():
        problems.append("TDF SDs cannot be negative.")
    lo, hi = envelope["source_n"]
    if ((data.source_n < lo) | (data.source_n > hi)).any() or (data.source_n != np.round(data.source_n)).any():
        problems.append(f"Source sample sizes n must be whole numbers from {lo} to {hi}.")
    if data.conc is not None:
        if (data.conc <= 0).any():
            problems.append("Every concentration must be positive.")
        elif (data.conc.max(0) / data.conc.min(0) > envelope["conc_max_ratio"]).any():
            problems.append(f"Concentrations within a tracer vary more than "
                            f"{envelope['conc_max_ratio']:g}-fold.")
    a_lo, a_hi = envelope["alpha"]
    if ((alpha < a_lo) | (alpha > a_hi)).any():
        problems.append(f"alpha must be {a_lo} to {a_hi} for every source.")
    if cont_std is not None and cont_range is not None and cont_std.size and np.isfinite(cont_std).all():
        for c, name in enumerate(data.continuous):
            z = cont_std[:, c]
            if z.min() < cont_range[0] or z.max() > cont_range[1]:
                problems.append(f"Some values of {name} are more than {cont_range[1]:g} SDs from "
                                "its mean; the networks are trained on covariates without such "
                                "extremes (consider transforming it, for example to logs).")
    if np.isfinite(x_std).all() and np.abs(x_std).max() > x_max:
        problems.append("Some consumers are extremely far from the sources (more than "
                        f"{x_max:g} pooled SDs); check the data.")
    if problems:
        raise EnvelopeError("These data or model options are outside the supported envelope:\n  - "
                            + "\n  - ".join(problems))


@dataclass
class GeneralPosterior:
    """Marginal posteriors of the diets (``summary``: one row per block, level and
    source) and of the parameters (``parameters``: one row per parameter).

    ``summary`` blocks: ``global``; each effect, by level; ``<covariate> (continuous)``
    at covariate values (original units); ``<covariate> by <effect>``, the covariate
    curve within each level of an effect; ``consumer``, each distinct combination of
    levels and covariate values among the consumers (MixSIAR's ``p.ind``); and
    ``combination``, combinations asked for. ``combinations`` describes every
    ``<covariate> by <effect>``, ``consumer`` and ``combination`` level (one column per
    effect and covariate); ``consumers`` gives, for each consumer (row of the consumer
    file), the block and level of its diet.

    ``parameters`` rows: ``sd`` (each random effect's SD, ``fac.sig``), ``slope (CLR)``
    (each covariate's slope per source, on the centred log-ratio scale, per unit of
    the covariate in its original units) and ``resid.prop`` (per tracer, Residual *
    Process only).

    Every output is a marginal posterior: there are no joint draws (see
    :meth:`draws`).
    """

    summary: pd.DataFrame
    probs: np.ndarray               # bar probabilities of the diets, [rows of summary, bars]
    borders: np.ndarray
    notes: list[str]
    parameters: pd.DataFrame = field(default_factory=pd.DataFrame)
    parameter_probs: list = field(default_factory=list)      # one [bars] array per row
    parameter_borders: list = field(default_factory=list)    # the borders for each row
    combinations: pd.DataFrame = field(default_factory=pd.DataFrame)
    consumers: pd.DataFrame = field(default_factory=pd.DataFrame)
    # Joint draws of every diet (block, level, draw, source, value; each draw of a diet
    # sums to 1), when asked for and the network has conditional diet queries
    joint: pd.DataFrame | None = None

    def draws(self, n: int = 3000, seed: int | None = None) -> pd.DataFrame:
        """Independent draws from each diet row's marginal posterior, in long format
        (the summary's block, level and source columns plus ``draw`` and ``value``).

        These are *marginal* draws: draws with the same number in different rows are
        not joint draws and proportions do not sum to 1. Use them for per-proportion
        summaries and plots, not for sums, differences or ratios of proportions.
        """
        values = bars.bar_sample(self.probs, self.borders, n, np.random.default_rng(seed))
        keys = self.summary[["block", "level", "source"]]
        out = keys.loc[keys.index.repeat(n)].reset_index(drop=True)   # each row n times
        out["draw"] = np.tile(np.arange(1, n + 1), len(keys))
        out["value"] = values.T.reshape(-1)
        return out

    def parameter_draws(self, n: int = 3000, seed: int | None = None) -> pd.DataFrame:
        """Independent draws from each parameter's marginal posterior, in long format
        (``parameter``, ``label``, ``draw``, ``value``); marginal, as :meth:`draws`."""
        rng = np.random.default_rng(seed)
        frames = []
        for (_, row), pr, b in zip(self.parameters.iterrows(), self.parameter_probs,
                                   self.parameter_borders):
            frames.append(pd.DataFrame({"parameter": row.parameter, "label": row.label,
                                        "draw": np.arange(1, n + 1),
                                        "value": bars.bar_sample(pr[None], b, n, rng)[:, 0]}))
        return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame(
            columns=["parameter", "label", "draw", "value"])


def _summarise(probs: np.ndarray, borders: np.ndarray) -> dict:
    mean, sd = bars.bar_mean_sd(probs, borders)
    return {"mean": mean, "sd": sd,
            **{f"q{q * 100:g}": bars.bar_quantile(probs, borders, q) for q in QUANTILES}}


def _profile_label(names: list[str], values: list) -> str:
    """e.g. "Region=2; Length=51.3"."""
    parts = []
    for name, v in zip(names, values):
        if v is None or (isinstance(v, float) and np.isnan(v)):
            continue
        parts.append(f"{name}={v:.6g}" if isinstance(v, (float, np.floating)) else f"{name}={v}")
    return "; ".join(parts)


def _unique_labels(labels: list[str]) -> list[str]:
    """Make repeated labels distinct ("x", "x (2)", ...): covariate values that agree to
    the printed precision would otherwise share a label."""
    seen, out = {}, []
    for lab in labels:
        seen[lab] = seen.get(lab, 0) + 1
        out.append(lab if seen[lab] == 1 else f"{lab} ({seen[lab]})")
    return out


def fit_general(data: GeneralData, alpha=1, error: str = "mult", network=None,
                seed: int = 1, n_assignments: int | None = None, covariate_values=None,
                n_grid: int = 25, covariate_by: str | None = None, consumer_diets: bool = True,
                combinations: pd.DataFrame | None = None, joint_draws: int = 0) -> GeneralPosterior:
    """Marginal posteriors of every diet and parameter (see :class:`GeneralPosterior`).

    Args:
        data: from :func:`read_general_csvs`.
        alpha: Dirichlet prior; a number (all sources), a vector in ``data.sources``
            order, or a dict by source name. MixSIAR's default is 1.
        error: ``mult`` (Residual * Process), ``resid`` (Residual only) or ``process``.
        network: a loaded network (:class:`mixsiarpfn.runtime.network.GeneralNetwork`,
            or anything with its ``meta``, ``head_borders`` and ``predict``), or the
            path of an ``.onnx`` file; by default the released network for ``error``,
            downloaded on first use.
        seed: seed for the random level assignments averaged over.
        n_assignments: how many level assignments to average (default: the network's).
        covariate_values: dict of covariate name -> values (original units) to report
            the diet at; by default ``n_grid`` values evenly over the observed range.
        n_grid: number of default covariate values.
        covariate_by: an effect name: also report each covariate's curve within every
            level of this effect (block ``<covariate> by <effect>``).
        consumer_diets: report the diet of each distinct combination of levels and
            covariate values among the consumers (block ``consumer``), when there is
            a covariate or two or more effects (otherwise each consumer's diet is
            already a level row; ``consumers`` says which).
        combinations: further diets to report (block ``combination``): one row each,
            with columns named after effects (level labels; missing means no level)
            and covariates (original units; missing means the covariate's mean).
        joint_draws: also draw this many joint draws of every diet (``joint``), by
            stick-breaking with a random source order per draw
            (:mod:`mixsiarpfn.runtime.joint`); each draw sums to 1. Needs a network
            trained with conditional diet queries.

    Raises:
        EnvelopeError: if the data, prior, model options or requested covariate values
            are outside the envelope.
    """
    from mixsiarpfn.queries import (
        COMBINATION,
        COVARIATE,
        GLOBAL,
        LEVEL,
        RESID,
        SD,
        SLOPE,
        head_of_kind,
        standard_queries,
    )
    from mixsiarpfn.runtime.weights import load_network

    if network is None or isinstance(network, (str, Path)):
        network = load_network(error, network)
    if network.meta["error"] != error:
        raise EnvelopeError(f"This network is for '{network.meta['error']}' error, not '{error}'.")
    alpha_vec = alpha_vector(alpha, data.sources)
    std = standardise(data)
    ecfg = network.meta["encoding"]
    lo, hi = network.meta["queries"]["covariate_range"]
    check_general_envelope(data, alpha_vec, error, network.meta["envelope"], std["X_iso"],
                           ecfg["x_max"], std["cont"], (lo, hi))
    k, j, _ = data.source_mean.shape
    n_eff, n_cont = len(data.effects), len(data.continuous)
    centre, scale = std["cont_centre"], std["cont_scale"]
    to_scaled = lambda c, v: (np.asarray(v, dtype=np.float64) - centre[c]) / scale[c]  # noqa: E731
    to_raw = lambda c, z: float(z * scale[c] + centre[c])                               # noqa: E731

    # Covariate values to report the diet at (scaled), checked against the envelope
    grids = []
    for c, name in enumerate(data.continuous):
        if covariate_values is not None and name in covariate_values:
            z = to_scaled(c, covariate_values[name])
            if (z < lo).any() or (z > hi).any():
                raise EnvelopeError(f"Values of {name} must be within {lo:g} to {hi:g} SDs of its "
                                    f"mean: {to_raw(c, lo):.4g} to {to_raw(c, hi):.4g}.")
        else:
            z = np.linspace(std["cont"][:, c].min(), std["cont"][:, c].max(), n_grid)
        grids.append(np.atleast_1d(z))

    # Combinations: rows of (levels [E], values [C], block, label)
    combo = []
    names = list(data.effect_names) + list(data.continuous)
    if covariate_by is not None:
        if covariate_by not in data.effect_names:
            raise EnvelopeError(f"covariate_by: '{covariate_by}' is not one of the effects "
                                f"({', '.join(data.effect_names) or 'none'}).")
        e = data.effect_names.index(covariate_by)
        for c, name in enumerate(data.continuous):
            for lev, label in enumerate(data.levels[e]):
                for z in grids[c]:
                    r = np.full(n_eff, -1)
                    r[e] = lev
                    v = np.zeros(n_cont)
                    v[c] = z
                    label_rz = f"{covariate_by}={label}; {name}={to_raw(c, z):.6g}"
                    combo.append((r, v, f"{name} by {covariate_by}", label_rz))
    outer = {eff.nested_in for eff in data.effects if eff.nested_in is not None}
    n_parts = len([e for e in range(n_eff) if e not in outer]) + n_cont
    profile_of = None
    # A covariate's consumers each have their own value, so their diets are new rows
    if consumer_diets and (n_parts >= 2 or n_cont):
        profiles = np.concatenate([data.level_index.astype(np.float64), std["cont"]], axis=1)
        uniq, profile_of = np.unique(profiles, axis=0, return_inverse=True)
        first = len(combo)
        for u in uniq:
            lev = u[:n_eff].astype(np.int64)
            label = _profile_label(names, [data.levels[e][lev[e]] for e in range(n_eff)]
                                   + [to_raw(c, u[n_eff + c]) for c in range(n_cont)])
            combo.append((lev, u[n_eff:], "consumer", label))
        profile_of = first + np.asarray(profile_of).reshape(-1)
    if combinations is not None:
        for _, row in combinations.iterrows():
            r, v = np.full(n_eff, -1), np.zeros(n_cont)
            for e, name in enumerate(data.effect_names):
                if name in row and not pd.isna(row[name]):
                    labels = [str(x) for x in data.levels[e]]
                    value = row[name]
                    # A column with missing values reads whole numbers as floats (2.0)
                    if isinstance(value, float) and value.is_integer():
                        value = int(value)
                    if str(value) not in labels:
                        raise EnvelopeError(f"combinations: {name} has no level '{value}'.")
                    r[e] = labels.index(str(value))
            for c, name in enumerate(data.continuous):
                if name in row and not pd.isna(row[name]):
                    v[c] = to_scaled(c, row[name])
                    if not lo <= v[c] <= hi:
                        raise EnvelopeError(f"combinations: {name} = {row[name]} is more than "
                                            f"{hi:g} SDs from its mean.")
            label = _profile_label(names, [data.levels[e][r[e]] if r[e] >= 0 else None
                                           for e in range(n_eff)]
                                   + [float(row[nm]) if nm in row and not pd.isna(row[nm]) else None
                                      for nm in data.continuous])
            combo.append((r, v, "combination", label))

    # Labels must identify rows within a block
    for b in dict.fromkeys(c[2] for c in combo):
        idx = [i for i, c in enumerate(combo) if c[2] == b]
        for i, lab in zip(idx, _unique_labels([combo[i][3] for i in idx])):
            combo[i] = (*combo[i][:3], lab)
    one = lambda a: np.asarray(a, dtype=np.float64)[None]            # noqa: E731 (batch of 1)
    config = ModelConfig(effects=data.effects, n_continuous=n_cont, error=error,
                         conc_dep=data.conc is not None, source_factor=data.source_factor)
    design = Design(
        config=config, mu=one(std["MU_array"]), sig2=one(std["SIG2_array"]), n=one(data.source_n),
        frac_mu=one(std["frac_mu"]), frac_sig2=one(std["frac_sig2"]),
        conc=one(data.conc if data.conc is not None else np.ones((k, j))),
        alpha=one(alpha_vec), cont=one(std["cont"]), levels=data.level_index,
        n_levels=tuple(len(lv) for lv in data.levels), parents=data.parents)
    comb_arg = None
    if combo:
        comb_arg = (np.stack([c[0] for c in combo]), np.stack([c[1] for c in combo]).reshape(len(combo), n_cont))
    queries = standard_queries(data.effects, design.n_levels, data.parents, 1, n_cont, grids,
                               comb_arg, error)
    enc = encode(one(std["X_iso"]), design, queries, network.meta["model"]["max_effects"])
    probs = {h: v[0] for h, v in network.predict(enc, n_assignments, np.random.default_rng(seed)).items()}
    head = head_of_kind(enc.query_kind, network.meta["model"]["max_effects"])
    groups = enc.query_group

    # Diets: block and level of each diet, in query order
    blocks = [("global", "all")]
    for e, name in enumerate(data.effect_names):
        blocks += [(name, lvl) for lvl in data.levels[e]]
    for c, name in enumerate(data.continuous):
        blocks += [(f"{name} (continuous)", to_raw(c, z)) for z in grids[c]]
    blocks += [(b, label) for _, _, b, label in combo]
    diet = np.isin(groups, [GLOBAL, LEVEL, COVARIATE, COMBINATION])
    diet_probs = probs["unit"][diet]
    borders = network.head_borders["unit"]
    summary = pd.DataFrame({"block": [b for b, _ in blocks for _ in range(k)],
                            "level": [lv for _, lv in blocks for _ in range(k)],
                            "source": data.sources * len(blocks)})
    for col, values in _summarise(diet_probs, borders).items():
        summary[col] = values

    # Parameters
    labels = []
    labels += [("sd", data.effect_names[e]) for e in queries.sd_effects]
    if queries.slopes:
        labels += [("slope (CLR)", f"{name}: {src}") for name in data.continuous for src in data.sources]
    if queries.resid:
        labels += [("resid.prop", t) for t in data.tracers]
    par_idx = np.flatnonzero(np.isin(groups, [SD, SLOPE, RESID]))
    par_probs, par_borders, rows = [], [], []
    for (parameter, label), q in zip(labels, par_idx):
        h = ("unit", "scale", "slope")[head[q]]
        b = network.head_borders[h].astype(np.float64)
        if parameter == "slope (CLR)":
            # Per unit of the covariate in its original units (trained per scaled unit)
            c = data.continuous.index(label.split(": ")[0])
            b = b / scale[c]
        par_probs.append(probs[h][q])
        par_borders.append(b)
        rows.append({"parameter": parameter, "label": label,
                     **{col: v[()] for col, v in _summarise(probs[h][q], b).items()}})
    parameters = pd.DataFrame(rows, columns=["parameter", "label", "mean", "sd"]
                              + [f"q{q * 100:g}" for q in QUANTILES])

    comb_rows = []
    for r, v, b, label in combo:
        row = {"block": b, "level": label}
        for e, name in enumerate(data.effect_names):
            row[name] = data.levels[e][r[e]] if r[e] >= 0 else None
        for c, name in enumerate(data.continuous):
            row[name] = to_raw(c, v[c])
        comb_rows.append(row)
    combos = pd.DataFrame(comb_rows)

    # Each consumer's diet row
    if profile_of is not None:
        cons = [(combo[i][2], combo[i][3]) for i in profile_of]
    elif n_cont:
        cons = [(None, None)] * data.consumers.shape[0]               # consumer_diets=False
    elif n_eff:
        e = next(e for e in range(n_eff) if e not in outer)
        cons = [(data.effect_names[e], data.levels[e][lv]) for lv in data.level_index[:, e]]
    else:
        cons = [("global", "all")] * data.consumers.shape[0]
    consumers = pd.DataFrame({"consumer": np.arange(1, data.consumers.shape[0] + 1),
                              "block": [b for b, _ in cons], "level": [lv for _, lv in cons]})
    joint = None
    if joint_draws:
        # Joint draws by stick-breaking (mixsiarpfn.runtime.joint); needs a network
        # trained with conditional diet queries
        from mixsiarpfn.runtime.joint import joint_draws as draw_joint
        pi = draw_joint(network, enc, len(blocks), k, j, joint_draws,
                        np.random.default_rng(seed + 1), n_assignments)    # [n, D, K]
        n_d = len(blocks)
        joint = pd.DataFrame({
            "block": np.repeat([b for b, _ in blocks], k)[None].repeat(joint_draws, 0).reshape(-1),
            "level": np.repeat(np.array([lv for _, lv in blocks], dtype=object), k)[None]
                     .repeat(joint_draws, 0).reshape(-1),
            "draw": np.repeat(np.arange(1, joint_draws + 1), n_d * k),
            "source": np.tile(np.array(data.sources, dtype=object), joint_draws * n_d),
            "value": pi.reshape(-1)})
    return GeneralPosterior(summary=summary, probs=diet_probs, borders=borders, notes=list(data.notes),
                            parameters=parameters, parameter_probs=par_probs,
                            parameter_borders=par_borders, combinations=combos, consumers=consumers,
                            joint=joint)
