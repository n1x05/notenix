{ config, lib, pkgs, pkgs-unstable, ... }:

# Optional feature flags that can be toggled independently of the preset.
# Written to machine.nix by kanal; each defaults to false so the base system
# remains lean until the user explicitly enables a feature.

with lib;

let
  cfg = config.notenix.features;
in
{
  options.notenix.features = {
    ssh = mkOption {
      type        = types.bool;
      default     = false;
      description = "Enable OpenSSH server (password auth, root login disabled).";
    };

    powerOffLauncher = mkOption {
      type        = types.bool;
      default     = false;
      description = "Add a Power Off launcher to the desktop dock.";
    };

    kiosk = mkOption {
      type        = types.bool;
      default     = false;
      description = "Kiosk mode: auto-login to a single-app fullscreen session.";
    };

    rustdesk = mkOption {
      type        = types.bool;
      default     = false;
      description = "RustDesk remote desktop server (allows remote access to this machine).";
    };

    nvidia = mkOption {
      type        = types.bool;
      default     = false;
      description = "Enable NVIDIA proprietary drivers.";
    };

    canonPrinter = mkOption {
      type        = types.bool;
      default     = false;
      description = "Enable Canon UFR II printer drivers (LBP/MF series, e.g. LBP633CDW).";
    };

    zfs = mkOption {
      type        = types.bool;
      default     = false;
      description = "Enable ZFS kernel module support for mounting ZFS pools.";
    };

    tailscale = mkOption {
      type        = types.bool;
      default     = false;
      description = "Enable Tailscale VPN. Adds tailscale-status GNOME extension when GNOME is active.";
    };

    logitechWireless = mkOption {
      type        = types.bool;
      default     = false;
      description = "Enable Solaar and udev rules for Logitech Unifying/Bolt wireless devices.";
    };

    experimental = mkOption {
      type        = types.bool;
      default     = false;
      description = "Unlock alternative package sources for extensions (unstable/upstream). May cause instability.";
    };

    steam = mkOption {
      type        = types.bool;
      default     = false;
      description = "Enable Steam game client with hardware controller support.";
    };

    swap = mkOption {
      type        = types.bool;
      default     = true;
      description = "Enable a 4 GiB swapfile and zram compressed swap.";
    };
  };

  config = mkMerge [
    # Enable 3D acceleration for all GPU types (AMD/Intel/NVIDIA open).
    # Mesa selects the correct driver (radeonsi, iris, nouveau) automatically.
    {
      hardware.graphics = {
        enable      = true;
        enable32Bit = true;
      };
    }

    (mkIf cfg.ssh {
      services.openssh = {
        enable                          = true;
        openFirewall                    = true;
        settings.PasswordAuthentication = true;
        settings.PermitRootLogin        = "no";
      };
    })

    # Kiosk: the host config still needs to set the actual app; this just
    # enables the infrastructure (auto-login + no screen lock).
    (mkIf cfg.kiosk {
      services.displayManager.autoLogin.enable = mkDefault true;
      programs.dconf.profiles.user.databases = mkAfter [
        {
          lockAll  = false;
          settings."org/gnome/desktop/screensaver".lock-enabled = false;
          settings."org/gnome/desktop/session".idle-delay = config.lib.gvariant.mkUint32 0;
        }
      ];
    })

    (mkIf cfg.rustdesk {
      environment.systemPackages = [ pkgs-unstable.rustdesk ];
      networking.firewall.allowedTCPPorts = [ 21115 21116 21117 21118 21119 ];
      networking.firewall.allowedUDPPorts = [ 21116 ];
    })

    (mkIf cfg.nvidia {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = true;
        open               = false;
        nvidiaSettings     = true;
        package            = config.boot.kernelPackages.nvidiaPackages.stable;
      };
      hardware.graphics.enable = true;
    })

    (mkIf cfg.canonPrinter {
      services.printing.enable = true;
      services.printing.drivers = [ pkgs.canon-cups-ufr2 ];
    })

    (mkIf cfg.zfs {
      # Provide ZFS userspace tools only. No initrd integration, no auto-import.
      # Load kernel module manually before use: sudo modprobe zfs
      boot.kernelPackages = mkForce pkgs.linuxPackages_6_12;
      boot.extraModulePackages = [ config.boot.kernelPackages.${pkgs.zfs.kernelModuleAttribute} ];
      environment.systemPackages = [ pkgs.zfs ];
      networking.hostId = mkDefault (
        builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName)
      );
    })

    (mkIf cfg.logitechWireless {
      hardware.logitech.wireless.enable          = true;
      hardware.logitech.wireless.enableGraphical = true;  # installs Solaar
      # Allow Solaar to create virtual input devices (required for remapping)
      hardware.uinput.enable = true;
      users.groups.uinput.members = [ config.notenix.system.install.userName ];
    })

    (mkIf cfg.steam {
      programs.steam = {
        enable                  = true;
        gamescopeSession.enable = true;
        remotePlay.openFirewall = true;
      };
      programs.gamescope.enable = true;
    })

    (mkIf cfg.tailscale {
      services.tailscale.enable = true;
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
      # Install tailscale-status extension when GNOME is active.
      # Enabling is handled by adding it to notenix.desktop.gnome.extensions via mkForce
      # so it merges with the user's list at the right priority.
      environment.systemPackages = mkIf config.notenix.desktop.gnome.enable [
        pkgs.gnomeExtensions.tailscale-status
      ];
    })

    (mkIf cfg.swap {
      swapDevices = [{
        device = "/var/lib/swapfile";
        size   = 4 * 1024;  # 4 GiB in MiB
      }];
      zramSwap = {
        enable    = true;
        algorithm = "zstd";
      };
    })
  ];
}
