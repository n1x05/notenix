{ config, lib, pkgs, ... }:

# Native (nixpkgs) application packages.
# Use for apps whose config directories should be restorable via Nextcloud.
# Keep Flatpak for apps that are large to build or have no config worth restoring.

let
  cfg = config.notenix.applications.native;
in
{
  options.notenix.applications.native = {
    enable = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Install native nixpkgs browser apps (Firefox, Chromium) for Nextcloud profile restore.";
    };

    firefox = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Install Firefox browser (native nixpkgs — profile restorable via Nextcloud).";
    };

    chromium = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Install Chromium browser (native nixpkgs — profile restorable via Nextcloud).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      lib.optionals cfg.firefox  [ pkgs.firefox ] ++
      lib.optionals cfg.chromium [ pkgs.chromium ];
  };
}
