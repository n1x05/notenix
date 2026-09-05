{
  description = "notenix — portable NixOS modules for a minimal GNOME + Flatpak desktop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url   = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nix-snapd.url = "github:nix-community/nix-snapd";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";
    kanal.url   = "path:pkgs/kanal";
    kanal.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, nix-snapd, kanal, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      baseModules = [
        self.nixosModules.default
        disko.nixosModules.disko
        nix-snapd.nixosModules.default
        ./hosts/notenix/configuration.nix
        ./hosts/notenix/disk.nix
        { environment.systemPackages = [ self.packages.${system}.kanal ]; }
        { _module.args.pkgs-unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; }; }
      ];
    in
    {
      # ---------------------------------------------------------------------------
      # Modules — notenix-local NixOS modules (no shkatle dependency)
      # ---------------------------------------------------------------------------
      nixosModules = {
        default = import ./modules;
      };

      # ---------------------------------------------------------------------------
      # Metadata consumed by kanal — defined in pkgs/kanal/flake.nix
      # ---------------------------------------------------------------------------
      lib.kanal = kanal.lib.kanal;

      # ---------------------------------------------------------------------------
      # lib.mkMachineSystem — used by /etc/nixos/flake.nix on real machines.
      # Takes { modules } and returns a full nixosSystem with all notenix
      # modules, disko, disk layout, and kanal pre-installed.
      # Machine-specific settings (preset, hostname, user, etc.) come from
      # the caller's modules list (typically /etc/nixos/machine.nix).
      # ---------------------------------------------------------------------------
      lib.mkMachineSystem = { modules ? [] }: lib.nixosSystem {
        inherit system;
        modules = baseModules ++ modules;
      };

      # ---------------------------------------------------------------------------
      # NixOS configurations
      #   - sample:      real machine install target (used by the install script)
      #   - vm-headless: quick headless smoke-test VM
      #   - vm-gnome:    full GNOME desktop VM (needs QEMU with a display)
      # ---------------------------------------------------------------------------
      nixosConfigurations = {
          notenix = lib.nixosSystem {
            inherit system;
            modules = baseModules;
          };
          # Alias so `--flake .` works without specifying a hostname
          default = self.nixosConfigurations.notenix;

          # Full GNOME VM: requires a display (QEMU GTK or VNC)
          # Run with:  nix run .#vm
          vm = import ./vm.nix {
            inherit lib nixpkgs nix-snapd system;
            kanal = self.packages.${system}.kanal;
          };
        };

      # ---------------------------------------------------------------------------
      # Packages
      #   nix run .#install  — interactive TUI installer (use from live ISO)
      #   nix run            — alias for .#install
      #   nix run .#vm       — full GNOME desktop VM (needs QEMU display)
      # ---------------------------------------------------------------------------
      packages.${system} = {
        install = import ./install.nix { inherit nixpkgs disko system self; };
        kanal   = kanal.packages.${system}.kanal;
        default = self.packages.${system}.install;
        vm      = self.nixosConfigurations.vm.config.system.build.vm;
      };

      # ---------------------------------------------------------------------------
      # Dev shell — `nix develop`
      #   Provides Python + kanal deps for hacking on pkgs/kanal without a full
      #   Nix build.  Run kanal directly with:
      #     KANAL_DRY_RUN=1 python -m kanal.gui
      # ---------------------------------------------------------------------------
      devShells.${system}.default =
        let pkgs = nixpkgs.legacyPackages.${system}; in
        pkgs.mkShell {
          name = "notenix-dev";
          packages = with pkgs; [
            # Python runtime + GTK bindings + test runner
            (python3.withPackages (ps: with ps; [ pygobject3 pyyaml packaging pytest ]))
            gobject-introspection
            gtk4
            libadwaita
            glib
            # Release tooling
            commitizen
            pre-commit
            gh
            # Useful tools
            nixd
            nil
          ];
          # Make GTK typelib path available
          GI_TYPELIB_PATH = "${pkgs.gtk4}/lib/girepository-1.0:${pkgs.libadwaita}/lib/girepository-1.0:${pkgs.glib}/lib/girepository-1.0";
          shellHook = ''
            # pkgs/kanal/src/ is the package root (src layout); add it to PYTHONPATH
            # so `import kanal` works without installing.
            export PYTHONPATH="$PWD/pkgs/kanal/src:$PYTHONPATH"
            export KANAL_DRY_RUN=1
            echo "notenix dev shell — $(python --version)"
            echo "Run GUI: python -m kanal"
            echo "Run CLI: python -m kanal --ctl status"
            # Install pre-commit hooks if not already installed
            if [ -d .git ] && [ ! -f .git/hooks/commit-msg ]; then
              pre-commit install --hook-type commit-msg
            fi
          '';
        };
    };
}
