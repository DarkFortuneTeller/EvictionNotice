module EvictionNotice.Gameplay

import EvictionNotice.System.ENSystemEventListener
import EvictionNotice.Settings.ENSettings
import EvictionNotice.Services.ENPropertyStateService

public final class ENRentSystemGlenEventListeners extends ENRentSystemBaseEventListeners {
	private func GetSystemInstance() -> wref<ENRentSystemBase> {
		return ENRentSystemGlen.Get();
	}
}

public final class ENRentSystemGlen extends ENRentSystemBase {
    public final static func GetSystemName() -> CName {
        return n"EvictionNotice.Gameplay.ENRentSystemGlen";
    }

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENRentSystemGlen> {
		let instance: ref<ENRentSystemGlen> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(ENRentSystemGlen.GetSystemName()) as ENRentSystemGlen;
		return instance;
	}

	public final static func Get() -> ref<ENRentSystemGlen> {
		return ENRentSystemGlen.GetInstance(GetGameInstance());
	}

    private final func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {
        // Allow the Quest Phase graph to begin executing.
        this.QuestsSystem.SetFact(this.GetSystemRunningQuestFact(), 1);
    }

    public func OnSettingChangedSpecific(changedSettings: array<String>) -> Void {
        // TODO - Can this be consolidated under Base?
        if ArrayContains(changedSettings, "glenPaymentsUntilQuest") {
            this.QuestsSystem.SetFact(this.GetPaidRentCountRequiredForLoyaltyQuestFact(), this.Settings.glenPaymentsUntilQuest);
        }

        // TODO - Can this be consolidated under Base?
        if ArrayContains(changedSettings, "glenPurchaseAllowed") {
            let purchaseAllowed: Int32 = Equals(this.Settings.glenPurchaseAllowed, true) ? 1 : 0;
            this.QuestsSystem.SetFact(this.GetApartmentPurchaseAllowedQuestFact(), purchaseAllowed);
        }
    }

    //
    //  Required Overrides
    //
    public func GetBaseGamePurchasedQuestFact() -> CName {
        return n"dlc6_apart_hey_gle_purchased";
    }

    public final func GetQuestPhaseGraphDebugQuestFact() -> CName {
        return n"en_fact_glen_debug";
    }

    public final func GetSystemRunningQuestFact() -> CName {
        return n"en_fact_glen_system_running";
    }

    public func GetActionUpdateLastRentStateQuestFact() -> CName {
        return n"en_fact_glen_action_update_last_rent_state";
    }

    public func GetRentStateQuestFact() -> CName {
        return n"en_fact_glen_rent_state";
    }

    public func GetLastRentStateQuestFact() -> CName {
        return n"en_fact_glen_last_rent_state";
    }

    public func GetActionCancelMoveOutQuestFact() -> CName {
        return n"en_fact_glen_action_cancel_move_out";
    }

    public func GetActionRefundSecurityDepositQuestFact() -> CName {
        return n"en_fact_glen_action_refund_security_deposit";
    }

    public func GetActionSendOneDayMoveOutWarningQuestFact() -> CName {
        return n"en_fact_glen_action_send_one_day_move_out_warning";
    }

    public func GetActionQueueMoveOutQuestFact() -> CName {
        return n"en_fact_glen_action_queue_move_out";
    }

    public func GetActionUpdateMoveOutStateFactQuestFact() -> CName {
        return n"en_fact_glen_action_update_move_out_state_fact";
    }

    public func GetActionSendWelcomeMessageQuestFact() -> CName {
        return n"en_fact_glen_action_send_welcome_message";
    }

    public func GetMoveOutStateQuestFact() -> CName {
        return n"en_fact_glen_move_out_state";
    }

    public func GetActionStartMoveOutConvoQuestFact() -> CName {
        return n"en_fact_glen_action_start_move_out_convo";
    }

