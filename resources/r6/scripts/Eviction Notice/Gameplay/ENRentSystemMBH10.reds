module EvictionNotice.Gameplay

import EvictionNotice.Logging.*
import EvictionNotice.System.{
    ENSystem,
    ENSystemEventListener
}
import EvictionNotice.Settings.ENSettings
import EvictionNotice.Services.ENPropertyStateService

public final class ENRentSystemMBH10EventListeners extends ENRentSystemBaseEventListeners {
	private func GetSystemInstance() -> wref<ENRentSystemBase> {
		return ENRentSystemMBH10.Get();
	}
}

public final class ENRentSystemMBH10 extends ENRentSystemBase {
    private let factListenerQ305JohnnySceneActive: Uint32;

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENRentSystemMBH10> {
		let instance: ref<ENRentSystemMBH10> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(NameOf(ENRentSystemMBH10)) as ENRentSystemMBH10;
		return instance;
	}

	public final static func Get() -> ref<ENRentSystemMBH10> {
		return ENRentSystemMBH10.GetInstance(GetGameInstance());
	}

    private final func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {
        // Allow the Quest Phase graph to begin executing.
        this.QuestsSystem.SetFact(this.GetSystemRunningQuestFact(), 1);
    }

    // Always make MBH10 available when Eviction Notice is disabled.
    private func DoPostSuspendActions() -> Void {
        this.SetRequiredPaidAndOccupancyStates();
        this.UnlockApartmentDoor();
    }

    // Always make MBH10 available when Eviction Notice is re-enabled.
    private func DoPostResumeActions() -> Void {
        this.SetRequiredPaidAndOccupancyStates();
        this.UnlockApartmentDoor();
    }

    private func RegisterListeners() -> Void {
        super.RegisterListeners();

        this.factListenerQ305JohnnySceneActive = this.QuestsSystem.RegisterListener(this.GetQ305JohnnySceneActiveQuestFact(), this, n"OnQ305JohnnySceneActive");
    }

    private func UnregisterListeners() -> Void {
        super.UnregisterListeners();

        this.QuestsSystem.UnregisterListener(this.GetQ305JohnnySceneActiveQuestFact(), this.factListenerQ305JohnnySceneActive);
        this.factListenerQ305JohnnySceneActive = 0u;
    }

    //
    //  Required Overrides
    //
    public func GetBaseGamePurchasedQuestFact() -> CName {
        // This property doesn't have a purchased quest fact.
        return n"";
    }

    public final func GetQuestPhaseGraphDebugQuestFact() -> CName {
        return n"en_fact_mbh10_debug";
    }

    public final func GetSystemRunningQuestFact() -> CName {
        return n"en_fact_mbh10_system_running";
    }

    public func GetActionUpdateLastRentStateQuestFact() -> CName {
        return n"en_fact_mbh10_action_update_last_rent_state";
    }

    public func GetRentStateQuestFact() -> CName {
        return n"en_fact_mbh10_rent_state";
    }

    public func GetLastRentStateQuestFact() -> CName {
        return n"en_fact_mbh10_last_rent_state";
    }

    public func GetActionCancelMoveOutQuestFact() -> CName {
        return n"en_fact_mbh10_action_cancel_move_out";
    }

    public func GetActionRefundSecurityDepositQuestFact() -> CName {
        return n"en_fact_mbh10_action_refund_security_deposit";
    }

    public func GetActionSendOneDayMoveOutWarningQuestFact() -> CName {
        return n"en_fact_mbh10_action_send_one_day_move_out_warning";
    }

    public func GetActionQueueMoveOutQuestFact() -> CName {
        return n"en_fact_mbh10_action_queue_move_out";
    }

    public func GetActionUpdateMoveOutStateFactQuestFact() -> CName {
        return n"en_fact_mbh10_action_update_move_out_state_fact";
    }

    public func GetActionSendWelcomeMessageQuestFact() -> CName {
        return n"en_fact_mbh10_action_send_welcome_message";
    }

    public func GetMoveOutStateQuestFact() -> CName {
        return n"en_fact_mbh10_move_out_state";
    }

    public func GetActionStartMoveOutConvoQuestFact() -> CName {
        return n"en_fact_mbh10_action_start_move_out_convo";
    }

    public final func GetActionTryToPayRentQuestFact() -> CName {
        // 0 = Default
        // 1 = Try To Pay Rent
        // 2 = Success
        // 3 = Failure
        return n"en_fact_mbh10_action_try_to_pay_rent";
    }

    public final func GetActionCloseAndLockDoorQuestFact() -> CName {
        return n"en_fact_mbh10_action_close_and_lock_door";
    }

