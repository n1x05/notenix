# vm.nix — VM nixosConfiguration for `nix run .#vm`
# Imported by flake.nix as nixosConfigurations.vm.
{ lib, nixpkgs, nix-snapd, system, kanal }:
let
  # Single source of truth for VM identity — reused in both vmOverrides
  # and the seeded /etc/nixos/machine.nix activation script below.
  vmHostName     = "notenix-vm";
  vmUserName     = "user";
  vmUserDesc     = "Test User";
  vmTimeZone     = "Europe/Ljubljana";
  vmLocale       = "sl_SI.UTF-8";
  vmKeyboard     = "si";
  vmPreset       = "desktop-lite";
  vmStateVersion = "25.11";

  vmOverrides = {
    notenix.system.install.hostName        = lib.mkForce vmHostName;
    notenix.system.install.userName        = lib.mkForce vmUserName;
    notenix.system.install.userDescription = lib.mkForce vmUserDesc;
    notenix.system.install.timeZone        = lib.mkForce vmTimeZone;
    notenix.system.install.locale          = lib.mkForce vmLocale;
    notenix.system.install.keyboardLayout  = lib.mkForce vmKeyboard;
    # VMs have no bootloader — switch activates immediately without reboot
    notenix.system.autoupgrade.operation   = lib.mkForce "switch";
    # Enable desktop-lite preset in the VM
    notenix.preset                         = lib.mkForce vmPreset;

    # Pre-set a password so the VM is usable without extra steps
    users.users.${vmUserName}.initialPassword = "user";
  };

  # machine.nix seeded into the VM — defined once here as a store file and
  # copied by the activation script, so option paths only appear once.
  # Nix store files seeded into /etc/nixos on first VM boot.
  # Defined here so all values are interpolated from the variables above.
  # To add more files, append { src = builtins.toFile "name" ''…''; dst = "/etc/nixos/name"; } to the list.
  seedFiles = [
    {
      src = builtins.toFile "machine.nix" ''
        { lib, ... }: {
          notenix.preset                         = lib.mkForce "${vmPreset}";
          notenix.system.autoupgrade.flakeRepo   = lib.mkForce "path:/etc/nixos";
          notenix.system.autoupgrade.hostName    = lib.mkForce "${vmHostName}";
          notenix.system.autoupgrade.operation   = lib.mkForce "switch";
          notenix.system.install.hostName        = lib.mkForce "${vmHostName}";
          notenix.system.install.userName        = lib.mkForce "${vmUserName}";
          notenix.system.install.userDescription = lib.mkForce "${vmUserDesc}";
          notenix.system.install.timeZone        = lib.mkForce "${vmTimeZone}";
          notenix.system.install.locale          = lib.mkForce "${vmLocale}";
          notenix.system.install.keyboardLayout  = lib.mkForce "${vmKeyboard}";
          system.stateVersion                    = "${vmStateVersion}";
        }
      '';
      dst = "/etc/nixos/machine.nix";
    }
    {
      src = builtins.toFile "flake.nix" ''
        # /etc/nixos/flake.nix — machine entry point (seeded by VM).
        # inputs.notenix.url is rewritten by kanal to switch branches.
        {
          inputs.notenix.url = "github:n1x05/notenix";
          outputs = { notenix, ... }: {
            nixosConfigurations.notenix =
              notenix.lib.mkMachineSystem { modules = [ ./machine.nix ]; };
          };
        }
      '';
      dst = "/etc/nixos/flake.nix";
    }
  ];

  # Shell snippet that copies each seedFile if the destination doesn't exist yet.
  seedScript = lib.concatMapStrings (f: ''
    if [ ! -e "${f.dst}" ]; then
      cp ${f.src} "${f.dst}"
      chmod 644 "${f.dst}"
    fi
  '') seedFiles;

  vmBaseModules = [
    ./modules
    nix-snapd.nixosModules.default
    ./hosts/notenix/configuration.nix
    "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
    vmOverrides
    { environment.systemPackages = [ kanal ]; }
    {
      virtualisation.diskSize    = 16384;
      virtualisation.memorySize  = 8192;
      virtualisation.cores       = 4;
      virtualisation.graphics    = true;
      virtualisation.resolution  = { x = 1440; y = 900; };
      # virtio-gpu with virgl gives GPU-accelerated rendering inside the VM
      virtualisation.qemu.options = [
        "-device" "virtio-vga-gl"
        "-display" "gtk,gl=on,zoom-to-fit=off"
      ];
      # Auto-login to GDM so the desktop appears immediately
      services.displayManager.autoLogin.enable = true;
      services.displayManager.autoLogin.user   = "user";
      # Disable screen lock — no password needed in the test VM
      programs.dconf.profiles.user.databases = lib.mkAfter [
        {
          lockAll  = false;
          settings."org/gnome/desktop/screensaver".lock-enabled = false;
          settings."org/gnome/desktop/session".idle-delay = lib.gvariant.mkUint32 0;
        }
      ];
      # Pre-seed /etc/nixos/machine.nix and flake.nix so kanal has something to edit.
      # Uses an activation script (not environment.etc) so the files are
      # real writable files, not read-only Nix store symlinks.
      system.activationScripts.notenix-machine = {
        text = ''
          mkdir -p /etc/nixos
          ${seedScript}
        '';
        deps = [];
      };
    }
  ];
in
lib.nixosSystem {
  inherit system;
  modules = vmBaseModules;
}
