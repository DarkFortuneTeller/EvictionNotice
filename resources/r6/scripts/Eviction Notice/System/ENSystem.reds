// -----------------------------------------------------------------------------
// ENSystem
// -----------------------------------------------------------------------------
//
// - Base class for nearly all Eviction Notice ScriptableSystems.
// - Provides a common interface for handling system startup, shutdown,
//   querying required systems, registering for callbacks and listeners, etc.
//

module EvictionNotice.System

import EvictionNotice.Logging.*
import EvictionNotice.Main.{
    ENTimeSkipData,
    MainSystemPlayerDeathEvent,
    MainSystemTimeSkipFinishedEvent
}
import EvictionNotice.Settings.{
    ENSettings,
    SettingChangedEvent
}

enum ENSystemState {
    Uninitialized = 0,
    Suspended = 1,
    Running = 2
}


public func IsSystemEnabledAndRunning(system: ref<ENSystem>) -> Bool {
    if !ENSettings.Get().mainSystemEnabled { return false; }

    return system.GetSystemToggleSettingValue() && Equals(system.state, ENSystemState.Running);
}

public abstract class ENSystemEventListener extends ScriptableService {
	//
	// Required Overrides
	//
	private func GetSystemInstance() -> wref<ENSystem> {
		ENLog(true, this, "MISSING REQUIRED METHOD OVERRIDE FOR GetSystemInstance()", ENLogLevel.Error);
		return null;
	}

	private cb func OnLoad() {
		GameInstance.GetCallbackSystem().RegisterCallback(n"EvictionNotice.Main.MainSystemPlayerDeathEvent", this, n"OnMainSystemPlayerDeathEvent", true);
		GameInstance.GetCallbackSystem().RegisterCallback(n"EvictionNotice.Main.MainSystemTimeSkipFinishedEvent", this, n"OnMainSystemTimeSkipFinishedEvent", true);
        GameInstance.GetCallbackSystem().RegisterCallback(n"EvictionNotice.Settings.SettingChangedEvent", this, n"OnSettingChangedEvent", true);
    }

	private cb func OnMainSystemPlayerDeathEvent(event: ref<MainSystemPlayerDeathEvent>) {
        this.GetSystemInstance().OnPlayerDeath();
    }

	private cb func OnMainSystemTimeSkipFinishedEvent(event: ref<MainSystemTimeSkipFinishedEvent>) {
        this.GetSystemInstance().OnTimeSkipFinished(event.GetData());
    }

    private cb func OnSettingChangedEvent(event: ref<SettingChangedEvent>) {
		this.GetSystemInstance().OnSettingChanged(event.GetData());
    }
}

public abstract class ENSystem extends ScriptableSystem {
    public let state: ENSystemState = ENSystemState.Uninitialized;
    private let debugEnabled: Bool = true;
    private let player: ref<PlayerPuppet>;
    private let Settings: ref<ENSettings>;
    private let DelaySystem: ref<DelaySystem>;

    public func Init(attachedPlayer: ref<PlayerPuppet>) -> Void {
        this.player = attachedPlayer;
		this.DoInitActions(attachedPlayer);
        this.InitSpecific(attachedPlayer);

        // Now that all data has been set correctly, if this system should be
        // toggled off, suspend it.
        if Equals(this.GetSystemToggleSettingValue(), false) {
            this.Suspend();
        }
    }

    private func DoInitActions(attachedPlayer: ref<PlayerPuppet>) -> Void {
        this.SetupDebugLogging();
		ENLog(this.debugEnabled, this, "Init");

        this.GetRequiredSystems();
		this.GetSystems();
		this.GetBlackboards(attachedPlayer);
        this.SetupData();
		this.RegisterListeners();
        this.RegisterAllRequiredDelayCallbacks();

        this.state = ENSystemState.Running;
        ENLog(this.debugEnabled, this, "INIT - Current State: " + ToString(this.state));
    }

    public func Suspend() -> Void {
        ENLog(this.debugEnabled, this, "SUSPEND - Current State: " + ToString(this.state));
        if Equals(this.state, ENSystemState.Running) {
            this.state = ENSystemState.Suspended;
            this.UnregisterAllDelayCallbacks();
            this.DoPostSuspendActions();
        }
        ENLog(this.debugEnabled, this, "SUSPEND - Current State: " + ToString(this.state));
    }

