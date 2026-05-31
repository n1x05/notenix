{ config, lib, pkgs, ... }:

# Nextcloud-backed config restore.
# - Backs up /etc/nixos/machine.nix → ~/Nextcloud/notenix/<hostname>/machine.nix
# - Backs up dconf → ~/Nextcloud/notenix/<hostname>/dconf.ini (15-min timer)
# - Creates browser profile symlinks once Nextcloud dir exists
# - Writes Nextcloud sync-exclude rules to skip browser caches
# - Auto-starts Nextcloud on first login

let
  cfg      = config.notenix.system.restore;
  userName = config.notenix.system.install.userName;
  hostName = config.networking.hostName;

  ncDir    = "${cfg.nextcloudBaseDir}/notenix/${hostName}";

  # Script that runs as root: copies machine.nix to the user's Nextcloud dir
  machineSyncScript = pkgs.writeShellScript "notenix-machine-backup" ''
    set -euo pipefail
    USER_HOME=$(getent passwd "${userName}" | cut -d: -f6)
    NC_DIR="$USER_HOME/${lib.removePrefix "~/" cfg.nextcloudBaseDir}/notenix/${hostName}"
    if [ -d "$NC_DIR" ]; then
      install -m 0644 /etc/nixos/machine.nix "$NC_DIR/machine.nix"
    fi
  '';

  # Script that runs as user: dconf backup
  dconfBackupScript = pkgs.writeShellScript "notenix-dconf-backup" ''
    set -euo pipefail
    NC_DIR="${ncDir}"
    mkdir -p "$NC_DIR"
    ${pkgs.dconf}/bin/dconf dump / > "$NC_DIR/dconf.ini"
  '';

  # Script that runs as user: create browser symlinks + write NC exclude list
  restoreSetupScript = pkgs.writeShellScript "notenix-restore-setup" ''
    set -euo pipefail
    NC_DIR="${ncDir}"
    STAMP="$HOME/.config/notenix-nc-synced"

    # Write Nextcloud sync-exclude entries for browser caches
    NC_EXCLUDE="$HOME/.config/Nextcloud/sync-exclude.lst"
    mkdir -p "$(dirname "$NC_EXCLUDE")"
    if ! grep -q "notenix-managed" "$NC_EXCLUDE" 2>/dev/null; then
      cat >> "$NC_EXCLUDE" <<'EOF'
# notenix-managed — browser cache exclusions
Cache/
cache/
cache2/
GPUCache/
Code Cache/
storage/
CacheStorage/
DawnCache/
ShaderCache/
*.lock
*.ldb
LOG
LOG.old
MANIFEST-*
EOF
    fi

    # Only create symlinks if Nextcloud has synced (dir exists with content)
    if [ ! -d "$NC_DIR/browser" ]; then
      exit 0
    fi

    # Firefox profile symlink
    FIREFOX_NC="$NC_DIR/browser/firefox"
    FIREFOX_HOME="$HOME/.mozilla/firefox"
    mkdir -p "$FIREFOX_NC"
    if [ ! -L "$FIREFOX_HOME" ] && [ ! -d "$FIREFOX_HOME" ]; then
      ln -s "$FIREFOX_NC" "$FIREFOX_HOME"
    elif [ -d "$FIREFOX_HOME" ] && [ ! -L "$FIREFOX_HOME" ]; then
      # Existing dir — move into Nextcloud then symlink
      mv "$FIREFOX_HOME" "$FIREFOX_NC.bak-$(date +%s)" || true
      ln -s "$FIREFOX_NC" "$FIREFOX_HOME"
    fi

    # Chromium profile symlink
    CHROMIUM_NC="$NC_DIR/browser/chromium"
    CHROMIUM_HOME="$HOME/.config/chromium"
    mkdir -p "$CHROMIUM_NC"
    if [ ! -L "$CHROMIUM_HOME" ] && [ ! -d "$CHROMIUM_HOME" ]; then
      ln -s "$CHROMIUM_NC" "$CHROMIUM_HOME"
    elif [ -d "$CHROMIUM_HOME" ] && [ ! -L "$CHROMIUM_HOME" ]; then
      mv "$CHROMIUM_HOME" "$CHROMIUM_NC.bak-$(date +%s)" || true
      ln -s "$CHROMIUM_NC" "$CHROMIUM_HOME"
    fi

    # Import dconf if this is the first login with a backup present
    if [ ! -f "$STAMP" ] && [ -f "$NC_DIR/dconf.ini" ]; then
      ${pkgs.dconf}/bin/dconf load / < "$NC_DIR/dconf.ini" || true
    fi

    # Write stamp — browser symlinks are now set up
    touch "$STAMP"

    # Write Nextcloud autostart only once (first login)
    AUTOSTART_DIR="$HOME/.config/autostart"
    AUTOSTART_FILE="$AUTOSTART_DIR/org.nextcloud.Nextcloud.desktop"
    AUTOSTART_STAMP="$HOME/.config/notenix-nc-autostarted"
    if [ ! -f "$AUTOSTART_STAMP" ]; then
      mkdir -p "$AUTOSTART_DIR"
      cat > "$AUTOSTART_FILE" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Nextcloud
Exec=/usr/bin/flatpak run org.nextcloud.Nextcloud
X-GNOME-Autostart-enabled=true
DESKTOP
      touch "$AUTOSTART_STAMP"
    fi
  '';

in
{
  options.notenix.system.restore = {
    enable = lib.mkEnableOption "Nextcloud-backed config restore (machine.nix, dconf, browser profiles)";

    nextcloudBaseDir = lib.mkOption {
      type    = lib.types.str;
      default = "~/Nextcloud";
      description = "Base Nextcloud sync directory (tilde expanded relative to user home).";
    };
  };

  config = lib.mkIf cfg.enable {

    # ── System path unit: machine.nix → Nextcloud on change ───────────────
    systemd.paths."notenix-machine-backup" = {
      description = "Watch /etc/nixos/machine.nix for changes";
      wantedBy    = [ "multi-user.target" ];
      pathConfig.PathModified = "/etc/nixos/machine.nix";
    };

    systemd.services."notenix-machine-backup" = {
      description = "Copy machine.nix to Nextcloud";
      serviceConfig = {
        Type      = "oneshot";
        ExecStart = machineSyncScript;
      };
    };

    # ── User timer: dconf backup every 15 minutes ─────────────────────────
    systemd.user.timers."notenix-dconf-backup" = {
      description = "Periodic dconf backup to Nextcloud";
      wantedBy    = [ "timers.target" ];
      timerConfig = {
        OnBootSec          = "2min";
        OnUnitActiveSec    = "15min";
        RandomizedDelaySec = "1min";
      };
    };

    systemd.user.services."notenix-dconf-backup" = {
      description = "Back up dconf settings to Nextcloud";
      serviceConfig = {
        Type      = "oneshot";
        ExecStart = dconfBackupScript;
      };
    };

    # ── User service at login: symlinks + first-run dconf restore ─────────
    systemd.user.services."notenix-restore-setup" = {
      description  = "Set up Nextcloud browser symlinks and restore config";
      wantedBy     = [ "default.target" ];
      after        = [ "graphical-session.target" ];
      serviceConfig = {
        Type      = "oneshot";
        ExecStart = restoreSetupScript;
        # Re-run on each login in case Nextcloud wasn't synced last time
        RemainAfterExit = false;
      };
    };
  };
}
