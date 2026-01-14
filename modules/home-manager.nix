{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.gnomeCosmicUi;

  enabledExtensions =
    (lib.optionals cfg.enableDashToDock [ "dash-to-dock@micxgx.gmail.com" ])
    ++ (lib.optionals cfg.enableDashToPanel [ "dash-to-panel@jderose9.github.com" ])
    ++ (lib.optionals cfg.enableBlurMyShell [ "blur-my-shell@aunetx" ])
    ++ (lib.optionals cfg.enableSpaceBar [ "space-bar@luchrioh" ])
    ++ (lib.optionals (cfg.tiling == "forge" || cfg.tiling == "both") [ "forge@jmmaranan.com" ])
    ++ (lib.optionals (cfg.tiling == "tiling-assistant" || cfg.tiling == "both") [
      "tiling-assistant@leleat-on-github"
    ]);

  monitorKey = builtins.toString cfg.monitorIndex;
  jsonString = value: "{\"${monitorKey}\":\"${value}\"}";
  jsonNumber = value: "{\"${monitorKey}\":${value}}";
in
{
  options.programs.gnomeCosmicUi = {
    enable = lib.mkEnableOption "COSMIC-like GNOME panel/dock/workspaces";

    monitorIndex = lib.mkOption {
      type = lib.types.int;
      default = 0;
    };

    enableDashToPanel = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    enableBlurMyShell = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    enableSpaceBar = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    enableDashToDock = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    showApplicationsButton = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    showActivitiesButton = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    enableHotCorners = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    panelOpacity = lib.mkOption {
      type = lib.types.float;
      default = 0.15;
    };
    panelRadius = lib.mkOption {
      type = lib.types.int;
      default = 18;
    };
    panelLength = lib.mkOption {
      type = lib.types.int;
      default = -1;
    };
    panelAnchor = lib.mkOption {
      type = lib.types.enum [
        "START"
        "MIDDLE"
        "END"
      ];
      default = "MIDDLE";
    };
    panelMarginsX = lib.mkOption {
      type = lib.types.int;
      default = 10;
    };
    panelMarginsY = lib.mkOption {
      type = lib.types.int;
      default = 6;
    };
    panelPaddingX = lib.mkOption {
      type = lib.types.int;
      default = 6;
    };
    panelPaddingY = lib.mkOption {
      type = lib.types.int;
      default = 4;
    };
    showTaskbar = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    blurSigma = lib.mkOption {
      type = lib.types.int;
      default = 15;
    };
    blurBrightness = lib.mkOption {
      type = lib.types.float;
      default = 0.8;
    };
    blurOverview = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    spaceBarAlwaysShowNumbers = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    spaceBarShowEmptyWorkspaces = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    spaceBarToggleOverview = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    spaceBarPosition = lib.mkOption {
      type = lib.types.enum [
        "left"
        "center"
        "right"
      ];
      default = "center";
    };

    dockPosition = lib.mkOption {
      type = lib.types.enum [
        "LEFT"
        "RIGHT"
        "TOP"
        "BOTTOM"
      ];
      default = "BOTTOM";
    };
    dockOpacity = lib.mkOption {
      type = lib.types.float;
      default = 0.15;
    };
    dockIconSize = lib.mkOption {
      type = lib.types.int;
      default = 48;
    };

    dynamicWorkspaces = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    workspacesOnlyOnPrimary = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    tiling = lib.mkOption {
      type = lib.types.enum [
        "none"
        "forge"
        "tiling-assistant"
        "both"
      ];
      default = "forge";
    };
    forgeWorkspaceSkipTile = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      lib.optionals cfg.enableDashToDock [ pkgs.gnomeExtensions.dash-to-dock ]
      ++ lib.optionals cfg.enableDashToPanel [ pkgs.gnomeExtensions.dash-to-panel ]
      ++ lib.optionals cfg.enableBlurMyShell [ pkgs.gnomeExtensions.blur-my-shell ]
      ++ lib.optionals cfg.enableSpaceBar [ pkgs.gnomeExtensions.space-bar ]
      ++ lib.optionals (cfg.tiling == "forge" || cfg.tiling == "both") [ pkgs.gnomeExtensions.forge ]
      ++ lib.optionals (cfg.tiling == "tiling-assistant" || cfg.tiling == "both") [
        pkgs.gnomeExtensions.tiling-assistant
      ];

    dconf.settings = {
      "org/gnome/shell" = {
        enabled-extensions = enabledExtensions;
        show-applications-button = cfg.showApplicationsButton;
        enable-hot-corners = cfg.enableHotCorners;
      };

      "org/gnome/mutter" = {
        dynamic-workspaces = cfg.dynamicWorkspaces;
        workspaces-only-on-primary = cfg.workspacesOnlyOnPrimary;
      };

      "org/gnome/shell/extensions/dash-to-panel" = lib.mkIf cfg.enableDashToPanel {
        panel-positions = jsonString "TOP";
        panel-lengths = jsonNumber (builtins.toString cfg.panelLength);
        panel-anchors = jsonString cfg.panelAnchor;

        show-activities-button = cfg.showActivitiesButton;
        show-running-apps = cfg.showTaskbar;
        show-favorites = cfg.showTaskbar;

        panel-top-bottom-margins = cfg.panelMarginsY;
        panel-side-margins = cfg.panelMarginsX;
        panel-top-bottom-padding = cfg.panelPaddingY;
        panel-side-padding = cfg.panelPaddingX;
        global-border-radius = cfg.panelRadius;

        trans-use-custom-opacity = true;
        trans-use-dynamic-opacity = false;
        trans-panel-opacity = cfg.panelOpacity;
      };

      "org/gnome/shell/extensions/blur-my-shell/panel" = lib.mkIf cfg.enableBlurMyShell {
        blur = true;
        customize = true;
        sigma = cfg.blurSigma;
        brightness = cfg.blurBrightness;
        static-blur = true;
        unblur-in-overview = false;
      };

      "org/gnome/shell/extensions/blur-my-shell/overview" = lib.mkIf cfg.enableBlurMyShell {
        blur = cfg.blurOverview;
      };

      "org/gnome/shell/extensions/blur-my-shell/dash-to-panel" = lib.mkIf cfg.enableBlurMyShell {
        blur-original-panel = true;
      };

      "org/gnome/shell/extensions/space-bar/behavior" = lib.mkIf cfg.enableSpaceBar {
        indicator-style = "workspaces-bar";
        always-show-numbers = cfg.spaceBarAlwaysShowNumbers;
        show-empty-workspaces = cfg.spaceBarShowEmptyWorkspaces;
        toggle-overview = cfg.spaceBarToggleOverview;
        position = cfg.spaceBarPosition;
      };

      "org/gnome/shell/extensions/dash-to-dock" = lib.mkIf cfg.enableDashToDock {
        dock-position = cfg.dockPosition;
        dock-fixed = false;
        intellihide = true;
        autohide = true;
        autohide-in-fullscreen = true;
        show-apps-at-top = true;
        transparency-mode = "FIXED";
        background-opacity = cfg.dockOpacity;
        custom-theme-shrink = true;
        icon-size = cfg.dockIconSize;
        dash-max-icon-size = cfg.dockIconSize;
      };

      "org/gnome/shell/extensions/forge" = lib.mkIf (cfg.tiling == "forge" || cfg.tiling == "both") {
        tiling-mode-enabled = true;
        quick-settings-enabled = true;
        workspace-skip-tile = cfg.forgeWorkspaceSkipTile;
      };
    };
  };
}
