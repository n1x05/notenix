"""kanal.constants — all paths, NixOS option keys, and environment-driven flags.

Nothing in this module has side effects beyond reading environment variables at
import time.  Every other module imports from here; nothing imports back.
"""

from __future__ import annotations

import importlib.resources
import os
from pathlib import Path

import yaml

# ---------------------------------------------------------------------------
# File paths
# ---------------------------------------------------------------------------

LOCAL_FLAKE_PATH  = Path("/etc/nixos/flake.nix")
MACHINE_PATH      = Path("/etc/nixos/machine.nix")
LOCAL_FLAKE_ATTR  = "notenix"          # nixosConfigurations.<attr>
FLAKE_REPO        = "path:/etc/nixos"   # autoupgrade always builds from local flake
NIXOS_REBUILD_BIN = Path("/run/current-system/sw/bin/nixos-rebuild")
NIX_BIN           = Path("/run/current-system/sw/bin/nix")

RELEASES_CACHE    = Path("~/.cache/kanal/releases.json").expanduser()

# ---------------------------------------------------------------------------
# NixOS option keys written to machine.nix
# ---------------------------------------------------------------------------

KEY_OP        = "notenix.system.autoupgrade.operation"
KEY_FLAKEREPO = "notenix.system.autoupgrade.flakeRepo"
KEY_PRESET    = "notenix.preset"

# ---------------------------------------------------------------------------
# Tab catalog — loaded from default.yaml bundled in the package.
# Drives all dynamic tabs (features, extensions, apps) in the GUI.
# ---------------------------------------------------------------------------

def _load_catalog() -> dict:
    ref = importlib.resources.files("kanal").joinpath("default.yaml")
    with importlib.resources.as_file(ref) as p:
        return yaml.safe_load(p.read_text())


_CATALOG: dict = _load_catalog()

TAB_CATALOG: list[dict] = _CATALOG["tabs"]

# Convenience lookup by tab id
_TABS_BY_ID: dict[str, dict] = {t["id"]: t for t in TAB_CATALOG}

FEATURE_CATALOG: list[dict] = _TABS_BY_ID["features"]["items"]

ALL_FEATURES: list[str] = [f["key"] for f in FEATURE_CATALOG]

# Per-feature constants: KEY_FEATURE_SSH, KEY_FEATURE_KIOSK, …
for _f in FEATURE_CATALOG:
    globals()[f"KEY_FEATURE_{_f['const']}"] = _f["key"]

# list_option nix keys — derived from YAML nix_key fields
KEY_FLATPAK_PACKAGES: str = _TABS_BY_ID["apps"]["nix_key"]
KEY_SNAP_PACKAGES: str = "notenix.applications.snap.packages"
KEY_GNOME_EXTENSIONS: str = _TABS_BY_ID["extensions"]["nix_key"]

# Extension items that expose selectable package sources
EXT_SOURCE_ITEMS: list[dict] = [
    item for item in _TABS_BY_ID["extensions"]["items"] if "sources" in item
]

# Machine identity fields — loaded from default.yaml machine.fields
MACHINE_FIELDS: list[dict] = _CATALOG["machine"]["fields"]
MACHINE_GROUPS: list[dict] = _CATALOG["machine"]["groups"]

# Generate KEY_HOSTNAME, KEY_USERNAME, … from YAML
for _mf in MACHINE_FIELDS:
    globals()[f"KEY_{_mf['id'].upper()}"] = _mf["nix_key"]

# Convenience: {nix_key: cli_flag} mapping used by privileged.py / cli.py
MACHINE_KEY_FLAGS: dict[str, str] = {f["nix_key"]: f["cli_flag"] for f in MACHINE_FIELDS}


def get_tab_catalog() -> list[dict]:
    """Return the full ordered tab catalog from default.yaml."""
    return TAB_CATALOG


def get_feature_catalog() -> list[dict]:
    """Return feature items (bool_options tab). Backward compat."""
    return FEATURE_CATALOG

# ---------------------------------------------------------------------------
# Runtime flags (injected by the Nix build via makeWrapper)
# ---------------------------------------------------------------------------

# Path to the kanalctl binary; falls back to PATH for local development.
KANALCTL_BIN = os.environ.get("KANALCTL_BIN", "kanalctl")

# Flake ref used for nix eval to fetch metadata; baked in by the Nix build.
FLAKE_REF = os.environ.get("KANAL_FLAKE_REF", "github:n1x05/notenix")

# Set KANAL_DRY_RUN=1 to skip all file writes (useful for UI development).
DRY_RUN = os.environ.get("KANAL_DRY_RUN", "") not in ("", "0", "false")
