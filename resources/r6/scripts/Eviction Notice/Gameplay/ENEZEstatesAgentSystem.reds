// -----------------------------------------------------------------------------
// ENEZEstatesAgentSystem
// -----------------------------------------------------------------------------
//
// - Gameplay System that handles the EZ Estates Agent text message interaction.
//

module EvictionNotice.Gameplay

import EvictionNotice.System.*
import EvictionNotice.Logging.*
import EvictionNotice.Settings.ENSettings
import EvictionNotice.Main.ENTimeSkipData
import EvictionNotice.Services.{
    ENPropertyStateService,
    ENPropertyStateServiceCurrentDayUpdateEvent
}
import EvictionNotice.Utils.{
    GetPlayerMoney
}

class ENEZEstatesAgentSystemEventListener extends ENSystemEventListener {
	private func GetSystemInstance() -> wref<ENEZEstatesAgentSystem> {
		return ENEZEstatesAgentSystem.Get();
	}

    private cb func OnLoad() {
		super.OnLoad();

        GameInstance.GetCallbackSystem().RegisterCallback(n"EvictionNotice.Services.ENPropertyStateServiceCurrentDayUpdateEvent", this, n"OnPropertyStateServiceCurrentDayUpdateEvent", true);
    }

    private cb func OnPropertyStateServiceCurrentDayUpdateEvent(event: ref<ENPropertyStateServiceCurrentDayUpdateEvent>) {
		this.GetSystemInstance().OnDayUpdated(event.GetData());
	}
}

public class ENEZEstatesAgentSystem extends ENSystem {
    private persistent let lastTextBackDismissedDay: Int32;
    private persistent let textBackQueued: Bool = false;

    private let QuestsSystem: ref<QuestsSystem>;
    private let TransactionSystem: ref<TransactionSystem>;
    private let PropertyStateService: ref<ENPropertyStateService>;

