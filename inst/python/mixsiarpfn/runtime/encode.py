"""The general model's encoding in numpy (the twin of
:func:`mixsiarpfn.general_net.encode_general`, which training uses).

See :mod:`mixsiarpfn.general_net` for the layout of items, columns and queries, and
:mod:`mixsiarpfn.queries` for what the queries ask; this module must produce exactly
the same arrays (``tests/test_runtime.py`` checks it).
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from mixsiarpfn.options import ModelConfig
from mixsiarpfn.queries import Queries, resid_kind, sd_kind, slope_kind

N_CELL_FEATURES = 7
TRACER, COVARIATE = 0, 1


@dataclass
class Design:
    """What the network conditions on, on the JAGS (standardised) scale, as numpy
    arrays with a leading batch axis B (the fields of
    :class:`mixsiarpfn.simulators.general.GeneralDesign`)."""

    config: ModelConfig
    mu: np.ndarray          # MU_array, [B, K, J, S]
    sig2: np.ndarray        # SIG2_array, [B, K, J, S]
    n: np.ndarray           # n_array, [B, K, S]
    frac_mu: np.ndarray     # TDF means, [B, K, J]
    frac_sig2: np.ndarray   # TDF variances, [B, K, J]
    conc: np.ndarray        # concentrations, [B, K, J] (ones without concentration dependence)
    alpha: np.ndarray       # Dirichlet hyperparameters, [B, K]
    cont: np.ndarray        # centred and scaled continuous covariates, [B, N, C]
    levels: np.ndarray      # 0-based level of each consumer for each effect, [N, E]
    n_levels: tuple = ()    # number of levels of each effect
    parents: tuple = ()     # per effect: outer level of each of its levels if nested, else None


@dataclass
class Encoded:
    """Network inputs (see :class:`mixsiarpfn.general_net.GeneralBatch`); level index -1
    means "no level of this effect"."""

    consumers: np.ndarray        # [B, N, F, 1]
    sources: np.ndarray          # [B, S, F, 7]
    queries: np.ndarray          # [B, Q, F, 7]
    column_kind: np.ndarray      # [F]
    consumer_levels: np.ndarray  # [N, E]
    source_levels: np.ndarray    # [S, E]
    query_levels: np.ndarray     # [Q, E]
    query_kind: np.ndarray       # [Q]
    query_column: np.ndarray     # [Q], -1 = none
    effect_random: tuple
    n_levels: tuple
    query_group: np.ndarray | None = None   # [Q] labels (not a network input)


def encode(x: np.ndarray, design: Design, queries: Queries, max_effects: int) -> Encoded:
    """Encode consumers ``x`` [B, N, J] (standardised scale), their design and the
    queries (numpy arrays, e.g. from :func:`mixsiarpfn.queries.standard_queries`)."""
    cfg = design.config
    batch, n_sources, n_tracers, n_src = design.mu.shape
    n_cont = cfg.n_continuous
    n_cols = n_tracers + n_cont
    n_eff = len(cfg.effects)
    n_items = n_sources * n_src
    dtype = x.dtype

    # Source items, source-major: [B, K, J, S] -> [B, K * S, J]
    def items(a: np.ndarray) -> np.ndarray:
        return a.transpose(0, 1, 3, 2).reshape(batch, n_items, n_tracers)

    def per_source(a: np.ndarray) -> np.ndarray:            # [B, K, J] -> [B, S, J]
        return np.repeat(a, n_src, axis=1)                  # like rep(each = n_src) in R

    corrected = items(design.mu + design.frac_mu[..., None])
    centre = corrected.mean(axis=1, keepdims=True)          # [B, 1, J]
    log_conc = np.log(design.conc)
    n_flat = np.broadcast_to(design.n.reshape(batch, n_items)[..., None], (batch, n_items, n_tracers))
    sig2 = items(design.sig2)
    log_alpha = np.broadcast_to(np.log(design.alpha)[..., None], (batch, n_sources, n_tracers))
    cells = np.stack([
        np.arcsinh(corrected - centre),
        np.sqrt(sig2),
        np.sqrt(sig2 / n_flat),
        per_source(np.sqrt(design.frac_sig2)),
        np.log(n_flat),
        per_source(log_conc - log_conc.mean(axis=1, keepdims=True)),
        per_source(log_alpha),
    ], axis=-1)                                             # [B, S, J, 7]
    zeros_cov = np.zeros((batch, n_items, n_cont, N_CELL_FEATURES), dtype=dtype)
    sources = np.concatenate([cells, zeros_cov], axis=2).astype(dtype)

    consumers = np.concatenate([np.arcsinh(x - centre), design.cont], axis=2)[..., None].astype(dtype)

    lev_of_item = np.tile(np.arange(n_src), n_sources)      # like rep(times = K) in R
    source_levels = np.full((n_items, n_eff), -1, dtype=np.int64)
    if cfg.source_factor is not None:
        source_levels[:, cfg.source_factor] = lev_of_item
    by_source = sources.reshape(batch, n_sources, n_src, n_cols, N_CELL_FEATURES)
    mean_item = by_source.mean(axis=2)                      # [B, K, F, 7]
    overall = mean_item.mean(axis=1, keepdims=True)         # [B, 1, F, 7]

    # Diet queries, diet-major and source-minor; candidate cells: each source's items,
    # then (index n_src) the mean over them
    diet_levels = np.asarray(queries.diet_levels, dtype=np.int64)
    diet_levels = diet_levels.reshape(diet_levels.shape[0], n_eff)
    n_diets = diet_levels.shape[0]
    d_idx = np.repeat(np.arange(n_diets), n_sources)
    k_idx = np.tile(np.arange(n_sources), n_diets)
    candidates = np.concatenate([by_source, mean_item[:, :, None]], axis=2)
    sf = cfg.source_factor
    s_idx = (np.full(n_diets, n_src) if sf is None
             else np.where(diet_levels[:, sf] >= 0, diet_levels[:, sf], n_src))
    diet_cells = candidates[:, k_idx, s_idx[d_idx]].copy()  # [B, D K, F, 7]
    if n_cont:
        values = np.asarray(queries.diet_values, dtype=dtype)
        diet_cells[:, :, n_tracers:, 0] = values[:, d_idx]

    q_cells, q_levels = [diet_cells], [diet_levels[d_idx]]
    q_kind = [np.zeros(n_diets * n_sources, dtype=np.int64)]
    q_column = [np.full(n_diets * n_sources, -1, dtype=np.int64)]

    def add(cells_q: np.ndarray, kind: int, column: int) -> None:
        q_cells.append(cells_q)
        q_levels.append(np.full((cells_q.shape[1], n_eff), -1, dtype=np.int64))
        q_kind.append(np.full(cells_q.shape[1], kind, dtype=np.int64))
        q_column.append(np.full(cells_q.shape[1], column, dtype=np.int64))

    for e in queries.sd_effects:
        add(overall, sd_kind(e), -1)
    if queries.slopes:
        for c in range(n_cont):
            for k in range(n_sources):
                add(mean_item[:, k:k + 1], slope_kind(max_effects), n_tracers + c)
    if queries.resid:
        for j in range(n_tracers):
            add(overall, resid_kind(max_effects), j)

    return Encoded(
        consumers=consumers, sources=sources,
        queries=np.concatenate(q_cells, axis=1).astype(dtype),
        column_kind=np.array([TRACER] * n_tracers + [COVARIATE] * n_cont, dtype=np.int64),
        consumer_levels=np.asarray(design.levels, dtype=np.int64).reshape(x.shape[1], n_eff),
        source_levels=source_levels, query_levels=np.concatenate(q_levels).astype(np.int64),
        query_kind=np.concatenate(q_kind), query_column=np.concatenate(q_column),
        effect_random=tuple(e.random for e in cfg.effects), n_levels=tuple(design.n_levels),
        query_group=queries.groups(n_sources, n_tracers))
