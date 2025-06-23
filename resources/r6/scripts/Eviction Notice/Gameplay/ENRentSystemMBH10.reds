module EvictionNotice.Gameplay

import EvictionNotice.System.ENSystemEventListener
import EvictionNotice.Settings.ENSettings
import EvictionNotice.Services.ENPropertyStateService

public final class ENRentSystemMBH10EventListeners extends ENRentSystemBaseEventListeners {
	private func GetSystemInstance() -> wref<ENRentSystemBase> {
		return ENRentSystemMBH10.Get();
	}
}

public final class ENRentSystemMBH10 extends ENRentSystemBase {
    public final static func GetSystemName() -> CName {
        return n"EvictionNotice.Gameplay.ENRentSystemMBH10";
    }

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENRentSystemMBH10> {
		let instance: ref<ENRentSystemMBH10> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(ENRentSystemMBH10.GetSystemName()) as ENRentSystemMBH10;
		return instance;
	}

	public final static func Get() -> ref<ENRentSystemMBH10> {
		return ENRentSystemMBH10.GetInstance(GetGameInstance());
	}

    private final func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {
        // Allow the Quest Phase graph to begin executing.
        this.QuestsSystem.SetFact(this.GetSystemRunningQuestFact(), 1);
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

    public final func GetPlayerHasRentMoneyQuestFact() -> CName {
        return n"en_fact_mbh10_player_has_rent_money";
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

    private final func GetApartmentDebugName() -> String {
        return "Megabuilding H10";
    }

    private final func GetApartmentDoorNodeRefPath() -> String {
        return "$/03_night_city/c_watson/little_china/loc_megabuilding_a_prefab4KCU2IQ/loc_megabuilding_a_gameplay_prefab2GWVWSA/#loc_megabuilding_a_devices/{q001_door_v_flat}_prefab4EOA7RA/#q001_door_v_flat";
    }

    private final func GetApartmentScreenNodeRefPath() -> String {
        return "$/mod/worldbuildergroup_en_mbh10/#worldbuildergroup_en_mbh10_en_apartment_screen";
    }

    //private final func GetMBH10OriginalApartmentScreenNodeRefPath() -> String {
    //    return "$/03_night_city/c_watson/little_china/loc_megabuilding_a_prefab4KCU2IQ/loc_megabuilding_a_gameplay_prefab2GWVWSA/#loc_megabuilding_a_devices/{q001_door_v_flat}_prefab4EOA7RA/apartment_screen_1_prefabO4JL7SI";
    //}
}