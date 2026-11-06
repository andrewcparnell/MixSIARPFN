"""A general network exported to ONNX (by :mod:`mixsiarpfn.export_onnx`), run with ONNX
Runtime.

The level embeddings are built here, in numpy, exactly as
:meth:`mixsiarpfn.general_net.GeneralPFN.level_embeddings` builds them: each effect's
levels get distinct embeddings drawn at random from that effect slot's pool (a fixed
effect's level 0 gets the baseline embedding instead), plus the effect-kind embedding,
plus a final zero row meaning "no level of this effect". The bar probabilities are
averaged over several such random assignments (a mixture).
"""

from __future__ import annotations

import base64
import io
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort

from mixsiarpfn.queries import HEADS
from mixsiarpfn.runtime.bars import softmax
from mixsiarpfn.runtime.encode import Encoded

METADATA_KEY = "mixsiarpfn"
INPUTS = ["consumers", "sources", "queries", "column_kind", "query_kind", "query_column",
          "consumer_levels", "source_levels", "query_levels"]
FORMAT_VERSION = 2


class GeneralNetwork:
    """One exported general network (one error structure).

    Args:
        path: the ``.onnx`` file.
        threads: CPU threads for ONNX Runtime (default: its own choice).
        max_items: about how many items (consumers, source items and queries, summed
            over the datasets and assignments) to run in one call; larger inputs are
            split over calls to bound memory. The default runs one assignment per call
            for the largest datasets in the envelope (1,000 consumers, 8 sources, 4
            tracers, 20 levels: about 15 s and 1.9 GB, against 6 GB for four
            assignments per call at the same speed; 24 October 2026).
        max_queries: at most this many queries per call; more are split over calls
            (queries attend only to the data, so the answers do not change).
    """

    def __init__(self, path: str | Path, threads: int | None = None, max_items: int = 1500,
                 max_queries: int = 2000):
        options = ort.SessionOptions()
        if threads:
            options.intra_op_num_threads = threads
        self.session = ort.InferenceSession(str(path), options, providers=["CPUExecutionProvider"])
        props = self.session.get_modelmeta().custom_metadata_map
        if METADATA_KEY not in props:
            raise ValueError(f"{path} is not a mixsiarpfn network (no '{METADATA_KEY}' metadata).")
        self.meta = json.loads(props[METADATA_KEY])
        if self.meta.get("format_version") != FORMAT_VERSION:
            raise ValueError(f"{path} is an older network format (version "
                             f"{self.meta.get('format_version')}); this version of mixsiarpfn "
                             f"needs version {FORMAT_VERSION}.")
        arrays = np.load(io.BytesIO(base64.b64decode(props[METADATA_KEY + "_arrays"])))
        self.level_pools = arrays["level_pools"]       # [E, pool, d]
        self.baseline = arrays["baseline"]             # [E, d]
        self.effect_kind = arrays["effect_kind"]       # [2, d]: fixed, random
        self.head_borders = {h: arrays[f"borders_{h}"] for h in HEADS}
        self.borders = self.head_borders["unit"]       # the proportions' borders
        self.max_effects = self.meta["model"]["max_effects"]
        # Query cell width: 7, plus conditioning features for networks with joint diets
        # (mixsiarpfn.runtime.joint); narrower query cells are padded with zeros
        self.conditional_features = self.meta["model"].get("conditional_features", 0)
        self.query_cell_width = 7 + self.conditional_features
        self.max_items = max_items
        self.max_queries = max_queries

    @property
    def error(self) -> str:
        return self.meta["error"]

    def level_embeddings(self, e: int, n_levels: int, random: bool,
                         assignment: np.ndarray) -> np.ndarray:
        """[L + 1, d]: the levels of effect slot ``e`` plus a zero row for "none"."""
        emb = self.level_pools[e][np.asarray(assignment)]
        if not random:
            emb = np.concatenate([self.baseline[e:e + 1], emb], axis=0)
        emb = emb + self.effect_kind[int(random)]
        return np.concatenate([emb, np.zeros_like(emb[:1])], axis=0).astype(np.float32)

    def draw_assignments(self, enc: Encoded, n: int, rng: np.random.Generator) -> list[list]:
        """``n`` random assignments: for each, one array of distinct pool indices per
        effect (the levels' pool embeddings; a fixed effect's baseline needs none)."""
        pool = self.level_pools.shape[1]
        out = []
        for _ in range(n):
            out.append([rng.permutation(pool)[:n_lev if random else n_lev - 1]
                        for n_lev, random in zip(enc.n_levels, enc.effect_random)])
        return out

    def check_levels(self, enc: Encoded) -> None:
        pool = self.level_pools.shape[1]
        if len(enc.n_levels) > self.max_effects:
            raise ValueError(f"{len(enc.n_levels)} effects but the network has "
                             f"{self.max_effects} effect slots.")
        for n_lev, random in zip(enc.n_levels, enc.effect_random):
            if (n_lev if random else n_lev - 1) > pool:
                raise ValueError(f"{n_lev} levels but a pool of only {pool}.")

    def probabilities(self, enc: Encoded, assignments: list[list]) -> dict[str, np.ndarray]:
        """Bar probabilities of every head for every query, ``{head: [B, Q, bars]}``
        (float64), averaged over ``assignments`` (from :meth:`draw_assignments`; one
        empty list per assignment without effects). Each query's answer is the head
        for its kind (:func:`mixsiarpfn.queries.head_of_kind`)."""
        self.check_levels(enc)
        n_q = enc.queries.shape[1]
        if n_q > self.max_queries:
            # Queries attend only to the data, so they can be asked in parts
            parts = [self.probabilities(_query_slice(enc, slice(a, a + self.max_queries)), assignments)
                     for a in range(0, n_q, self.max_queries)]
            return {h: np.concatenate([p[h] for p in parts], axis=1) for h in HEADS}
        batch = enc.consumers.shape[0]
        n_eff = len(enc.n_levels)
        d = self.level_pools.shape[2]

        # Level indices with "none" (-1) as the last row of each table; unused effect
        # slots get a one-row zero table and index 0
        def slots(levels: np.ndarray) -> np.ndarray:
            out = np.zeros((levels.shape[0], self.max_effects), dtype=np.int64)
            for e in range(n_eff):
                out[:, e] = np.where(levels[:, e] < 0, enc.n_levels[e], levels[:, e])
            return out

        feeds = {"consumers": enc.consumers.astype(np.float32),
                 "sources": enc.sources.astype(np.float32),
                 "queries": _pad_cells(enc.queries, self.query_cell_width).astype(np.float32),
                 "column_kind": enc.column_kind.astype(np.int64),
                 "query_kind": enc.query_kind.astype(np.int64),
                 "query_column": enc.query_column.astype(np.int64),
                 "consumer_levels": slots(enc.consumer_levels),
                 "source_levels": slots(enc.source_levels),
                 "query_levels": slots(enc.query_levels)}
        tables = [[self.level_embeddings(e, enc.n_levels[e], enc.effect_random[e], a[e])
                   for e in range(n_eff)] for a in assignments]
        items = sum(getattr(enc, k).shape[1] for k in ("consumers", "sources", "queries"))
        per_call = max(1, self.max_items // (items * batch))

        total = {h: 0.0 for h in HEADS}
        for start in range(0, len(assignments), per_call):
            chunk = tables[start:start + per_call]
            reps = len(chunk)
            # Each assignment runs on its own copy of the batch (np.tile stacks copies
            # along the batch axis, like rbind of copies in R)
            run = {k: (np.tile(v, (reps,) + (1,) * (v.ndim - 1))
                       if k in ("consumers", "sources", "queries") else v)
                   for k, v in feeds.items()}
            for e in range(self.max_effects):
                if e < n_eff:
                    emb = np.stack([t[e] for t in chunk])                      # [reps, L + 1, d]
                    emb = np.repeat(emb, batch, axis=0)                        # [reps * B, L + 1, d]
                else:
                    emb = np.zeros((reps * batch, 1, d), dtype=np.float32)
                run[f"emb_{e}"] = emb
            outputs = self.session.run([f"logits_{h}" for h in HEADS], run)  # each [reps * B, Q, bars]
            for h, logits in zip(HEADS, outputs):
                total[h] = total[h] + softmax(logits).reshape(reps, batch, *logits.shape[1:]).sum(0)
        return {h: v / len(assignments) for h, v in total.items()}

    def predict(self, enc: Encoded, n_assignments: int | None = None,
                rng: np.random.Generator | None = None) -> dict[str, np.ndarray]:
        """Bar probabilities of every head, ``{head: [B, Q, bars]}``, averaged over
        random level assignments (the network's default number unless given); a
        single pass without effects."""
        if not enc.n_levels:
            return self.probabilities(enc, [[]])
        n = n_assignments or self.meta["inference"].get("level_assignments", 8)
        rng = rng or np.random.default_rng()
        return self.probabilities(enc, self.draw_assignments(enc, n, rng))


def _pad_cells(cells: np.ndarray, width: int) -> np.ndarray:
    """Cells with zero features appended up to ``width`` (an unconditional query of a
    joint-diet network has all-zero conditioning features)."""
    missing = width - cells.shape[-1]
    if missing <= 0:
        return cells
    return np.concatenate([cells, np.zeros(cells.shape[:-1] + (missing,), cells.dtype)], axis=-1)


def _query_slice(enc: Encoded, sl: slice) -> Encoded:
    """The same data with only some of the queries."""
    from dataclasses import replace

    return replace(enc, queries=enc.queries[:, sl], query_levels=enc.query_levels[sl],
                   query_kind=enc.query_kind[sl], query_column=enc.query_column[sl],
                   query_group=None if enc.query_group is None else enc.query_group[sl])
