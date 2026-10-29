"""What the general network is asked: query kinds, output heads and query sets.

No PyTorch here, so inference can use it; training builds the same :class:`Queries`
with torch tensors (:func:`mixsiarpfn.general_net.training_queries`).

Every diet is invILR(global + the offsets of the chosen levels + slope x covariate
value), MixSIAR's ``p.ind`` for that combination (MixSIAR sets each consumer's own
deviation ``ilr.ind`` to 0). One query form covers them all: a level (or none) for
each effect and a value for each covariate (0, the covariate's mean, when unset).
``p.global`` has no levels, MixSIAR's ``p.fac<e>`` one level (and its parent's, if
nested), a covariate curve one value, and a combination several.

Each diet gives one query per source. The parameter queries are: each random effect's
SD (``fac<e>.sig``), each covariate's slope per source on the centred log-ratio (CLR)
scale, and, for Residual * Process, ``resid.prop`` per tracer.

Query order: diets (diet-major, source-minor), SDs, slopes (covariate-major,
source-minor), ``resid.prop`` (by tracer).
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

# Query kinds (the network input ``query_kind``): diets share kind 0, since what a diet
# is about is in its level embeddings and covariate cells; each effect slot has its own
# SD kind.
DIET = 0


def sd_kind(e: int) -> int:
    return 1 + e


def slope_kind(max_effects: int) -> int:
    return 1 + max_effects


def resid_kind(max_effects: int) -> int:
    return 2 + max_effects


def n_query_kinds(max_effects: int) -> int:
    return 3 + max_effects


# Output heads, each with its own bars: proportions on [0, 1], SDs and resid.prop on
# [0, 20] (both have U(0, 20) priors), CLR slopes on the real line
HEADS = ("unit", "scale", "slope")


def head_of_kind(kind, max_effects: int):
    """Index into :data:`HEADS` for each query kind (works on numpy arrays and torch
    tensors alike: plain comparisons and arithmetic only)."""
    is_sd_or_resid = ((kind >= 1) & (kind <= max_effects)) | (kind == resid_kind(max_effects))
    is_slope = kind == slope_kind(max_effects)
    return 1 * is_sd_or_resid + 2 * is_slope


# Query groups: labels for validation and reporting only (not network inputs)
GLOBAL, LEVEL, COVARIATE, COMBINATION, SD, SLOPE, RESID = range(7)
GROUP_NAMES = ("global", "level", "covariate", "combination", "sd", "slope", "resid")


@dataclass
class Queries:
    """The queries for one batch: a layout shared by its datasets, with covariate
    values per dataset. Arrays are numpy or torch, used the same way.

    Attributes:
        diet_levels: [D, E] level of each effect for each diet (-1: none); a nested
            effect's level comes with its parent's (see :func:`with_parents`).
        diet_values: [B, D, C] covariate values on the centred and scaled scale.
        diet_groups: [D] GLOBAL, LEVEL, COVARIATE or COMBINATION.
        sd_effects: the random effects whose SD is asked for.
        slopes: ask for each covariate's CLR slope per source.
        resid: ask for ``resid.prop`` per tracer (Residual * Process only).
    """

    diet_levels: object
    diet_values: object
    diet_groups: object
    sd_effects: tuple = ()
    slopes: bool = False
    resid: bool = False

    def count(self, n_sources: int, n_tracers: int) -> int:
        """Number of queries."""
        n_cont = self.diet_values.shape[2]
        return (n_sources * self.diet_levels.shape[0] + len(self.sd_effects)
                + n_sources * n_cont * self.slopes + n_tracers * self.resid)

    def groups(self, n_sources: int, n_tracers: int) -> np.ndarray:
        """Group label of every query, in query order."""
        n_cont = self.diet_values.shape[2]
        dg = self.diet_groups
        dg = dg.cpu().numpy() if hasattr(dg, "cpu") else np.asarray(dg)   # torch tensor or numpy
        return np.concatenate([
            np.repeat(dg, n_sources),
            np.full(len(self.sd_effects), SD),
            np.full(n_sources * n_cont * self.slopes, SLOPE),
            np.full(n_tracers * self.resid, RESID)]).astype(np.int64)


def with_parents(levels: np.ndarray, effects, parents) -> np.ndarray:
    """Fill in the outer level of every nested effect that has a level."""
    levels = np.array(levels, dtype=np.int64)
    for e, eff in enumerate(effects):
        if eff.nested_in is not None:
            has = levels[:, e] >= 0
            levels[has, eff.nested_in] = np.asarray(parents[e])[levels[has, e]]
    return levels


def standard_queries(effects, n_levels, parents, n_batch: int, n_cont: int,
                     covariate_values=(), combinations=None, error: str = "mult") -> Queries:
    """The queries inference asks: ``p.global``, every level of every effect, each
    covariate at ``covariate_values`` (scaled; the others at their mean), any
    ``combinations``, and every parameter.

    Args:
        effects, n_levels, parents: the model's effects (as in the design).
        n_batch: datasets in the batch (covariate values are shared by all of them).
        covariate_values: per covariate, the scaled values to ask the diet at.
        combinations: optional ``(levels [M, E], values [M, C])``: diets for these
            combinations of levels (-1: none; parents are filled in) and covariate
            values (scaled).
        error: the error structure (``resid.prop`` is asked for under ``mult``).
    """
    n_eff = len(effects)
    rows, values, groups = [np.full(n_eff, -1)], [np.zeros(n_cont)], [GLOBAL]
    for e in range(n_eff):
        for lev in range(n_levels[e]):
            r = np.full(n_eff, -1)
            r[e] = lev
            rows.append(r)
            values.append(np.zeros(n_cont))
            groups.append(LEVEL)
    for c, vals in enumerate(covariate_values):
        for v in vals:
            val = np.zeros(n_cont)
            val[c] = v
            rows.append(np.full(n_eff, -1))
            values.append(val)
            groups.append(COVARIATE)
    if combinations is not None:
        lev = np.asarray(combinations[0])
        lev = lev.reshape(lev.shape[0], n_eff)
        val = np.asarray(combinations[1], dtype=np.float64).reshape(len(lev), n_cont)
        for r, v in zip(lev, val):
            rows.append(r)
            values.append(v)
            groups.append(COMBINATION)
    levels = with_parents(np.stack(rows).reshape(len(rows), n_eff), effects, parents)
    diet_values = np.broadcast_to(np.stack(values).reshape(len(rows), n_cont),
                                  (n_batch, len(rows), n_cont)).copy()
    return Queries(diet_levels=levels, diet_values=diet_values,
                   diet_groups=np.asarray(groups, dtype=np.int64),
                   sd_effects=tuple(e for e, eff in enumerate(effects) if eff.random),
                   slopes=n_cont > 0, resid=error == "mult")


def clr_matrix(n_sources: int) -> np.ndarray:
    """[K, K - 1] matrix taking MixSIAR's ILR coordinates to centred log-ratios.

    MixSIAR's inverse ILR raises the columns of its basis ``e`` to the ILR powers, so
    log p = log(e) @ ilr + a constant; each column of log(e) is an orthonormal
    contrast minus a constant, so centring over sources gives clr(p) = V @ ilr with V
    = log(e) centred by column. V has orthonormal columns.
    """
    e = np.zeros((n_sources, n_sources - 1))
    for c in range(1, n_sources):                     # as simulators.core.ilr_basis
        col = np.zeros(n_sources)
        col[:c] = np.sqrt(1.0 / (c * (c + 1)))
        col[c] = -np.sqrt(c / (c + 1))
        col = np.exp(col)
        e[:, c - 1] = col / col.sum()
    log_e = np.log(e)
    return log_e - log_e.mean(axis=0, keepdims=True)
