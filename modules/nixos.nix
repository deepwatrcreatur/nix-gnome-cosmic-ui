{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.gnomeCosmicUi;

  monitorKey = builtins.toString cfg.monitorIndex;
  # dash-to-panel stores multi-monitor settings as JSON *strings* (schema type `s`).
  # So we must write a GVariant string that contains JSON.
  mkJson = value: "\"'{\\\"${monitorKey}\\\":${value}}'\"";
  mkJsonString = value: "\"'{\\\"${monitorKey}\\\":\\\"${value}\\\"}'\"";

  enabledExtensions =
    (lib.optionals cfg.enableDashToDock [ "dash-to-dock@micxgx.gmail.com" ])
    ++ (lib.optionals cfg.enableDashToPanel [ "dash-to-panel@jderose9.github.com" ])
    ++ (lib.optionals cfg.enableBlurMyShell [ "blur-my-shell@aunetx" ])
    ++ (lib.optionals cfg.enableSpaceBar [ "space-bar@luchrioh" ])
    ++ (lib.optionals (cfg.tiling == "forge" || cfg.tiling == "both") [ "forge@jmmaranan.com" ])
    ++ (lib.optionals (cfg.tiling == "tiling-assistant" || cfg.tiling == "both") [
      "tiling-assistant@leleat-on-github"
    ]);

  # Render enabledExtensions as a GVariant array string.
  mkGvariantStringArray =
    xs:
    let
      quoted = map (x: "'${x}'") xs;
    in
    "[" + lib.concatStringsSep ", " quoted + "]";

  desiredExtensionsGvariant = mkGvariantStringArray enabledExtensions;

  writeDconf = pkgs.writeShellScript "apply-gnome-cosmic-ui" ''
    set -eu

    ${lib.optionalString (cfg.user != null) ''
      if [ "''${USER:-}" != "${cfg.user}" ]; then
        exit 0
      fi
    ''}

    DCONF="${pkgs.dconf}/bin/dconf"
    if ! [ -x "$DCONF" ]; then
      exit 0
    fi

    # Merge our desired extensions with existing enabled-extensions.
    current="$($DCONF read /org/gnome/shell/enabled-extensions 2>/dev/null || echo "[]")"
    normalized=$(printf '%s' "$current" | tr -d "[]'" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d' || true)

    combined=""
    for ext in $normalized; do
      combined="$combined $ext"
    done

    for ext in ${lib.concatStringsSep " " enabledExtensions}; do
      case " $combined " in
        *" $ext "*) ;;
        *) combined="$combined $ext" ;;
      esac
    done

    out="["
    first=1
    for ext in $combined; do
      if [ $first -eq 1 ]; then
        first=0
      else
        out="$out, "
      fi
      out="$out'$ext'"
    done
    out="$out]"

    $DCONF write /org/gnome/shell/enabled-extensions "$out"

    $DCONF write /org/gnome/shell/show-applications-button "${
      if cfg.showApplicationsButton then "true" else "false"
    }"
    $DCONF write /org/gnome/shell/enable-hot-corners "${
      if cfg.enableHotCorners then "true" else "false"
    }"

    # Workspaces behavior
    $DCONF write /org/gnome/mutter/dynamic-workspaces "${
      if cfg.dynamicWorkspaces then "true" else "false"
    }"
    $DCONF write /org/gnome/mutter/workspaces-only-on-primary "${
      if cfg.workspacesOnlyOnPrimary then "true" else "false"
    }"

    # Dash-to-Panel: compact top bar
    ${lib.optionalString cfg.enableDashToPanel ''
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/panel-positions ${mkJsonString "TOP"}
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/panel-lengths ${mkJson (builtins.toString cfg.panelLength)}
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/panel-anchors ${mkJsonString cfg.panelAnchor}

      $DCONF write /org/gnome/shell/extensions/dash-to-panel/show-activities-button "${
        if cfg.showActivitiesButton then "true" else "false"
      }"
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/show-running-apps "${
        if cfg.showTaskbar then "true" else "false"
      }"
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/show-favorites "${
        if cfg.showTaskbar then "true" else "false"
      }"

      $DCONF write /org/gnome/shell/extensions/dash-to-panel/panel-top-bottom-margins "${builtins.toString cfg.panelMarginsY}"
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/panel-side-margins "${builtins.toString cfg.panelMarginsX}"
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/panel-top-bottom-padding "${builtins.toString cfg.panelPaddingY}"
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/panel-side-padding "${builtins.toString cfg.panelPaddingX}"
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/global-border-radius "${builtins.toString cfg.panelRadius}"

      $DCONF write /org/gnome/shell/extensions/dash-to-panel/trans-use-custom-opacity "true"
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/trans-use-dynamic-opacity "false"
      $DCONF write /org/gnome/shell/extensions/dash-to-panel/trans-panel-opacity "${builtins.toString cfg.panelOpacity}"
    ''}

    # Blur My Shell
    ${lib.optionalString cfg.enableBlurMyShell ''
      $DCONF write /org/gnome/shell/extensions/blur-my-shell/panel/blur "true"
      $DCONF write /org/gnome/shell/extensions/blur-my-shell/panel/customize "true"
      $DCONF write /org/gnome/shell/extensions/blur-my-shell/panel/sigma "${builtins.toString cfg.blurSigma}"
      $DCONF write /org/gnome/shell/extensions/blur-my-shell/panel/brightness "${builtins.toString cfg.blurBrightness}"
      $DCONF write /org/gnome/shell/extensions/blur-my-shell/panel/static-blur "true"
      $DCONF write /org/gnome/shell/extensions/blur-my-shell/panel/unblur-in-overview "false"

      $DCONF write /org/gnome/shell/extensions/blur-my-shell/overview/blur "${
        if cfg.blurOverview then "true" else "false"
      }"
      $DCONF write /org/gnome/shell/extensions/blur-my-shell/dash-to-panel/blur-original-panel "true"
    ''}

    # Space Bar (numbered workspaces in the panel)
    ${lib.optionalString cfg.enableSpaceBar ''
      $DCONF write /org/gnome/shell/extensions/space-bar/behavior/indicator-style "'workspaces-bar'"
      $DCONF write /org/gnome/shell/extensions/space-bar/behavior/always-show-numbers "${
        if cfg.spaceBarAlwaysShowNumbers then "true" else "false"
      }"
      $DCONF write /org/gnome/shell/extensions/space-bar/behavior/show-empty-workspaces "${
        if cfg.spaceBarShowEmptyWorkspaces then "true" else "false"
      }"
      $DCONF write /org/gnome/shell/extensions/space-bar/behavior/toggle-overview "${
        if cfg.spaceBarToggleOverview then "true" else "false"
      }"
      $DCONF write /org/gnome/shell/extensions/space-bar/behavior/position "'${cfg.spaceBarPosition}'"
    ''}

    # Dash to Dock (separate dock)
    ${lib.optionalString cfg.enableDashToDock ''
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/dock-position "'${cfg.dockPosition}'"
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/dock-fixed "false"
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/intellihide "true"
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/autohide "true"
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/autohide-in-fullscreen "true"
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/show-apps-at-top "true"
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/transparency-mode "'FIXED'"
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/background-opacity "${builtins.toString cfg.dockOpacity}"
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/custom-theme-shrink "true"
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/icon-size "${builtins.toString cfg.dockIconSize}"
      $DCONF write /org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size "${builtins.toString cfg.dockIconSize}"
    ''}

    # Forge tiling (per-workspace control via workspace-skip-tile)
    ${lib.optionalString (cfg.tiling == "forge" || cfg.tiling == "both") ''
      $DCONF write /org/gnome/shell/extensions/forge/tiling-mode-enabled "true"
      $DCONF write /org/gnome/shell/extensions/forge/quick-settings-enabled "true"
      $DCONF write /org/gnome/shell/extensions/forge/workspace-skip-tile "'${cfg.forgeWorkspaceSkipTile}'"
    ''}
  '';

