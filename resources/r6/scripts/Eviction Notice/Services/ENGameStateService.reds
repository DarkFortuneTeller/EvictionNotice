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
    Invalid = 1,
    TemporarilyInvalid = 2
}

@wrapMethod(PlayerPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
    let gameStateService: ref<ENGameStateService> = ENGameStateService.Get();

    if IsSystemEnabledAndRunning(gameStateService) {
        let effectTags: array<CName> = evt.staticData.GameplayTags();

        if ArrayContains(effectTags, n"CyberspacePresence") {
            gameStateService.OnCyberspaceStateChanged(true);
        }
    }

	return wrappedMethod(evt);
}

@wrapMethod(PlayerPuppet)
protected cb func OnStatusEffectRemoved(evt: ref<RemoveStatusEffect>) -> Bool {
    let gameStateService: ref<ENGameStateService> = ENGameStateService.Get();

    if IsSystemEnabledAndRunning(gameStateService) {
        let effectTags: array<CName> = evt.staticData.GameplayTags();

        if ArrayContains(effectTags, n"CyberspacePresence") {
            gameStateService.OnCyberspaceStateChanged(false);
        }
    }

	return wrappedMethod(evt);
}

public class ENGameStateServiceCyberspaceChangedEvent extends CallbackSystemEvent {
    private let data: Bool;

    public func GetData() -> Bool {
        return this.data;
    }

    static func Create(data: Bool) -> ref<ENGameStateServiceCyberspaceChangedEvent> {
        let event = new ENGameStateServiceCyberspaceChangedEvent();
        event.data = data;
        return event;
    }
}

public class ENGameStateServiceSceneTierChangedEvent extends CallbackSystemEvent {
    private let data: GameplayTier;

    public func GetData() -> GameplayTier {
        return this.data;
    }

    static func Create(data: GameplayTier) -> ref<ENGameStateServiceSceneTierChangedEvent> {
        let event = new ENGameStateServiceSceneTierChangedEvent();
        event.data = data;
        return event;
    }
}

public class ENGameStateServiceMenuUpdateEvent extends CallbackSystemEvent {
    private let data: Bool;

    public func GetData() -> Bool {
        return this.data;
    }

    static func Create(data: Bool) -> ref<ENGameStateServiceMenuUpdateEvent> {
        let event = new ENGameStateServiceMenuUpdateEvent();
        event.data = data;
        return event;
    }
}

class ENGameStateServiceEventListener extends ENSystemEventListener {
	private func GetSystemInstance() -> wref<ENGameStateService> {
		return ENGameStateService.Get();
	}
}

public final class ENGameStateService extends ENSystem {
    private persistent let hasShownActivationMessage: Bool = false;

    private let BlackboardSystem: ref<BlackboardSystem>;
    private let QuestsSystem: ref<QuestsSystem>;

    private let UISystemBlackboard: ref<IBlackboard>;
    private let UISystemDef: ref<UI_SystemDef>;
    private let playerStateMachineBlackboard: ref<IBlackboard>;
    private let playerSMDef: ref<PlayerStateMachineDef>;

    private let gameplayTierChangeListener: ref<CallbackHandle>;
    private let replacerChangeListener: ref<CallbackHandle>;
    private let startupSequenceDoneFactListener: Uint32;
    private let baseGamePointOfNoReturnFactListener: Uint32;

