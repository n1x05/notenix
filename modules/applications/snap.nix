{ config, lib, pkgs, ... }:

let
  cfg = config.notenix.applications.snap;
  installScript = pkgs.writeShellScript "notenix-install-snaps" ''
    set -euo pipefail
    for app in ${lib.escapeShellArgs cfg.packages}; do
      if ! /run/current-system/sw/bin/snap list "$app" >/dev/null 2>&1; then
        echo "notenix: installing Snap $app …"
        /run/current-system/sw/bin/snap install "$app"
      else
        echo "notenix: $app already installed, skipping."
      fi
    done
  '';
  solitaireLauncher = pkgs.writeShellScriptBin "ms-solitaire-launcher" ''
    exec /run/current-system/sw/bin/snap run --shell ms-solitaire -c \
      'RUN_EXE=/snap/ms-solitaire/current/sol.exe /snap/ms-solitaire/current/bin/sommelier run-exe'
  '';
in
{
  options.notenix.applications.snap = {
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "ms-solitaire" "chromium" ];
      description = "Snap application names to install through snapd.";
    };
  };

  config = lib.mkIf (cfg.packages != []) {
    services.snap.enable = true;

    environment.systemPackages = lib.optionals (builtins.elem "ms-solitaire" cfg.packages) [
      solitaireLauncher
      (pkgs.writeTextFile {
        name = "ms-solitaire-desktop-entry";
        destination = "/share/applications/ms-solitaire.desktop";
        text = ''
          [Desktop Entry]
          Name=Microsoft Solitaire
          Comment=Microsoft Solitaire from Windows XP
          Exec=ms-solitaire-launcher
          Icon=applications-games
          Terminal=false
          Type=Application
          Categories=Game;CardGame;
          StartupNotify=true
        '';
      })
    ];

    systemd.services."notenix-install-snaps" = {
      description = "Install notenix Snap applications";
      wantedBy = [ "multi-user.target" ];
      after = [ "snapd.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      requires = [ "snapd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = installScript;
      };
    };
  };
}