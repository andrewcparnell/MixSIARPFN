"""Joint diet draws by stick-breaking, for networks trained with conditional diet queries.

numpy only (no PyTorch). The conditioning features are those of
:mod:`mixsiarpfn.conditional` (same definition, so a network sees here what it saw in
training): see that module and ``docs/plan_joint_diets.md``.

Each draw takes its own random order of the K sources. In pass t (t = 0 .. K - 2) every
draw asks, for the t-th source in its order, the share ``v`` of the mass the earlier
sources left, given their drawn values; ``v`` is drawn from that query's bars. The last
source takes what is left, so every draw sums to 1 exactly.

Random level assignments (which pool embedding each level gets) are handled in one of
two ways (``mode``):

- ``"per_draw"`` (default): each draw is given one of the assignments and keeps it in
  every pass. Choosing an assignment at random and then drawing from it is exactly a
  draw from the average over assignments, as for the marginals, and each draw follows
  one coherent chain of conditionals. Each query row runs under one assignment only, so
  this is about ``n_assignments`` times faster.
- ``"average"``: every pass averages each query's answer over all the assignments, as
  the marginals do (each row runs under every assignment).
"""

from __future__ import annotations

from dataclasses import replace

import numpy as np

from mixsiarpfn.runtime.bars import bar_sample

N_COND_FEATURES = 6
EPS = 1e-8


def conditional_features(cells: np.ndarray, pi: np.ndarray, mask: np.ndarray,
                         n_tracers: int) -> np.ndarray:
    """numpy version of :func:`mixsiarpfn.conditional.conditional_features`.

    Args:
        cells: [..., K, F, 7] the diet's query cells, one row per source.
        pi: [..., K] the diet's proportions so far.
        mask: [..., R, K] which sources are in each query's prefix (bool).
        n_tracers: the first ``n_tracers`` columns are tracers.

    Returns:
        [..., R, F, 6].
    """
    k = pi.shape[-1]
    n_cols = cells.shape[-2]
    m = mask.astype(pi.dtype)
    piw = pi[..., None, :] * m                                         # [..., R, K]
    has = mask.any(-1)
    mass = 1.0 - piw.sum(-1)
    c = np.exp(cells[..., 5])[..., None, :, :]                         # [..., 1, K, F]
    corr = np.sinh(cells[..., 0])[..., None, :, :]
    var_j = (cells[..., 1] ** 2 + cells[..., 3] ** 2)[..., None, :, :]
    w = piw[..., None] * c                                             # [..., R, K, F]
    b = w.sum(-2)
    a = (w * corr).sum(-2)
    var = (piw[..., None] ** 2 * var_j).sum(-2)
    tracer = np.arange(n_cols) < n_tracers
    keep = has[..., None] & tracer
    every = lambda t: np.broadcast_to(t[..., None], b.shape)           # noqa: E731
    only = lambda t: np.where(keep, t, 0.0)                            # noqa: E731
    return np.stack([
        every(np.log(np.maximum(mass, EPS))),
        every(m.sum(-1) / k),
        only(np.arcsinh(a / np.maximum(b, EPS))),
        only(np.log(np.maximum(b, EPS))),
        only(np.log(np.maximum(var, EPS))),
        every(has.astype(pi.dtype)),
    ], axis=-1)


def joint_draws(network, enc, n_diets: int, n_sources: int, n_tracers: int, n_draws: int,
                rng: np.random.Generator, n_assignments: int | None = None,
                mode: str = "per_draw") -> np.ndarray:
    """Joint draws of every diet, [n_draws, n_diets, K] (dataset 0 of ``enc``).

    Args:
        network: a :class:`mixsiarpfn.runtime.network.GeneralNetwork` trained with
            conditional diet queries (``conditional_features`` 6).
        enc: the encoded data and queries; its first ``n_diets * K`` queries are the
            diets (diet-major, source-minor), as :func:`mixsiarpfn.runtime.encode.encode`
            writes them.
        mode: ``"per_draw"`` or ``"average"`` (see the module docstring).
    """
    if mode not in ("per_draw", "average"):
        raise ValueError("mode must be 'per_draw' or 'average'")
    if getattr(network, "conditional_features", 0) < N_COND_FEATURES:
        raise ValueError("This network was trained without conditional diet queries, so "
                         "it gives marginal posteriors only (no joint draws).")
    k, d = n_sources, n_diets
    n_cols = enc.queries.shape[2]
    base = enc.queries[0, :d * k, :, :7].reshape(d, k, n_cols, 7)
    levels = enc.query_levels[:d * k].reshape(d, k, -1)
    if enc.n_levels:
        n = n_assignments or network.meta["inference"].get("level_assignments", 8)
        assignments = network.draw_assignments(enc, n, rng)
    else:
        assignments = [[]]
    borders = network.head_borders["unit"]

    # One random order per draw and diet: order[i, d] is a permutation of the sources
    order = np.argsort(rng.random((n_draws, d, k)), axis=-1)
    # per_draw: draw i keeps assignment i mod n (draws are exchangeable, so this is a
    # random choice); rows are grouped by assignment, each group run under its own
    groups = ([np.arange(n_draws)] if mode == "average" or len(assignments) == 1
              else [np.arange(a, n_draws, len(assignments)) for a in range(len(assignments))])
    pi = np.zeros((n_draws, d, k))
    taken = np.zeros((n_draws, d, k), dtype=bool)
    d_idx = np.broadcast_to(np.arange(d)[None, :], (n_draws, d)).reshape(-1)
    for t in range(k - 1):
        src = order[:, :, t].reshape(-1)                                # [R], R = n_draws * d
        cells_diet = base[d_idx]                                        # [R, K, F, 7]
        feats = conditional_features(cells_diet, pi.reshape(-1, k), taken.reshape(-1, 1, k),
                                     n_tracers)[:, 0]                   # [R, F, 6]
        cells = np.concatenate([base[d_idx, src], feats], axis=-1)      # [R, F, 13]
        row_levels = levels[d_idx, src]
        probs = np.empty((len(src), len(borders) - 1))
        for a, draws in enumerate(groups):
            rows = (draws[:, None] * d + np.arange(d)[None, :]).reshape(-1)   # rows of these draws
            step = replace(enc, queries=cells[rows][None], query_levels=row_levels[rows],
                           query_kind=np.zeros(len(rows), dtype=np.int64),
                           query_column=np.full(len(rows), -1, dtype=np.int64), query_group=None)
            use = assignments if len(groups) == 1 else [assignments[a]]
            probs[rows] = network.probabilities(step, use)["unit"][0]    # [rows, bars]
        v = bar_sample(probs, borders, 1, rng)[0]                       # [R]
        mass = 1.0 - pi.reshape(-1, k).sum(-1)
        flat_pi = pi.reshape(-1, k)
        flat_pi[np.arange(len(src)), src] = np.clip(v, 0.0, 1.0) * mass
        taken.reshape(-1, k)[np.arange(len(src)), src] = True
    last = order[:, :, k - 1].reshape(-1)
    flat_pi = pi.reshape(-1, k)
    flat_pi[np.arange(len(last)), last] = np.maximum(1.0 - flat_pi.sum(-1), 0.0)
    return pi
