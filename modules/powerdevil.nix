{ config, lib, ... }:
let
  cfg = config.programs.plasma;

  powerButtonActions = {
    nothing = 0;
    sleep = 1;
    hibernate = 2;
    shutDown = 8;
    lockScreen = 32;
    showLogoutScreen = null;
    turnOffScreen = 64;
  };

  autoSuspendActions = {
    nothing = 0;
    hibernate = 2;
    sleep = null;
    shutDown = 8;
  };

  whenSleepingEnterActions = {
    standby = null;
    hybridSleep = 2;
    standbyThenHibernate = 3;
  };

  whenLaptopLidClosedActions = {
    doNothing = 0;
    sleep = null;
    hibernate = 2;
    shutdown = 8;
    lockScreen = 32;
    turnOffScreen = 64;
  };

  # Since AC and battery allows the same options we create a function here which
  # can generate the options by just specifying the type (i.e. "AC" or
  # "battery").
  createPowerDevilOptions = type: {
    powerButtonAction = lib.mkOption {
      type = with lib.types; nullOr (enum (builtins.attrNames powerButtonActions));
      default = null;
      example = "nothing";
      description = ''
        The action, when on ${type}, to perform when the power button is pressed.
      '';
      apply = action: if (action == null) then null else powerButtonActions."${action}";
    };
    autoSuspend = {
      action = lib.mkOption {
        type = with lib.types; nullOr (enum (builtins.attrNames autoSuspendActions));
        default = null;
        example = "nothing";
        description = ''
          The action, when on ${type}, to perform after a certain period of inactivity.
        '';
        apply = action: if (action == null) then null else autoSuspendActions."${action}";
      };
      idleTimeout = lib.mkOption {
        type = with lib.types; nullOr (ints.between 60 600000);
        default = null;
        example = 600;
        description = ''
          The duration (in seconds), when on ${type}, the computer must be idle
          until the auto-suspend action is executed.
        '';
      };
    };
    whenSleepingEnter = lib.mkOption {
      type = with lib.types; nullOr (enum (builtins.attrNames whenSleepingEnterActions));
      default = null;
      example = "standbyThenHibernate";
      description = ''
        The state, when on ${type}, to enter when sleeping.
      '';
      apply = action: if (action == null) then null else whenSleepingEnterActions."${action}";
    };
    whenLaptopLidClosed = lib.mkOption {
      type = with lib.types; nullOr (enum (builtins.attrNames whenLaptopLidClosedActions));
      default = null;
      example = "shutdown";
      description = ''
        The action, when on ${type}, to perform when the laptop lid is closed.
      '';
      apply = action: if (action == null) then null else whenLaptopLidClosedActions."${action}";
    };
    turnOffDisplay = {
      idleTimeout = lib.mkOption {
        type = with lib.types; nullOr (either (enum [ "never" ]) (ints.between 30 600000));
        default = null;
        example = 300;
        description = ''
          The duration (in seconds), when on ${type}, the computer must be idle
          (when unlocked) until the display turns off.
        '';
        apply = timeout:
          if (timeout == null) then null else
          if (timeout == "never") then -1
          else timeout;
      };
      idleTimeoutWhenLocked = lib.mkOption {
        type = with lib.types; nullOr (either (enum [ "whenLockedAndUnlocked" "immediately" ]) (ints.between 20 600000));
        default = null;
        example = 60;
        description = ''
          The duration (in seconds), when on ${type}, the computer must be idle
          (when locked) until the display turns off.
        '';
        apply = timeout:
          if (timeout == null) then null else
          if (timeout == "whenLockedAndUnlocked") then -2 else
          if (timeout == "immediately") then 0
          else timeout;
      };
    };
    dimDisplay = {
      enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = false;
        description = "Enable or disable screen dimming.";
      };
      idleTimeOut = lib.mkOption {
        type = with lib.types; nullOr (ints.between 20 600000);
        default = null;
        example = 300;
        description = ''
          The duration (in seconds), when on ${type}, the computer must be idle
          until the display starts dimming.
        '';
      };
    };
  };

  # By the same logic as createPowerDevilOptions, we can generate the
  # configuration. cfgSectName is here the name of the section in powerdevilrc,
  # while optionsName is the name of the "namespace" where we should draw the
  # options from (i.e. powerdevil.AC or powerdevil.battery).
  createPowerDevilConfig = cfgSectName: optionsName: {
    "${cfgSectName}/SuspendAndShutdown" = {
      PowerButtonAction = cfg.powerdevil.${optionsName}.powerButtonAction;
      AutoSuspendAction = cfg.powerdevil.${optionsName}.autoSuspend.action;
      AutoSuspendIdleTimeoutSec = cfg.powerdevil.${optionsName}.autoSuspend.idleTimeout;
      SleepMode = cfg.powerdevil.${optionsName}.whenSleepingEnter;
      LidAction = cfg.powerdevil.${optionsName}.whenLaptopLidClosed;
    };
    "${cfgSectName}/Display" = {
      TurnOffDisplayIdleTimeoutSec = cfg.powerdevil.${optionsName}.turnOffDisplay.idleTimeout;
      TurnOffDisplayIdleTimeoutWhenLockedSec = cfg.powerdevil.${optionsName}.turnOffDisplay.idleTimeoutWhenLocked;
      DimDisplayWhenIdle =
        if (cfg.powerdevil.${optionsName}.dimDisplay.enable != null) then
          cfg.powerdevil.${optionsName}.dimDisplay.enable
        else if (cfg.powerdevil.${optionsName}.dimDisplay.idleTimeOut != null) then
          true
        else
          null;
      DimDisplayIdleTimeoutSec = cfg.powerdevil.${optionsName}.dimDisplay.idleTimeOut;
    };
  };
