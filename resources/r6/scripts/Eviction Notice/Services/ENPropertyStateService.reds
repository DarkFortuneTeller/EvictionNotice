// -----------------------------------------------------------------------------
// ENPropertyStateService
// -----------------------------------------------------------------------------
//
// - Service that provides an interface to interact with the state of all real estate properties.
//

module EvictionNotice.Services

import EvictionNotice.System.*
import EvictionNotice.Utils.{
    RunGuard,
    GetHalfDaysUntilEviction
}
import EvictionNotice.Settings.{
    ENSettings,
    ENSettingRentStateOnNewGame
}
import EvictionNotice.Logging.*
import EvictionNotice.Main.ENTimeSkipData
import EvictionNotice.Gameplay.{
    ENRentalProperty,
    ENRentState,
    ENSurrenderReason,
    ENWelcomeMessageType,
    ENRentSystemBase,
    ENRentSystemMBH10,
    ENRentSystemNorthside,
    ENRentSystemJapantown,
    ENRentSystemGlen,
    ENRentSystemCorpoPlaza,
    ENEZEstatesAgentSystem,
    ENBillPaySystem
}

public class ENPropertyStateServiceCurrentDayUpdateEvent extends CallbackSystemEvent {
    private let currentDay: Int32;

    public func GetData() -> Int32 {
        return this.currentDay;
    }

    static func Create(currentDay: Int32) -> ref<ENPropertyStateServiceCurrentDayUpdateEvent> {
        let self: ref<ENPropertyStateServiceCurrentDayUpdateEvent> = new ENPropertyStateServiceCurrentDayUpdateEvent();
        self.currentDay = currentDay;
        return self;
    }
}

public class EvictionNoticeCurrentDayUpdateEvent extends Event {}

@addMethod(PlayerPuppet)
private cb func OnEvictionNoticeCurrentDayUpdate(evt: ref<EvictionNoticeCurrentDayUpdateEvent>) -> Bool {
    ENPropertyStateService.Get().UpdateCurrentDay();
}

public struct ENRentCycle {
    public persistent let day: Int32;
    public persistent let initialized: Bool;
}

class ENPropertyStateServiceEventListener extends ENSystemEventListener {
	private func GetSystemInstance() -> wref<ENPropertyStateService> {
		return ENPropertyStateService.Get();
	}
}

public final class ENPropertyStateService extends ENSystem {
    private persistent let oneTimeSetupDone: Bool = false;
    private persistent let CurrentDay: Int32;
    private persistent let CurrentRentCycleStart: ENRentCycle;
    private persistent let NextRentCycleStart: ENRentCycle;
    private persistent let RentalPeriodInDays: Int32;
    private persistent let EvictionLockoutDays: Int32;

    private let QuestsSystem: ref<QuestsSystem>;
    private let GameStateService: ref<ENGameStateService>;
    private let EZEstates: ref<ENEZEstatesAgentSystem>;
    private let BillPay: ref<ENBillPaySystem>;
    private let MBH10: ref<ENRentSystemMBH10>;
    private let Northside: ref<ENRentSystemNorthside>;
    private let Japantown: ref<ENRentSystemJapantown>;
    private let Glen: ref<ENRentSystemGlen>;
    private let CorpoPlaza: ref<ENRentSystemCorpoPlaza>;

    private let dayTimeListener: Uint32;

    private let factListenerQuestPhaseDebug: Uint32;
    private let factListenerActionUpdateSurrenderReasonFromMoveInPendingID: Uint32;
    private let factListenerActionUpdateLastRentedPropertyCount: Uint32;
    private let factListenerActionSendWelcomeBackMessageFromMoveInPendingID: Uint32;
    private let factListenerActionSetNewGameStateAct2Start: Uint32;
    private let factListenerActionSetNewGameStatePhantomLibertyStart: Uint32;
    private let factListenerActionSetNewGameStateLoadSaveStart: Uint32;

