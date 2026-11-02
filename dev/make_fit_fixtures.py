"""Make the reference values for tests/testthat/test-fit.R: the Python package's fits of
the three vignettes, with the networks in the package's manifest.

Run from the package root with MixSIARPFN-build's environment, after the networks are
in the cache (pfn_networks() in R):

    uv run --project ~/simmr-pfn python dev/make_fit_fixtures.py
"""
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "inst" / "python"))      # the bundled code, as R uses it
os.environ.setdefault("MIXSIARPFN_CACHE", str(Path.home() / ".cache" / "R" / "MixSIARPFN"))

from mixsiarpfn.infer_general import fit_general, read_general_csvs  # noqa: E402
from mixsiarpfn.runtime.weights import network_path  # noqa: E402

EXT = ROOT / "inst" / "extdata"
VIGNETTES = {
    "killerwhale": dict(options={}, error="mult"),
    "geese": dict(options={"fixed": ["Group"]}, error="resid"),
    "wolves": dict(options={"random": ["Region", "Pack"], "nested": {"Pack": "Region"},
                            "sources_by": "Region"}, error="mult"),
}

for name, v in VIGNETTES.items():
    data = read_general_csvs(EXT / f"{name}_consumer.csv", EXT / f"{name}_sources.csv",
                             EXT / f"{name}_discrimination.csv", tracers=["d13C", "d15N"],
                             **v["options"])
    post = fit_general(data, alpha=1, error=v["error"],
                       network=str(network_path(v["error"], download=False)), seed=1)
    out = post.summary[["block", "level", "source", "mean", "sd", "q2.5", "q97.5"]]
    out.to_csv(ROOT / "tests" / "testthat" / "fixtures" / f"{name}_python.csv", index=False)
    print(f"{name}: {len(out)} rows, network {network_path(v['error'], download=False).name}")
