module EvictionNotice.Gameplay

import EvictionNotice.System.ENSystemEventListener
import EvictionNotice.Settings.ENSettings
import EvictionNotice.Services.ENPropertyStateService

public final class ENRentSystemNorthsideEventListeners extends ENRentSystemBaseEventListeners {
	private func GetSystemInstance() -> wref<ENRentSystemBase> {
		return ENRentSystemNorthside.Get();
	}
}

public final class ENRentSystemNorthside extends ENRentSystemBase {
    public final static func GetSystemName() -> CName {
        return n"EvictionNotice.Gameplay.ENRentSystemNorthside";
    }

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENRentSystemNorthside> {
		let instance: ref<ENRentSystemNorthside> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(ENRentSystemNorthside.GetSystemName()) as ENRentSystemNorthside;
		return instance;
	}

	public final static func Get() -> ref<ENRentSystemNorthside> {
		return ENRentSystemNorthside.GetInstance(GetGameInstance());
	}

    private final func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {
        // Allow the Quest Phase graph to begin executing.
        this.QuestsSystem.SetFact(this.GetSystemRunningQuestFact(), 1);
    }

    private final func SetupData() -> Void {
        super.SetupData();
        this.ApartmentScreen.SetIsMotelScreen();
        this.UpdateScreenState(this.rentState);
    }

    //
    //  Required Overrides
    //
    public func GetBaseGamePurchasedQuestFact() -> CName {
        return n"dlc6_apart_wat_nid_purchased";
    }

    public final func GetQuestPhaseGraphDebugQuestFact() -> CName {
        return n"en_fact_northside_debug";
    }

    public final func GetSystemRunningQuestFact() -> CName {
        return n"en_fact_northside_system_running";
    }

    public func GetActionUpdateLastRentStateQuestFact() -> CName {
        return n"en_fact_northside_action_update_last_rent_state";
    }

    public func GetRentStateQuestFact() -> CName {
        return n"en_fact_northside_rent_state";
    }

    public func GetLastRentStateQuestFact() -> CName {
        return n"en_fact_northside_last_rent_state";
    }

    public func GetActionCancelMoveOutQuestFact() -> CName {
        return n"en_fact_northside_action_cancel_move_out";
    }

    public func GetActionRefundSecurityDepositQuestFact() -> CName {
        return n"en_fact_northside_action_refund_security_deposit";
    }

    public func GetActionSendOneDayMoveOutWarningQuestFact() -> CName {
        return n"en_fact_northside_action_send_one_day_move_out_warning";
    }

    public func GetActionQueueMoveOutQuestFact() -> CName {
        return n"en_fact_northside_action_queue_move_out";
    }

    public func GetActionUpdateMoveOutStateFactQuestFact() -> CName {
        return n"en_fact_northside_action_update_move_out_state_fact";
    }

    public func GetActionSendWelcomeMessageQuestFact() -> CName {
        return n"en_fact_northside_action_send_welcome_message";
    }

    public func GetMoveOutStateQuestFact() -> CName {
        return n"en_fact_northside_move_out_state";
    }

    public func GetActionStartMoveOutConvoQuestFact() -> CName {
        return n"en_fact_northside_action_start_move_out_convo";
    }

    public final func GetActionTryToPayRentQuestFact() -> CName {
        // 0 = Default
        // 1 = Try To Pay Rent
        // 2 = Success
        // 3 = Failure
        return n"en_fact_northside_action_try_to_pay_rent";
    }

    public final func GetActionCloseAndLockDoorQuestFact() -> CName {
        return n"en_fact_northside_action_close_and_lock_door";
    }

    public final func GetPlayerHasRentMoneyQuestFact() -> CName {
        return n"en_fact_northside_player_has_rent_money";
    }

    public func GetCostLateFeePerDay() -> Int32 {
        return this.Settings.costNorthsideLateFee;
    }

    public func GetRentAmount() -> Int32 {
        return this.Settings.costNorthsideRent;
    }

    public func GetSecurityDepositAmount() -> Int32 {
        return FromVariant<Int32>(TweakDBInterface.GetFlat(t"EconomicAssignment.vs_apartment_dlc6_apart_wat_nid.overrideValue"));
    }

    private final func GetApartmentDebugName() -> String {
        return "Northside";
    }

    private final func GetApartmentDoorNodeRefPath() -> String {
        return "$/03_night_city/c_watson/northside/loc_dlc6_apart_wat_nid_prefabGGXQIJI/loc_dlc6_apart_wat_nid_gameplay_prefab7LQTKCI/#loc_dlc6_apart_wat_nid_devices/{dlc6_apart_wat_nid_pr_door}_prefabUO7RFGY/#dlc6_apart_wat_nid_dvc_door";
    }

    private final func GetApartmentScreenNodeRefPath() -> String {
        return "$/mod/worldbuildergroup_en_northside/#worldbuildergroup_en_northside_en_motel_screen";
    }

    /*private final func GetApartmentScreenNodeRefPath() -> String {
        return "$/03_night_city/c_watson/northside/loc_dlc6_apart_wat_nid_prefabGGXQIJI/loc_dlc6_apart_wat_nid_gameplay_prefab7LQTKCI/#loc_dlc6_apart_wat_nid_devices/#dlc6_apart_wat_nid_dvc_motel_screen";
    }*/
}