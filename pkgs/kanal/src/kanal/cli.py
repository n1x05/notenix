"""kanal.cli — kanalctl terminal interface.

Subcommands
-----------
status [--json]
    Print current channel and operation.
set <channel> [boot|switch]
    Write channel (and optionally operation) to flake.nix / machine.nix.
    Must be run as root (pkexec kanalctl set …).
apply <channel> <boot|switch>
    Write channel + operation, then run nixos-rebuild directly.
    Must be run as root (pkexec kanalctl apply …).
set-machine --hostname H --username U --userdesc D --timezone T --locale L --kblayout K
    Write machine-specific settings to machine.nix.
    Must be run as root (pkexec kanalctl set-machine …).
"""

from __future__ import annotations

import argparse
import json
import sys

from kanal import backend


def _cmd_status(args: argparse.Namespace) -> int:
    status = backend.read_status()
    if args.json:
        print(status.to_json())
    else:
        print(f"Channel  : {status.channel} ({status.flake_output})")
        print(f"Operation: {status.operation}")
        print(f"File     : {status.overrides_path}")
        print(f"Preset   : {status.preset}")
    return 0


def _cmd_set(args: argparse.Namespace) -> int:
    try:
        backend.set_channel(args.channel, args.operation, args.preset,
                            flake_url=getattr(args, "flake_url", None))
    except (ValueError, OSError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print(f"Channel set to {args.channel}")
    return 0


def _cmd_apply(args: argparse.Namespace) -> int:
    try:
        backend.set_channel(args.channel, args.operation, args.preset,
                            flake_url=getattr(args, "flake_url", None))
    except (ValueError, OSError) as exc:
        print(f"Error saving: {exc}", file=sys.stderr)
        return 1

    print(f"Channel set to {args.channel} — running nixos-rebuild {args.operation}", flush=True)
    rc = backend.run_upgrade(args.operation)
    if rc == 0:
        print("Done.", flush=True)
    else:
        print(f"nixos-rebuild failed (exit {rc})", file=sys.stderr, flush=True)
    return rc


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def _collect_machine(args: argparse.Namespace) -> dict:
    """Map CLI args → {nix_key: value} for all machine fields present in args."""
    out = {}
    for mf in backend.MACHINE_FIELDS:
        dest = mf["cli_flag"][2:].replace("-", "_")
        val = getattr(args, dest, None)
        if val is not None:
            out[mf["nix_key"]] = val
    return out


def _do_rebuild() -> int:
    """Run nixos-rebuild using the current channel/operation from status."""
    status = backend.read_status()
    print(f"Running nixos-rebuild {status.operation}…", flush=True)
    rc = backend.run_upgrade(status.operation)
    if rc != 0:
        print(f"nixos-rebuild failed (exit {rc})", file=sys.stderr, flush=True)
    return rc


def _save_and_rebuild(save_fn, data, success_msg: str, args: argparse.Namespace) -> int:
    """Call save_fn(data), print success_msg, optionally rebuild. Returns exit code."""
    try:
        save_fn(data)
    except OSError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print(success_msg, flush=True)
    return _do_rebuild() if args.rebuild else 0


# ---------------------------------------------------------------------------
# Subcommand handlers
# ---------------------------------------------------------------------------

def _cmd_set_machine(args: argparse.Namespace) -> int:
    return _save_and_rebuild(backend.save_machine, _collect_machine(args),
                             "Machine settings saved.", args)


# Dispatch: save_cmd → backend save function
_TAB_SAVE_FN = {
    tab["save_cmd"]: getattr(backend, tab["save_cmd"].replace("-", "_").replace("set_", "save_"))
    for tab in backend.TAB_CATALOG
}


def _collect_tab_data(tab: dict, args: argparse.Namespace):
    if tab["type"] == "bool_options":
        return {f["key"]: val
                for f in tab["items"]
                if (val := getattr(args, f["id"], None)) is not None}
    return getattr(args, tab["id"]) or []  # list_option


def _make_tab_handler(tab: dict):
    def handler(args: argparse.Namespace) -> int:
        return _save_and_rebuild(_TAB_SAVE_FN[tab["save_cmd"]],
                                 _collect_tab_data(tab, args),
                                 f"{tab['title']} saved.", args)
    return handler


def _cmd_save_all(args: argparse.Namespace) -> int:
    """Save features, apps, extensions, machine settings, and extension sources in one root call."""
    tab_args = {}
    for tab in backend.TAB_CATALOG:
        if tab["type"] == "bool_options":
            json_val = getattr(args, f"{tab['id']}_json", None)
            if json_val is not None:
                tab_args[tab["save_cmd"]] = json.loads(json_val)
        else:
            value = getattr(args, tab["id"], None)
            if value is not None:
                tab_args[tab["save_cmd"]] = value
    settings    = _collect_machine(args)
    snaps      = args.snaps
    ext_sources = json.loads(args.ext_sources_json or "{}")
    ext_hashes  = json.loads(args.ext_hashes_json  or "{}")
    try:
        for save_cmd, data in tab_args.items():
            _TAB_SAVE_FN[save_cmd](data)
        if snaps is not None:
            backend.save_snaps(snaps)
        if settings:
            backend.save_machine(settings)
        if ext_sources or ext_hashes:
            backend.save_extension_sources(ext_sources, ext_hashes)
    except OSError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print("All settings saved.", flush=True)
    if args.rebuild:
        try:
            backend.set_channel(args.channel, args.operation, args.preset,
                                flake_url=getattr(args, "flake_url", None))
        except (ValueError, OSError) as exc:
            print(f"Error setting channel: {exc}", file=sys.stderr)
            return 1
        print(f"Running nixos-rebuild {args.operation}\u2026", flush=True)
        rc = backend.run_upgrade(args.operation)
        if rc != 0:
            print(f"nixos-rebuild failed (exit {rc})", file=sys.stderr, flush=True)
        return rc
    return 0


def _cmd_apply_release(args: argparse.Namespace) -> int:
    """Pin flake.nix to a specific release tag (requires root)."""
    try:
        from kanal.nixfiles import apply_release
        apply_release(args.tag)
    except OSError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print(f"Pinned to release {args.tag}.", flush=True)
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="kanalctl",
        description="Manage the notenix update channel.",
    )
    sub = p.add_subparsers(dest="command", metavar="COMMAND")

    # status
    st = sub.add_parser("status", help="Show current channel and operation")
    st.add_argument("--json", action="store_true", help="Output as JSON")
    st.set_defaults(func=_cmd_status)

    # set
    s = sub.add_parser("set", help="Set the channel (requires root)")
    s.add_argument("channel")
    s.add_argument("operation", choices=["boot", "switch"], nargs="?", default=None,
                   help="Omit to keep existing / use module default")
    s.add_argument("--preset", default=None,
                   help="Preset id (validated per-channel)")
    s.add_argument("--flake-url", dest="flake_url", default=None,
                   help="Explicit flake URL (bypasses metadata cache)")
    s.set_defaults(func=_cmd_set)

    # apply
    a = sub.add_parser("apply", help="Set channel and run nixos-rebuild now (requires root)")
    a.add_argument("channel")
    a.add_argument("operation", choices=["boot", "switch"])
    a.add_argument("--preset", default=None,
                   help="Preset id (validated per-channel)")
    a.add_argument("--flake-url", dest="flake_url", default=None,
                   help="Explicit flake URL (bypasses metadata cache)")
    a.set_defaults(func=_cmd_apply)

    # set-machine
    m = sub.add_parser("set-machine", help="Save machine-specific settings (requires root)")
    for mf in backend.MACHINE_FIELDS:
        m.add_argument(mf["cli_flag"], default=None)
    m.add_argument("--rebuild", action="store_true", help="Run nixos-rebuild after saving")
    m.set_defaults(func=_cmd_set_machine)

    # set-features / set-apps / set-extensions — generated from TAB_CATALOG
    for tab in backend.TAB_CATALOG:
        tp = sub.add_parser(tab["save_cmd"],
                            help=f"Set {tab['title'].lower()} (requires root)")
        if tab["type"] == "bool_options":
            for feat in tab["items"]:
                flag = feat["id"].replace("_", "-")
                tp.add_argument(f"--{flag}",    dest=feat["id"], action="store_true",  default=None)
                tp.add_argument(f"--no-{flag}", dest=feat["id"], action="store_false")
        else:  # list_option
            tp.add_argument(tab["id"], nargs="*", metavar="ID",
                            help=f"{tab['title']} IDs (replaces current list; omit all to clear)")
        tp.add_argument("--rebuild", action="store_true", help="Run nixos-rebuild after saving")
        tp.set_defaults(func=_make_tab_handler(tab))

    # save-all
    sa = sub.add_parser("save-all", help="Save all settings atomically (requires root)")
    for tab in backend.TAB_CATALOG:
        if tab["type"] == "bool_options":
            sa.add_argument(f"--{tab['id']}-json", dest=f"{tab['id']}_json", default=None,
                            help=f"JSON object mapping {tab['id']} keys to booleans")
        else:
            sa.add_argument(f"--{tab['id']}", nargs="*", default=None, metavar="ID")
    for mf in backend.MACHINE_FIELDS:
        sa.add_argument(mf["cli_flag"], default=None)
    sa.add_argument("--rebuild",   action="store_true", help="Save + run nixos-rebuild")
    sa.add_argument("--channel",   default=None)
    sa.add_argument("--operation", choices=["boot", "switch"], default=None)
    sa.add_argument("--preset",    default=None)
    sa.add_argument("--flake-url", dest="flake_url", default=None)
    sa.add_argument("--snaps", nargs="*", default=None, metavar="SNAP",
                    help="Snap package names (replaces current list; omit to leave unchanged)")
    sa.add_argument("--ext-sources-json", dest="ext_sources_json", default=None,
                    help="JSON object mapping nix_source_key to source id")
    sa.add_argument("--ext-hashes-json",  dest="ext_hashes_json",  default=None,
                    help="JSON object mapping nix_hash_key to sha256 hash")
    sa.set_defaults(func=_cmd_save_all)

    # apply-release
    ar = sub.add_parser("apply-release", help="Pin flake.nix to a release tag (requires root)")
    ar.add_argument("tag", help="Release tag, e.g. v0.2.3")
    ar.set_defaults(func=_cmd_apply_release)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not args.command:
        parser.print_help()
        return 1
    return args.func(args)
