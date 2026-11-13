{
  description = "kanal — NixOS channel switcher GUI/CLI";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs   = nixpkgs.legacyPackages.${system};
    in
    {
      # -------------------------------------------------------------------------
      # Metadata consumed by kanal at runtime.
      # Channels are discovered from GitHub branches; presets are defined here.
      # -------------------------------------------------------------------------
      lib.kanal = {
        flakeBase = "github:n1x05/notenix";
        presets = [
          { id = "desktop";      label = "Desktop";      subtitle = "Full desktop with Flatpak, sound, bluetooth, printing"; }
          { id = "desktop-lite"; label = "Desktop Lite"; subtitle = "Lightweight desktop with sound, bluetooth, printing"; }
          { id = "minimal";      label = "Minimal";      subtitle = "No desktop, essentials only"; }
        ];
      };

      packages.${system} = {
        kanal = pkgs.python3Packages.buildPythonApplication {
          pname   = "kanal";
          version = "0.9.0";
          src     = ./.;
          format  = "pyproject";
          nativeBuildInputs = with pkgs; [
            python3Packages.setuptools
            wrapGAppsHook4
            gobject-introspection
            gettext
          ];
          buildInputs = with pkgs; [ gtk4 libadwaita glibc ];
          dependencies = with pkgs.python3Packages; [ pygobject3 pyyaml packaging ];
          postInstall = ''
            install -Dm644 si.n1x05.notenix.kanal.desktop \
              $out/share/applications/si.n1x05.notenix.kanal.desktop
            install -Dm644 ${./assets/update-symbolic.svg} \
              $out/share/icons/hicolor/scalable/actions/update-symbolic.svg
            for po in po/*.po; do
              lang=$(basename "$po" .po)
              mkdir -p $out/share/locale/$lang/LC_MESSAGES
              msgfmt "$po" -o $out/share/locale/$lang/LC_MESSAGES/kanal.mo
            done
            wrapProgram $out/bin/kanal \
              --set KANALCTL_BIN $out/bin/kanalctl \
              --set KANAL_FLAKE_REF "${self.lib.kanal.flakeBase}" \
              --set KANAL_BUILD_REV "${if self ? rev then self.shortRev else self.dirtyShortRev}" \
              --set KANAL_LOCALE_SUPPORTED "${pkgs.glibc}/share/i18n/SUPPORTED" \
              --set KANAL_XKB_EVDEV_XML "${pkgs.xkeyboard-config}/share/X11/xkb/rules/evdev.xml" \
              --set TEXTDOMAINDIR $out/share/locale \
              --set LOCALE_ARCHIVE "${pkgs.glibcLocalesUtf8}/lib/locale/locale-archive"
          '';
        };

        default = self.packages.${system}.kanal;
      };
    };
}
