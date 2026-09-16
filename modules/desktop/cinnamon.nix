{ config, lib, pkgs, ... }:

# Cinnamon desktop environment.

let
  cfg = config.notenix.desktop.cinnamon;
  powerOffLauncher = config.notenix.features.powerOffLauncher;
  fmRadio = config.notenix.features.fmRadio;
  fmRadioPackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "cinnamon-fm-radio-applet";
    version = "1.3.3";
    src = pkgs.fetchzip {
      url = "https://cinnamon-spices.linuxmint.com/files/applets/FM-Radio@hilyxx.zip";
      hash = "sha256-4ylivlzjwRodNhdU2Pn1QEnQFFQdyfV1igNZ5OXeups=";
      stripRoot = false;
    };
    installPhase = ''
      mkdir -p $out/share/cinnamon/applets
      cp -r FM-Radio@hilyxx $out/share/cinnamon/applets/
    '';
  };
  ensureFmRadioApplet = pkgs.writeShellScript "notenix-enable-fm-radio-applet" ''
    set -eu
    appletDirectory="$HOME/.local/share/cinnamon/applets"
    mkdir -p "$appletDirectory"
    ln -sfn "${fmRadioPackage}/share/cinnamon/applets/FM-Radio@hilyxx" \
      "$appletDirectory/FM-Radio@hilyxx"

    key=/org/cinnamon/enabled-applets
    current=$(${pkgs.dconf}/bin/dconf read "$key")
    case "$current" in
      *"FM-Radio@hilyxx"*) exit 0 ;;
    esac
    for index in 11 10 9 8 7 6 5 4 3 2 1; do
      next=$((index + 1))
      current=$(printf '%s\n' "$current" | ${pkgs.gnused}/bin/sed "s/panel1:right:''${index}:/panel1:right:''${next}:/g")
    done
    current=$(printf '%s\n' "$current" | ${pkgs.gnused}/bin/sed \
      "s#panel1:right:0:systray@cinnamon.org:3#panel1:right:0:systray@cinnamon.org:3', 'panel1:right:1:FM-Radio@hilyxx:16#")
    ${pkgs.dconf}/bin/dconf write "$key" "$current"
  '';
in
{
  options.notenix.desktop.cinnamon = {
    enable = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Cinnamon desktop environment.";
    };

    extraPackages = lib.mkOption {
      type    = lib.types.listOf lib.types.package;
      default = [];
      description = "Extra packages to add to the Cinnamon desktop.";
    };

    applets.fmRadio.enable = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = "Install and enable the FM Radio Cinnamon applet.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable                         = true;
      desktopManager.cinnamon.enable = true;
      displayManager.lightdm.enable  = true;
    };

    # dconf defaults for Cinnamon: taskbar favourites
    programs.dconf.enable = true;
    programs.dconf.profiles.user.databases = [
      {
        lockAll = false;
        settings = {
          "org/cinnamon" = {
            favorite-apps = [
              "firefox.desktop"
              "nemo.desktop"
              "org.gnome.Calculator.desktop"
              "org.gnome.Console.desktop"
              ] ++ lib.optional powerOffLauncher "notenix-poweroff.desktop";

            enabled-applets = [
              "panel1:left:0:menu@cinnamon.org:0"
              "panel1:left:1:separator@cinnamon.org:1"
              "panel1:left:2:grouped-window-list@cinnamon.org:2"
            ] ++ (if fmRadio then [
              "panel1:right:0:systray@cinnamon.org:3"
              "panel1:right:1:FM-Radio@hilyxx:16"
              "panel1:right:2:xapp-status@cinnamon.org:4"
              "panel1:right:3:notifications@cinnamon.org:5"
              "panel1:right:4:printers@cinnamon.org:6"
              "panel1:right:5:removable-drives@cinnamon.org:7"
              "panel1:right:6:keyboard@cinnamon.org:8"
              "panel1:right:7:favorites@cinnamon.org:9"
              "panel1:right:8:network@cinnamon.org:10"
              "panel1:right:9:sound@cinnamon.org:11"
              "panel1:right:10:power@cinnamon.org:12"
              "panel1:right:11:calendar@cinnamon.org:13"
              "panel1:right:12:cornerbar@cinnamon.org:14"
            ] else [
              "panel1:right:0:systray@cinnamon.org:3"
              "panel1:right:1:xapp-status@cinnamon.org:4"
              "panel1:right:2:notifications@cinnamon.org:5"
              "panel1:right:3:printers@cinnamon.org:6"
              "panel1:right:4:removable-drives@cinnamon.org:7"
              "panel1:right:5:keyboard@cinnamon.org:8"
              "panel1:right:6:favorites@cinnamon.org:9"
              "panel1:right:7:network@cinnamon.org:10"
              "panel1:right:8:sound@cinnamon.org:11"
              "panel1:right:9:power@cinnamon.org:12"
              "panel1:right:10:calendar@cinnamon.org:13"
              "panel1:right:11:cornerbar@cinnamon.org:14"
            ])
            ++ lib.optional powerOffLauncher "panel1:left:3:panel-launchers@cinnamon.org:15"
            ;
          } // lib.optionalAttrs (powerOffLauncher || fmRadio) {
            next-applet-id = lib.gvariant.mkInt32 (if fmRadio then 17 else 16);
          };
        } // lib.optionalAttrs powerOffLauncher {
          "org/cinnamon/spices/panel-launchers@cinnamon.org/15" = {
            launcher-list = [ "notenix-poweroff.desktop" ];
            allow-dragging = true;
          };
        };
      }
    ];

    systemd.user.services.notenix-cinnamon-fm-radio = lib.mkIf fmRadio {
      description = "Enable notenix FM Radio Cinnamon applet";
      wantedBy = [ "default.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ensureFmRadioApplet;
      };
    };

    # Typical apps shipped with a Cinnamon desktop
    environment.systemPackages = with pkgs; [
      # File management
      nemo-with-extensions
      gnome-disk-utility
      baobab                   # disk usage analyser

      # Media
      celluloid                # video player (MPV frontend)
      rhythmbox                # music player
      eog                      # image viewer

      # App store
      gnome-software
      cinnamon-control-center

      # Productivity
      gnome-calculator
      evince                   # PDF viewer

      # System tools
      gnome-system-monitor
      gparted

      # Communication / web
      firefox

      # Theming
      mint-themes
      mint-y-icons
      adwaita-icon-theme   # Adwaita cursor fallback
      gnome-themes-extra   # Adwaita GTK theme
    ] ++ cfg.extraPackages ++ lib.optionals fmRadio [
      fmRadioPackage
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav
    ];
      # NixOS keeps GStreamer plugins in the system profile, but Cinnamon does
      # not discover them unless the plugin directory is exposed explicitly.
      environment.variables = lib.mkIf fmRadio {
        GST_PLUGIN_PATH = "/run/current-system/sw/lib/gstreamer-1.0";
        GST_PLUGIN_SYSTEM_PATH_1_0 = "/run/current-system/sw/lib/gstreamer-1.0";
      };
  };
}
