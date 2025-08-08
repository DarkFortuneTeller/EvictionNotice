// -----------------------------------------------------------------------------
// ENGameStateService
// -----------------------------------------------------------------------------
//
// - A service that allows querying whether or not the game's current state is 
//   "valid" for the purposes of Eviction Notice.
//
// - To obtain whether or not the current game state is valid, use IsValidGameState().
// - To obtain the specific game state, use GetGameState().
//

module EvictionNotice.Services

import EvictionNotice.Logging.*
import EvictionNotice.System.*
import EvictionNotice.Settings.*
import EvictionNotice.Main.{
    ENMainSystem,
    ENTimeSkipData
}

enum GameState {
    Valid = 0,
    Invalid = 1
}

class ENGameStateServiceEventListener extends ENSystemEventListener {
	private func GetSystemInstance() -> wref<ENGameStateService> {
		return ENGameStateService.Get();
	}
}

public final class ENGameStateService extends ENSystem {
    private let QuestsSystem: ref<QuestsSystem>;

    private let baseGamePointOfNoReturnFactListener: Uint32;
    private let baseGamePointOfNoReturnDone: Bool = false;

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENGameStateService> {
		let instance: ref<ENGameStateService> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"EvictionNotice.Services.ENGameStateService") as ENGameStateService;
		return instance;
	}

    public final static func Get() -> ref<ENGameStateService> {
        return ENGameStateService.GetInstance(GetGameInstance());
	}

    //
    //  ENSystem Required Methods
    //
    private func RegisterAllRequiredDelayCallbacks() -> Void {}
    private func UnregisterAllDelayCallbacks() -> Void {}
    private func SetupData() -> Void {}
    public func OnTimeSkipStart() -> Void {}
    public func OnTimeSkipCancelled() -> Void {}
    public func OnTimeSkipFinished(data: ENTimeSkipData) -> Void {}
    public func OnSettingChangedSpecific(changedSettings: array<String>) -> Void {}

    private func SetupDebugLogging() -> Void {
        this.debugEnabled = false;
    }

    private func DoPostSuspendActions() -> Void {}
    private func DoPostResumeActions() -> Void {}

    private func GetSystems() -> Void {
        let gameInstance = GetGameInstance();
        this.QuestsSystem = GameInstance.GetQuestsSystem(gameInstance);
    }

    private func GetBlackboards(attachedPlayer: ref<PlayerPuppet>) -> Void {}

    private func RegisterListeners() -> Void {
        this.baseGamePointOfNoReturnFactListener = this.QuestsSystem.RegisterListener(n"q115_point_of_no_return", this, n"OnBaseGamePointOfNoReturnFactChanged");
    }

    private func UnregisterListeners() -> Void {
        this.QuestsSystem.UnregisterListener(n"q115_point_of_no_return", this.baseGamePointOfNoReturnFactListener);
        this.baseGamePointOfNoReturnFactListener = 0u;
    }

    private func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {}

    private final func GetSystemToggleSettingValue() -> Bool {
		// This system does not have a system-specific toggle.
		return true;
	}

	private final func GetSystemToggleSettingString() -> String {
		// This system does not have a system-specific toggle.
		return "INVALID";
	}

    //
    //  System-Specific Methods
    //
    private final func OnBaseGamePointOfNoReturnFactChanged(value: Int32) -> Void {
        ENLog(this, "OnBaseGamePointOfNoReturnFactChanged value = " + ToString(value));
        this.baseGamePointOfNoReturnDone = value == 1 ? true : false;
    }

    public final func GetGameState(caller: ref<IScriptable>, opt ignoreTemporarilyInvalid: Bool, opt ignoreSleepCinematic: Bool) -> GameState {
        let callerName: String = NameToString(caller.GetClassName());

        if !this.Settings.mainSystemEnabled {
            ENLog(this, "GetGameState() returned Invalid for caller " + callerName + ": this.Settings.mainSystemEnabled=" + ToString(this.Settings.mainSystemEnabled));
            return GameState.Invalid;
        }

        if this.baseGamePointOfNoReturnDone {
            ENLog(this, "GetGameState() returned Invalid for caller " + callerName + ": this.baseGamePointOfNoReturnDone=" + ToString(this.baseGamePointOfNoReturnDone));
            return GameState.Invalid;
        }

        return GameState.Valid;
    }

    public final func IsValidGameState(caller: ref<IScriptable>, opt ignoreTemporarilyInvalid: Bool, opt ignoreSleepCinematic: Bool) -> Bool {
        return Equals(this.GetGameState(caller, ignoreTemporarilyInvalid, ignoreSleepCinematic), GameState.Valid);
    }
}