    private let factListenerQuestPhaseDebug: Uint32;
    private let factListenerActionTryToDoMoveInToPending: Uint32;
    private let factListenerActionTryToPurchasePending: Uint32;
    private let factListenerActionGetRentCycleTimeLeft: Uint32;
    private let factListenerActionSetEZBobDismissTimer: Uint32;

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENEZEstatesAgentSystem> {
		let instance: ref<ENEZEstatesAgentSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"EvictionNotice.Gameplay.ENEZEstatesAgentSystem") as ENEZEstatesAgentSystem;
		return instance;
	}

	public final static func Get() -> ref<ENEZEstatesAgentSystem> {
		return ENEZEstatesAgentSystem.GetInstance(GetGameInstance());
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
    private func DoPostResumeActions() -> Void {}

    private func GetSystems() -> Void {
        let gameInstance = GetGameInstance();
        this.QuestsSystem = GameInstance.GetQuestsSystem(gameInstance);
        this.TransactionSystem = GameInstance.GetTransactionSystem(gameInstance);
        this.PropertyStateService = ENPropertyStateService.GetInstance(gameInstance);
    }

    private func GetBlackboards(attachedPlayer: ref<PlayerPuppet>) -> Void {}
    private func SetupData() -> Void {}
    
    private func RegisterListeners() -> Void {
        this.factListenerQuestPhaseDebug = this.QuestsSystem.RegisterListener(this.GetQuestPhaseGraphDebugQuestFact(), this, n"OnQuestPhaseDebugFactChanged");
        
        this.factListenerActionTryToDoMoveInToPending = this.QuestsSystem.RegisterListener(this.GetActionTryToDoMoveInToPendingQuestFact(), this, n"OnTryToDoMoveInToPending");
        this.factListenerActionTryToPurchasePending = this.QuestsSystem.RegisterListener(this.GetActionTryToPurchasePendingApartmentQuestFact(), this, n"OnTryToPurchasePending");
        this.factListenerActionGetRentCycleTimeLeft = this.QuestsSystem.RegisterListener(this.GetActionGetRentCycleTimeLeftQuestFact(), this, n"OnGetRentCycleTimeLeft");
        this.factListenerActionSetEZBobDismissTimer = this.QuestsSystem.RegisterListener(this.GetActionSetEZBobDismissTimerQuestFact(), this, n"OnSetEZBobDismissTimer");
    }

    private func RegisterAllRequiredDelayCallbacks() -> Void {}
    
    private func UnregisterListeners() -> Void {
        this.QuestsSystem.UnregisterListener(this.GetQuestPhaseGraphDebugQuestFact(), this.factListenerQuestPhaseDebug);
        this.factListenerQuestPhaseDebug = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionTryToDoMoveInToPendingQuestFact(), this.factListenerActionTryToDoMoveInToPending);
        this.factListenerActionTryToDoMoveInToPending = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionTryToDoMoveInToPendingQuestFact(), this.factListenerActionTryToPurchasePending);
        this.factListenerActionTryToPurchasePending = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionGetRentCycleTimeLeftQuestFact(), this.factListenerActionGetRentCycleTimeLeft);
        this.factListenerActionGetRentCycleTimeLeft = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionSetEZBobDismissTimerQuestFact(), this.factListenerActionSetEZBobDismissTimer);
        this.factListenerActionSetEZBobDismissTimer = 0u;
    }
    
    private func UnregisterAllDelayCallbacks() -> Void {}
    public func OnTimeSkipFinished(data: ENTimeSkipData) -> Void {}
    public func OnSettingChangedSpecific(changedSettings: array<String>) -> Void {}
    private func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {}

    //
    //  System-Specific Methods
    //
    public func GetQuestPhaseGraphDebugQuestFact() -> CName {
        return n"en_fact_ezbob_debug";
    }

    public func GetActionStartEZEstatesAgentQuestFact() -> CName {
        return n"en_fact_action_start_ezestates_agent";
    }

    public func GetActionTryToDoMoveInToPendingQuestFact() -> CName {
        return n"en_fact_action_try_to_do_movein_to_pending";
    }

    public func GetActionGetRentCycleTimeLeftQuestFact() -> CName {
        return n"en_fact_action_get_rent_cycle_time_left";
    }

    public func GetActionTryToPurchasePendingApartmentQuestFact() -> CName {
        return n"en_fact_action_try_to_purchase_pending";
    }

    public func GetActionSetEZBobDismissTimerQuestFact() -> CName {
        return n"en_fact_action_set_ezbob_dismiss_timer";
    }

    public func GetActionEZBobDismissTimerCompleteQuestFact() -> CName {
        return n"en_fact_action_ezbob_dismiss_timer_complete";
    }

    public func GetLastMoveInWasSuccessfulQuestFact() -> CName {
        return n"en_fact_last_movein_was_successful";
    }

    public func GetHasEverMovedBackInQuestFact() -> CName {
        return n"en_fact_has_ever_moved_back_in";
    }

    public func GetHasEverMovedBackInToMBH10QuestFact() -> CName {
        return n"en_fact_has_ever_moved_back_in_to_MBH10";
    }

    public func GetRentCycleTimeLeftQuestFact() -> CName {
        return n"en_fact_rent_cycle_time_left";
    }

    public func GetPurchaseOffersCountQuestFact() -> CName {
        return n"en_fact_purchase_offers_count";
    }

    public func GetLastPurchaseWasSuccessfulQuestFact() -> CName {
        return n"en_fact_last_purchase_was_successful";
    }

    public final func GetAgentFee() -> Int32 {
        return this.Settings.costEZBobFee;
    }

    private final func OnQuestPhaseDebugFactChanged(value: Int32) -> Void {
        if value != 0 {
            ENLog(this, "#### DEBUG Quest Phase Graph --- Value: " + ToString(value));
            this.QuestsSystem.SetFact(this.GetQuestPhaseGraphDebugQuestFact(), 0);
        }
    }

    private final func SetLastMoveInWasSuccessful(success: Bool) -> Void {
        if success {
            this.QuestsSystem.SetFact(this.GetLastMoveInWasSuccessfulQuestFact(), 1);
        } else {
            this.QuestsSystem.SetFact(this.GetLastMoveInWasSuccessfulQuestFact(), 0);
        }
    }

    private final func SetLastPurchaseWasSuccessful(success: Bool) -> Void {
        if success {
            this.QuestsSystem.SetFact(this.GetLastPurchaseWasSuccessfulQuestFact(), 1);
        } else {
            this.QuestsSystem.SetFact(this.GetLastPurchaseWasSuccessfulQuestFact(), 0);
        }
    }

    public final func GetOutstandingBalanceForProperty(apartmentID: Int32) -> Int32 {
        let apartment: ENRentalProperty = this.PropertyStateService.GetRentalPropertyByID(apartmentID);
        let rentSystem: ref<ENRentSystemBase> = this.PropertyStateService.GetRentalSystemFromRentalProperty(apartment);
        return rentSystem.GetOutstandingBalance();
    }

    public final func GetPurchaseCostForProperty(apartmentID: Int32) -> Int32 {
        let apartment: ENRentalProperty = this.PropertyStateService.GetRentalPropertyByID(apartmentID);
        let rentSystem: ref<ENRentSystemBase> = this.PropertyStateService.GetRentalSystemFromRentalProperty(apartment);
        return rentSystem.GetPurchaseAmount();
    }

    private final func OnTryToDoMoveInToPending(value: Int32) -> Void {
        if value != 0 {
            let apartmentID: Int32 = this.PropertyStateService.GetPendingMoveInApartmentID();
            let moveInCost: Int32 = this.GetOutstandingBalanceForProperty(apartmentID);
            let pendingApartment: ENRentalProperty = this.PropertyStateService.GetRentalPropertyByID(apartmentID);
            let pendingApartmentRentalSystem: ref<ENRentSystemBase> = this.PropertyStateService.GetRentalSystemFromRentalProperty(pendingApartment);

            // If the player has enough money, execute the move-in.
            if GetPlayerMoney() < moveInCost {
                this.SetLastMoveInWasSuccessful(false);

            } else {
                // Set a fact to note if we have ever moved back in after moving out or eviction. Changes dialogue.
                this.QuestsSystem.SetFact(this.GetHasEverMovedBackInQuestFact(), 1);

                pendingApartmentRentalSystem.MoveIn(moveInCost);
                this.SetLastMoveInWasSuccessful(true);

                // If this was Megabuilding H10, note that we have now paid a deposit. Changes dialogue.
                if Equals(pendingApartment, ENRentalProperty.MegabuildingH10) {
                    this.QuestsSystem.SetFact(this.GetHasEverMovedBackInToMBH10QuestFact(), 1);
                }
            }

            // Allow Quest Phase graph to continue
            this.QuestsSystem.SetFact(this.GetActionTryToDoMoveInToPendingQuestFact(), 0);
        }
    }

    private final func OnTryToPurchasePending(value: Int32) -> Void {
        if value != 0 {
            let apartmentID: Int32 = this.PropertyStateService.GetPendingPurchaseApartmentID();
            let purchaseCost: Int32 = this.GetPurchaseCostForProperty(apartmentID);
            let pendingApartment: ENRentalProperty = this.PropertyStateService.GetRentalPropertyByID(apartmentID);
            let pendingApartmentRentalSystem: ref<ENRentSystemBase> = this.PropertyStateService.GetRentalSystemFromRentalProperty(pendingApartment);

            // If the player has enough money, execute the purchase.
            if GetPlayerMoney() < purchaseCost {
                this.SetLastPurchaseWasSuccessful(false);

            } else {
                pendingApartmentRentalSystem.Purchase(purchaseCost);
                this.SetLastPurchaseWasSuccessful(true);
            }

            // Allow Quest Phase graph to continue
            this.QuestsSystem.SetFact(this.GetActionTryToPurchasePendingApartmentQuestFact(), 0);
        }
    }

    private final func OnGetRentCycleTimeLeft(value: Int32) -> Void {
        if value != 0 {
            this.QuestsSystem.SetFact(this.GetRentCycleTimeLeftQuestFact(), this.PropertyStateService.GetDaysLeftInRentCycle());

            this.QuestsSystem.SetFact(this.GetActionGetRentCycleTimeLeftQuestFact(), 0);
        }
    }

    public final func OnSetEZBobDismissTimer(value: Int32) -> Void {
        if Equals(value, 1) {
            this.lastTextBackDismissedDay = this.PropertyStateService.GetCurrentDay();
            this.textBackQueued = true;

            this.QuestsSystem.SetFact(this.GetActionSetEZBobDismissTimerQuestFact(), 0);
        }
    }

    public func OnDayUpdated(currentDay: Int32) {
        if this.textBackQueued {
            if currentDay - this.lastTextBackDismissedDay >= 2 {
                this.textBackQueued = false;
                this.QuestsSystem.SetFact(this.GetActionEZBobDismissTimerCompleteQuestFact(), 1);
            }
        }
    }
}