in
{
  options.services.gnomeCosmicUi = {
    enable = lib.mkEnableOption "COSMIC-like GNOME panel/dock/workspaces";

    # Because GNOME settings are per-user, we optionally guard the service.
    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "If set, only apply settings when $USER matches.";
    };

    monitorIndex = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Monitor index key used by dash-to-panel JSON settings.";
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

    # GNOME Shell buttons
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

    # Dash-to-panel shape/size/opacity
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
      description = "Panel length percentage for dash-to-panel; -1 means dynamic/shrink.";
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

    # Taskbar behavior (dash-to-panel embedded dash)
    showTaskbar = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, dash-to-panel shows running apps/favorites.";
    };

    # Blur My Shell
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

    # Space Bar
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
      description = "Clicking the workspace bar toggles GNOME Overview (gives previews + drag windows).";
    };
    spaceBarPosition = lib.mkOption {
      type = lib.types.enum [
        "left"
        "center"
        "right"
      ];
      default = "center";
    };

    # Dash to Dock
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

    # Workspaces behavior
    dynamicWorkspaces = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    workspacesOnlyOnPrimary = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    # Tiling
    tiling = lib.mkOption {
      type = lib.types.enum [
        "none"
        "forge"
        "tiling-assistant"
        "both"
      ];
      default = "forge";
      description = "Which tiling extension(s) to enable.";
    };

    # Forge: empty string means tile everywhere
    forgeWorkspaceSkipTile = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Comma-separated workspace indices to skip tiling (Forge workspace-skip-tile).";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.dconf.enable = true;

    environment.systemPackages = [
      pkgs.gnome-shell-extensions
      pkgs.dconf
    ]
    ++ lib.optionals cfg.enableDashToDock [ pkgs.gnomeExtensions.dash-to-dock ]
    ++ lib.optionals cfg.enableDashToPanel [ pkgs.gnomeExtensions.dash-to-panel ]
    ++ lib.optionals cfg.enableBlurMyShell [ pkgs.gnomeExtensions.blur-my-shell ]
    ++ lib.optionals cfg.enableSpaceBar [ pkgs.gnomeExtensions.space-bar ]
    ++ lib.optionals (cfg.tiling == "forge" || cfg.tiling == "both") [ pkgs.gnomeExtensions.forge ]
    ++ lib.optionals (cfg.tiling == "tiling-assistant" || cfg.tiling == "both") [
      pkgs.gnomeExtensions.tiling-assistant
    ];

    systemd.user.services.gnome-cosmic-ui-apply = {
      description = "Apply COSMIC-like GNOME UI (panel/dock/workspaces)";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [
        "graphical-session.target"
        "dbus.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${writeDconf}";
      };
    };
  };
}
