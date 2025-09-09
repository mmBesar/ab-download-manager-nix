{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.ab-download-manager;
in
{
  options.programs.ab-download-manager = {
    enable = mkEnableOption "AB Download Manager";

    package = mkOption {
      type = types.package;
      default = pkgs.ab-download-manager or (pkgs.callPackage ./package.nix { });
      description = "The AB Download Manager package to use";
    };

    autoStart = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to auto-start AB Download Manager";
    };

    systemTray = mkOption {
      type = types.bool;
      default = true;
      description = "Enable system tray integration";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Desktop integration
    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/http" = [ "ab-download-manager.desktop" ];
      "x-scheme-handler/https" = [ "ab-download-manager.desktop" ];
    };

    # Auto-start configuration
    xdg.configFile."autostart/ab-download-manager.desktop" = mkIf cfg.autoStart {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=AB Download Manager
        Comment=A download manager that speeds up your downloads
        Exec=${cfg.package}/bin/ab-download-manager --minimized
        Icon=ab-download-manager
        Hidden=false
        NoDisplay=false
        X-GNOME-Autostart-enabled=true
        StartupNotify=false
        Terminal=false
        Categories=Network;FileTransfer;
      '';
    };

    # Browser integration directory
    xdg.dataFile."ab-download-manager/.keep".text = "";
  };
}