    public func GetActionUpdateApartmentPurchaseAllowedQuestFact() -> CName {
        return n"en_fact_action_update_mbh10_purchase_allowed";
    }

    public func GetActionUpdateHasAvailableDiscountQuestFact() -> CName {
        return n"en_fact_action_update_mbh10_has_available_discount";
    }

    public func GetActionSendPurchaseOfferMessageQuestFact() -> CName {
        return n"en_fact_action_send_purchase_offer_message_mbh10";
    }

    public func GetActionSendPurchaseCompleteMessageQuestFact() -> CName {
        return n"en_fact_action_send_purchase_complete_message_mbh10";
    }

    public final func GetActionDoRentDurationChangedCleanup() -> CName {
        return n"en_fact_action_do_rent_duration_changed_cleanup_mbh10";
    }

    public final func GetPlayerHasRentMoneyQuestFact() -> CName {
        return n"en_fact_mbh10_player_has_rent_money";
    }

    public func GetApartmentPurchaseAllowedQuestFact() -> CName {
        return n"en_fact_mbh10_purchase_allowed";
    }

    public func GetApartmentPurchaseAvailableQuestFact() -> CName {
        return n"en_fact_mbh10_purchase_available";
    }

    public func GetPaidRentCountRequiredForLoyaltyQuestFact() -> CName {
        return n"en_fact_mbh10_rent_paid_count_req_loyalty_quest";
    }

    public func GetHasAvailableDiscountQuestFact() -> CName {
        return n"en_fact_mbh10_has_available_discount";
    }

    public func GetQ305JohnnySceneActiveQuestFact() -> CName {
        return n"q305_johnny_scene_active";
    }

    public func GetCostLateFeePerDay() -> Int32 {
        return this.Settings.costH10LateFee;
    }

    public func GetRentAmount() -> Int32 {
        return this.Settings.costH10Rent;
    }

    public func GetSecurityDepositAmount() -> Int32 {
        return this.Settings.costH10SecurityDeposit;
    }

    public func GetPurchaseAmount() -> Int32 {
        return 1000000;
    }

    private final func GetApartmentDebugName() -> String {
        return "Megabuilding H10";
    }

    private final func GetApartmentDoorNodeRefPath() -> String {
        return "$/03_night_city/c_watson/little_china/loc_megabuilding_a_prefab4KCU2IQ/loc_megabuilding_a_gameplay_prefab2GWVWSA/#loc_megabuilding_a_devices/{q001_door_v_flat}_prefab4EOA7RA/#q001_door_v_flat";
    }

    private final func GetApartmentScreenNodeRefPath() -> String {
        return "$/mod/worldbuildergroup_en_mbh10/#worldbuildergroup_en_mbh10_en_apartment_screen";
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
        return "quests/minor_quest/mbh10_loyaltyquest";
    }

    private func GetShowApartmentScreenMessageOnPurchase() -> Bool {
        return false;
    }

    //
    // System-Specific Methods
    //
    public func GetOutstandingBalance() -> Int32 {
        let rentState: ENRentState = this.GetRentState();

        if Equals(rentState, ENRentState.Evicted) {
            // If the player was evicted, to move back in, they must pay:
            // * All of the late fees for their last cycle
            // * The outstanding rent
            // * The agent fee
            // * (MBH10 Only) If they have never paid a security deposit, they must pay it now.
            let balance: Int32 = this.GetRentAmount() + (this.GetCostLateFeePerDay() * (this.PropertyStateService.RentalPeriodInDays - 1)) + this.EZEstatesAgentSystem.GetAgentFee();
            if Equals(this.QuestsSystem.GetFact(ENEZEstatesAgentSystem.Get().GetHasEverMovedBackInToMBH10QuestFact()), 0) {
                balance += this.GetSecurityDepositAmount();
            }
            this.lastOutstandingBalance = balance;
            //ENLog(this, "    ENRentState.Evicted, balance: " + ToString(this.lastOutstandingBalance));

            return this.lastOutstandingBalance;
        } else {
            return super.GetOutstandingBalance();
        }
    }

    // Q305 - Lock and unlock the door to Megabuilding H10 according to the scene with Johnny.
    private final func OnQ305JohnnySceneActive(value: Int32) -> Void {
        ENLog(this, "@@@@@@ Q305 Bugfix - Johnny Scene Active, value: " + ToString(value));
        if value > 0 {
            if !this.IsCurrentRentStateRented() {
                this.UnlockApartmentDoor();
            }
        } else if Equals(value, 0) {
            if !this.IsCurrentRentStateRented() {
                this.LockApartmentDoor();
            }
        }
    }
}