{ config, lib, ... }:

# Presets are named bundles of module defaults.  A preset sets options via
# lib.mkDefault so any explicit option in the host config or overrides file
# still wins.  The default preset is "desktop" (full GNOME experience).
#
# Additional optional features (SSH, kiosk, …) live in features.nix and are
# toggled independently via notenix.features.*.

with lib;

let
  cfg = config.notenix.preset;

  # ── preset building blocks ──────────────────────────────────────────────
  desktopOptions = {
    notenix.desktop.gnome.enable        = true;
    notenix.applications.flatpak.enable = true;
    services.snap.enable                = true;
    notenix.hardware.sound.enable       = true;
    notenix.hardware.bluetooth.enable   = true;
    notenix.hardware.printing.enable    = true;
  };

  desktopLiteOptions = {
    notenix.desktop.cinnamon.enable     = true;
    notenix.applications.flatpak.enable = true;
    services.snap.enable               = true;
    notenix.hardware.sound.enable       = true;
    notenix.hardware.bluetooth.enable   = true;
    notenix.hardware.printing.enable    = true;
  };

in
{
  options.notenix.preset = mkOption {
    type        = types.enum [ "desktop" "desktop-lite" "minimal" ];
    default     = "desktop";
    description = ''
      Named configuration preset that controls which notenix features are
      enabled by default.

      desktop       — full GNOME desktop with Flatpak, sound, bluetooth, printing
      desktop-lite  — Cinnamon desktop with Flatpak, sound, bluetooth, printing
      minimal       — headless / server: no desktop, no Flatpak, only essentials
    '';
  };

  config = mkMerge [
    (mkIf (cfg == "desktop")      desktopOptions)
    (mkIf (cfg == "desktop-lite") desktopLiteOptions)
  ];
}
