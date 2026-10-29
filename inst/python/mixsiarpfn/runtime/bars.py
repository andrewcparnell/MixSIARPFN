"""Summaries of a bar distribution in numpy (the twins of the functions in
:mod:`mixsiarpfn.model`). ``probs`` are bar probabilities over the last axis, which
sum to 1; within a bar the density is uniform."""

from __future__ import annotations

import numpy as np


def make_borders(n_uniform: int, n_logit: int, logit_limit: float) -> np.ndarray:
    """Bar borders on [0, 1]: uniform spacing mixed with logit spacing (as
    :func:`mixsiarpfn.model.make_borders`, float32)."""
    uniform = np.linspace(0.0, 1.0, n_uniform + 1)
    logit = 1 / (1 + np.exp(-np.linspace(-logit_limit, logit_limit, n_logit)))
    return np.unique(np.concatenate([uniform, logit])).astype(np.float32)   # unique() also sorts


def softmax(logits: np.ndarray) -> np.ndarray:
    z = logits.astype(np.float64)
    z = np.exp(z - z.max(axis=-1, keepdims=True))
    return z / z.sum(axis=-1, keepdims=True)


def bar_mean_sd(probs: np.ndarray, borders: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Mean and SD of each marginal."""
    lo, hi = borders[:-1].astype(np.float64), borders[1:].astype(np.float64)
    mean = (probs * (lo + hi) / 2).sum(-1)
    second = (probs * (lo**2 + lo * hi + hi**2) / 3).sum(-1)
    return mean, np.sqrt(np.clip(second - mean**2, 0.0, None))


def bar_cdf(probs: np.ndarray, borders: np.ndarray, y: np.ndarray) -> np.ndarray:
    """P(p <= y) for one marginal (``probs`` [bars]) at each value of ``y``."""
    cum = np.concatenate([[0.0], probs.cumsum()])
    idx = np.clip(np.searchsorted(borders, y) - 1, 0, len(borders) - 2)
    lo, hi = borders[idx].astype(np.float64), borders[idx + 1].astype(np.float64)
    frac = np.clip((y - lo) / (hi - lo), 0, 1)
    return cum[idx] + frac * probs[idx]


def bar_quantile(probs: np.ndarray, borders: np.ndarray, q: float) -> np.ndarray:
    """The q quantile of each marginal."""
    cum = probs.cumsum(-1)
    # The first bar whose cumulative probability reaches q (searchsorted, row by row)
    idx = np.minimum((cum < q).sum(-1, keepdims=True), probs.shape[-1] - 1)
    p_bar = np.take_along_axis(probs, idx, -1)
    before = np.take_along_axis(cum, idx, -1) - p_bar
    frac = np.clip((q - before) / np.maximum(p_bar, 1e-12), 0, 1)
    lo, hi = borders[idx].astype(np.float64), borders[idx + 1].astype(np.float64)
    return (lo + frac * (hi - lo))[..., 0]


def bar_sample(probs: np.ndarray, borders: np.ndarray, n_draws: int,
               rng: np.random.Generator) -> np.ndarray:
    """Independent draws from each marginal, [n_draws, *probs.shape[:-1]].

    These are marginal draws only: draws for different sources are not jointly
    distributed and do not sum to 1.
    """
    flat = probs.reshape(-1, probs.shape[-1])
    u = rng.random((n_draws, flat.shape[0]))
    # Inverse-CDF draw of a bar for each row, then uniform within the bar
    idx = np.empty(u.shape, dtype=np.int64)
    for r in range(flat.shape[0]):
        idx[:, r] = np.searchsorted(flat[r].cumsum(), u[:, r])
    idx = np.minimum(idx, flat.shape[-1] - 1)
    lo, hi = borders[idx].astype(np.float64), borders[idx + 1].astype(np.float64)
    draws = lo + rng.random(lo.shape) * (hi - lo)
    return draws.reshape(n_draws, *probs.shape[:-1])
