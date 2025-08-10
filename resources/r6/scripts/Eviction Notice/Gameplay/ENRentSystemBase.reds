// -----------------------------------------------------------------------------
// ENRentSystem
// -----------------------------------------------------------------------------
//
// - Gameplay System that handles the amount of rent owed for each real estate property.
//

// TODO - Update the q303 emails to reflect the player's current rental state

module EvictionNotice.Gameplay

import EvictionNotice.Logging.*
import EvictionNotice.System.*
import EvictionNotice.Utils.{
    RunGuard,
    IsGameTimeAfter,
    GivePlayerMoney,
    TryToRemovePlayerMoney,
    PlayerHasMoney,
    RemovePlayerMoney,
    GetHalfDaysUntilEviction
}
import EvictionNotice.Settings.ENSettings
import EvictionNotice.Main.ENTimeSkipData
import EvictionNotice.Services.{
    ENGameStateService,
    ENPropertyStateService,
    ENPropertyStateServiceCurrentDayUpdateEvent
}

public enum ENRentalProperty {
    MegabuildingH10 = 0,
    Northside = 1,
    Japantown = 2,
    Glen = 3,
    CorpoPlaza = 4
}

public enum ENRentState {
    Purchased = -2,
    NeverRented = -1,
    Paid = 0,
    Due = 1,
    OverdueFirstWarning = 2,
    OverdueSecondWarning = 3,
    OverdueFinalWarning = 4,
    MovedOut = 5,
    Evicted = 6
}

public enum ENPropertyStatus {
    None = 0,
    Available = 1,
    RoutineMaintenance = 2
}

public enum ENTryToPayRentAction {
    Idle = 0,
    Execute = 1,
    Success = 2,
    Failure = 3
}

public enum ENMoveOutState {
    NotMovingOut = 0,
    MovingOut = 1,
    SentWarning = 2,
    MovedOut = 3
}

public enum ENSurrenderReason {
    MovedOut = 0,
    Evicted = 1
}

public enum ENWelcomeMessageType {
    None = 0,
    Welcome = 1,
    WelcomeBack = 2
}

public abstract class ENRentSystemBaseEventListeners extends ENSystemEventListener {
    //
	// Required Overrides
	//
	private func GetSystemInstance() -> wref<ENRentSystemBase> {
		ENLogNoSystem(true, this, "MISSING REQUIRED METHOD OVERRIDE FOR GetSystemInstance()", ENLogLevel.Error);
		return null;
	}

    private cb func OnLoad() {
		super.OnLoad();

        GameInstance.GetCallbackSystem().RegisterCallback(n"EvictionNotice.Services.ENPropertyStateServiceCurrentDayUpdateEvent", this, n"OnPropertyStateServiceCurrentDayUpdateEvent", true);
    }

    private cb func OnPropertyStateServiceCurrentDayUpdateEvent(event: ref<ENPropertyStateServiceCurrentDayUpdateEvent>) {
		this.GetSystemInstance().OnDayUpdated(event.GetData());
	}
}

public abstract class ENRentSystemBase extends ENSystem {
    private persistent let oneTimeSetupDone: Bool = false;
    private persistent let moveOutState: ENMoveOutState;
    private persistent let rentState: ENRentState = ENRentState.NeverRented;
    private persistent let lastPaidRentCycleStartDay: Int32;
    private persistent let lastDaysOverdue: Int32;
    private persistent let lastOutstandingBalance: Int32;
    private persistent let lastDayEvicted: Int32;

    private let ApartmentDoor: ref<DoorControllerPS>;
    private let ApartmentScreen: ref<ApartmentScreenControllerPS>;

    private let QuestsSystem: ref<QuestsSystem>;
    private let JournalManager: ref<JournalManager>;
    private let PersistencySystem: ref<GamePersistencySystem>;
    private let BlackboardSystem: ref<BlackboardSystem>;
    private let GameStateService: ref<ENGameStateService>;
    private let PropertyStateService: ref<ENPropertyStateService>;
    private let EZEstatesAgentSystem: ref<ENEZEstatesAgentSystem>;
    private let BillPaySystem: ref<ENBillPaySystem>;

    private let factListenerQuestPhaseDebug: Uint32;
    private let factListenerBaseGamePurchasedFact: Uint32;
    private let factListenerActionUpdateLastRentState: Uint32;
    private let factListenerActionTryToPayRent: Uint32;
    private let factListenerActionCloseAndLockDoor: Uint32;
    private let factListenerActionQueueMoveOut: Uint32;
    private let factListenerActionRefundSecurityDeposit: Uint32;
    private let factListenerActionCancelMoveOut: Uint32;
    private let factListenerActionUpdateMoveOutStateFact: Uint32;
    private let factListenerActionUpdatePurchaseAllowedFact: Uint32;
    private let factListenerActionUpdateHasAvailableDiscountFact: Uint32;

    private let propertyDebugName: String;

    private let updateDelayID: DelayID;

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

