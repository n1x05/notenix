{ config, lib, pkgs, pkgs-unstable, ... }:

# GNOME desktop environment with opinionated defaults.

let
  cfg = config.notenix.desktop.gnome;

  # Helper: read shell-version list from a built extension package and warn if
  # it doesn't declare support for the running GNOME shell major version.
  _gnomeMajor = lib.versions.major pkgs.gnome-shell.version;

  _checkExtCompat = id: pkg:
    let
      metaFile = "${pkg}/share/gnome-shell/extensions/${pkg.extensionUuid}/metadata.json";
      meta     = builtins.fromJSON (builtins.readFile metaFile);
      supported = meta.shell-version or [];
    in
      if builtins.elem _gnomeMajor supported then pkg
      else lib.warn
        "notenix: extension '${id}' (${pkg.version or "?"}) declares shell-version ${builtins.toJSON supported} — GNOME ${_gnomeMajor} not listed. Extension may not load."
        pkg;

  _extPkgs = {
    "appindicator"                = pkgs.gnomeExtensions.appindicator;
    "dash-to-dock"                = pkgs.gnomeExtensions.dash-to-dock;
    "gsconnect"                   = pkgs.gnomeExtensions.gsconnect;
    "gtk4-desktop-icons-ng-ding"  =
      let
        base = if cfg.dingSource == "stable"
               then pkgs.gnomeExtensions.gtk4-desktop-icons-ng-ding
               else pkgs-unstable.gnomeExtensions.gtk4-desktop-icons-ng-ding;
        pkg  = if cfg.dingSource == "upstream-main" && cfg.dingSourceHash != "" then
          base.overrideAttrs (_: {
            version = "upstream-main";
            src = builtins.fetchTarball {
              url    = "https://gitlab.com/smedius/desktop-icons-ng/-/archive/main/desktop-icons-ng-main.tar.gz";
              sha256 = cfg.dingSourceHash;
            };
          })
        else base;
      in _checkExtCompat "gtk4-desktop-icons-ng-ding" pkg;
    "tailscale-status"            = pkgs.gnomeExtensions.tailscale-status;
  };
  _activeExtIds  = builtins.filter (id: builtins.hasAttr id _extPkgs) cfg.extensions;
  _activeExtPkgs = map (id: _extPkgs.${id}) _activeExtIds;
