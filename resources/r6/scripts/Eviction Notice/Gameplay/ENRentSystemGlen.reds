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

    public final func GetPlayerHasRentMoneyQuestFact() -> CName {
        return n"en_fact_glen_player_has_rent_money";
    }

    public func GetCostLateFeePerDay() -> Int32 {
        return this.Settings.costGlenLateFee;
    }

    public func GetRentAmount() -> Int32 {
        return this.Settings.costGlenRent;
    }
    
    public func GetSecurityDepositAmount() -> Int32 {
        return FromVariant<Int32>(TweakDBInterface.GetFlat(t"EconomicAssignment.vs_apartment_dlc6_apart_hey_gle.overrideValue"));
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

    // Screen trigger: $/mod/worldbuildergroup_en_glen/#worldbuildergroup_en_glen_trigger_area_screen
}