    private func DoPostSuspendActions() -> Void {
        // If rented in the base game, make the apartment available again.
        if NotEquals(this.GetRentState(), ENRentState.NeverRented) {
            this.SetRequiredPaidAndOccupancyStates();
            this.UnlockApartmentDoor();
        }
    }

    private func DoPostResumeActions() -> Void {
        // If rented in the base game, set the last paid day to today and start updates.
        if NotEquals(this.GetRentState(), ENRentState.NeverRented) {
            this.SetRequiredPaidAndOccupancyStates();
            this.UnlockApartmentDoor();
        }
    }

    private func GetSystems() -> Void {
        let gameInstance = GetGameInstance();
        this.QuestsSystem = GameInstance.GetQuestsSystem(gameInstance);
        this.JournalManager = GameInstance.GetJournalManager(gameInstance);
        this.PersistencySystem = GameInstance.GetPersistencySystem(gameInstance);
        this.BlackboardSystem = GameInstance.GetBlackboardSystem(gameInstance);
        this.GameStateService = ENGameStateService.GetInstance(gameInstance);
        this.PropertyStateService = ENPropertyStateService.GetInstance(gameInstance);
        this.EZEstatesAgentSystem = ENEZEstatesAgentSystem.GetInstance(gameInstance);
        this.BillPaySystem = ENBillPaySystem.GetInstance(gameInstance);
    }

    private func GetBlackboards(attachedPlayer: ref<PlayerPuppet>) -> Void {}

    private func SetupData() -> Void {
        this.propertyDebugName = this.GetApartmentDebugName();
        
        let apartmentDoorPID: PersistentID = this.CreatePersistentIDFromNodeRefPath(this.GetApartmentDoorNodeRefPath(), n"controller");
        this.ApartmentDoor = this.PersistencySystem.GetConstAccessToPSObject(apartmentDoorPID, n"DoorControllerPS") as DoorControllerPS;

        let apartmentScreenPID: PersistentID = this.CreatePersistentIDFromNodeRefPath(this.GetApartmentScreenNodeRefPath(), n"controller");
        this.ApartmentScreen = this.PersistencySystem.GetConstAccessToPSObject(apartmentScreenPID, n"ApartmentScreenControllerPS") as ApartmentScreenControllerPS;
        this.ApartmentScreen.SetEvictionNoticeManaged();
        this.ApartmentScreen.SetShowMessageOnPurchase(this.GetShowApartmentScreenMessageOnPurchase());
    }

    private func RegisterListeners() -> Void {
        this.factListenerQuestPhaseDebug = this.QuestsSystem.RegisterListener(this.GetQuestPhaseGraphDebugQuestFact(), this, n"OnQuestPhaseDebugFactChanged");

        if NotEquals(this.GetBaseGamePurchasedQuestFact(), n"") {
            this.factListenerBaseGamePurchasedFact = this.QuestsSystem.RegisterListener(this.GetBaseGamePurchasedQuestFact(), this, n"OnBaseGamePurchasedFactChanged");
        }

        this.factListenerActionUpdateLastRentState = this.QuestsSystem.RegisterListener(this.GetActionUpdateLastRentStateQuestFact(), this, n"OnUpdateLastRentStateActionFactChanged");
        this.factListenerActionTryToPayRent = this.QuestsSystem.RegisterListener(this.GetActionTryToPayRentQuestFact(), this, n"OnTryToPayRentActionFactChanged");
        this.factListenerActionCloseAndLockDoor = this.QuestsSystem.RegisterListener(this.GetActionCloseAndLockDoorQuestFact(), this, n"OnCloseAndLockDoorActionFactChanged");
        this.factListenerActionQueueMoveOut = this.QuestsSystem.RegisterListener(this.GetActionQueueMoveOutQuestFact(), this, n"OnQueueMoveOutActionFactChanged");
        this.factListenerActionRefundSecurityDeposit = this.QuestsSystem.RegisterListener(this.GetActionRefundSecurityDepositQuestFact(), this, n"OnRefundSecurityDepositActionFactChanged");
        this.factListenerActionCancelMoveOut = this.QuestsSystem.RegisterListener(this.GetActionCancelMoveOutQuestFact(), this, n"OnCancelMoveOutActionFactChanged");
        this.factListenerActionUpdateMoveOutStateFact = this.QuestsSystem.RegisterListener(this.GetActionUpdateMoveOutStateFactQuestFact(), this, n"OnUpdateMoveOutStateFactActionFactChanged");
        this.factListenerActionUpdatePurchaseAllowedFact = this.QuestsSystem.RegisterListener(this.GetActionUpdateApartmentPurchaseAllowedQuestFact(), this, n"OnUpdateApartmentPurchaseAllowed");
        this.factListenerActionUpdateHasAvailableDiscountFact = this.QuestsSystem.RegisterListener(this.GetActionUpdateHasAvailableDiscountQuestFact(), this, n"OnUpdateHasAvailableDiscount");
    }