    private let gameplayTier: GameplayTier = GameplayTier.Tier1_FullGameplay;
    private let startupSequenceDone: Bool = false;
    private let baseGamePointOfNoReturnDone: Bool = false;
    private let isReplacer: Bool = false;
    private let isInSleepCinematic: Bool = false;
    private let isInFury: Bool = false;
    private let isInCyberspace: Bool = false;

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
        this.debugEnabled = true;
    }

    private func DoPostSuspendActions() -> Void {
        this.gameplayTier = GameplayTier.Tier1_FullGameplay;
        this.startupSequenceDone = false;
        this.isReplacer = false;
        this.isInSleepCinematic = false;
        this.isInFury = false;
    }

    private func DoPostResumeActions() -> Void {
        this.OnSceneTierChange(this.player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.SceneTier));
        this.OnStartupSequenceDoneFactChanged(this.QuestsSystem.GetFact(n"en_fact_startup_sequence_done"));
        this.OnReplacerChanged(this.player.IsReplacer());
        this.OnCyberspaceStateChanged(StatusEffectSystem.ObjectHasStatusEffectWithTag(this.player, n"CyberspacePresence"), true);
        this.isInSleepCinematic = false;
    }

    private func GetSystems() -> Void {
        let gameInstance = GetGameInstance();
        this.BlackboardSystem = GameInstance.GetBlackboardSystem(gameInstance);
        this.QuestsSystem = GameInstance.GetQuestsSystem(gameInstance);
    }

    private func GetBlackboards(attachedPlayer: ref<PlayerPuppet>) -> Void {
        let allBlackboards: ref<AllBlackboardDefinitions> = GetAllBlackboardDefs();
        this.playerStateMachineBlackboard = this.BlackboardSystem.GetLocalInstanced(attachedPlayer.GetEntityID(), allBlackboards.PlayerStateMachine);
        this.UISystemBlackboard = this.BlackboardSystem.Get(allBlackboards.UI_System);
        this.playerSMDef = allBlackboards.PlayerStateMachine;
        this.UISystemDef = allBlackboards.UI_System;
    }

    private func RegisterListeners() -> Void {
        this.gameplayTierChangeListener = this.playerStateMachineBlackboard.RegisterListenerInt(this.playerSMDef.SceneTier, this, n"OnSceneTierChange", true);
        this.startupSequenceDoneFactListener = this.QuestsSystem.RegisterListener(n"en_fact_startup_sequence_done", this, n"OnStartupSequenceDoneFactChanged");
        this.baseGamePointOfNoReturnFactListener = this.QuestsSystem.RegisterListener(n"q115_point_of_no_return", this, n"OnBaseGamePointOfNoReturnFactChanged");
    }

    private func UnregisterListeners() -> Void {
        this.player.GetPlayerStateMachineBlackboard().UnregisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.SceneTier, this.gameplayTierChangeListener);
        this.gameplayTierChangeListener = null;

        this.QuestsSystem.UnregisterListener(n"en_fact_startup_sequence_done", this.startupSequenceDoneFactListener);
        this.startupSequenceDoneFactListener = 0u;

        this.QuestsSystem.UnregisterListener(n"q115_point_of_no_return", this.baseGamePointOfNoReturnFactListener);
        this.baseGamePointOfNoReturnFactListener = 0u;
    }

    private func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {
        this.OnStartupSequenceDoneFactChanged(this.QuestsSystem.GetFact(n"en_fact_startup_sequence_done"));
        this.OnReplacerChanged(this.player.IsReplacer());
    }

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
    public final func SetInSleepCinematic(value: Bool) -> Void {
        this.isInSleepCinematic = value;
    }

    protected cb func OnSceneTierChange(value: Int32) -> Void {
        ENLog(this.debugEnabled, this, "+++++++++++++++");
        ENLog(this.debugEnabled, this, "+++++++++++++++ OnSceneTierChange value = " + ToString(value));
        ENLog(this.debugEnabled, this, "+++++++++++++++");

        if NotEquals(IntEnum<GameplayTier>(value), GameplayTier.Undefined) {
            this.gameplayTier = IntEnum<GameplayTier>(value);
            GameInstance.GetCallbackSystem().DispatchEvent(ENGameStateServiceSceneTierChangedEvent.Create(this.gameplayTier));
        }

        this.TryToShowTutorial();
    }

    private final func OnStartupSequenceDoneFactChanged(value: Int32) -> Void {
        ENLog(this.debugEnabled, this, "OnStartupSequenceDoneFactChanged value = " + ToString(value));
        this.startupSequenceDone = value == 1 ? true : false;
    }

    private final func OnBaseGamePointOfNoReturnFactChanged(value: Int32) -> Void {
        ENLog(this.debugEnabled, this, "OnBaseGamePointOfNoReturnFactChanged value = " + ToString(value));
        this.baseGamePointOfNoReturnDone = value == 1 ? true : false;
    }

    private final func OnReplacerChanged(value: Bool) -> Void {
        ENLog(this.debugEnabled, this, "OnReplacerChange value = " + ToString(value));
        this.isReplacer = value;
    }

    private final func OnCyberspaceStateChanged(value: Bool, opt noEvent: Bool) -> Void {
        ENLog(this.debugEnabled, this, "OnCyberspaceStateChanged value = " + ToString(value));
        this.isInCyberspace = value;

        if !noEvent {
            GameInstance.GetCallbackSystem().DispatchEvent(ENGameStateServiceCyberspaceChangedEvent.Create(value));
        }
        
    }

    public final func GetGameState(callerName: String, opt ignoreTemporarilyInvalid: Bool, opt ignoreSleepCinematic: Bool) -> GameState {
        if !this.Settings.mainSystemEnabled {
            ENLog(this.debugEnabled, this, "GetGameState() returned Invalid for caller " + callerName + ": this.Settings.mainSystemEnabled=" + ToString(this.Settings.mainSystemEnabled));
            return GameState.Invalid;
        }

        if !this.startupSequenceDone {
            ENLog(this.debugEnabled, this, "GetGameState() returned Invalid for caller " + callerName + ": this.startupSequenceDone=" + ToString(this.startupSequenceDone));
            return GameState.Invalid;
        }

        if this.baseGamePointOfNoReturnDone {
            ENLog(this.debugEnabled, this, "GetGameState() returned Invalid for caller " + callerName + ": this.baseGamePointOfNoReturnDone=" + ToString(this.baseGamePointOfNoReturnDone));
            return GameState.Invalid;
        }

        if this.isReplacer {
            ENLog(this.debugEnabled, this, "GetGameState() returned Invalid for caller " + callerName + ": this.isReplacer=" + ToString(this.isReplacer));
            return GameState.Invalid;
        }

        if this.isInCyberspace {
            ENLog(this.debugEnabled, this, "GetGameState() returned Invalid for caller " + callerName + ": this.isInCyberspace=" + ToString(this.isInCyberspace));
            return GameState.Invalid;
        }

        if !ignoreSleepCinematic && this.isInSleepCinematic {
            ENLog(this.debugEnabled, this, "GetGameState() returned Invalid for caller " + callerName + ": this.isInSleepCinematic=" + ToString(this.isInSleepCinematic));
            return GameState.Invalid;
        }

        if !ignoreTemporarilyInvalid && this.isInFury {
            ENLog(this.debugEnabled, this, "GetGameState() returned Temporarily Invalid for caller " + callerName + ": this.isInFury=" + ToString(this.isInFury));
            return GameState.TemporarilyInvalid;
        }

        if !ignoreTemporarilyInvalid && !Equals(this.gameplayTier, GameplayTier.Tier1_FullGameplay) && !Equals(this.gameplayTier, GameplayTier.Tier2_StagedGameplay) {
            ENLog(this.debugEnabled, this, "GetGameState() returned Temporarily Invalid for caller " + callerName + ": this.gameplayTier=" + ToString(this.gameplayTier));
            return GameState.TemporarilyInvalid;
        }

        // TODO: Move to more relevant location
        return GameState.Valid;
    }

    public final func IsValidGameState(callerName: String, opt ignoreTemporarilyInvalid: Bool, opt ignoreSleepCinematic: Bool) -> Bool {
        return Equals(this.GetGameState(callerName, ignoreTemporarilyInvalid, ignoreSleepCinematic), GameState.Valid);
    }

    private func GetActivationTitleKey() -> CName {
		return n"EvictionNoticeTutorialActivateTitle";
	}

	private func GetActivationMessageKey() -> CName {
		return n"EvictionNoticeTutorialActivate";
	}

    // TODO
    private final func TryToShowTutorial() -> Void {
        let blackboardDef: ref<IBlackboard> = this.BlackboardSystem.Get(GetAllBlackboardDefs().UIGameData);
        let myMargin: inkMargin = new inkMargin(0.0, 0.0, 0.0, 150.0);
        let popupSettingsDatum: PopupSettings;
        popupSettingsDatum.closeAtInput = false;
        popupSettingsDatum.pauseGame = false;
        popupSettingsDatum.fullscreen = false;
        popupSettingsDatum.position = PopupPosition.LowerLeft;
        popupSettingsDatum.hideInMenu = true;
        popupSettingsDatum.margin = myMargin;

        let tutorialTitle: String = "Hi";
        let tutorialMessage: String = "Test";
        let popupDatum: PopupData;
        popupDatum.title = tutorialTitle;
        popupDatum.message = tutorialMessage;
        popupDatum.isModal = false;
        popupDatum.videoType = VideoType.Unknown;

        blackboardDef.SetVariant(GetAllBlackboardDefs().UIGameData.Popup_Settings, ToVariant(popupSettingsDatum));
        blackboardDef.SetVariant(GetAllBlackboardDefs().UIGameData.Popup_Data, ToVariant(popupDatum));
        blackboardDef.SignalVariant(GetAllBlackboardDefs().UIGameData.Popup_Data);

    /*    if !this.hasShownActivationMessage {
			this.hasShownActivationMessage = true;
			let tutorial: ENTutorial;
			tutorial.title = GetLocalizedTextByKey(this.GetActivationTitleKey());
			tutorial.message = GetLocalizedTextByKey(this.GetActivationMessageKey());
            tutorial.iconID = t"UIIcon.EvictionNoticeTutorial";
			this.NotificationService.QueueTutorial(tutorial);
		}
    */
	}
}

