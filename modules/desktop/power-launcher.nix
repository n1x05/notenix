{ config, lib, pkgs, ... }:

let
  cfg = config.notenix.features.powerOffLauncher;
  launcher = pkgs.writeTextFile {
    name = "notenix-poweroff-launcher";
    destination = "/share/applications/notenix-poweroff.desktop";
    text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=Power Off
      Name[sl]=Izklop
      Comment=Power off
      Comment[sl]=Izklop
      Icon=system-shutdown
      Exec=systemctl poweroff
      Terminal=false
      Categories=System;
      Keywords=poweroff;shutdown;system;
      Keywords[sl]=izklop;ugasni;sistem;
    '';
  };
in
{
  config = lib.mkIf cfg {
    environment.systemPackages = [ launcher ];
  };
}