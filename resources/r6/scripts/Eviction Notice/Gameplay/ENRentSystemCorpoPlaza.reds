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

    public final func GetPlayerHasRentMoneyQuestFact() -> CName {
        return n"en_fact_corpoplaza_player_has_rent_money";
    }

    public func GetCostLateFeePerDay() -> Int32 {
        return 0;
    }

    public func GetRentAmount() -> Int32 {
        return this.Settings.costCorpoPlazaRent;
    }

    public func GetSecurityDepositAmount() -> Int32 {
        return FromVariant<Int32>(TweakDBInterface.GetFlat(t"EconomicAssignment.vs_apartment_dlc6_apart_cct_dtn.overrideValue"));
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

    // System-Specific Methods
    //
    private final func GetCorpoPlazaChosenNameQuestFact() -> CName {
        return n"en_fact_corpoplaza_chosen_name";
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
}