in
{
  imports = [
    (lib.mkRenamedOptionModule [ "programs" "plasma" "powerdevil" "powerButtonAction" ] [ "programs" "plasma" "powerdevil" "AC" "powerButtonAction" ])
    (lib.mkRenamedOptionModule [ "programs" "plasma" "powerdevil" "autoSuspend" ] [ "programs" "plasma" "powerdevil" "AC" "autoSuspend" ])
    (lib.mkRenamedOptionModule [ "programs" "plasma" "powerdevil" "turnOffDisplay" ] [ "programs" "plasma" "powerdevil" "AC" "turnOffDisplay" ])
  ];

  config.assertions =
    let
      createAssertions = type: [
        {
          assertion = (cfg.powerdevil.${type}.autoSuspend.action != autoSuspendActions.nothing || cfg.powerdevil.${type}.autoSuspend.idleTimeout == null);
          message = "Setting programs.plasma.powerdevil.${type}.autoSuspend.idleTimeout for autosuspend-action \"nothing\" is not supported.";
        }
        {
          assertion = (cfg.powerdevil.${type}.turnOffDisplay.idleTimeout != -1 || cfg.powerdevil.${type}.turnOffDisplay.idleTimeoutWhenLocked == null);
          message = "Setting programs.plasma.powerdevil.${type}.turnOffDisplay.idleTimeoutWhenLocked for idleTimeout \"never\" is not supported.";
        }
        {
          assertion = (cfg.powerdevil.${type}.dimDisplay.enable != false || cfg.powerdevil.${type}.dimDisplay.idleTimeOut == null);
          message = "Cannot set programs.plasma.powerdevil.${type}.dimDisplay.idleTimeOut when programs.plasma.powerdevil.${type}.dimDisplay.enable is disabled.";
        }
      ];
    in
    (createAssertions "AC") ++ (createAssertions "battery") ++ (createAssertions "lowBattery");

  options = {
    programs.plasma.powerdevil = {
      AC = (createPowerDevilOptions "AC");
      battery = (createPowerDevilOptions "battery");
      lowBattery = (createPowerDevilOptions "lowBattery");
    };
  };

  config.programs.plasma.configFile = lib.mkIf cfg.enable {
    powerdevilrc = lib.filterAttrs (k: v: v != null) ((createPowerDevilConfig "AC" "AC")
      // (createPowerDevilConfig "Battery" "battery")
      // (createPowerDevilConfig "LowBattery" "lowBattery"));
  };
}
