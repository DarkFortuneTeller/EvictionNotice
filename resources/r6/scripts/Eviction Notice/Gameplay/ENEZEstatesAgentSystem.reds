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
import EvictionNotice.Services.ENPropertyStateService
import EvictionNotice.Utils.{
    GetPlayerMoney,
    RemovePlayerMoney
}

class ENEZEstatesAgentSystemEventListener extends ENSystemEventListener {
	private func GetSystemInstance() -> wref<ENEZEstatesAgentSystem> {
		return ENEZEstatesAgentSystem.Get();
	}
}

public class ENEZEstatesAgentSystem extends ENSystem {
    private let QuestsSystem: ref<QuestsSystem>;
    private let TransactionSystem: ref<TransactionSystem>;
    private let PropertyStateService: ref<ENPropertyStateService>;

    private let factListenerQuestPhaseDebug: Uint32;
    private let factListenerActionTryToDoMoveInToPending: Uint32;
    private let factListenerActionGetRentCycleTimeLeft: Uint32;

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENEZEstatesAgentSystem> {
		let instance: ref<ENEZEstatesAgentSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"EvictionNotice.Gameplay.ENEZEstatesAgentSystem") as ENEZEstatesAgentSystem;
		return instance;
	}

	public final static func Get() -> ref<ENEZEstatesAgentSystem> {
		return ENEZEstatesAgentSystem.GetInstance(GetGameInstance());
	}

    private func SetupDebugLogging() -> Void {
        this.debugEnabled = true;
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
        this.factListenerActionGetRentCycleTimeLeft = this.QuestsSystem.RegisterListener(this.GetActionGetRentCycleTimeLeftQuestFact(), this, n"OnGetRentCycleTimeLeft");
    }

    private func RegisterAllRequiredDelayCallbacks() -> Void {}
    
    private func UnregisterListeners() -> Void {
        this.QuestsSystem.UnregisterListener(this.GetQuestPhaseGraphDebugQuestFact(), this.factListenerQuestPhaseDebug);
        this.factListenerQuestPhaseDebug = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionTryToDoMoveInToPendingQuestFact(), this.factListenerActionTryToDoMoveInToPending);
        this.factListenerActionTryToDoMoveInToPending = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionGetRentCycleTimeLeftQuestFact(), this.factListenerActionGetRentCycleTimeLeft);
        this.factListenerActionGetRentCycleTimeLeft = 0u;
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

    public func GetLastMoveInWasSuccessfulQuestFact() -> CName {
        return n"en_fact_last_movein_was_successful";
    }

    public func GetHasEverMovedBackInQuestFact() -> CName {
        return n"en_fact_has_ever_moved_back_in";
    }

    public func GetRentCycleTimeLeftQuestFact() -> CName {
        return n"en_fact_rent_cycle_time_left";
    }

    public final func GetAgentFee() -> Int32 {
        return this.Settings.costEZBobFee;
    }

    private final func OnQuestPhaseDebugFactChanged(value: Int32) -> Void {
        if value != 0 {
            ENLog(this.debugEnabled, this, "#### DEBUG Quest Phase Graph --- Value: " + ToString(value));
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

    public final func GetOutstandingBalanceForProperty(apartmentID: Int32) -> Int32 {
        let apartment: ENRentalProperty = this.PropertyStateService.GetRentalPropertyByID(apartmentID);
        let rentSystem: ref<ENRentSystemBase> = this.PropertyStateService.GetRentalSystemFromRentalProperty(apartment);
        return rentSystem.GetOutstandingBalance();
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
            }

            // Allow Quest Phase graph to continue
            this.QuestsSystem.SetFact(this.GetActionTryToDoMoveInToPendingQuestFact(), 0);
        }
    }

    private final func OnGetRentCycleTimeLeft(value: Int32) -> Void {
        if value != 0 {
            this.QuestsSystem.SetFact(this.GetRentCycleTimeLeftQuestFact(), this.PropertyStateService.GetDaysLeftInRentCycle());

            this.QuestsSystem.SetFact(this.GetActionGetRentCycleTimeLeftQuestFact(), 0);
        }
    }
}