    public final func GetActionTryToPayRentQuestFact() -> CName {
        // 0 = Default
        // 1 = Try To Pay Rent
        // 2 = Success
        // 3 = Failure
        return n"en_fact_glen_action_try_to_pay_rent";
    }

    public final func GetActionCloseAndLockDoorQuestFact() -> CName {
        return n"en_fact_glen_action_close_and_lock_door";
    }

    public func GetActionUpdateApartmentPurchaseAllowedQuestFact() -> CName {
        return n"en_fact_action_update_glen_purchase_allowed";
    }

    public func GetActionUpdateHasAvailableDiscountQuestFact() -> CName {
        return n"en_fact_action_update_glen_has_available_discount";
    }

    public func GetActionSendPurchaseOfferMessageQuestFact() -> CName {
        return n"en_fact_action_send_purchase_offer_message_glen";
    }

    public func GetActionSendPurchaseCompleteMessageQuestFact() -> CName {
        return n"en_fact_action_send_purchase_complete_message_glen";
    }

    public final func GetActionDoRentDurationChangedCleanup() -> CName {
        return n"en_fact_action_do_rent_duration_changed_cleanup_glen";
    }

    public final func GetPlayerHasRentMoneyQuestFact() -> CName {
        return n"en_fact_glen_player_has_rent_money";
    }

    public func GetApartmentPurchaseAllowedQuestFact() -> CName {
        return n"en_fact_glen_purchase_allowed";
    }

    public func GetApartmentPurchaseAvailableQuestFact() -> CName {
        return n"en_fact_glen_purchase_available";
    }

    public func GetPaidRentCountRequiredForLoyaltyQuestFact() -> CName {
        return n"en_fact_glen_rent_paid_count_req_loyalty_quest";
    }

    public func GetHasAvailableDiscountQuestFact() -> CName {
        return n"en_fact_glen_has_available_discount";
    }

    public func GetCostLateFeePerDay() -> Int32 {
        return this.Settings.costGlenLateFee;
    }

    public func GetRentAmount() -> Int32 {
        let loyaltyQuestComplete: Bool = this.IsLoyaltyQuestComplete();
        let discountMult: Float = Cast<Float>(100 - this.Settings.glenLoyaltyDiscountPct) / 100.0;

        if loyaltyQuestComplete {
            return FloorF(Cast<Float>(this.Settings.costGlenRent) * discountMult);
        } else {
            return this.Settings.costGlenRent;
        }
    }
    
    public func GetSecurityDepositAmount() -> Int32 {
        return FromVariant<Int32>(TweakDBInterface.GetFlat(t"EconomicAssignment.vs_apartment_dlc6_apart_hey_gle.overrideValue"));
    }

    public func GetPurchaseAmount() -> Int32 {
        return this.Settings.costGlenPurchase;
    }

    private final func GetApartmentDebugName() -> String {
        return "The Glen";
    }

    private final func GetApartmentDoorNodeRefPath() -> String {
        return "$/03_night_city/#c_heywood/glen/loc_dlc6_apart_hey_gle_prefabNE2OSJQ/loc_dlc6_apart_hey_gle_gameplay_prefab65UL2QQ/#loc_dlc6_apart_hey_gle_devices/lift_2_floors_prefabE2SM4GI/lift_door_2";
    }

    private final func GetApartmentScreenNodeRefPath() -> String {
        return "$/mod/worldbuildergroup_en_glen/#worldbuildergroup_en_glen_en_apartment_screen_1";
    }

    private func GetApartmentPurchaseAllowedSettingValue() -> Bool {
        return this.Settings.glenPurchaseAllowed;
    }

    private func GetLoyaltyQuestDiscountPctSettingValue() -> Int32 {
        return this.Settings.glenLoyaltyDiscountPct;
    }

    private func GetLoyaltyQuestPath() -> String {
        return "quests/minor_quest/glen_loyaltyquest";
    }

    private func GetShowApartmentScreenMessageOnPurchase() -> Bool {
        return true;
    }
}