in
{
  options.notenix.desktop.gnome = {
    enable = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "GNOME desktop environment.";
    };

    autoSuspend = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Allow GDM to auto-suspend the machine.";
    };

    favoriteApps = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [
        "firefox.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.Calculator.desktop"
      ] ++ lib.optional config.notenix.features.powerOffLauncher "notenix-poweroff.desktop";
      description = "Dock favourite apps (desktop file IDs).";
    };

    excludePackages = lib.mkOption {
      type    = lib.types.listOf lib.types.package;
      default = with pkgs; [
        gnome-tour
        gnome-music
        gnome-maps
        gnome-contacts
        gnome-weather
        epiphany   # GNOME Web — ship Firefox instead
        geary      # email client
        totem      # Videos
        yelp       # Help browser
      ];
      defaultText = lib.literalExpression "[ pkgs.gnome-tour pkgs.epiphany … ]";
      description = "Packages to exclude from the default GNOME install.";
    };

    extraPackages = lib.mkOption {
      type    = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "[ pkgs.gnome-tweaks ]";
      description = "Additional packages to install alongside GNOME.";
    };

    power = {
      acSleepType = lib.mkOption {
        type    = lib.types.str;
        default = "nothing";
        description = "GNOME power action when idle on AC power (\"nothing\", \"suspend\", \"hibernate\").";
      };
      acSleepTimeout = lib.mkOption {
        type    = lib.types.int;
        default = 0;
        description = "Idle timeout on AC power in seconds. 0 = never.";
      };
      batterySleepType = lib.mkOption {
        type    = lib.types.str;
        default = "nothing";
        description = "GNOME power action when idle on battery.";
      };
      batterySleepTimeout = lib.mkOption {
        type    = lib.types.int;
        default = 0;
        description = "Idle timeout on battery in seconds. 0 = never.";
      };
    };

    dockFixed = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Show the dash-to-dock panel permanently (true) or auto-hide it (false).";
    };

    extensions = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [ "appindicator" "dash-to-dock" "gsconnect" ];
      description = "GNOME extensions to install and enable. Valid IDs: appindicator, dash-to-dock, gsconnect, gtk4-desktop-icons-ng-ding.";
    };

    dingSource = lib.mkOption {
      type    = lib.types.enum [ "unstable" "stable" "upstream-main" ];
      default = "unstable";
      description = "Package source for gtk4-desktop-icons-ng-ding. upstream-main requires dingSourceHash.";
    };

    dingSourceHash = lib.mkOption {
      type    = lib.types.str;
      default = "";
      description = "sha256 hash (base32, from nix-prefetch-url --unpack) for the upstream-main source. Set by kanal.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.displayManager.gdm = {
      enable      = true;
      autoSuspend = cfg.autoSuspend;
    };
    services.desktopManager.gnome.enable = true;

    environment.gnome.excludePackages = cfg.excludePackages;

    # Set GDM cursor so it's not a blank square
    programs.dconf.profiles.gdm.databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            cursor-theme = "Adwaita";
          };
        };
      }
    ];

    programs.dconf.profiles.user.databases = [
      {
        # Locked: cursor + icon theme must always be Adwaita in GNOME regardless
        # of what a previous desktop environment wrote to the user's dconf.
        lockAll = true;
        settings = {
          "org/gnome/desktop/interface" = {
            cursor-theme = "Adwaita";
            icon-theme   = "Adwaita";
          };
        };
      }
      {
        lockAll  = false;
        settings = {
          "org/gnome/shell" = {
            enabled-extensions = map (id: _extPkgs.${id}.extensionUuid) _activeExtIds;
            favorite-apps = cfg.favoriteApps;
          };

          "org/gnome/settings-daemon/plugins/power" = {
            sleep-inactive-ac-type         = cfg.power.acSleepType;
            sleep-inactive-ac-timeout      = lib.gvariant.mkUint32 cfg.power.acSleepTimeout;
            sleep-inactive-battery-type    = cfg.power.batterySleepType;
            sleep-inactive-battery-timeout = lib.gvariant.mkUint32 cfg.power.batterySleepTimeout;
          };

          "org/gnome/desktop/wm/preferences" = {
            button-layout = "appmenu:minimize,maximize,close";
          };

          "org/gnome/shell/extensions/dash-to-dock" = {
            custom-theme-shrink = true;
            dash-max-icon-size  = lib.gvariant.mkUint32 42;
            dock-fixed          = cfg.dockFixed;
            autohide            = !cfg.dockFixed;
            intellihide         = false;
          };
        } // lib.optionalAttrs (builtins.elem "gtk4-desktop-icons-ng-ding" cfg.extensions) {
          "org/gnome/shell/extensions/gtk4-ding" = {
            show-home  = false;
            show-trash = false;
          };
        };
      }
    ];

    environment.systemPackages = with pkgs; [
      adwaita-icon-theme
      firefox
      gnome-calculator
      gnome-calendar
      gnome-screenshot
      gnome-console
      gnome-software
      dconf
      libnotify
      gawk
      gnugrep
    ] ++ _activeExtPkgs ++ cfg.extraPackages;

    # GSConnect / KDE Connect ports
    networking.firewall.allowedTCPPortRanges = [{ from = 1714; to = 1764; }];
    networking.firewall.allowedUDPPortRanges = [{ from = 1714; to = 1764; }];

    # Run xdg-user-dirs-update with correct LANG and TEXTDOMAINDIR so it finds
    # its own translations in the Nix store (they live in the package, not /usr/share/locale).
    # This mirrors what gnome-initial-setup does on standard distros.
    systemd.user.services.xdg-user-dirs-init = {
      description = "Initialise XDG user directories for current locale";
      wantedBy    = [ "default.target" ];
      after       = [ "basic.target" ];
      environment = {
        LANG           = config.i18n.defaultLocale;
        TEXTDOMAINDIR  = "${pkgs.xdg-user-dirs}/share/locale";
      };
      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        ExecStart       = "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update --force";
      };
    };
  };
}
