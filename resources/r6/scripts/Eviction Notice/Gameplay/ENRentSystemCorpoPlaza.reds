module EvictionNotice.Gameplay

import EvictionNotice.System.ENSystemEventListener
import EvictionNotice.Settings.ENSettings
import EvictionNotice.Services.ENPropertyStateService

public enum ENCorpoPlazaChosenName {
    NotChosen = 0,
    Formal = 1,
    Informal = 2,
    Full = 3
}

public final class ENRentSystemCorpoPlazaEventListeners extends ENRentSystemBaseEventListeners {
	private func GetSystemInstance() -> wref<ENRentSystemBase> {
		return ENRentSystemCorpoPlaza.Get();
	}
}

public final class ENRentSystemCorpoPlaza extends ENRentSystemBase {
    private let factListenerActionUpdateRequestFacts: Uint32;

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENRentSystemCorpoPlaza> {
		let instance: ref<ENRentSystemCorpoPlaza> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(NameOf(ENRentSystemCorpoPlaza)) as ENRentSystemCorpoPlaza;
		return instance;
	}

	public final static func Get() -> ref<ENRentSystemCorpoPlaza> {
		return ENRentSystemCorpoPlaza.GetInstance(GetGameInstance());
	}

    private final func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {
        // Allow the Quest Phase graph to begin executing.
        this.QuestsSystem.SetFact(this.GetSystemRunningQuestFact(), 1);
    }

    private func RegisterListeners() -> Void {
        super.RegisterListeners();

        this.factListenerActionUpdateRequestFacts = this.QuestsSystem.RegisterListener(this.GetActionUpdateRequestFacts(), this, n"OnUpdateRequestFacts");
    }

    //
    //  Required Overrides
    //
    public func GetBaseGamePurchasedQuestFact() -> CName {
        return n"dlc6_apart_cct_dtn_purchased";
    }

    public final func GetQuestPhaseGraphDebugQuestFact() -> CName {
        return n"en_fact_corpoplaza_debug";
    }

    public final func GetSystemRunningQuestFact() -> CName {
        return n"en_fact_corpoplaza_system_running";
    }

    public func GetActionUpdateLastRentStateQuestFact() -> CName {
        return n"en_fact_corpoplaza_action_update_last_rent_state";
    }

    public func GetRentStateQuestFact() -> CName {
        return n"en_fact_corpoplaza_rent_state";
    }

    public func GetLastRentStateQuestFact() -> CName {
        return n"en_fact_corpoplaza_last_rent_state";
    }

    public func GetActionCancelMoveOutQuestFact() -> CName {
        return n"en_fact_corpoplaza_action_cancel_move_out";
    }

    public func GetActionRefundSecurityDepositQuestFact() -> CName {
        return n"en_fact_corpoplaza_action_refund_security_deposit";
    }

    public func GetActionSendOneDayMoveOutWarningQuestFact() -> CName {
        return n"en_fact_corpoplaza_action_send_one_day_move_out_warning";
    }

    public func GetActionQueueMoveOutQuestFact() -> CName {
        return n"en_fact_corpoplaza_action_queue_move_out";
    }

    public func GetActionUpdateMoveOutStateFactQuestFact() -> CName {
        return n"en_fact_corpoplaza_action_update_move_out_state_fact";
    }

    public func GetActionSendWelcomeMessageQuestFact() -> CName {
        return n"en_fact_corpoplaza_action_send_welcome_message";
    }

    public func GetMoveOutStateQuestFact() -> CName {
        return n"en_fact_corpoplaza_move_out_state";
    }

    public func GetActionStartMoveOutConvoQuestFact() -> CName {
        return n"en_fact_corpoplaza_action_start_move_out_convo";
    }

    public final func GetActionTryToPayRentQuestFact() -> CName {
        // 0 = Default
        // 1 = Try To Pay Rent
        // 2 = Success
        // 3 = Failure
        return n"en_fact_corpoplaza_action_try_to_pay_rent";
    }

    public final func GetActionCloseAndLockDoorQuestFact() -> CName {
        return n"en_fact_corpoplaza_action_close_and_lock_door";
    }

    public func GetActionUpdateApartmentPurchaseAllowedQuestFact() -> CName {
        return n"en_fact_action_update_corpoplaza_purchase_allowed";
    }

    public func GetActionUpdateHasAvailableDiscountQuestFact() -> CName {
        return n"en_fact_action_update_corpoplaza_has_available_discount";
    }

    public func GetActionSendPurchaseOfferMessageQuestFact() -> CName {
        return n"en_fact_action_send_purchase_offer_message_corpoplaza";
    }

    public func GetActionSendPurchaseCompleteMessageQuestFact() -> CName {
        return n"en_fact_action_send_purchase_complete_message_corpoplaza";
    }

    public final func GetActionDoRentDurationChangedCleanup() -> CName {
        return n"en_fact_action_do_rent_duration_changed_cleanup_corpoplaza";
    }

