"""kanal.privileged — subprocess helpers that require root (via pkexec).

All public functions in this module either:
- run ``nixos-rebuild`` directly (already root, called from kanalctl), or
- invoke ``pkexec kanalctl <subcommand>`` to obtain root for a single operation.

The streaming variants (``*_stream``) yield log lines as strings and then a
final ``(None, returncode)`` sentinel so the GUI can update in real time.
"""

from __future__ import annotations

import json
import os
import subprocess

import kanal.constants as _const

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _pkexec_stream(cmd: list[str], dry_msg: str):
    """Core: dry-run guard → Popen → yield lines → (None, returncode) sentinel."""
    if _const.DRY_RUN:
        yield f"[kanal dry-run] {dry_msg}\n"
        yield None, 0
        return
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env,
    )
    for line in proc.stdout:
        yield line
    proc.wait()
    yield None, proc.returncode


# {nix_key: cli_flag} — loaded from default.yaml, no hardcoding needed
_MACHINE_FLAGS = _const.MACHINE_KEY_FLAGS

# ---------------------------------------------------------------------------
# Direct rebuild (already root — called from kanalctl apply / save-all)
# ---------------------------------------------------------------------------

def run_upgrade(operation: str) -> int:
    """Update the flake lock file and run ``nixos-rebuild``.

    Streams combined stdout+stderr to our own stdout so the GUI can capture it.
    Returns the nixos-rebuild exit code.
    """
    flake_dir = str(_const.LOCAL_FLAKE_PATH.parent)
    flake_arg = f"path:/etc/nixos#{_const.LOCAL_FLAKE_ATTR}"

    print("Updating flake inputs…", flush=True)
    update = subprocess.Popen(
        [str(_const.NIX_BIN), "flake", "update", "--flake", flake_dir],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    for line in update.stdout:
        print(line, end="", flush=True)
    update.wait()
    if update.returncode != 0:
        print(f"nix flake update failed (exit {update.returncode})", flush=True)
        return update.returncode

    proc = subprocess.Popen(
        [str(_const.NIXOS_REBUILD_BIN), operation, "--flake", flake_arg],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    for line in proc.stdout:
        print(line, end="", flush=True)
    proc.wait()
    return proc.returncode

# ---------------------------------------------------------------------------
# pkexec helpers — prompt for root once, then run the kanalctl subcommand
# ---------------------------------------------------------------------------

def prefetch_hash_stream(fetch_url: str):
    """Fetch the sha256 hash of a tarball using ``nix-prefetch-url --unpack``.

    No root required.  Yields log lines then ``(None, returncode)``.
    The hash is the last non-empty, non-"path" line on stdout.
    """
    import shutil
    from pathlib import Path
    prefetch = str(_const.NIX_BIN.parent / "nix-prefetch-url")
    if not Path(prefetch).exists():
        prefetch = shutil.which("nix-prefetch-url") or "nix-prefetch-url"
    if _const.DRY_RUN:
        yield f"[kanal dry-run] nix-prefetch-url --unpack {fetch_url}\n"
        yield "0f4q8cpcb2z5ln5hccwnfy1lz16hqb5937z9abn09bawhq0sd0mj\n"
        yield None, 0
        return
    proc = subprocess.Popen(
        [prefetch, "--unpack", fetch_url],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    for line in proc.stdout:
        yield line
    proc.wait()
    yield None, proc.returncode


def pkexec_apply_release_stream(tag: str):
    """Pin flake.nix to *tag* via pkexec kanalctl apply-release."""
    cmd = ["pkexec", _const.KANALCTL_BIN, "apply-release", tag]
    yield from _pkexec_stream(cmd, f"apply-release {tag}")


def pkexec_save_all_stream(payload: dict, rebuild: bool = False):
    cmd = ["pkexec", _const.KANALCTL_BIN, "save-all"]
    for tab in _const.TAB_CATALOG:
        tab_id = tab["id"]
        data   = payload.get(tab_id)
        if tab["type"] == "bool_options":
            cmd += [f"--{tab_id}-json", json.dumps(data if data is not None else {})]
        elif data:
            cmd += [f"--{tab_id}", *data]
    for key, flag in _MACHINE_FLAGS.items():
        if payload["machine"].get(key):
            cmd += [flag, payload["machine"][key]]
    ext_sources = payload.get("ext_sources", {})
    ext_hashes  = payload.get("ext_hashes",  {})
    snaps = payload.get("snaps")
    if snaps is not None:
        cmd += ["--snaps", *snaps]
    if ext_sources:
        cmd += ["--ext-sources-json", json.dumps(ext_sources)]
    if ext_hashes:
        cmd += ["--ext-hashes-json", json.dumps(ext_hashes)]
    if rebuild:
        cmd += ["--rebuild", "--channel", payload["channel"],
                "--operation", payload["operation"]]
        if payload.get("preset"):
            cmd += ["--preset", payload["preset"]]
        if payload.get("flake_url"):
            cmd += ["--flake-url", payload["flake_url"]]
    dry = f"save-all rebuild={rebuild} ch={payload.get('channel')!r} features={payload['features']}"
    yield from _pkexec_stream(cmd, dry)