    private func RegisterAllRequiredDelayCallbacks() -> Void {}

    private func UnregisterListeners() -> Void {
        this.QuestsSystem.UnregisterListener(this.GetQuestPhaseGraphDebugQuestFact(), this.factListenerQuestPhaseDebug);
        this.factListenerQuestPhaseDebug = 0u;

        this.QuestsSystem.UnregisterListener(this.GetBaseGamePurchasedQuestFact(), this.factListenerBaseGamePurchasedFact);
        this.factListenerBaseGamePurchasedFact = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionUpdateLastRentStateQuestFact(), this.factListenerActionUpdateLastRentState);
        this.factListenerActionUpdateLastRentState = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionTryToPayRentQuestFact(), this.factListenerActionTryToPayRent);
        this.factListenerActionTryToPayRent = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionCloseAndLockDoorQuestFact(), this.factListenerActionCloseAndLockDoor);
        this.factListenerActionCloseAndLockDoor = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionQueueMoveOutQuestFact(), this.factListenerActionQueueMoveOut);
        this.factListenerActionQueueMoveOut = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionRefundSecurityDepositQuestFact(), this.factListenerActionRefundSecurityDeposit);
        this.factListenerActionRefundSecurityDeposit = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionCancelMoveOutQuestFact(), this.factListenerActionCancelMoveOut);
        this.factListenerActionCancelMoveOut = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionUpdateMoveOutStateFactQuestFact(), this.factListenerActionUpdateMoveOutStateFact);
        this.factListenerActionUpdateMoveOutStateFact = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionUpdateApartmentPurchaseAllowedQuestFact(), this.factListenerActionUpdatePurchaseAllowedFact);
        this.factListenerActionUpdatePurchaseAllowedFact = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionUpdateHasAvailableDiscountQuestFact(), this.factListenerActionUpdateHasAvailableDiscountFact);
        this.factListenerActionUpdateHasAvailableDiscountFact = 0u;
    }

    private func UnregisterAllDelayCallbacks() -> Void {}
    public func OnTimeSkipFinished(data: ENTimeSkipData) -> Void {}
    public func OnSettingChangedSpecific(changedSettings: array<String>) -> Void {}

    private func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {
        if !this.oneTimeSetupDone {
            // Set the last day evicted in the distant past to avoid lockout at game start
            this.lastDayEvicted = -9999;

            this.oneTimeSetupDone = true;
        }
    }

    //
    //  Required Overrides
    //
    public func GetBaseGamePurchasedQuestFact() -> CName {
        this.LogMissingOverrideError("GetBaseGamePurchasedQuestFact");
        return n"";
    }

    public func GetRentStateQuestFact() -> CName {
        this.LogMissingOverrideError("GetRentStateQuestFact");
        return n"";
    }

    public func GetLastRentStateQuestFact() -> CName {
        this.LogMissingOverrideError("GetLastRentStateQuestFact");
        return n"";
    }

    public func GetActionUpdateLastRentStateQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionUpdateLastRentStateQuestFact");
        return n"";
    }

    public func GetQuestPhaseGraphDebugQuestFact() -> CName {
        this.LogMissingOverrideError("GetQuestPhaseGraphDebugQuestFact");
        return n"";
    }

    public func GetActionCancelMoveOutQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionCancelMoveOutQuestFact");
        return n"";
    }

    public func GetActionRefundSecurityDepositQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionRefundSecurityDepositQuestFact");
        return n"";
    }

    public func GetActionSendOneDayMoveOutWarningQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionSendOneDayMoveOutWarningQuestFact");
        return n"";
    }

    public func GetActionQueueMoveOutQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionQueueMoveOutQuestFact");
        return n"";
    }

    public func GetActionUpdateMoveOutStateFactQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionUpdateMoveOutStateFactQuestFact");
        return n"";
    }

    public func GetActionSendWelcomeMessageQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionSendWelcomeMessageQuestFact");
        return n"";
    }

    public func GetMoveOutStateQuestFact() -> CName {
        this.LogMissingOverrideError("GetMoveOutStateQuestFact");
        return n"";
    }

    public func GetActionStartMoveOutConvoQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionStartMoveOutConvoQuestFact");
        return n"";
    }

    public func GetActionTryToPayRentQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionTryToPayRentQuestFact");
        return n"";
    }

    public func GetActionCloseAndLockDoorQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionCloseAndLockDoorQuestFact");
        return n"";
    }

    public func GetActionUpdateApartmentPurchaseAllowedQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionUpdateApartmentPurchaseAllowedQuestFact");
        return n"";
    }

    public func GetActionUpdateHasAvailableDiscountQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionUpdateHasAvailableDiscountQuestFact");
        return n"";
    }

    public func GetActionSendPurchaseOfferMessageQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionSendPurchaseOfferMessageQuestFact");
        return n"";
    }

    public func GetActionSendPurchaseCompleteMessageQuestFact() -> CName {
        this.LogMissingOverrideError("GetActionSendPurchaseCompleteMessageQuestFact");
        return n"";
    }

    public final func GetActionDoRentDurationChangedCleanup() -> CName {
        this.LogMissingOverrideError("GetActionDoRentDurationChangedCleanup");
        return n"";
    }

    public func GetPlayerHasRentMoneyQuestFact() -> CName {
        this.LogMissingOverrideError("GetPlayerHasRentMoneyQuestFact");
        return n"";
    }

    public func GetApartmentPurchaseAllowedQuestFact() -> CName {
        this.LogMissingOverrideError("GetApartmentPurchaseAllowedQuestFact");
        return n"";
    }

    public func GetApartmentPurchaseAvailableQuestFact() -> CName {
        this.LogMissingOverrideError("GetApartmentPurchaseAvailableQuestFact");
        return n"";
    }

    public func GetPaidRentCountRequiredForLoyaltyQuestFact() -> CName {
        this.LogMissingOverrideError("GetPaidRentCountRequiredForLoyaltyQuestFact");
        return n"";
    }

    public func GetHasAvailableDiscountQuestFact() -> CName {
        this.LogMissingOverrideError("GetHasAvailableDiscountQuestFact");
        return n"";
    }

    public func GetCostLateFeePerDay() -> Int32 {
        this.LogMissingOverrideError("GetCostLateFeePerDay");
		return -1;
    }

    public func GetRentAmount() -> Int32 {
        this.LogMissingOverrideError("GetRentAmount");
        return -1;
    }

    public func GetSecurityDepositAmount() -> Int32 {
        this.LogMissingOverrideError("GetSecurityDepositAmount");
        return -1;
    }

    public func GetPurchaseAmount() -> Int32 {
        this.LogMissingOverrideError("GetPurchaseAmount");
        return -1;
    }

    private func GetApartmentDebugName() -> String {
        this.LogMissingOverrideError("GetApartmentDebugName");
		return "";
    }

    private func GetApartmentDoorNodeRefPath() -> String {
        this.LogMissingOverrideError("GetApartmentDoorNodeRefPath");
		return "";
    }

    private func GetApartmentScreenNodeRefPath() -> String {
        this.LogMissingOverrideError("GetApartmentScreenNodeRefPath");
		return "";
    }

    private func GetApartmentPurchaseAllowedSettingValue() -> Bool {
        this.LogMissingOverrideError("GetApartmentPurchaseAllowedSettingValue");
		return true;
    }

    private func GetLoyaltyQuestDiscountPctSettingValue() -> Int32 {
        this.LogMissingOverrideError("GetLoyaltyQuestDiscountPctSettingValue");
		return 0;
    }

    private func GetLoyaltyQuestPath() -> String {
        this.LogMissingOverrideError("GetLoyaltyQuestPath");
        return "";
    }

    private func GetShowApartmentScreenMessageOnPurchase() -> Bool {
        this.LogMissingOverrideError("GetShowApartmentScreenMessageOnPurchase");
        return false;
    }

    //
    //  System-Specific Methods
    //
    public final func GetDaysOverdue() -> Int32 {
        return this.PropertyStateService.GetCurrentDay() - this.GetRentExpirationDay();
    }

    public final func GetDaysUntilEviction() -> Int32 {
        return (this.lastPaidRentCycleStartDay + (this.PropertyStateService.RentalPeriodInDays * 2)) - this.PropertyStateService.GetCurrentDay();
    }

    private final func GetRentExpirationDay() -> Int32 {
        return (this.lastPaidRentCycleStartDay + this.PropertyStateService.RentalPeriodInDays);
    }

    private final func GetEvictionDay() -> Int32 {
        return (this.lastPaidRentCycleStartDay + (this.PropertyStateService.RentalPeriodInDays * 2));
    }

    private final func GetOverdueFirstWarningDay() -> Int32 {
        return (this.lastPaidRentCycleStartDay + this.PropertyStateService.RentalPeriodInDays + 1);
    }

    private final func GetOverdueSecondWarningDay() -> Int32 {
        return this.lastPaidRentCycleStartDay + this.PropertyStateService.RentalPeriodInDays + GetHalfDaysUntilEviction();
    }

    private final func GetOverdueFinalWarningDay() -> Int32 {
        return (this.lastPaidRentCycleStartDay + (this.PropertyStateService.RentalPeriodInDays * 2)) - 1;
    }

    private func GetEvictionLockoutPeriodInDays() -> Int32 {
        return this.Settings.evictionLockoutDays;
    }

    private final func IsLoyaltyQuestComplete() -> Bool {
        let loyaltyQuestState: gameJournalEntryState = this.JournalManager.GetEntryState(this.JournalManager.GetEntryByString(this.GetLoyaltyQuestPath(), "gameJournalQuest"));
        return Equals(loyaltyQuestState, gameJournalEntryState.Succeeded) ? true : false;
    }

    public func OnDayUpdated(currentDay: Int32) {
        this.UpdateRent(currentDay);
    }

    public func GetOutstandingBalance() -> Int32 {
        let rentState: ENRentState = this.GetRentState();

        if Equals(rentState, ENRentState.Due) {
            // If the rent is due on the due date, they simply owe the rent amount.
            this.lastOutstandingBalance = this.GetRentAmount();
            //ENLog(this, "    ENRentState.Due, balance: " + ToString(this.lastOutstandingBalance));

        } else if this.IsCurrentRentStateOverdue() {
            // If the rent is overdue, they owe the rent, plus a late fee for each day, if applicable.
            this.lastOutstandingBalance = this.GetRentAmount() + (this.GetCostLateFeePerDay() * this.GetDaysOverdue());
            ENLog(this, "    Overdue, balance: " + ToString(this.lastOutstandingBalance));

        } else if Equals(rentState, ENRentState.Evicted) {
            // If the player was evicted, to move back in, they must pay:
            // * All of the late fees for their last cycle
            // * The outstanding rent
            // * The agent fee
            this.lastOutstandingBalance = this.GetRentAmount() + (this.GetCostLateFeePerDay() * (this.PropertyStateService.RentalPeriodInDays - 1)) + this.EZEstatesAgentSystem.GetAgentFee();
            //ENLog(this, "    ENRentState.Evicted, balance: " + ToString(this.lastOutstandingBalance));

        } else if Equals(rentState, ENRentState.MovedOut) {
            // If the player moved out, to move back in, they must pay:
            // * The security deposit
            // * One period's rent (pro-rated)
            // * The agent fee
            let proRatePercentage: Float = 1.0 - Cast<Float>(this.PropertyStateService.GetDayOfCurrentRentCycle()) / Cast<Float>(this.Settings.rentalPeriodInDays);
            let proRatedRent: Int32 = CeilF(Cast<Float>(this.GetRentAmount()) * proRatePercentage);
            
            this.lastOutstandingBalance = this.GetSecurityDepositAmount() + proRatedRent + this.EZEstatesAgentSystem.GetAgentFee();
            //ENLog(this, "    ENRentState.MovedOut, balance: " + ToString(this.lastOutstandingBalance));
        }

        // Also returns the last calculated outstanding balance when ENRentState.Paid, for SMS display purposes.
        return this.lastOutstandingBalance;
    }

    private final func SetRequiredPaidAndOccupancyStates() -> Void {
        this.lastPaidRentCycleStartDay = this.PropertyStateService.GetCurrentRentCycleStartDay();
        this.SetRentState(ENRentState.Paid);
        this.SetMoveOutState(ENMoveOutState.NotMovingOut);
    }

    public final func MoveIn(moveInCost: Int32) -> Void {
        RemovePlayerMoney(moveInCost); // Does not require scene tier check.
        this.SetRequiredPaidAndOccupancyStates();
        this.UnlockApartmentDoor();
    }

    // Does not require scene tier check.
    public final func Purchase(purchaseCost: Int32) -> Void {
        RemovePlayerMoney(purchaseCost); // Does not require scene tier check.
        
        this.SetRentState(ENRentState.Purchased);
        this.SetMoveOutState(ENMoveOutState.NotMovingOut);
        this.QuestsSystem.SetFact(this.GetApartmentPurchaseAvailableQuestFact(), 0);
        this.QuestsSystem.SetFact(this.GetActionSendPurchaseCompleteMessageQuestFact(), 1);

        this.UnlockApartmentDoor();
    }

    private final func CreatePersistentIDFromNodeRefPath(nodeRefPath: String, componentName: CName) -> PersistentID {
        let nr: NodeRef = CreateNodeRef(nodeRefPath);
        let eid: EntityID = EntityID.FromHash(NodeRefToHash(nr));
        return CreatePersistentID(eid, componentName);
    }

    private func GetPropertyDebugName() -> String {
        return this.propertyDebugName;
    }

    private func SetPropertyDebugName(debugName: String) -> Void {
        this.propertyDebugName = debugName;
    }

    private final func UpdateRent(currentDay: Int32) {
        ENLog(this, "############### UpdateRent: The Current Day Is Now: " + ToString(currentDay) + " ###############");

        if this.IsCurrentRentStateRented() {
            let rentExpirationDay: Int32 = this.GetRentExpirationDay();
            if currentDay >= rentExpirationDay {
                if currentDay == rentExpirationDay {
                    if Equals(this.moveOutState, ENMoveOutState.MovingOut) || Equals(this.moveOutState, ENMoveOutState.SentWarning) {
                        ENLog(this, "    Moved out.");
                        this.SetMoveOutState(ENMoveOutState.MovedOut);
                        this.SetRentState(ENRentState.MovedOut);

                    } else if Equals(this.moveOutState, ENMoveOutState.MovedOut) {
                        // Do nothing; remain in this state.
    
                    } else if !this.BillPaySystem.IsAutoPayEnabled() {
                        ENLog(this, "    Rent on " + this.GetPropertyDebugName() + " is due today!");
                        this.SetRentState(ENRentState.Due);
                    }
                } else {
                    ENLog(this, "Rent on " + this.GetPropertyDebugName() + " is past due by " + ToString(currentDay - rentExpirationDay) + "! Checking for eviction.");
                    if currentDay >= this.GetEvictionDay() {
                        ENLog(this, "    You have been evicted!");
                        this.SetRentState(ENRentState.Evicted);
                    } else {
                        if currentDay >= this.GetOverdueFinalWarningDay() {
                            ENLog(this, "    Overdue, sent final warning.");
                            this.SetRentState(ENRentState.OverdueFinalWarning);
                        } else if currentDay >= this.GetOverdueSecondWarningDay() {
                            ENLog(this, "    Overdue, sent second warning.");
                            this.SetRentState(ENRentState.OverdueSecondWarning);
                        } else if currentDay >= this.GetOverdueFirstWarningDay() {
                            ENLog(this, "    Overdue, sent first warning.");
                            this.SetRentState(ENRentState.OverdueFirstWarning);
                        }
                    }
                }
            } else {
                // Paid status is set when payment is made.
                ENLog(this, "    Rent on " + this.GetPropertyDebugName() + " is paid.");
                
                if Equals(this.moveOutState, ENMoveOutState.MovingOut) && currentDay == (rentExpirationDay - 1) {
                    ENLog(this, "    Sent one day remaining move out warning.");
                    this.moveOutState = ENMoveOutState.SentWarning;
                    this.QuestsSystem.SetFact(this.GetActionSendOneDayMoveOutWarningQuestFact(), 1);
                }
            }
        }

        ENLog(this, "UpdateRent for " + this.GetPropertyDebugName() + " complete, status: " + ToString(this.rentState));
    }

    private final func OnQuestPhaseDebugFactChanged(value: Int32) -> Void {
        if value != 0 {
            ENLog(this, "#### DEBUG Quest Phase Graph --- Value: " + ToString(value));
            this.QuestsSystem.SetFact(this.GetQuestPhaseGraphDebugQuestFact(), 0);
        }
    }

    private final func OnRefundSecurityDepositActionFactChanged(value: Int32) -> Void {
        if Equals(value, 1) {
            this.QuestsSystem.SetFact(this.GetActionRefundSecurityDepositQuestFact(), 0);

            if IsSystemEnabledAndRunning(this) {
                GivePlayerMoney(this.GetSecurityDepositAmount());
            }
        }
    }

    private final func OnTryToPayRentActionFactChanged(value: Int32) -> Void {
        let action: ENTryToPayRentAction = IntEnum<ENTryToPayRentAction>(value);

        if Equals(action, ENTryToPayRentAction.Execute) {
            let paid: Bool = this.TryToPayRent();

            if paid {
                this.QuestsSystem.SetFact(this.GetActionTryToPayRentQuestFact(), EnumInt<ENTryToPayRentAction>(ENTryToPayRentAction.Success));
            } else {
                this.QuestsSystem.SetFact(this.GetActionTryToPayRentQuestFact(), EnumInt<ENTryToPayRentAction>(ENTryToPayRentAction.Failure));
            }
        }
    }

    private final func OnUpdateLastRentStateActionFactChanged(value: Int32) -> Void {
        if Equals(value, 1) {
            ENLog(this, "OnUpdateLastRentStateActionFactChanged");
            this.QuestsSystem.SetFact(this.GetLastRentStateQuestFact(), this.QuestsSystem.GetFact(this.GetRentStateQuestFact()));
            this.QuestsSystem.SetFact(this.GetActionUpdateLastRentStateQuestFact(), 0);
        }
    }

    private final func OnCloseAndLockDoorActionFactChanged(value: Int32) -> Void {
        if Equals(value, 1) {
            this.QuestsSystem.SetFact(this.GetActionCloseAndLockDoorQuestFact(), 0);

            if IsSystemEnabledAndRunning(this) {
                this.LockApartmentDoor();
            }
        }
    }

    private final func OnQueueMoveOutActionFactChanged(value: Int32) -> Void {
        if Equals(value, 1) {
            this.QuestsSystem.SetFact(this.GetActionQueueMoveOutQuestFact(), 0);
            this.QuestsSystem.SetFact(this.GetActionStartMoveOutConvoQuestFact(), 1);
            
            this.QueueMoveOut();
        }
    }

    private final func OnCancelMoveOutActionFactChanged(value: Int32) -> Void {
        if Equals(value, 1) {
            this.QuestsSystem.SetFact(this.GetActionCancelMoveOutQuestFact(), 0);

            this.CancelMoveOut();
        }
    }

    private final func OnUpdateMoveOutStateFactActionFactChanged(value: Int32) -> Void {
        if Equals(value, 1) {
            this.SetMoveOutStateFactForProperty();
            this.QuestsSystem.SetFact(this.GetActionUpdateMoveOutStateFactQuestFact(), 0);
        }
    }

    private final func OnBaseGamePurchasedFactChanged(value: Int32) -> Void {
        if value > 0 {
            this.SetRequiredPaidAndOccupancyStates();
            this.SendWelcomeMessage(ENWelcomeMessageType.Welcome);
        }
    }

    private final func OnUpdateApartmentPurchaseAllowed(value: Int32) -> Void {
        if value > 0 {
            let purchaseAllowed: Int32 = Equals(this.GetApartmentPurchaseAllowedSettingValue(), true) ? 1 : 0;
            this.QuestsSystem.SetFact(this.GetApartmentPurchaseAllowedQuestFact(), purchaseAllowed);

            this.QuestsSystem.SetFact(this.GetActionUpdateApartmentPurchaseAllowedQuestFact(), 0);
        }
    }

    private final func OnUpdateHasAvailableDiscount(value: Int32) -> Void {
        if value > 0 {
            let hasAvailableDiscount: Int32 = this.GetLoyaltyQuestDiscountPctSettingValue() > 0 ? 1 : 0;
            this.QuestsSystem.SetFact(this.GetHasAvailableDiscountQuestFact(), hasAvailableDiscount);

            this.QuestsSystem.SetFact(this.GetActionUpdateHasAvailableDiscountQuestFact(), 0);
        }
    }

    public final func TryToPayRent() -> Bool {
        let paid: Bool = TryToRemovePlayerMoney(this.GetOutstandingBalance()); // Does not require scene tier check.
        if paid {
            this.lastPaidRentCycleStartDay = this.PropertyStateService.GetCurrentRentCycleStartDay();
            this.SetRentState(ENRentState.Paid);
            return true;

        } else {
            return false;
        }
    }

    private final func QueueMoveOut() -> Void {
        if this.PropertyStateService.GetDaysLeftInRentCycle() <= 1 {
            ENLog(this, "Sent one day remaining move out warning.");
            this.moveOutState = ENMoveOutState.SentWarning;
            this.QuestsSystem.SetFact(this.GetActionSendOneDayMoveOutWarningQuestFact(), 1);
        } else {
            this.moveOutState = ENMoveOutState.MovingOut;
        }
    }

    private final func CancelMoveOut() -> Void {
        this.moveOutState = ENMoveOutState.NotMovingOut;
    }

    private final func SetScreenState(state: ERentStatus, opt overdueDays: Int32) {
        ENLog(this, "Setting " + this.GetApartmentDebugName() + " screen to state " + ToString(state) + " (overdue days: " + ToString(overdueDays) + ")");
        this.ApartmentScreen.SetCurrentRentStatus(state);
        if overdueDays > 0 {
            this.ApartmentScreen.m_currentOverdue = overdueDays;
        }
        this.ApartmentScreen.UpdateRentState();
    }

    private final func SetScreenState(extendedState: ERentStatusExtended) {
        ENLog(this, "Setting " + this.GetApartmentDebugName() + " screen to extended state " + ToString(extendedState));
        this.ApartmentScreen.SetCurrentRentStatusExtended(ERentStatus.PAID, extendedState);
        this.ApartmentScreen.UpdateRentState();
    }

    private final func LockApartmentDoor() -> Void {
        ENLog(this, "LockApartmentDoor for " + this.GetPropertyDebugName());

        let pid: PersistentID = this.CreatePersistentIDFromNodeRefPath(this.GetApartmentDoorNodeRefPath(), n"controller");
        let closeAction = this.ApartmentDoor.ActionQuestForceCloseImmediate();
        let sealAction = this.ApartmentDoor.ActionQuestForceSeal();

        this.PersistencySystem.QueuePSEvent(pid, n"DoorControllerPS", closeAction);
        this.PersistencySystem.QueuePSEvent(pid, n"DoorControllerPS", sealAction);
    }

    private final func UnlockApartmentDoor() -> Void {
        ENLog(this, "UnlockApartmentDoor for " + this.GetPropertyDebugName());
        
        let pid: PersistentID = this.CreatePersistentIDFromNodeRefPath(this.GetApartmentDoorNodeRefPath(), n"controller");
        let unlockAction = this.ApartmentDoor.ActionQuestForceUnlock();

        this.PersistencySystem.QueuePSEvent(pid, n"DoorControllerPS", unlockAction);
    }

    private final func SetMoveOutState(state: ENMoveOutState) -> Void {
        this.moveOutState = state;
    }

    private final func SetMoveOutStateFactForProperty() -> Void {
        this.QuestsSystem.SetFact(this.GetMoveOutStateQuestFact(), EnumInt<ENMoveOutState>(this.moveOutState));
    }

    private final func SetRentState(state: ENRentState) -> Void {
        ENLog(this, "Setting Rent State to: " + ToString(state));
        this.rentState = state;
        this.QuestsSystem.SetFact(this.GetRentStateQuestFact(), EnumInt<ENRentState>(state));

        this.UpdateScreenState(state);
        this.PropertyStateService.UpdateRentedPropertyCount();

        if Equals(state, ENRentState.Evicted) {
            this.lastDayEvicted = this.PropertyStateService.GetCurrentDay();
            ENLog(this, "Last Day Evicted is now: " + ToString(this.lastDayEvicted));
        }
    }

    private final func UpdateScreenState(state: ENRentState) -> Void {
        ENLog(this, "Updating screen state to: " + ToString(state));

        if Equals(state, ENRentState.Paid) {
            this.SetScreenState(ERentStatus.PAID);
        } else if Equals(state, ENRentState.Due) {
            this.SetScreenState(ERentStatusExtended.Due);
        } else if Equals(state, ENRentState.OverdueFirstWarning) || Equals(state, ENRentState.OverdueSecondWarning) || Equals(state, ENRentState.OverdueFinalWarning) {
            let daysOverdue: Int32 = this.GetDaysOverdue();

            if NotEquals(daysOverdue, this.lastDaysOverdue) {
                this.SetScreenState(ERentStatus.OVERDUE, daysOverdue);
                this.lastDaysOverdue = daysOverdue;
            }
        } else if Equals(state, ENRentState.Evicted) {
            this.SetScreenState(ERentStatus.EVICTED);
        } else if Equals(state, ENRentState.MovedOut) || Equals(state, ENRentState.NeverRented) {
            this.SetScreenState(ERentStatusExtended.Available);
        } else if Equals(state, ENRentState.Purchased) {
            this.SetScreenState(ERentStatusExtended.Purchased);
        }
    }

    public final func GetRentState() -> ENRentState {
        return this.rentState;
    }

    private final func GetRentStateValue(rentState: ENRentState) -> Int32 {
        return EnumInt<ENRentState>(rentState);
    }

    public final func GetIsPurchasedInBaseGame() -> Bool {
        return this.QuestsSystem.GetFact(this.GetBaseGamePurchasedQuestFact()) >= 1;
    }

    public final func IsCurrentRentStateRented() -> Bool {
        return this.GetRentStateValue(this.rentState) >= this.GetRentStateValue(ENRentState.Paid) && this.GetRentStateValue(this.rentState) < this.GetRentStateValue(ENRentState.MovedOut);
    }

    private final func IsCurrentRentStateWithOutstandingBalance() -> Bool {
        return this.GetRentStateValue(this.rentState) >= this.GetRentStateValue(ENRentState.Due) && this.GetRentStateValue(this.rentState) <= this.GetRentStateValue(ENRentState.OverdueFinalWarning);
    }

    private final func IsCurrentRentStateSurrendered() -> Bool {
        return this.GetRentStateValue(this.rentState) == this.GetRentStateValue(ENRentState.MovedOut) || this.GetRentStateValue(this.rentState) == this.GetRentStateValue(ENRentState.Evicted);
    }

    private final func IsCurrentRentStateOverdue() -> Bool {
        return this.GetRentStateValue(this.rentState) > this.GetRentStateValue(ENRentState.Due) && this.GetRentStateValue(this.rentState) < this.GetRentStateValue(ENRentState.MovedOut);
    }

    public func SendWelcomeMessage(messageType: ENWelcomeMessageType) -> Void {
        this.QuestsSystem.SetFact(this.GetActionSendWelcomeMessageQuestFact(), EnumInt<ENWelcomeMessageType>(messageType));
    }
}

