{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.yoake;
in
{
  options.programs.yoake = {
    enable = mkEnableOption "system-level support for the Yoake desktop shell";
  };

  config = mkIf cfg.enable {
    networking.networkmanager.enable = mkDefault true;
    hardware.bluetooth.enable = mkDefault true;
    services.power-profiles-daemon.enable = mkDefault true;
    security.rtkit.enable = mkDefault true;

    services.pipewire = {
      enable = mkDefault true;
      alsa.enable = mkDefault true;
      alsa.support32Bit = mkDefault true;
      pulse.enable = mkDefault true;
    };

    fonts.packages = [ pkgs.nerd-fonts.iosevka ];
  };
}
