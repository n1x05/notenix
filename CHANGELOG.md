## v0.9.0 (2026-11-13)

### Feat

- [cinnamon] fm radio applet add
- [desktop] add power off shortcut in the dock
- [snap] ms-solitaire fix for launcher
- [snap] add snaps to notenix
- manual install guide, exclude extensions if full desktop is not installed (#7)
- [input] update all
- update flake.lock
- update flake.lock, minor fix for nix flake check

### Fix

- [kanal] saveing change / tabs

### Refactor

- **flake**: deduplicate shared NixOS module stack

## v0.8.3 (2026-06-01)

## v0.8.2 (2026-06-01)

### Fix

- **channel**: fix branch dropdown reset to placeholder on metadata refresh

## v0.8.1 (2026-06-01)

### Fix

- **channel**: branch dropdown always visible, fix main branch restore on reopen

## v0.8.0 (2026-05-31)

### Feat

- **kanal**: show commit hash in title for non-release builds only
- **kanal**: move update banner below title bar; add KANAL_PINNED_TAG test override

## v0.7.1 (2026-05-31)

### Fix

- **kanal**: use catalog defaults in read_features; write explicit false for default-on features

## v0.7.0 (2026-05-31)

### Feat

- **graphics**: enable hardware.graphics unconditionally for AMD/Intel/NVIDIA
- **features**: add swap feature (4 GiB swapfile + zramSwap, enabled by default)

### Fix

- **kanal**: give main branch explicit /main URL to fix dropdown readback
- **api**: pass GITHUB_TOKEN auth header to avoid rate limiting

## v0.6.11 (2026-05-28)

### Fix

- choosing to update to the latest version now properly sets the release selected in the dropdown and allow the user to click install

## v0.6.10 (2026-05-28)

### Fix

- **release**: remove update-changelog pre-commit hook; Makefile handles CHANGELOG

## v0.6.9 (2026-05-28)

### Fix

- **release**: disable update_changelog_on_bump so cz bump never clobbers CHANGELOG

## v0.6.8 (2026-05-28)

### Fix

- **release**: use && chain in do-release to ensure cz changelog runs before git add

## v0.6.7 (2026-05-28)

### Refactor

- **yaml**: sort features, extensions and apps alphabetically

## v0.6.6 (2026-05-28)

## v0.6.5 (2026-05-28)

### Fix

- **release**: split cz bump and cz changelog to ensure versioned notes are written

## v0.6.4 (2026-05-28)

### Fix

- install button now properly states what it's for

## v0.6.3 (2026-05-28)

## v0.6.2 (2026-05-28)

## v0.6.1 (2026-05-28)

### Fix

- pressing reload now always checks for new versions

## v0.6.0 (2026-05-28)

### Feat

- show kanal rev when not using release version

## v0.5.0 (2026-05-28)

### Feat

- show new updates when using releases
- **nix**: add n1x05.cachix.org substituter and public key

## v0.4.2 (2026-05-27)

### Fix

- **dev**: use plain version_files for flake.nix; no search pattern needed

## v0.4.1 (2026-05-27)

### Fix

- **dev**: sync flake.nix version to 0.4.0
- **kanal**: reload button also refreshes release list; dropdown updated after check_update

## v0.4.0 (2026-05-27)

### Feat

- **kanal**: release+branch dropdowns with mutual deselection and i18n

### Fix

- **dev**: fix version_files pattern for flake.nix semicolon; sync flake.nix to 0.3.0

## v0.3.0 (2026-05-27)

### Feat

- **releases**: stable release track, apply-release, hide channel row unless experimental
- **gnome**: add minimize/maximize window buttons via dconf

### Fix

- **kanal**: sync flake.nix version to 0.2.2, add version_files to cz config
- **releases**: filter draft releases; add KANAL_VERSION dev override; import os
- **dev**: push lightweight tag explicitly; --follow-tags skips them

## v0.2.2 (2026-05-27)

### Fix

- **dev**: rewrite release targets using define+shell for correct post-bump tag
- **dev**: use --files-only bump + manual tag to keep tag on correct commit

## v0.2.1 (2026-05-27)

### Fix

- **dev**: run cz changelog separately after bump to ensure CHANGELOG.md is written

## v0.2.0 (2026-05-27)

### Feat

- **dev**: add changelog target, auto-update via pre-commit, fix changelog path
- **dev**: add gh CLI to devShell, GitHub release creation in Makefile
- **releases**: add update notification with GitHub release notes, commitizen versioning, and Makefile release targets
- **features**: add steam feature flag with gamescope and remote play
- **kanal**: add experimental package sources for extensions
- **kanal**: add Slovenian i18n via gettext
- **kanal**: Apply button always visible; label Update/Apply by dirty state
- **kanal**: disable Save/Apply buttons until something changes
- **kanal**: unified Apply + Save buttons replacing per-tab saves
- in progress refactor app
- **features**: add logitech wireless (Solaar) feature flag
- **features**: add Tailscale feature with tailscale-status GNOME extension
- **features**: add ZFS support option (6.12 LTS kernel, hostId)
- **features**: add Canon UFR II printer driver option
- **features**: add nvidia proprietary driver option
- **gnome/kanal**: user-configurable GNOME extensions via Kanal Extensions tab
- **desktop**: add --refresh to rebuild launchers to fetch latest flake
- **kanal**: add RustDesk to Flatpak catalog
- **kanal**: add Chromium to Flatpak catalog
- **kanal**: Apps tab — Flatpak app picker with checkboxes
- add Apply Update desktop launchers with user-friendly EN/SL text
- add Firefox + apps to Cinnamon taskbar favorites via dconf
- silent boot with Plymouth splash
- add RustDesk feature + open GSConnect firewall ports in GNOME
- change RustDesk to unstable
- install rustdesk from nixpkgs-unstable
- desktop-lite, vm, documentation

### Fix

- **dev**: run cz from pkgs/kanal so pep621 provider finds pyproject.toml
- **dev**: pass --repo to gh release create since origin is Gitea
- **dev**: remove --quiet flag unsupported by this pre-commit version
- **gnome**: remove postPatch shell-version hack; add build-time compat warning
- **gnome**: patch upstream-main ding metadata.json to include GNOME 49 shell-version
- **features**: add missing notenix.features.experimental option
- **kanal/i18n**: use ASCII ... instead of U+2026 ellipsis to fix translation lookup
- **autoupgrade**: add --upgrade to default flags so service updates flake inputs
- **kanal**: remove locale.setlocale causing crash in restricted environments
- **kanal**: disable Save when Apply is clicked
- **kanal**: bundle update-symbolic icon and register icon search path
- **features**: grant uinput access for Solaar device remapping
- **features**: enable Solaar graphical app for logitechWireless
- **features**: sync tailscale-status extension into machine.nix via save_features
- **features**: enable tailscale-status via dconf directly, avoid mkForce collision
- **features**: use pkgs.zfs.kernelModuleAttribute for dynamic ZFS module resolution
- **features**: ZFS tools only, no kernel module at boot to avoid auto-import panic
- **features**: use pkgs.zfs.kernelModuleAttribute for extraModulePackages
- **features**: load ZFS as post-boot module only, avoid initrd scan panic
- **features**: add pkgs to module args for canon-cups-ufr2
- **kanal**: wire nvidia feature through cli and pkexec flag map
- **kanal**: export KEY_FEATURE_NVIDIA from backend
- **autoupgrade**: use path:/etc/nixos as flakeRepo default
- **kanal**: never use root as username fallback in _env_fallbacks
- **gnome**: use TEXTDOMAINDIR to find xdg-user-dirs translations in Nix store
- **desktop**: use --flake flag for nix flake update in launchers
- **gnome**: use --force in xdg-user-dirs-update to always apply locale
- **gnome**: run xdg-user-dirs-update on login to init localized folders
- **desktop**: update launcher done message to reflect kgx close behaviour
- **desktop**: update flake.lock before rebuild in launchers
- **gnome**: use pkgs-unstable for gtk4-desktop-icons-ng-ding extension
- **kanal**: add missing _cmd_set_extensions function to cli.py
- **desktop**: use standard freedesktop icon names for rebuild launchers
- **install**: use --no-filesystems instead of fragile sed to strip fileSystems
- **install**: stub hardware-configuration.nix before disko evaluates flake
- Cinnamon dconf/icons, GNOME GDM cursor, kanal forces boot on DM switch
- remove icon-theme overrides, keep only cursor-theme fix
- remove cursor-theme override from Cinnamon, use default
- lock Adwaita cursor-theme in GNOME user dconf to survive DM switches
- lock icon-theme=Adwaita in GNOME user dconf to survive Cinnamon switches
- import pkgs-unstable with allowUnfree=true for rustdesk/libsciter
- install script

### Refactor

- **kanal**: unify constants imports + drop dead code
- **kanal**: make all remaining code fully data-driven from default.yaml
- **kanal**: deduplicate machine.py, backend.py, window.py, cli.py
- **kanal**: generate set-* subcommands from TAB_CATALOG loop
- **kanal**: deduplicate cli.py handlers with shared helpers
- **kanal**: derive CLI feature flags and machine args from default.yaml
- **kanal**: move machine field keys + flags into default.yaml
- **kanal**: remove all dead pkexec_* functions
- **kanal**: extract stream/worker helpers, remove worker duplication
- **kanal**: unify all dynamic tabs under default.yaml tabs catalog
- **kanal**: data-driven feature catalog via default.yaml
