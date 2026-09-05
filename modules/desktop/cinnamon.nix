{ config, lib, pkgs, ... }:

# Cinnamon desktop environment.

let
  cfg = config.notenix.desktop.cinnamon;
  powerOffLauncher = config.notenix.features.powerOffLauncher;
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
            ] ++ lib.optional powerOffLauncher "panel1:left:3:panel-launchers@cinnamon.org:15";
          } // lib.optionalAttrs powerOffLauncher {
            next-applet-id = lib.gvariant.mkInt32 16;
          };
        } // lib.optionalAttrs powerOffLauncher {
          "org/cinnamon/spices/panel-launchers@cinnamon.org/15" = {
            launcher-list = [ "notenix-poweroff.desktop" ];
            allow-dragging = true;
          };
        };
      }
    ];

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
    ] ++ cfg.extraPackages;
  };
}