//  MessangerItemRenderer - Replace text message wildcards.
//
@wrapMethod(MessangerItemRenderer)
private final func SetMessageView(const txt: script_ref<String>, type: MessageViewType, const contactName: script_ref<String>) -> Void {
    // Called right before the UI pushes text data to the Phone SMS widget.
    // Look for and replace any numeric wildcards with Settings data.
    let plainTxt = GetLocalizedText(txt);
    
    if StrContains(plainTxt, "{EN_ALIAS_") {
        let newText = ENPropertyStateService.Get().ReplaceEvictionNoticeWildcards(plainTxt);
        wrappedMethod(newText, type, contactName);

    } else {
        wrappedMethod(txt, type, contactName);
    }
}

//  MessangerReplyItemRenderer - Replace text message wildcards.
//
@wrapMethod(MessangerReplyItemRenderer)
protected func OnJournalEntryUpdated(entry: wref<JournalEntry>, extraData: ref<IScriptable>) -> Void {
    let choiceEntry: wref<JournalPhoneChoiceEntry> = entry as JournalPhoneChoiceEntry;
    let plainTxt = GetLocalizedText(choiceEntry.GetText());

    if StrContains(plainTxt, "{EN_ALIAS_") {
        let newText = ENPropertyStateService.Get().ReplaceEvictionNoticeWildcards(plainTxt);
        inkTextRef.SetText(this.m_labelPathRef, newText);
        this.m_isQuestImportant = choiceEntry.IsQuestImportant();
        this.AnimateSelection();
    } else {
        wrappedMethod(entry, extraData);
    }
}