// TODO: Test
@replaceMethod(PopupsManager)
    private final func ShowTutorial() -> Void {
        let notificationData: ref<TutorialPopupData> = new TutorialPopupData();
        notificationData.notificationName = n"base\\gameplay\\gui\\widgets\\notifications\\tutorial.inkwidget";
        notificationData.queueName = n"tutorial";
        notificationData.closeAtInput = this.m_tutorialSettings.closeAtInput;
        notificationData.pauseGame = this.m_tutorialSettings.pauseGame;
        notificationData.position = this.m_tutorialSettings.position;
        notificationData.isModal = this.m_tutorialSettings.fullscreen;
        notificationData.margin = this.m_tutorialSettings.margin;
        notificationData.title = this.m_tutorialData.title;
        notificationData.message = this.m_tutorialData.message;
        notificationData.messageOverrideDataList = this.m_tutorialData.messageOverrideDataList;
        notificationData.imageId = this.m_tutorialData.iconID;
        notificationData.videoType = this.m_tutorialData.videoType;
        notificationData.video = PopupData.GetVideo(this.m_tutorialData);
        notificationData.isBlocking = this.m_tutorialSettings.closeAtInput;
        this.m_tutorialToken = this.ShowGameNotification(notificationData);
        this.m_tutorialToken.RegisterListener(this, n"OnPopupCloseRequest");
    }