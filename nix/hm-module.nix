{ self, ... }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.yoake;
  system = pkgs.stdenv.hostPlatform.system;

  jsonFormat = pkgs.formats.json { };
  inherit (import ./settings-options.nix { inherit lib pkgs; }) settingsSubmodule;

  templateSettings = builtins.fromJSON (builtins.readFile "${self}/config/yoake/settings.json");

  userSettings = lib.filterAttrsRecursive (_: v: v != null) cfg.settings;

  mergedSettings = lib.recursiveUpdate templateSettings userSettings;
  settingsFile = jsonFormat.generate "yoake-settings.json" mergedSettings;

  settingsTarget = "${config.xdg.configHome}/yoake/settings.json";
in
{
  options.programs.yoake = {
    enable = mkEnableOption "the Yoake Quickshell desktop shell";

    package = mkOption {
      type = types.package;
      default = self.packages.${system}.default;
      defaultText = literalExpression "yoake.packages.<system>.default";
      description = "The Yoake package to use.";
    };

    settings = mkOption {
      type = settingsSubmodule;
      default = { };
      example = literalExpression ''
        {
          bar.position = "left";
          bar.modules.right = [ "tray" [ "kb" "wifi" "bt" "vol" "bat" ] ];
          theme.fontFamily = "Adwaita Mono";
          notifications.dnd = true;
        }
      '';
      description = ''
        Yoake configuration, layered on top of the package's
        bundled `config/yoake/settings.json` and written to
        `$XDG_CONFIG_HOME/yoake/settings.json`.
        See settings-options.nix for the full list of typed fields;
        anything not listed there can still be set as a plain
        attribute.
      '';
    };

    systemd = {
      enable = mkOption {
        type = types.bool;
        default = pkgs.stdenv.isLinux;
        description = "Whether to run yoaked as a `systemd --user` service.";
      };

      target = mkOption {
        type = types.str;
        default = "graphical-session.target";
        description = "Target yoaked is tied to (start/stop/restart with it).";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = { QT_QPA_PLATFORM = "wayland"; };
        description = "Extra environment variables for the yoaked unit.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.yoake.settings.wallpaperDir = mkDefault "${config.home.homeDirectory}/Pictures/Wallpapers";

    home.activation.yoakeSettings = hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${escapeShellArg (builtins.dirOf settingsTarget)}
      run install -m 0644 ${settingsFile} ${escapeShellArg settingsTarget}
    '';

    systemd.user.services.yoake = mkIf cfg.systemd.enable {
      Unit = {
        Description = "Yoake shell daemon";
        After = [ cfg.systemd.target ];
        PartOf = [ cfg.systemd.target ];
        X-Restart-Triggers = [ "${settingsFile}" ];
      };

      Service = {
        ExecStart = "${cfg.package}/bin/yoaked";
        Restart = "on-failure";
        Environment = mapAttrsToList (n: v: "${n}=${v}") cfg.systemd.environment;
      };

      Install.WantedBy = [ cfg.systemd.target ];
    };
  };
}
