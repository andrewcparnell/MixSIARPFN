"""Reading MixSIAR-format data: helpers shared by every inference path (no PyTorch).

MixSIAR's conventions reproduced here: source and level order (R's ``sort()`` and
``factor()``), the Dirichlet prior given in several forms, and the pooled
standardisation of ``run_model()``.
"""

from __future__ import annotations

import re
import unicodedata

import numpy as np
import pandas as pd

QUANTILES = [0.025, 0.05, 0.25, 0.5, 0.75, 0.95, 0.975]


class EnvelopeError(ValueError):
    """The data or prior are outside what the network was trained for."""


def read_table(path_or_frame) -> pd.DataFrame:
    """A CSV path (or a data frame, copied) as a data frame."""
    if isinstance(path_or_frame, pd.DataFrame):
        return path_or_frame.copy()
    return pd.read_csv(path_or_frame)


def mixsiar_order(names: list[str]) -> list[str]:
    """Source names in the order MixSIAR uses.

    MixSIAR sorts sources with R's ``sort()``, which follows the locale's collation.
    In the usual English UTF-8 locales this ignores case and punctuation at first
    (so "algae" < "Benthic" < "fish eggs"), then breaks ties with lower case first.
    This function reproduces that; results are always labelled by name, so the order
    only matters when alpha is given as an unnamed vector.
    """
    def key(name: str):
        base = unicodedata.normalize("NFKD", name)
        letters = re.sub(r"[^0-9A-Za-z]", "", base).casefold()
        # Tie-breaks: punctuation and spaces, then lower case before upper case
        return (letters, base.casefold(), base.swapcase())
    return sorted(names, key=key)


def mixsiar_level_order(values) -> list:
    """Factor levels in MixSIAR's order: numbers sort numerically (R's ``factor()`` on
    a numeric column), text sorts as :func:`mixsiar_order`. Level 1 of the result is
    MixSIAR's baseline."""
    unique = list(pd.unique(pd.Series(values)))
    if all(isinstance(v, (int, float, np.integer, np.floating)) for v in unique):
        return sorted(unique)
    return mixsiar_order([str(v) for v in unique])


def alpha_vector(alpha, sources: list[str]) -> np.ndarray:
    """Dirichlet alpha in source order, from a number, a vector in MixSIAR's source
    order, or a dict by source name."""
    if isinstance(alpha, dict):
        unknown = sorted(set(alpha) - set(sources))
        missing = [s for s in sources if s not in alpha]
        if unknown or missing:
            raise EnvelopeError(
                "alpha must name each source exactly once"
                + (f"; unknown: {', '.join(unknown)}" if unknown else "")
                + (f"; missing: {', '.join(missing)}" if missing else "") + ".")
        return np.array([float(alpha[s]) for s in sources])
    values = np.atleast_1d(np.asarray(alpha, dtype=float))
    if values.size == 1:
        return np.full(len(sources), values.item())
    if values.size != len(sources):
        raise EnvelopeError(f"alpha has {values.size} values but there are {len(sources)} "
                            f"sources ({', '.join(sources)}).")
    return values


def pooled_standardisation(consumers: np.ndarray, source_mean: np.ndarray,
                           source_sd: np.ndarray, source_n: np.ndarray
                           ) -> tuple[np.ndarray, np.ndarray]:
    """Pooled mean and SD per tracer, exactly as MixSIAR's ``run_model()`` computes them
    (the numpy twin of :func:`mixsiarpfn.simulators.core.pooled_standardisation`).

    MixSIAR pools the N consumers with ``n`` notional observations from each source
    cell that have the cell's summary mean and sample variance, then takes the mean
    and the sample SD (denominator ``M - 1``) of all ``M = N + sum(n)`` values. When
    N = 1 the consumer variance term is dropped, as in MixSIAR.

    Args:
        consumers: raw consumer values, [N, J].
        source_mean, source_sd: raw source means and SDs, [cells, J].
        source_n: sample size of each cell, [cells].
    """
    consumers = np.asarray(consumers, dtype=np.float64)
    n_cons = consumers.shape[0]
    n = np.asarray(source_n, dtype=np.float64)[:, None]          # [cells, 1], broadcasts over J
    total = n_cons + n.sum()
    cons_mean = consumers.mean(axis=0)
    mean_pool = (n_cons * cons_mean + (n * source_mean).sum(axis=0)) / total
    sum_sq = ((n - 1) * source_sd**2).sum(axis=0) + (n * source_mean**2).sum(axis=0)
    if n_cons > 1:
        # ddof=1 is R's var(), denominator N - 1
        sum_sq = sum_sq + (n_cons - 1) * consumers.var(axis=0, ddof=1)
    sum_sq = sum_sq + n_cons * cons_mean**2 - total * mean_pool**2
    return mean_pool, np.sqrt(sum_sq / (total - 1))
