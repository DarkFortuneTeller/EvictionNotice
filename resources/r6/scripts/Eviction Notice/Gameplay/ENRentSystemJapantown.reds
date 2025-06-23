module EvictionNotice.Gameplay

import EvictionNotice.System.ENSystemEventListener
import EvictionNotice.Settings.ENSettings
import EvictionNotice.Services.ENPropertyStateService

public final class ENRentSystemJapantownEventListeners extends ENRentSystemBaseEventListeners {
	private func GetSystemInstance() -> wref<ENRentSystemBase> {
		return ENRentSystemJapantown.Get();
	}
}

public final class ENRentSystemJapantown extends ENRentSystemBase {
    public final static func GetSystemName() -> CName {
        return n"EvictionNotice.Gameplay.ENRentSystemJapantown";
    }

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENRentSystemJapantown> {
		let instance: ref<ENRentSystemJapantown> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(ENRentSystemJapantown.GetSystemName()) as ENRentSystemJapantown;
		return instance;
	}

	public final static func Get() -> ref<ENRentSystemJapantown> {
		return ENRentSystemJapantown.GetInstance(GetGameInstance());
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
        return n"dlc6_apart_wbr_jpn_purchased";
    }

    public final func GetQuestPhaseGraphDebugQuestFact() -> CName {
        return n"en_fact_japantown_debug";
    }

    public final func GetSystemRunningQuestFact() -> CName {
        return n"en_fact_japantown_system_running";
    }

    public func GetActionUpdateLastRentStateQuestFact() -> CName {
        return n"en_fact_japantown_action_update_last_rent_state";
    }

    public func GetRentStateQuestFact() -> CName {
        return n"en_fact_japantown_rent_state";
    }

    public func GetLastRentStateQuestFact() -> CName {
        return n"en_fact_japantown_last_rent_state";
    }

    public func GetActionCancelMoveOutQuestFact() -> CName {
        return n"en_fact_japantown_action_cancel_move_out";
    }

    public func GetActionRefundSecurityDepositQuestFact() -> CName {
        return n"en_fact_japantown_action_refund_security_deposit";
    }

    public func GetActionSendOneDayMoveOutWarningQuestFact() -> CName {
        return n"en_fact_japantown_action_send_one_day_move_out_warning";
    }

    public func GetActionQueueMoveOutQuestFact() -> CName {
        return n"en_fact_japantown_action_queue_move_out";
    }

    public func GetActionUpdateMoveOutStateFactQuestFact() -> CName {
        return n"en_fact_japantown_action_update_move_out_state_fact";
    }

    public func GetActionSendWelcomeMessageQuestFact() -> CName {
        return n"en_fact_japantown_action_send_welcome_message";
    }

    public func GetMoveOutStateQuestFact() -> CName {
        return n"en_fact_japantown_move_out_state";
    }

    public func GetActionStartMoveOutConvoQuestFact() -> CName {
        return n"en_fact_japantown_action_start_move_out_convo";
    }

    public final func GetActionTryToPayRentQuestFact() -> CName {
        // 0 = Default
        // 1 = Try To Pay Rent
        // 2 = Success
        // 3 = Failure
        return n"en_fact_japantown_action_try_to_pay_rent";
    }

    public final func GetActionCloseAndLockDoorQuestFact() -> CName {
        return n"en_fact_japantown_action_close_and_lock_door";
    }

    public final func GetPlayerHasRentMoneyQuestFact() -> CName {
        return n"en_fact_japantown_player_has_rent_money";
    }

    public func GetCostLateFeePerDay() -> Int32 {
        return this.Settings.costJapantownLateFee;
    }

    public func GetRentAmount() -> Int32 {
        return this.Settings.costJapantownRent;
    }

    public func GetSecurityDepositAmount() -> Int32 {
        return FromVariant<Int32>(TweakDBInterface.GetFlat(t"EconomicAssignment.vs_apartment_dlc6_apart_wbr_jpn.overrideValue"));
    }

    private final func GetApartmentDebugName() -> String {
        return "Japantown";
    }

    private final func GetApartmentDoorNodeRefPath() -> String {
        return "$/03_night_city/c_westbrook/japan_town/loc_dlc6_apart_wbr_jpn_prefab7DGW3BI/loc_dlc6_apart_wbr_jpn_gameplay_prefabOC46BLA/#loc_dlc6_apart_wbr_jpn_devices/single_door_2t_prefabCZ4YERA/{single_door}_prefabHKUWE3A";
    }

    private final func GetApartmentScreenNodeRefPath() -> String {
        return "$/mod/worldbuildergroup_en_japantown/#worldbuildergroup_en_japantown_en_motel_screen";
    }

    /*private final func GetApartmentScreenNodeRefPath() -> String {
        return "$/03_night_city/c_westbrook/japan_town/loc_dlc6_apart_wbr_jpn_prefab7DGW3BI/loc_dlc6_apart_wbr_jpn_gameplay_prefabOC46BLA/#loc_dlc6_apart_wbr_jpn_devices/single_door_2t_prefabCZ4YERA/{terminal_}1_prefabGFATCTA";
    }*/
}