"""A MixSIAR model described by its options (no PyTorch, so inference can use it).

The simulator (:mod:`mixsiarpfn.simulators.general`), the encoding and inference all
describe a model with these classes. See CLAUDE.md, "Model space".
"""

from __future__ import annotations

from dataclasses import dataclass

ERRORS = ("mult", "resid", "process")   # Residual * Process, Residual only, Process only


@dataclass(frozen=True)
class Effect:
    """One categorical effect: fixed (baseline level 0, offsets N(0, 1)) or random (no
    baseline, offsets N(0, sigma^2), sigma ~ U(0, 20)); ``nested_in`` is the index of
    the effect whose levels contain this effect's levels."""

    random: bool
    nested_in: int | None = None


@dataclass(frozen=True)
class ModelConfig:
    """A MixSIAR model, described by its options (not by any vignette's names)."""

    effects: tuple[Effect, ...] = ()
    n_continuous: int = 0
    error: str = "mult"
    conc_dep: bool = False
    source_factor: int | None = None     # index of the effect the sources are given by

    def __post_init__(self):
        if self.error not in ERRORS:
            raise ValueError(f"error must be one of {ERRORS}")
        if self.source_factor is not None and not 0 <= self.source_factor < len(self.effects):
            raise ValueError("source_factor must index one of the effects")
