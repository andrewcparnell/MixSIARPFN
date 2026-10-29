"""Released networks: downloaded on first use, checked by checksum and cached.

``networks.json`` (next to this file) lists one entry per error structure::

    {"mult": {"file": "general_mult_v1.onnx", "url": "https://...", "sha256": "...",
              "size": 31887218}}

Files are cached in ``$MIXSIARPFN_CACHE`` if set, otherwise in
``$XDG_CACHE_HOME/mixsiarpfn`` or ``~/.cache/mixsiarpfn``. A cached file is used only if
its checksum matches the manifest; a download is written to a temporary file and moved
into place only after its checksum is checked, so an interrupted download never leaves
a broken file behind.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import tempfile
import urllib.request
from importlib import resources
from pathlib import Path

from mixsiarpfn.data_io import EnvelopeError
from mixsiarpfn.options import ERRORS
from mixsiarpfn.runtime.network import GeneralNetwork

ERROR_NAMES = {"mult": "Residual * Process", "resid": "Residual only", "process": "Process only"}


class NetworkUnavailable(FileNotFoundError):
    """No released network for this error structure, or it could not be downloaded."""


def read_manifest(path: str | Path | None = None) -> dict:
    """The manifest of released networks (the packaged one unless ``path`` is given)."""
    if path is not None:
        return json.loads(Path(path).read_text())
    return json.loads((resources.files("mixsiarpfn.runtime") / "networks.json").read_text())


def cache_dir() -> Path:
    if os.environ.get("MIXSIARPFN_CACHE"):
        return Path(os.environ["MIXSIARPFN_CACHE"])
    base = os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache"
    return Path(base) / "mixsiarpfn"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def manifest_entry(path: str | Path, url: str) -> dict:
    """A manifest entry for a network file about to be uploaded to ``url``."""
    path = Path(path)
    return {"file": path.name, "url": url, "sha256": sha256(path), "size": path.stat().st_size}


def network_path(error: str, manifest: dict | None = None, download: bool = True,
                 quiet: bool = False) -> Path:
    """The cached file of the released network for ``error``, downloading it if needed."""
    if error not in ERRORS:
        raise ValueError(f"error must be one of {', '.join(ERRORS)}")
    manifest = read_manifest() if manifest is None else manifest
    if error not in manifest:
        raise NetworkUnavailable(
            f"No released network for {ERROR_NAMES[error]} error ('{error}') in this version "
            "of mixsiarpfn.")
    entry = manifest[error]
    target = cache_dir() / entry["file"]
    if target.is_file() and sha256(target) == entry["sha256"]:
        return target
    if not download:
        raise NetworkUnavailable(f"The {error} network is not in the cache ({target}).")
    target.parent.mkdir(parents=True, exist_ok=True)
    if not quiet:
        size = f" ({entry['size'] / 1e6:.0f} MB)" if "size" in entry else ""
        print(f"Downloading the {ERROR_NAMES[error]} network{size} to {target.parent} "
              "(only needed once)...", flush=True)
    fd, tmp_name = tempfile.mkstemp(dir=target.parent, suffix=".part")
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "wb") as out, urllib.request.urlopen(entry["url"], timeout=60) as response:
            shutil.copyfileobj(response, out)
        if sha256(tmp) != entry["sha256"]:
            raise NetworkUnavailable(
                f"The downloaded {error} network does not match its checksum; try again, or "
                f"download {entry['url']} by hand into {target.parent}.")
        tmp.replace(target)                     # atomic on the same file system
    except OSError as err:                      # includes urllib's URLError
        if isinstance(err, NetworkUnavailable):
            raise
        raise NetworkUnavailable(f"Could not download the {error} network from {entry['url']}: "
                                 f"{err}. Download it by hand into {target.parent}.") from err
    finally:
        tmp.unlink(missing_ok=True)
    return target


_LOADED: dict[str, GeneralNetwork] = {}


def load_network(error: str, path: str | Path | None = None,
                 manifest: dict | None = None) -> GeneralNetwork:
    """The network for ``error``: from ``path`` if given, otherwise the released one.
    Networks are loaded once per session and reused."""
    key = str(Path(path).resolve()) if path is not None else f"released:{error}"
    if key not in _LOADED:
        _LOADED[key] = GeneralNetwork(path if path is not None else network_path(error, manifest))
    net = _LOADED[key]
    if net.error != error:
        raise EnvelopeError(f"{path} is the network for '{net.error}' error, not '{error}'.")
    return net