    public final func GetPlayerHasRentMoneyQuestFact() -> CName {
        return n"en_fact_corpoplaza_player_has_rent_money";
    }

    public func GetApartmentPurchaseAllowedQuestFact() -> CName {
        return n"en_fact_corpoplaza_purchase_allowed";
    }

    public func GetApartmentPurchaseAvailableQuestFact() -> CName {
        return n"en_fact_corpoplaza_purchase_available";
    }

    public func GetPaidRentCountRequiredForLoyaltyQuestFact() -> CName {
        return n"en_fact_corpoplaza_rent_paid_count_req_loyalty_quest";
    }

    public func GetHasAvailableDiscountQuestFact() -> CName {
        return n"en_fact_corpoplaza_has_available_discount";
    }

    public func GetCostLateFeePerDay() -> Int32 {
        return this.Settings.costCorpoPlazaLateFee;
    }

    public func GetRentAmount() -> Int32 {
        return this.Settings.costCorpoPlazaRent;
    }

    public func GetSecurityDepositAmount() -> Int32 {
        return FromVariant<Int32>(TweakDBInterface.GetFlat(t"EconomicAssignment.vs_apartment_dlc6_apart_cct_dtn.overrideValue"));
    }

    public func GetPurchaseAmount() -> Int32 {
        return 440000;
    }

    private final func GetApartmentDebugName() -> String {
        return "Corpo Plaza";
    }

    private final func GetApartmentDoorNodeRefPath() -> String {
        return "$/03_night_city/#c_city_center/downtown/loc_dlc6_apart_cct_dtn_prefabPPFRIJQ/loc_dlc6_apart_cct_dtn_gameplay_prefabK5H7HSQ/#loc_dlc6_apart_cct_dtn_devices/single_door_2t_prefabEARRKSI/{single_door}_prefabHKUWE3A";
    }

    private final func GetApartmentScreenNodeRefPath() -> String {
        return "$/mod/worldbuildergroup_en_corpoplaza/#worldbuildergroup_en_corpoplaza_en_apartment_screen_4";
    }

    private func GetApartmentPurchaseAllowedSettingValue() -> Bool {
        // TODO - FUTURE
        return false;
    }

    private func GetLoyaltyQuestDiscountPctSettingValue() -> Int32 {
        // TODO - FUTURE
		return 0;
    }

    private func GetLoyaltyQuestPath() -> String {
        return "quests/minor_quest/corpoplaza_loyaltyquest";
    }

    private func GetShowApartmentScreenMessageOnPurchase() -> Bool {
        return true;
    }

    // System-Specific Methods
    //
    private final func GetCorpoPlazaChosenNameQuestFact() -> CName {
        return n"en_fact_corpoplaza_chosen_name";
    }

    public func GetActionUpdateRequestFacts() -> CName {
        return n"en_fact_action_corpoplaza_update_request_facts";
    }

    public func GetCorpoPlazaRequestFlowerStateFact() -> CName {
        return n"en_fact_corpoplaza_flower_state";
    }

    public func GetCorpoPlazaRequestLastFlowerStateFact() -> CName {
        return n"en_fact_last_corpoplaza_flower_state";
    }

    public final func GetChosenName() -> String {
        let chosenName: ENCorpoPlazaChosenName = IntEnum<ENCorpoPlazaChosenName>(this.QuestsSystem.GetFact(this.GetCorpoPlazaChosenNameQuestFact()));
        let isFemale: Bool = Equals(this.player.GetResolvedGenderName(), n"Female");

        if Equals(chosenName, ENCorpoPlazaChosenName.NotChosen) || Equals(chosenName, ENCorpoPlazaChosenName.Formal) {
            if isFemale {
                return GetLocalizedTextByKey(n"EvictionNotice_TextMsg_corpoplaza_PlayerName_Formal_Female");
            } else {
                return GetLocalizedTextByKey(n"EvictionNotice_TextMsg_corpoplaza_PlayerName_Formal_Male");
            }

        } else if Equals(chosenName, ENCorpoPlazaChosenName.Informal) {
            return GetLocalizedTextByKey(n"EvictionNotice_TextMsg_corpoplaza_PlayerName_Informal");

        } else if Equals(chosenName, ENCorpoPlazaChosenName.Full) {
            if isFemale {
                return GetLocalizedTextByKey(n"EvictionNotice_TextMsg_corpoplaza_PlayerName_Full_Female");
            } else {
                return GetLocalizedTextByKey(n"EvictionNotice_TextMsg_corpoplaza_PlayerName_Full_Male");
            }
        }

        return "";
    }

    public final func OnUpdateRequestFacts(value: Int32) {
        if Equals(value, 1) {
            this.QuestsSystem.SetFact(this.GetCorpoPlazaRequestLastFlowerStateFact(), this.QuestsSystem.GetFact(this.GetCorpoPlazaRequestFlowerStateFact()));

            // Continue.
            this.QuestsSystem.SetFact(this.GetActionUpdateRequestFacts(), 0);
        }
    }
}
