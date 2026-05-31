# Interactive TUI installer — called via `nix run .#install` (or just `nix run`).
# Takes the flake-level inputs so it can reference disko and nixpkgs packages.
{ nixpkgs, disko, system, self }:

let
  pkgs = nixpkgs.legacyPackages.${system};
  notenixRef = self.sourceInfo.rev or self.rev or "main";
in
pkgs.writeShellApplication {
  name = "notenix-install";

  runtimeInputs = [
    disko.packages.${system}.disko
    pkgs.nixos-install-tools  # nixos-install, nixos-enter
    pkgs.nix                  # nix (needed by nixos-install)
    pkgs.util-linux        # lsblk
    pkgs.coreutils         # mktemp, cat, echo, etc.
    pkgs.dialog            # TUI menus
    pkgs.tzdata            # zone1970.tab
    pkgs.xkeyboard_config  # evdev.lst
    pkgs.glibcLocales      # SUPPORTED locales
    pkgs.gawk
    pkgs.gnugrep
    pkgs.gnused
    pkgs.ncurses      # clear
    pkgs.nextcloud-client  # nextcloudcmd — restore machine.nix from cloud
  ];

  text = ''
    set -euo pipefail

    BACKTITLE="notenix installer"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    # Ensure dialog can find the terminal even under sudo
    export TERM=''${TERM:-xterm}

    # Helper: run dialog, capture result via temp file so stdout stays
    # connected to the TTY (required for dialog to render).
    pick() {
      local title="$1"; shift
      local out="$TMP/pick_result"
      dialog \
        --backtitle "$BACKTITLE" \
        --title "$title" \
        "$@" 2>"$out" </dev/tty >/dev/tty || { clear; echo "Installation cancelled."; exit 1; }
      cat "$out"
    }

    # ── 1. Disk ───────────────────────────────────────────────────────
    DISK_ARGS=()
    while IFS= read -r line; do
      NAME=$(echo "$line" | awk '{print $1}')
      SIZE=$(echo "$line" | awk '{print $2}')
      MODEL=$(echo "$line" | awk '{$1=$2=""; print $0}' | sed 's/^ *//')
      [ -z "$MODEL" ] && MODEL="—"
      DISK_ARGS+=("/dev/$NAME" "$SIZE  $MODEL" "off")
    done < <(lsblk -d -o NAME,SIZE,MODEL --noheadings | grep -v "^loop")

    DISK=$(pick "Select installation disk" \
      --radiolist "ALL DATA ON THE SELECTED DISK WILL BE ERASED.\n\nUse arrow keys + Space to select, Enter to confirm." \
      20 70 10 \
      "''${DISK_ARGS[@]}")

    # ── 2. Timezone ───────────────────────────────────────────────────
    TZ_ARGS=()
    TZ_DEFAULT="Europe/Ljubljana"
    seen_tz=0
    while IFS= read -r tz; do
      if [ "$tz" = "$TZ_DEFAULT" ]; then
        TZ_ARGS+=("$tz" "" "on")
        seen_tz=1
      else
        TZ_ARGS+=("$tz" "" "off")
      fi
    done < <(grep -v '^#' "${pkgs.tzdata}/share/zoneinfo/zone1970.tab" \
             | awk -F'\t' '{print $3}' | sort -u)
    if [ "$seen_tz" -eq 0 ]; then
      TZ_ARGS=("$TZ_DEFAULT" "" "on" "''${TZ_ARGS[@]}")
    fi

    TIMEZONE=$(pick "Select timezone" \
      --radiolist "Use arrow keys + Space to select, Enter to confirm." \
      25 60 18 \
      "''${TZ_ARGS[@]}")

    # ── 3. Locale ─────────────────────────────────────────────────────
    LOCALE_DEFAULT="sl_SI.UTF-8"
    LOCALE_ARGS=()
    seen_locale=0
    while IFS= read -r entry; do
      loc=$(echo "$entry" | awk '{print $1}' | sed 's|/.*||')
      [[ "$loc" == *"UTF-8"* ]] || continue
      if [ "$loc" = "$LOCALE_DEFAULT" ]; then
        LOCALE_ARGS+=("$loc" "" "on")
        seen_locale=1
      else
        LOCALE_ARGS+=("$loc" "" "off")
      fi
    done < <(grep -v '^#' "${pkgs.glibcLocales}/share/i18n/SUPPORTED" \
             | tr ' ' '\n' | grep -v '^$' | grep -vF "\\")
    if [ "$seen_locale" -eq 0 ]; then
      LOCALE_ARGS=("$LOCALE_DEFAULT" "" "on" "''${LOCALE_ARGS[@]}")
    fi

    LOCALE=$(pick "Select default locale" \
      --radiolist "UTF-8 locales only. This sets the language/format for the whole system." \
      25 60 18 \
      "''${LOCALE_ARGS[@]}")

    # ── 4. Keyboard layout ────────────────────────────────────────────
    KB_DEFAULT="si"
    KB_ARGS=()
    seen_kb=0
    in_layout=0
    while IFS= read -r line; do
      if echo "$line" | grep -q "^! layout"; then in_layout=1; continue; fi
      if echo "$line" | grep -q "^!"; then in_layout=0; fi
      if [ "$in_layout" -eq 1 ] && [ -n "$line" ]; then
        code=$(echo "$line" | awk '{print $1}')
        desc=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
        if [ "$code" = "$KB_DEFAULT" ]; then
          KB_ARGS+=("$code" "$desc" "on")
          seen_kb=1
        else
          KB_ARGS+=("$code" "$desc" "off")
        fi
      fi
    done < "${pkgs.xkeyboard_config}/share/X11/xkb/rules/evdev.lst"
    if [ "$seen_kb" -eq 0 ]; then
      KB_ARGS=("$KB_DEFAULT" "Slovenian" "on" "''${KB_ARGS[@]}")
    fi

    KBLAYOUT=$(pick "Select keyboard layout" \
      --radiolist "Keyboard layout for console and graphical session." \
      25 65 18 \
      "''${KB_ARGS[@]}")

    # ── 5. Preset ─────────────────────────────────────────────────────
    PRESET=$(pick "Configuration preset" \
      --menu "Choose the default feature set for this machine:" 12 65 3 \
      "desktop" "Full GNOME desktop (Flatpak, sound, bluetooth, printing)" \
      "desktop-lite" "Cinnamon desktop (lighter GUI, still with apps, sound, bluetooth, printing)" \
      "minimal" "Minimal headless system (no desktop, essentials only)")

    # ── 6. Hostname ───────────────────────────────────────────────────
    HOSTNAME=$(pick "Machine hostname" \
      --inputbox "Enter a hostname for this machine:" 8 50 "notenix")

    # ── 7. Username & full name ───────────────────────────────────────
    USERNAME=$(pick "Primary user" \
      --inputbox "Enter the primary username:" 8 50 "user")

    USERDESC=$(pick "Full name (optional)" \
      --inputbox "Enter the full name for '$USERNAME' (or leave blank):" 8 60 "")

    # ── 8. Summary & confirmation ─────────────────────────────────────
    clear
    MSG="Please review your choices:\n\n"
    MSG+="  Disk     : $DISK\n"
    MSG+="  Preset   : $PRESET\n"
    MSG+="  Hostname : $HOSTNAME\n"
    MSG+="  Username : $USERNAME\n"
    MSG+="  Full name: $USERDESC\n"
    MSG+="  Timezone : $TIMEZONE\n"
    MSG+="  Locale   : $LOCALE\n"
    MSG+="  Keyboard : $KBLAYOUT\n\n"
    MSG+="⚠️  ALL DATA ON $DISK WILL BE ERASED."

    dialog \
      --backtitle "$BACKTITLE" \
      --title "Confirm installation" \
      --yesno "$MSG" 20 65 </dev/tty >/dev/tty || { clear; echo "Cancelled."; exit 1; }
    clear

    # ── 8b. Optional Nextcloud restore ───────────────────────────────
    NC_MACHINE_NIX=""
    dialog \
      --backtitle "$BACKTITLE" \
      --title "Nextcloud restore (optional)" \
      --yesno "Do you want to restore machine.nix from Nextcloud?\n\nThis will fetch your existing config so you don't have to reconfigure manually." \
      10 65 </dev/tty >/dev/tty && NC_WANT_RESTORE=yes || NC_WANT_RESTORE=no
    clear

    if [ "$NC_WANT_RESTORE" = yes ]; then
      NC_URL=$(pick "Nextcloud URL" \
        --inputbox "Enter your Nextcloud server URL (e.g. https://cloud.example.com):" 8 65 "")
      NC_USER=$(pick "Nextcloud username" \
        --inputbox "Enter your Nextcloud username:" 8 50 "")
      NC_PASS=$(pick "Nextcloud app password" \
        --passwordbox "Enter an app password (Settings → Security → App passwords):" 9 65 "")
      clear

      NC_FETCH_DIR="$TMP/nc_fetch"
      mkdir -p "$NC_FETCH_DIR"
      echo "→ Fetching machine.nix from Nextcloud…"
      if nextcloudcmd \
           --user "$NC_USER" \
           --password "$NC_PASS" \
           --path "notenix/$HOSTNAME" \
           --exclude-hidden \
           "$NC_FETCH_DIR" \
           "$NC_URL" 2>/dev/null \
         && [ -f "$NC_FETCH_DIR/machine.nix" ]; then
        NC_MACHINE_NIX="$NC_FETCH_DIR/machine.nix"
        echo "  ✓ Found machine.nix in Nextcloud — will use it after partitioning."
      else
        echo "  ✗ machine.nix not found in Nextcloud — will write from installer answers."
      fi
      sleep 2
    fi

    # ── 9. Write machine-specific flake and config ───────────────────
    mkdir -p "$TMP/etc/nixos"

    cat > "$TMP/etc/nixos/flake.nix" <<FLAKE
{
  inputs.notenix.url = "github:n1x05/notenix/${notenixRef}";
  outputs = { notenix, ... }: {
    nixosConfigurations.notenix =
      notenix.lib.mkMachineSystem { modules = [ ./machine.nix ]; };
  };
}
FLAKE

    cat > "$TMP/etc/nixos/machine.nix" <<EOF
# /etc/nixos/machine.nix — machine-specific NixOS configuration.
# Written by the notenix installer. Safe to edit manually.
# kanal rewrites notenix.preset when you change profile in the app.
{ lib, ... }: {
  imports = [ ./hardware-configuration.nix ];
  notenix.preset                         = lib.mkForce "$PRESET";
  notenix.disk.device                    = lib.mkForce "$DISK";
  notenix.system.autoupgrade.flakeRepo   = lib.mkForce "path:/etc/nixos";
  notenix.system.autoupgrade.hostName    = lib.mkForce "notenix";
  notenix.system.install.hostName        = lib.mkForce "$HOSTNAME";
  notenix.system.install.userName        = lib.mkForce "$USERNAME";
  notenix.system.install.userDescription = lib.mkForce "$USERDESC";
  notenix.system.install.timeZone        = lib.mkForce "$TIMEZONE";
  notenix.system.install.locale          = lib.mkForce "$LOCALE";
  notenix.system.install.keyboardLayout  = lib.mkForce "$KBLAYOUT";
  system.stateVersion                    = "25.11";
}
EOF

    # If Nextcloud restore found a machine.nix, overwrite the generated one.
    # The restored file already contains the correct hostname/user/disk values.
    if [ -n "$NC_MACHINE_NIX" ]; then
      echo "→ Using restored machine.nix from Nextcloud."
      cp "$NC_MACHINE_NIX" "$TMP/etc/nixos/machine.nix"
    fi

    LOCAL_FLAKE="path:$TMP/etc/nixos#notenix"

    # Stub needed so disko can evaluate the flake (real file generated after disko)
    cat > "$TMP/etc/nixos/hardware-configuration.nix" <<'HWSTUB'
{ ... }: { }
HWSTUB

    # ── 10. Partition, format, install ────────────────────────────────
    echo ""
    echo "→ Partitioning $DISK…"
    disko --mode destroy,format,mount --flake "$LOCAL_FLAKE"

    echo ""
    echo "→ Detecting hardware…"
    # --no-filesystems: disko manages mounts; we only want kernel/initrd/hardware bits
    nixos-generate-config --no-filesystems --root /mnt
    # Remove generated configuration.nix — we use flake.nix + machine.nix instead
    rm -f /mnt/etc/nixos/configuration.nix

    echo "→ Copying machine config to /mnt/etc/nixos…"
    cp "$TMP/etc/nixos/flake.nix" /mnt/etc/nixos/
    cp "$TMP/etc/nixos/machine.nix" /mnt/etc/nixos/

    echo ""
    echo "→ Installing NixOS (fetching from binary cache, this takes a while)…"
    # Pre-lock the flake so the NAR hash stays stable when nixos-install copies it
    nix flake lock /mnt/etc/nixos \
      --extra-experimental-features "nix-command flakes"
    nixos-install \
      --flake "path:/mnt/etc/nixos#notenix" \
      --no-root-passwd \
      --option cores 1 \
      --option max-jobs 1

    # ── 11. Set password ──────────────────────────────────────────────
    echo ""
    echo "✓ Installation complete."
    echo ""
    echo "Set a password for '$USERNAME':"
    nixos-enter --root /mnt -c "passwd '$USERNAME'"

    echo ""
    echo "All done. Run: sudo reboot"
  '';
}