    private let lastRentSystemCheckedForEvictionLockout: ref<ENRentSystemBase>;

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENPropertyStateService> {
		let instance: ref<ENPropertyStateService> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"EvictionNotice.Services.ENPropertyStateService") as ENPropertyStateService;
		return instance;
	}

	public final static func Get() -> ref<ENPropertyStateService> {
		return ENPropertyStateService.GetInstance(GetGameInstance());
	}

    private func SetupDebugLogging() -> Void {
        this.debugEnabled = false;
    }

    private final func GetSystemToggleSettingValue() -> Bool {
		// This system does not have a system-specific toggle.
		return true;
	}

	private final func GetSystemToggleSettingString() -> String {
		// This system does not have a system-specific toggle.
		return "INVALID";
	}

    private func DoPostSuspendActions() -> Void {}

    private func DoPostResumeActions() -> Void {
        let now: GameTime = GetGameInstance().GetGameTime();
        this.CurrentDay = now.Days();

        this.InitializeStartupTimeData(ENSettingRentStateOnNewGame.Paid);
    }

    private func GetSystems() -> Void {
        let gameInstance = GetGameInstance();
        this.QuestsSystem = GameInstance.GetQuestsSystem(gameInstance);
        this.Settings = ENSettings.GetInstance(gameInstance);
        this.GameStateService = ENGameStateService.GetInstance(gameInstance);
        this.EZEstates = ENEZEstatesAgentSystem.GetInstance(gameInstance);
        this.BillPay = ENBillPaySystem.GetInstance(gameInstance);
        this.MBH10 = ENRentSystemMBH10.GetInstance(gameInstance);
        this.Northside = ENRentSystemNorthside.GetInstance(gameInstance);
        this.Japantown = ENRentSystemJapantown.GetInstance(gameInstance);
        this.Glen = ENRentSystemGlen.GetInstance(gameInstance);
        this.CorpoPlaza = ENRentSystemCorpoPlaza.GetInstance(gameInstance);
    }

    private func GetBlackboards(attachedPlayer: ref<PlayerPuppet>) -> Void {}

    private func SetupData() -> Void {}

    private func RegisterListeners() -> Void {
        this.factListenerQuestPhaseDebug = this.QuestsSystem.RegisterListener(this.GetQuestPhaseGraphDebugQuestFact(), this, n"OnQuestPhaseDebugFactChanged");

        this.factListenerActionUpdateSurrenderReasonFromMoveInPendingID = this.QuestsSystem.RegisterListener(this.GetActionUpdateSurrenderReasonFromMoveInPendingIDQuestFact(), this, n"OnUpdateSurrenderReasonFromMoveInPendingIDActionFactChanged");
        this.factListenerActionUpdateLastRentedPropertyCount = this.QuestsSystem.RegisterListener(this.GetActionUpdateLastRentedPropertyCountQuestFact(), this, n"OnUpdateLastRentedPropertyCountActionFactChanged");
        this.factListenerActionSendWelcomeBackMessageFromMoveInPendingID = this.QuestsSystem.RegisterListener(this.GetActionSendWelcomeBackMessageFromMoveInPendingIDQuestFact(), this, n"OnSendWelcomeBackMessageFromMoveInPendingIDActionFactChanged");
        this.factListenerActionSetNewGameStateAct2Start = this.QuestsSystem.RegisterListener(this.GetActionSetNewGameStateAct2Start(), this, n"OnSetNewGameStateAct2Start");
        this.factListenerActionSetNewGameStatePhantomLibertyStart = this.QuestsSystem.RegisterListener(this.GetActionSetNewGameStatePhantomLibertyStart(), this, n"OnSetNewGameStatePhantomLibertyStart");
        this.factListenerActionSetNewGameStateLoadSaveStart = this.QuestsSystem.RegisterListener(this.GetActionSetNewGameStateLoadSaveStart(), this, n"OnSetNewGameStateLoadSaveStart");

        // Update at midnight each day.
        let now: GameTime = GetGameInstance().GetGameTime();
        let dayTomorrow: Int32 = now.Days() + 1;
        let midnightTomorrow: GameTime = GameTime.MakeGameTime(dayTomorrow, 0);
        this.dayTimeListener = GameInstance.GetTimeSystem(GetGameInstance()).RegisterListener(this.player, new EvictionNoticeCurrentDayUpdateEvent(), midnightTomorrow, 0);
    }

    private func RegisterAllRequiredDelayCallbacks() -> Void {}

    private func UnregisterListeners() -> Void {
        this.QuestsSystem.UnregisterListener(this.GetQuestPhaseGraphDebugQuestFact(), this.factListenerQuestPhaseDebug);
        this.factListenerQuestPhaseDebug = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionUpdateSurrenderReasonFromMoveInPendingIDQuestFact(), this.factListenerActionUpdateSurrenderReasonFromMoveInPendingID);
        this.factListenerActionUpdateSurrenderReasonFromMoveInPendingID = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionUpdateLastRentedPropertyCountQuestFact(), this.factListenerActionUpdateLastRentedPropertyCount);
        this.factListenerActionUpdateLastRentedPropertyCount = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionSendWelcomeBackMessageFromMoveInPendingIDQuestFact(), this.factListenerActionSendWelcomeBackMessageFromMoveInPendingID);
        this.factListenerActionSendWelcomeBackMessageFromMoveInPendingID = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionSetNewGameStateAct2Start(), this.factListenerActionSetNewGameStateAct2Start);
        this.factListenerActionSetNewGameStateAct2Start = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionSetNewGameStatePhantomLibertyStart(), this.factListenerActionSetNewGameStatePhantomLibertyStart);
        this.factListenerActionSetNewGameStatePhantomLibertyStart = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionSetNewGameStateLoadSaveStart(), this.factListenerActionSetNewGameStateLoadSaveStart);
        this.factListenerActionSetNewGameStateLoadSaveStart = 0u;

        GameInstance.GetTimeSystem(GetGameInstance()).UnregisterListener(this.dayTimeListener);
        this.dayTimeListener = 0u;
    }
    
    private func UnregisterAllDelayCallbacks() -> Void {}
    public func OnTimeSkipFinished(data: ENTimeSkipData) -> Void {}

    public func OnSettingChangedSpecific(changedSettings: array<String>) -> Void {
        if IsSystemEnabledAndRunning(this) {
            this.CheckRentalDurationSettings(changedSettings);
        }
    }

    public final func CheckRentalDurationSettings(changedSettings: array<String>) -> Void {
        if ArrayContains(changedSettings, "rentalPeriodInDays") {
            if NotEquals(this.RentalPeriodInDays, this.Settings.rentalPeriodInDays) {
                ENLog(this, "@@@ @@@ @@@ rentalPeriodInDays has been updated, reinitialize time values!");
                this.RentalPeriodInDays = this.Settings.rentalPeriodInDays;

                let now: GameTime = GetGameInstance().GetGameTime();
                this.CurrentDay = now.Days();
                this.ReinitializeStartupTimeData();
            } else {
                ENLog(this, "@@@ @@@ @@@ rentalPeriodInDays has a non-default value, but is the same as the internal system state; continuing.");
            }
        }
    }

    private func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {
        let now: GameTime = GetGameInstance().GetGameTime();
        this.CurrentDay = now.Days();

        ENLog(this, "%%%%%%%%%%%%% CurrentDay: " + ToString(this.CurrentDay));

        if !this.oneTimeSetupDone {
            this.RentalPeriodInDays = this.Settings.rentalPeriodInDays;
            this.EvictionLockoutDays = this.Settings.evictionLockoutDays;

            this.UpdateRentedPropertyCount();

            this.oneTimeSetupDone = true;
        }
    }

    //
	//	RunGuard Protected Methods
	//
	public final func UpdateCurrentDay() -> Void {
		if RunGuard(this) { return; }
		ENLog(this, "CheckCurrentDay");

		if this.GameStateService.IsValidGameState(this) {
            let now: GameTime = GetGameInstance().GetGameTime();
            if now.Days() > this.CurrentDay {
                this.CurrentDay = now.Days();
                
                if now.Days() >= this.GetNextRentCycleStartDay() {
                    this.AdvanceRentCycle();
                }

                this.DispatchCurrentDayUpdateEvent();
            }
		}

        ENLog(this, "CurrentRentCycleStart.day: " + ToString(this.CurrentRentCycleStart.day));
        ENLog(this, "NextRentCycleStart.day: " + ToString(this.NextRentCycleStart.day));
	}

    //
    //  System-Specific Methods
    //
    private final func GetQuestPhaseGraphDebugQuestFact() -> CName {
        return n"en_fact_propertystateservice_debug";
    }

    public final func GetActionUpdateSurrenderReasonFromMoveInPendingIDQuestFact() -> CName {
        return n"en_fact_action_update_surrender_reason_from_movein_pending_id";
    }

    public final func GetActionUpdateLastRentedPropertyCountQuestFact() -> CName {
        return n"en_fact_action_update_last_rented_property_count";
    }

    public final func GetActionSendWelcomeBackMessageFromMoveInPendingIDQuestFact() -> CName {
        return n"en_fact_action_send_welcome_back_message_from_move_in_pending_id";
    }

    public final func GetActionSetNewGameStateAct2Start() -> CName {
        return n"en_fact_action_set_new_game_state_act_2_start";
    }

    public final func GetActionSetNewGameStatePhantomLibertyStart() -> CName {
        return n"en_fact_action_set_new_game_state_phantom_liberty_start";
    }

    public final func GetActionSetNewGameStateLoadSaveStart() -> CName {
        return n"en_fact_action_set_new_game_state_load_save_start";
    }

    public final func GetSurrenderReasonFromMoveInPendingIDQuestFact() -> CName {
        return n"en_fact_surrender_reason_from_movein_pending_id";
    }

    public final func GetPendingMoveInApartmentIDQuestFact() -> CName {
        return n"en_fact_pending_movein_apartment_id";
    }

    public func GetPendingPurchaseApartmentIDQuestFact() -> CName {
        return n"en_fact_pending_purchase_apartment_id";
    }

    public final func GetRentedPropertyCountQuestFact() -> CName {
        return n"en_fact_last_rented_property_count";
    }

    public final func GetLastRentedPropertyCountQuestFact() -> CName {
        return n"en_fact_rented_property_count";
    }

    public final func GetMBH10NewGameStateOnStartQuestFact() -> CName {
        return n"en_fact_mbh10_new_game_state_on_start";
    }

    public func GetRentCycleTimeLeftQuestFact() -> CName {
        return n"en_fact_rent_cycle_time_left";
    }

    public func GetEvictionLockoutRemainingDaysQuestFact() -> CName {
        return n"en_fact_eviction_lockout_remaining_days";
    }

    private final func OnQuestPhaseDebugFactChanged(value: Int32) -> Void {
        if value != 0 {
            ENLog(this, "#### DEBUG Quest Phase Graph --- Value: " + ToString(value));
            this.QuestsSystem.SetFact(this.GetQuestPhaseGraphDebugQuestFact(), 0);
        }
    }

    public final func GetRentalPropertyByID(id: Int32) -> ENRentalProperty {
        return IntEnum<ENRentalProperty>(id);
    }

    public final func GetPendingMoveInApartmentID() -> Int32 {
        return this.QuestsSystem.GetFact(this.GetPendingMoveInApartmentIDQuestFact());
    }

    public final func GetPendingPurchaseApartmentID() -> Int32 {
        return this.QuestsSystem.GetFact(this.GetPendingPurchaseApartmentIDQuestFact());
    }

    public final func GetSurrenderReasonFromMoveInPendingID() -> ENSurrenderReason {
        return IntEnum<ENSurrenderReason>(this.QuestsSystem.GetFact(this.GetSurrenderReasonFromMoveInPendingIDQuestFact()));
    }

    public final func OnUpdateSurrenderReasonFromMoveInPendingIDActionFactChanged(value: Int32) -> Void {
        if Equals(value, 1) {
            ENLog(this, "OnUpdateSurrenderReasonFromMoveInPendingIDActionFactChanged");

            let pendingMoveInRentalProperty: ENRentalProperty = this.GetRentalPropertyByID(this.GetPendingMoveInApartmentID());
            let rentSystem: ref<ENRentSystemBase> = this.GetRentalSystemFromRentalProperty(pendingMoveInRentalProperty);
            let rentState: ENRentState = rentSystem.GetRentState();

            ENLog(this, "    rentState of property " + ToString(pendingMoveInRentalProperty) + " = " + ToString(rentState));

            if Equals(rentState, ENRentState.MovedOut) {
                this.QuestsSystem.SetFact(this.GetSurrenderReasonFromMoveInPendingIDQuestFact(), EnumInt<ENSurrenderReason>(ENSurrenderReason.MovedOut));
                ENLog(this, "    setting " + NameToString(this.GetSurrenderReasonFromMoveInPendingIDQuestFact()) + " to " + ToString(EnumInt<ENSurrenderReason>(ENSurrenderReason.MovedOut)));
            } else if Equals(rentState, ENRentState.Evicted) {
                this.QuestsSystem.SetFact(this.GetSurrenderReasonFromMoveInPendingIDQuestFact(), EnumInt<ENSurrenderReason>(ENSurrenderReason.Evicted));
                
                let lockoutRemainingDays: Int32 = this.GetEvictionLockoutRemainingDays(rentSystem);
                ENLog(this, "    setting " + NameToString(this.GetEvictionLockoutRemainingDaysQuestFact()) + " to " + lockoutRemainingDays);
                this.QuestsSystem.SetFact(this.GetEvictionLockoutRemainingDaysQuestFact(), lockoutRemainingDays);
                
                this.SetLastRentSystemCheckedForEvictionLockout(rentSystem);
                ENLog(this, "    setting " + NameToString(this.GetSurrenderReasonFromMoveInPendingIDQuestFact()) + " to " + ToString(EnumInt<ENSurrenderReason>(ENSurrenderReason.Evicted)));
            }
            
            ENLog(this, "    Continuing...");
            this.QuestsSystem.SetFact(this.GetActionUpdateSurrenderReasonFromMoveInPendingIDQuestFact(), 0);
        }
    }

    public final func OnUpdateLastRentedPropertyCountActionFactChanged(value: Int32) -> Void {
        if Equals(value, 1) {
            this.QuestsSystem.SetFact(this.GetLastRentedPropertyCountQuestFact(), this.QuestsSystem.GetFact(this.GetRentedPropertyCountQuestFact()));

            this.QuestsSystem.SetFact(this.GetActionUpdateLastRentedPropertyCountQuestFact(), 0);
        }
    }

    public final func OnSendWelcomeBackMessageFromMoveInPendingIDActionFactChanged(value: Int32) -> Void {
        if Equals(value, 1) {
            let pendingMoveInRentalProperty: ENRentalProperty = this.GetRentalPropertyByID(this.GetPendingMoveInApartmentID());
            let rentSystem: ref<ENRentSystemBase> = this.GetRentalSystemFromRentalProperty(pendingMoveInRentalProperty);
            rentSystem.SendWelcomeMessage(ENWelcomeMessageType.WelcomeBack);
            this.QuestsSystem.SetFact(this.GetActionSendWelcomeBackMessageFromMoveInPendingIDQuestFact(), 0);
        }
    }

    public final func OnSetNewGameStateAct2Start(value: Int32) -> Void {
        if Equals(value, 1) {
            ENLog(this, "************ OnSetNewGameStateAct2Start ************");

            // Send the correct fact value to megabuildingh10_payrent.questphase based on the intended rent state and how long the rental period is
            this.InitializeStartupTimeData(this.Settings.H10RentStateOnNewGameAct2);

            let rentStateSetting: ENSettingRentStateOnNewGame = this.Settings.H10RentStateOnNewGameAct2;
            if Equals(rentStateSetting, ENSettingRentStateOnNewGame.Paid) {
                this.QuestsSystem.SetFact(this.GetMBH10NewGameStateOnStartQuestFact(), 0);
            } if Equals(rentStateSetting, ENSettingRentStateOnNewGame.Due) {
                this.QuestsSystem.SetFact(this.GetMBH10NewGameStateOnStartQuestFact(), 1);
            } else if Equals(rentStateSetting, ENSettingRentStateOnNewGame.Overdue) {
                let newGameStateOnStartFactValue: Int32 = this.RentalPeriodInDays == 2 ? 3 : 2;
                this.QuestsSystem.SetFact(this.GetMBH10NewGameStateOnStartQuestFact(), newGameStateOnStartFactValue);
            } else if Equals(rentStateSetting, ENSettingRentStateOnNewGame.Evicted) {
                this.QuestsSystem.SetFact(this.GetMBH10NewGameStateOnStartQuestFact(), 4);
            }

            this.QuestsSystem.SetFact(this.GetActionSetNewGameStateAct2Start(), 0);
        }
    }

    public final func OnSetNewGameStatePhantomLibertyStart(value: Int32) -> Void {
        if Equals(value, 1) {
            ENLog(this, "************ OnSetNewGameStatePhantomLibertyStart ************");
            

            // Send the correct fact value to megabuildingh10_payrent.questphase based on the intended rent state and how long the rental period is
            this.InitializeStartupTimeData(this.Settings.H10RentStateOnNewGamePhantomLiberty);

            let rentStateSetting: ENSettingRentStateOnNewGame = this.Settings.H10RentStateOnNewGamePhantomLiberty;
            if Equals(rentStateSetting, ENSettingRentStateOnNewGame.Paid) {
                this.QuestsSystem.SetFact(this.GetMBH10NewGameStateOnStartQuestFact(), 0);
            } if Equals(rentStateSetting, ENSettingRentStateOnNewGame.Due) {
                this.QuestsSystem.SetFact(this.GetMBH10NewGameStateOnStartQuestFact(), 1);
            } else if Equals(rentStateSetting, ENSettingRentStateOnNewGame.Overdue) {
                let newGameStateOnStartFactValue: Int32 = this.RentalPeriodInDays == 2 ? 3 : 2;
                this.QuestsSystem.SetFact(this.GetMBH10NewGameStateOnStartQuestFact(), newGameStateOnStartFactValue);
            } else if Equals(rentStateSetting, ENSettingRentStateOnNewGame.Evicted) {
                this.QuestsSystem.SetFact(this.GetMBH10NewGameStateOnStartQuestFact(), 4);
            }

            this.QuestsSystem.SetFact(this.GetActionSetNewGameStatePhantomLibertyStart(), 0);
        }
    }

    public final func OnSetNewGameStateLoadSaveStart(value: Int32) -> Void {
        if Equals(value, 1) {
            ENLog(this, "************ OnSetNewGameStateLoadSaveStart ************");
            this.InitializeStartupTimeData(ENSettingRentStateOnNewGame.Paid);
            this.QuestsSystem.SetFact(this.GetMBH10NewGameStateOnStartQuestFact(), 0);

            this.QuestsSystem.SetFact(this.GetActionSetNewGameStateLoadSaveStart(), 0);
        }
    }

    private final func InitializeStartupTimeData(newGameRentState: ENSettingRentStateOnNewGame) -> Void {
        ENLog(this, "************ InitializeStartupTimeData ************");

        if Equals(newGameRentState, ENSettingRentStateOnNewGame.Paid) || Equals(newGameRentState, ENSettingRentStateOnNewGame.Due) || Equals(newGameRentState, ENSettingRentStateOnNewGame.Evicted) {
            this.CurrentRentCycleStart.day = this.CurrentDay;
            this.CurrentRentCycleStart.initialized = true;
        } else if Equals(newGameRentState, ENSettingRentStateOnNewGame.Overdue) {
            this.CurrentRentCycleStart.day = this.CurrentDay - GetHalfDaysUntilEviction();
            this.CurrentRentCycleStart.initialized = true;
        }

        this.NextRentCycleStart.day = this.CurrentRentCycleStart.day + this.RentalPeriodInDays;
        this.NextRentCycleStart.initialized = true;

        let lastPaidDay: Int32;
        let initialRentState: ENRentState;
        if Equals(newGameRentState, ENSettingRentStateOnNewGame.Paid) {
            lastPaidDay = this.CurrentRentCycleStart.day;
            initialRentState = ENRentState.Paid;

        } else if Equals(newGameRentState, ENSettingRentStateOnNewGame.Due) {
            lastPaidDay = this.CurrentRentCycleStart.day - this.RentalPeriodInDays;
            initialRentState = ENRentState.Due;

        } else if Equals(newGameRentState, ENSettingRentStateOnNewGame.Overdue) {
            lastPaidDay = this.CurrentRentCycleStart.day - this.RentalPeriodInDays;
            initialRentState = ENRentState.OverdueSecondWarning;

        } else if Equals(newGameRentState, ENSettingRentStateOnNewGame.Evicted) {
            lastPaidDay = this.CurrentRentCycleStart.day - (this.RentalPeriodInDays * 2);
            initialRentState = ENRentState.Evicted;

        }

        this.MBH10.lastPaidRentCycleStartDay = lastPaidDay;
        this.MBH10.SetRentState(initialRentState);

        if this.Northside.GetIsPurchasedInBaseGame() {
            this.Northside.lastPaidRentCycleStartDay = lastPaidDay;
            this.Northside.SetRentState(initialRentState);
        } else {
            this.Northside.SetRentState(ENRentState.NeverRented);
        }
        
        if this.Japantown.GetIsPurchasedInBaseGame() {
            this.Japantown.lastPaidRentCycleStartDay = lastPaidDay;
            this.Japantown.SetRentState(initialRentState);
        } else {
            this.Japantown.SetRentState(ENRentState.NeverRented);
        }

        if this.Glen.GetIsPurchasedInBaseGame() {
            this.Glen.lastPaidRentCycleStartDay = lastPaidDay;
            this.Glen.SetRentState(initialRentState);
        } else {
            this.Glen.SetRentState(ENRentState.NeverRented);
        }

        if this.CorpoPlaza.GetIsPurchasedInBaseGame() {
            this.CorpoPlaza.lastPaidRentCycleStartDay = lastPaidDay;
            this.CorpoPlaza.SetRentState(initialRentState);
        } else {
            this.CorpoPlaza.SetRentState(ENRentState.NeverRented);
        }
    }

    // Called when the Rent Duration setting has changed.
    private final func ReinitializeStartupTimeData() -> Void {
        ENLog(this, "************ ReinitializeStartupTimeData ************");

        this.CurrentRentCycleStart.day = this.CurrentDay;
        this.CurrentRentCycleStart.initialized = true;

        this.NextRentCycleStart.day = this.CurrentRentCycleStart.day + this.RentalPeriodInDays;
        this.NextRentCycleStart.initialized = true;

        let lastPaidDay: Int32 = this.CurrentRentCycleStart.day;

        if this.MBH10.IsCurrentRentStateRented() {
            this.QuestsSystem.SetFact(this.MBH10.GetActionDoRentDurationChangedCleanup(), 1);
            this.MBH10.lastPaidRentCycleStartDay = lastPaidDay;
            this.MBH10.SetRentState(ENRentState.Paid);
        }

        if this.Northside.IsCurrentRentStateRented() {
            this.QuestsSystem.SetFact(this.Northside.GetActionDoRentDurationChangedCleanup(), 1);
            this.Northside.lastPaidRentCycleStartDay = lastPaidDay;
            this.Northside.SetRentState(ENRentState.Paid);
        }

        if this.Japantown.IsCurrentRentStateRented() {
            this.QuestsSystem.SetFact(this.Japantown.GetActionDoRentDurationChangedCleanup(), 1);
            this.Japantown.lastPaidRentCycleStartDay = lastPaidDay;
            this.Japantown.SetRentState(ENRentState.Paid);
        }

        if this.Glen.IsCurrentRentStateRented() {
            this.QuestsSystem.SetFact(this.Glen.GetActionDoRentDurationChangedCleanup(), 1);
            this.Glen.lastPaidRentCycleStartDay = lastPaidDay;
            this.Glen.SetRentState(ENRentState.Paid);
        }

        if this.CorpoPlaza.IsCurrentRentStateRented() {
            this.QuestsSystem.SetFact(this.CorpoPlaza.GetActionDoRentDurationChangedCleanup(), 1);
            this.CorpoPlaza.lastPaidRentCycleStartDay = lastPaidDay;
            this.CorpoPlaza.SetRentState(ENRentState.Paid);
        }
    }

    public final func GetRentalSystemFromRentalProperty(rentalProperty: ENRentalProperty) -> ref<ENRentSystemBase> {
        switch rentalProperty {
            case ENRentalProperty.MegabuildingH10:
                return this.MBH10;
                break;
            case ENRentalProperty.Northside:
                return this.Northside;
                break;
            case ENRentalProperty.Japantown:
                return this.Japantown;
                break;
            case ENRentalProperty.Glen:
                return this.Glen;
                break;
            case ENRentalProperty.CorpoPlaza:
                return this.CorpoPlaza;
                break;
        }
    }

    public final func GetRentedPropertyCount() -> Uint32 {
        let rentedCount: Uint32;

        if this.MBH10.IsCurrentRentStateRented() {
            rentedCount += 1u;
        }

        if this.Northside.IsCurrentRentStateRented() {
            rentedCount += 1u;
        }

        if this.Japantown.IsCurrentRentStateRented() {
            rentedCount += 1u;
        }

        if this.Glen.IsCurrentRentStateRented() {
            rentedCount += 1u;
        }

        if this.CorpoPlaza.IsCurrentRentStateRented() {
            rentedCount += 1u;
        }

        return rentedCount;
    }

    public final func UpdateRentedPropertyCount() -> Void {
        this.QuestsSystem.SetFact(this.GetRentedPropertyCountQuestFact(), Cast<Int32>(this.GetRentedPropertyCount()));
        ENLog(this, "The rented property count is now: " + ToString(this.GetRentedPropertyCount()));

        this.BillPay.TryToSendAutoPayInvite();
    }

    public final func GetSurrenderedPropertyCount() -> Uint32 {
        let surrenderedCount: Uint32;

        if this.MBH10.IsCurrentRentStateSurrendered() {
            surrenderedCount += 1u;
        }

        if this.Northside.IsCurrentRentStateSurrendered() {
            surrenderedCount += 1u;
        }

        if this.Japantown.IsCurrentRentStateSurrendered() {
            surrenderedCount += 1u;
        }

        if this.Glen.IsCurrentRentStateSurrendered() {
            surrenderedCount += 1u;
        }

        if this.CorpoPlaza.IsCurrentRentStateSurrendered() {
            surrenderedCount += 1u;
        }

        return surrenderedCount;
    }

    // Important: Never reference "now" when modifying the rent cycle outside of initialization 
    // to avoid potentially offsetting by +/- 1 day depending on the moment this function is called.
    public final func AdvanceRentCycle() -> Void {
        this.CurrentRentCycleStart.day = this.NextRentCycleStart.day;
        this.NextRentCycleStart.day = this.CurrentRentCycleStart.day + this.RentalPeriodInDays;
    }

    public final func GetCurrentDay() -> Int32 {
        return this.CurrentDay;
    }

    public final func GetCurrentRentCycleStartDay() -> Int32 {
        return this.CurrentRentCycleStart.day;
    }

    public final func GetNextRentCycleStartDay() -> Int32 {
        return this.NextRentCycleStart.day;
    }

    public final func GetDayOfCurrentRentCycle() -> Int32 {
        let now: GameTime = GetGameInstance().GetGameTime();
        return this.RentalPeriodInDays - (this.GetNextRentCycleStartDay() - now.Days());
    }

    public final func GetDaysLeftInRentCycle() -> Int32 {
        let now: GameTime = GetGameInstance().GetGameTime();
        return this.GetNextRentCycleStartDay() - now.Days();
    }

    public final func GetLastQueriedDaysLeftInRentCycle() -> Int32 {
        return this.QuestsSystem.GetFact(this.GetRentCycleTimeLeftQuestFact());
    }

    private final func DispatchCurrentDayUpdateEvent() -> Void {
        ENLog(this, "ENPropertyStateService:DispatchCurrentDayUpdateEvent");
        GameInstance.GetCallbackSystem().DispatchEvent(ENPropertyStateServiceCurrentDayUpdateEvent.Create(this.CurrentDay));
    }

    public final func GetEvictionLockoutRemainingDays(rentalSystem: ref<ENRentSystemBase>) -> Int32 {
        ENLog(this, "   lastDayEvicted: " + ToString(rentalSystem.lastDayEvicted));
        ENLog(this, "   evictionLockoutDays: " + ToString(this.Settings.evictionLockoutDays));
        ENLog(this, "   currentDay: " + ToString(this.GetCurrentDay()));
        let remainingDays: Int32 = (rentalSystem.lastDayEvicted + this.Settings.evictionLockoutDays) - this.GetCurrentDay();

        ENLog(this, "   remainingDays: " + ToString(remainingDays));
        return remainingDays;
    }

    public final func SetLastRentSystemCheckedForEvictionLockout(rentalSystem: ref<ENRentSystemBase>) -> Void {
        this.lastRentSystemCheckedForEvictionLockout = rentalSystem;
    }

    //
    //  Text Replacement
    //
    private final func ReplaceAliasTokenWithNumber(out txt: String, token: String, number: Int32, opt euroDollar: String, opt isCurrency: Bool) {
        if StrContains(txt, token) {
            if isCurrency {
                StrReplaceAll(txt, token, euroDollar + ToString(number));
            } else {
                StrReplaceAll(txt, token, ToString(number));
            }
        }
    }

    private final func ReplaceAliasToken(out txt: String, token: String, replacement: String) {
        if StrContains(txt, token) {
            StrReplaceAll(txt, token, replacement);
        }
    }

    public final func ReplaceEvictionNoticeWildcards(plainTxt: String) -> String {
        if StrContains(plainTxt, "{EN_ALIAS_COST_") {
            let euroDollar = GetLocalizedTextByKey(n"Common-Characters-EuroDollar");
            
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_H10_BALANCE_NOLATEFEE}", this.MBH10.GetRentAmount(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_H10_BALANCE}", this.MBH10.GetOutstandingBalance(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_H10_LATEFEE}", this.MBH10.GetCostLateFeePerDay(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_H10_DEPOSIT}", this.MBH10.GetSecurityDepositAmount(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_PURCHASE_MBH10}", this.MBH10.GetPurchaseAmount(), euroDollar, true);

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_NORTHSIDE_BALANCE_NOLATEFEE}", this.Northside.GetRentAmount(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_NORTHSIDE_BALANCE}", this.Northside.GetOutstandingBalance(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_NORTHSIDE_LATEFEE}", this.Northside.GetCostLateFeePerDay(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_NORTHSIDE_DEPOSIT}", this.Northside.GetSecurityDepositAmount(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_PURCHASE_NORTHSIDE}", this.Northside.GetPurchaseAmount(), euroDollar, true);

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_JAPANTOWN_BALANCE_NOLATEFEE}", this.Japantown.GetRentAmount(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_JAPANTOWN_BALANCE}", this.Japantown.GetOutstandingBalance(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_JAPANTOWN_LATEFEE}", this.Japantown.GetCostLateFeePerDay(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_JAPANTOWN_DEPOSIT}", this.Japantown.GetSecurityDepositAmount(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_PURCHASE_JAPANTOWN}", this.Japantown.GetPurchaseAmount(), euroDollar, true);

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_GLEN_BALANCE_NOLATEFEE}", this.Glen.GetRentAmount(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_GLEN_BALANCE}", this.Glen.GetOutstandingBalance(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_GLEN_LATEFEE}", this.Glen.GetCostLateFeePerDay(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_GLEN_DEPOSIT}", this.Glen.GetSecurityDepositAmount(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_PURCHASE_GLEN}", this.Glen.GetPurchaseAmount(), euroDollar, true);

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_CORPOPLAZA_BALANCE_NOLATEFEE}", this.CorpoPlaza.GetRentAmount(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_CORPOPLAZA_BALANCE}", this.CorpoPlaza.GetOutstandingBalance(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_CORPOPLAZA_LATEFEE}", this.CorpoPlaza.GetCostLateFeePerDay(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_CORPOPLAZA_DEPOSIT}", this.CorpoPlaza.GetSecurityDepositAmount(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_PURCHASE_CORPOPLAZA}", this.CorpoPlaza.GetPurchaseAmount(), euroDollar, true);

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_EZBOB_FEE}", this.EZEstates.GetAgentFee(), euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_SELECTED_MOVE_IN}", this.EZEstates.GetOutstandingBalanceForProperty(this.GetPendingMoveInApartmentID()), euroDollar, true);

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_WILLIAMS_FEE}", this.Settings.costAutoPayFee, euroDollar, true);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_COST_WILLIAMS_AUTOPAY_TOTAL}", this.BillPay.lastPaidAmount, euroDollar, true);
        }

        if StrContains(plainTxt, "{EN_ALIAS_DAYS_") {
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_H10_OVERDUE_WARN2}", this.MBH10.GetOverdueSecondWarningDay() - this.MBH10.GetRentExpirationDay());
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_H10_OVERDUE_WARN3}", this.MBH10.GetOverdueFinalWarningDay() - this.MBH10.GetRentExpirationDay());

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_NORTHSIDE_OVERDUE_WARN2}", this.Northside.GetOverdueSecondWarningDay() - this.Northside.GetRentExpirationDay());
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_NORTHSIDE_OVERDUE_WARN3}", this.Northside.GetOverdueFinalWarningDay() - this.Northside.GetRentExpirationDay());

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_JAPANTOWN_OVERDUE_WARN2}", this.Japantown.GetOverdueSecondWarningDay() - this.Japantown.GetRentExpirationDay());
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_JAPANTOWN_OVERDUE_WARN3}", this.Japantown.GetOverdueFinalWarningDay() - this.Japantown.GetRentExpirationDay());

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_GLEN_OVERDUE_WARN2}", this.Glen.GetOverdueSecondWarningDay() - this.Glen.GetRentExpirationDay());
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_GLEN_OVERDUE_WARN3}", this.Glen.GetOverdueFinalWarningDay() - this.Glen.GetRentExpirationDay());

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_CORPOPLAZA_OVERDUE_WARN2}", this.CorpoPlaza.GetOverdueSecondWarningDay() - this.CorpoPlaza.GetRentExpirationDay());
            //this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_CORPOPLAZA_OVERDUE_WARN3}", this.CorpoPlaza.GetOverdueFinalWarningDay() - this.CorpoPlaza.GetRentExpirationDay());

            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_RENTDUE}", this.GetLastQueriedDaysLeftInRentCycle());
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_RENTALPERIOD}", this.Settings.rentalPeriodInDays);
            this.ReplaceAliasTokenWithNumber(plainTxt, "{EN_ALIAS_DAYS_EVICTION_LOCKOUT}", this.QuestsSystem.GetFact(this.GetEvictionLockoutRemainingDaysQuestFact()));
        }

        if StrContains(plainTxt, "{EN_ALIAS_GENERAL_") {
            this.ReplaceAliasToken(plainTxt, "{EN_ALIAS_GENERAL_CORPOPLAZA_NAME}", this.CorpoPlaza.GetChosenName());
        }

        return plainTxt;
    }
}