    public func Resume() -> Void {
        ENLog(this.debugEnabled, this, "RESUME - Current State: " + ToString(this.state));
        if Equals(this.state, ENSystemState.Suspended) {
            this.state = ENSystemState.Running;
            this.RegisterAllRequiredDelayCallbacks();
            this.DoPostResumeActions();
        }
        ENLog(this.debugEnabled, this, "RESUME - Current State: " + ToString(this.state));
    }

    public func Stop() -> Void {
        this.UnregisterListeners();
        this.UnregisterAllDelayCallbacks();

        this.state = ENSystemState.Uninitialized;
    }

    public func OnPlayerDeath() -> Void {
        this.Stop();
	}

    private func GetRequiredSystems() -> Void {
        let gameInstance = GetGameInstance();
        this.Settings = ENSettings.GetInstance(gameInstance);
        this.DelaySystem = GameInstance.GetDelaySystem(gameInstance);
    }

    public func OnSettingChanged(changedSettings: array<String>) -> Void {
        // Check for specific system toggle
        if this.Settings.mainSystemEnabled {
            if ArrayContains(changedSettings, this.GetSystemToggleSettingString()) {
                if Equals(this.GetSystemToggleSettingValue(), true) {
                    this.Resume();
                } else {
                    this.Suspend();
                }
            }
        }
        

        this.OnSettingChangedSpecific(changedSettings);
    }

    //
    //  Required Overrides
    //
    private func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {
        this.LogMissingOverrideError("InitSpecific");
    }

    private func GetSystemToggleSettingValue() -> Bool {
        this.LogMissingOverrideError("GetSystemToggleSettingValue");
        return false;
    }

    private func GetSystemToggleSettingString() -> String {
        this.LogMissingOverrideError("GetSystemToggleSettingString");
        return "INVALID";
    }

    private func DoPostSuspendActions() -> Void {
        this.LogMissingOverrideError("DoPostSuspendActions");
    }

    private func DoPostResumeActions() -> Void {
        this.LogMissingOverrideError("DoPostResumeActions");
    }

    private func SetupDebugLogging() -> Void {
		this.LogMissingOverrideError("SetupDebugLogging");
	}

    private func GetSystems() -> Void {
        this.LogMissingOverrideError("GetSystems");
    }

    private func GetBlackboards(attachedPlayer: ref<PlayerPuppet>) -> Void {
        this.LogMissingOverrideError("GetBlackboards");
    }

    private func SetupData() -> Void {
        this.LogMissingOverrideError("SetupData");
    }

    private func RegisterListeners() -> Void {
		this.LogMissingOverrideError("RegisterListeners");
	}

    private func UnregisterListeners() -> Void {
		this.LogMissingOverrideError("UnregisterListeners");
	}

    private func RegisterAllRequiredDelayCallbacks() -> Void {
        this.LogMissingOverrideError("RegisterAllRequiredDelayCallbacks");
    }

    private func UnregisterAllDelayCallbacks() -> Void {
        this.LogMissingOverrideError("UnregisterAllDelayCallbacks");
    }

	public func OnTimeSkipFinished(data: ENTimeSkipData) -> Void {
		this.LogMissingOverrideError("OnTimeSkipFinished");
	}

    public func OnSettingChangedSpecific(changedSettings: array<String>) {
        this.LogMissingOverrideError("OnSettingChangedSpecific");
    }

    //
	//	Logging
	//
	private final func LogMissingOverrideError(funcName: String) -> Void {
		ENLog(true, this, "MISSING REQUIRED METHOD OVERRIDE FOR " + funcName + "()", ENLogLevel.Error);
	}
}

/* Required Override Template

//
//  ENSystem Required Methods
//
private func SetupDebugLogging() -> Void {}
private func GetSystemToggleSettingValue() -> Bool {}
private func GetSystemToggleSettingString() -> String {}
private func DoPostSuspendActions() -> Void {}
private func DoPostResumeActions() -> Void {}
private func GetSystems() -> Void {}
private func GetBlackboards(attachedPlayer: ref<PlayerPuppet>) -> Void {}
private func SetupData() -> Void {}
private func RegisterListeners() -> Void {}
private func RegisterAllRequiredDelayCallbacks() -> Void {}
private func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {}
private func UnregisterListeners() -> Void {}
private func UnregisterAllDelayCallbacks() -> Void {}
public func OnTimeSkipStart() -> Void {}
public func OnTimeSkipCancelled() -> Void {}
public func OnTimeSkipFinished(data: ENTimeSkipData) -> Void {}
public func OnSettingChangedSpecific(changedSettings: array<String>) -> Void {}

*/