//  WorldMapTooltipController - Add rent information to the World Map tooltips
//
@wrapMethod(WorldMapTooltipController)
public func SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>) -> Void {
    wrappedMethod(data, menu);

    let mappinVariant: gamedataMappinVariant = Deref(data).mappin.GetVariant();
    if Equals(mappinVariant, gamedataMappinVariant.Zzz05_ApartmentToPurchaseVariant) {
        let poiMappin: ref<PointOfInterestMappin> = Deref(data).mappin as PointOfInterestMappin;
        if poiMappin != null {
            let journalManager: ref<JournalManager> = menu.GetJournalManager();
            let apartmentOffer: ref<PurchaseOffer_Record> = this.GetApartmentOfferForMapPin(poiMappin, journalManager);
            let price: Int32 = apartmentOffer.PriceHandle().OverrideValue();
            let textParams: ref<inkTextParams> = new inkTextParams();
            textParams.AddNumber("price", price);

            let apartmentName: String = apartmentOffer.Name();
            if Equals(apartmentName, "LocKey#80746") {
                // Corpo Plaza
                textParams.AddNumber("rent", ENRentSystemCorpoPlaza.Get().GetRentAmount());

            } else if Equals(apartmentName, "LocKey#80747") {
                // Glen
                textParams.AddNumber("rent", ENRentSystemGlen.Get().GetRentAmount());

            } else if Equals(apartmentName, "LocKey#80748") {
                // Northside
                textParams.AddNumber("rent", ENRentSystemNorthside.Get().GetRentAmount());

            } else if Equals(apartmentName, "LocKey#80749") {
                // Japantown
                textParams.AddNumber("rent", ENRentSystemJapantown.Get().GetRentAmount());
            }
            textParams.AddNumber("period", ENSettings.Get().rentalPeriodInDays);

            let descStr: String = "LocKey#93557";
            inkTextRef.SetLocalizedTextScript(this.m_descText, descStr, textParams);

            // Bugfix - Fix the size of the preview image for apartments
            let previewImageSize: Vector2 = new Vector2(594.0, 333.7);
            inkWidgetRef.SetSize(this.m_linkImage, previewImageSize);
        }
    }
}

//  WorldMapTooltipController - Reset the size of the preview image back to the default
//
@wrapMethod(WorldMapTooltipController)
protected final func Reset() -> Void {
    wrappedMethod();
    let previewImageSize: Vector2 = new Vector2(594.0, 194.0);
    inkWidgetRef.SetSize(this.m_linkImage, previewImageSize);
}

@wrapMethod(PopupsManager)
private final func ShowTutorial() -> Void {
    let oldMessage: String = GetLocalizedText(this.m_tutorialData.message);
    let newMessage: String = ENPropertyStateService.Get().ReplaceEvictionNoticeWildcards(oldMessage);

    if NotEquals(oldMessage, newMessage) {
        this.m_tutorialData.message = newMessage;
    }

    wrappedMethod();
}