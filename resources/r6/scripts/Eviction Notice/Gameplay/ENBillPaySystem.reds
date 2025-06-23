// -----------------------------------------------------------------------------
// ENBillPaySystem
// -----------------------------------------------------------------------------
//
// - Gameplay System that handles consolidated auto-pay.
//

module EvictionNotice.Gameplay

import EvictionNotice.System.*
import EvictionNotice.Logging.*
import EvictionNotice.Main.ENTimeSkipData
import EvictionNotice.Services.{
    ENPropertyStateService,
    ENPropertyStateServiceCurrentDayUpdateEvent
}
import EvictionNotice.Settings.ENSettings
import EvictionNotice.Utils.{
    TryToRemovePlayerMoney,
    ENResourceHandler
}

public enum ENAutoPayEnableResult {
    None = 0,
    Success = 1,
    FailedOutstandingBalance = 2,
    FailedNoProperty = 3
}

public enum ENAutoPayDisableReason {
    None = 0,
    FromAgent = 1,
    FromPaymentFailed = 2,
    FromNoProperty = 3,
    FromSetting = 4
}

public enum ENAutoPayMessageType {
    None = 0,
    Intro = 1,
    DisablePaymentFailed = 2,
    DisableNoProperty = 3,
    PaymentProcessed = 4,
    PaymentReminder = 5
}

public class ENBillPaySystemBaseEventListeners extends ENSystemEventListener {
    //
	// Required Overrides
	//
	private func GetSystemInstance() -> wref<ENBillPaySystem> {
		return ENBillPaySystem.Get();
	}

    private cb func OnLoad() {
		super.OnLoad();

        GameInstance.GetCallbackSystem().RegisterCallback(n"EvictionNotice.Services.ENPropertyStateServiceCurrentDayUpdateEvent", this, n"OnPropertyStateServiceCurrentDayUpdateEvent", true);
    }

    private cb func OnPropertyStateServiceCurrentDayUpdateEvent(event: ref<ENPropertyStateServiceCurrentDayUpdateEvent>) {
		this.GetSystemInstance().OnDayUpdated(event.GetData());
	}
}

public class ENBillPaySystem extends ENSystem {
    private persistent let lastPaidAmount: Int32;
    private persistent let autoPayInviteSent: Bool = false;

    private let QuestsSystem: ref<QuestsSystem>;
    private let JournalManager: ref<JournalManager>;
    private let PropertyStateService: ref<ENPropertyStateService>;
    private let MBH10: ref<ENRentSystemMBH10>;
    private let Northside: ref<ENRentSystemNorthside>;
    private let Japantown: ref<ENRentSystemJapantown>;
    private let Glen: ref<ENRentSystemGlen>;
    private let CorpoPlaza: ref<ENRentSystemCorpoPlaza>;

    private let factListenerQuestPhaseDebug: Uint32;
    private let factListenerActionTryToEnableAutoPay: Uint32;
    private let factListenerActionDisableAutoPay: Uint32;
    private let factListenerActionUpdateLastAutoPayState: Uint32;

    private let rentalSystems: array<ref<ENRentSystemBase>>;
    private let repeatableMessages: array<ref<JournalPhoneMessage>>;

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENBillPaySystem> {
		let instance: ref<ENBillPaySystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"EvictionNotice.Gameplay.ENBillPaySystem") as ENBillPaySystem;
		return instance;
	}

	public final static func Get() -> ref<ENBillPaySystem> {
		return ENBillPaySystem.GetInstance(GetGameInstance());
	}

    private func SetupDebugLogging() -> Void {
        this.debugEnabled = true;
    }

    private final func GetSystemToggleSettingValue() -> Bool {
		return this.Settings.autoPayAllowed;
	}

	private final func GetSystemToggleSettingString() -> String {
		return "autoPayAllowed";
	}

    private func DoPostSuspendActions() -> Void {
        this.DisableAutoPay(ENAutoPayDisableReason.FromSetting);
        this.SetAutoPayAvailable(false);
    }

    private func DoPostResumeActions() -> Void {
        // TODO
        this.TryToSendAutoPayInvite();
    }

    private func GetSystems() -> Void {
        let gameInstance = GetGameInstance();
        this.QuestsSystem = GameInstance.GetQuestsSystem(gameInstance);
        this.JournalManager = GameInstance.GetJournalManager(gameInstance);
        this.PropertyStateService = ENPropertyStateService.GetInstance(gameInstance);
        this.MBH10 = ENRentSystemMBH10.GetInstance(gameInstance);
        this.Northside = ENRentSystemNorthside.GetInstance(gameInstance);
        this.Japantown = ENRentSystemJapantown.GetInstance(gameInstance);
        this.Glen = ENRentSystemGlen.GetInstance(gameInstance);
        this.CorpoPlaza = ENRentSystemCorpoPlaza.GetInstance(gameInstance);
    }

    private func GetBlackboards(attachedPlayer: ref<PlayerPuppet>) -> Void {}
    
    private func SetupData() -> Void {
        if ArraySize(this.rentalSystems) == 0 {
            ArrayPush(this.rentalSystems, this.MBH10);
            ArrayPush(this.rentalSystems, this.Northside);
            ArrayPush(this.rentalSystems, this.Japantown);
            ArrayPush(this.rentalSystems, this.Glen);
            ArrayPush(this.rentalSystems, this.CorpoPlaza);
        }

        this.repeatableMessages = ENResourceHandler.Get().GetRepeatableMessages();
        ENLog(this.debugEnabled, this, "ENBillPaySystem: repeatableMessages: " + ToString(this.repeatableMessages));
    }
    
    private func RegisterListeners() -> Void {
        this.factListenerQuestPhaseDebug = this.QuestsSystem.RegisterListener(this.GetQuestPhaseGraphDebugQuestFact(), this, n"OnQuestPhaseDebugFactChanged");

        this.factListenerActionTryToEnableAutoPay = this.QuestsSystem.RegisterListener(this.GetActionTryToEnableAutoPayQuestFact(), this, n"OnTryToEnableAutoPay");
        this.factListenerActionDisableAutoPay = this.QuestsSystem.RegisterListener(this.GetActionDisableAutoPayQuestFact(), this, n"OnDisableAutoPay");
        this.factListenerActionUpdateLastAutoPayState = this.QuestsSystem.RegisterListener(this.GetActionUpdateLastAutoPayStateQuestFact(), this, n"OnUpdateLastAutoPayState");
    }
    
    private func RegisterAllRequiredDelayCallbacks() -> Void {}
    
    private func UnregisterListeners() -> Void {
        this.QuestsSystem.UnregisterListener(this.GetQuestPhaseGraphDebugQuestFact(), this.factListenerQuestPhaseDebug);
        this.factListenerQuestPhaseDebug = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionTryToEnableAutoPayQuestFact(), this.factListenerActionTryToEnableAutoPay);
        this.factListenerActionTryToEnableAutoPay = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionDisableAutoPayQuestFact(), this.factListenerActionDisableAutoPay);
        this.factListenerActionDisableAutoPay = 0u;

        this.QuestsSystem.UnregisterListener(this.GetActionUpdateLastAutoPayStateQuestFact(), this.factListenerActionUpdateLastAutoPayState);
        this.factListenerActionUpdateLastAutoPayState = 0u;
    }
    
    private func UnregisterAllDelayCallbacks() -> Void {}
    public func OnTimeSkipFinished(data: ENTimeSkipData) -> Void {}
    public func OnSettingChangedSpecific(changedSettings: array<String>) -> Void {}
    private func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {}

    //
    //  System-Specific Methods
    //
    public func GetQuestPhaseGraphDebugQuestFact() -> CName {
        return n"en_fact_williamsmgmt_debug";
    }

    public func GetActionTryToEnableAutoPayQuestFact() -> CName {
        return n"en_fact_action_try_to_enable_autopay";
    }

    public func GetActionDisableAutoPayQuestFact() -> CName {
        return n"en_fact_action_disable_autopay";
    }

    public func GetActionSendAutoPayMessageOfTypeQuestFact() -> CName {
        return n"en_fact_action_send_williamsmgmt_message_of_type";
    }

    public func GetActionUpdateLastAutoPayStateQuestFact() -> CName {
        return n"en_fact_action_update_last_autopay_state";
    }

    public func GetAutoPayAvailableQuestFact() -> CName {
        return n"en_fact_autopay_available";
    }

    public func GetAutoPayEnabledQuestFact() -> CName {
        return n"en_fact_autopay_enabled";
    }

    public func GetLastAutoPayEnabledQuestFact() -> CName {
        return n"en_fact_last_autopay_enabled";
    }

    public func GetLastAutoPayDisableReasonQuestFact() -> CName {
        return n"en_fact_last_autopay_disable_reason";
    }

    public func GetAutoPayEnableResultQuestFact() -> CName {
        return n"en_fact_enable_autopay_result";
    }

    private final func OnQuestPhaseDebugFactChanged(value: Int32) -> Void {
        if value != 0 {
            ENLog(this.debugEnabled, this, "#### DEBUG Quest Phase Graph --- Value: " + ToString(value));
            this.QuestsSystem.SetFact(this.GetQuestPhaseGraphDebugQuestFact(), 0);
        }
    }

    public final func OnDayUpdated(currentDay: Int32) {
        if this.IsAutoPayEnabled() {
            this.HandleAutoPay(currentDay);
        }
    }

    public final func TryToSendAutoPayInvite() -> Void {
        if IsSystemEnabledAndRunning(this) && !this.autoPayInviteSent {
            ENLog(this.debugEnabled, this, "Checking if Auto-Pay invite should be sent...");
            let rentedPropertyCount: Uint32 = this.PropertyStateService.GetRentedPropertyCount();

            if rentedPropertyCount >= Cast<Uint32>(this.Settings.autoPayMinimumPropertyCount) {
                this.SendAutoPayMessageOfType(ENAutoPayMessageType.Intro);
                this.autoPayInviteSent = true;
            }
        }
    }

    private final func HandleAutoPay(currentDay: Int32) -> Void {
        // Gather the collection of rental systems that are due today.
        let rentalSystemsDueToday: array<ref<ENRentSystemBase>>;
        ENLog(this.debugEnabled, this, "$$$$$$$$$$$$$$$$$$$ AutoPay Current Day: " + ToString(currentDay));

        for rentalSystem in this.rentalSystems {
            if rentalSystem.IsCurrentRentStateRented() {
                let rentExpirationDay: Int32 = rentalSystem.GetRentExpirationDay();
                if Equals(currentDay, rentExpirationDay) {
                    if Equals(rentalSystem.moveOutState, ENMoveOutState.NotMovingOut) {
                        ENLog(this.debugEnabled, this, "$$$$$$$$$$$$$$$$$$$ Due Today: " + ToString(rentalSystem.GetPropertyDebugName()));
                        ArrayPush(rentalSystemsDueToday, rentalSystem);
                    }
                } else if Equals(currentDay, rentExpirationDay - 1) {
                    ENLog(this.debugEnabled, this, "$$$$$$$$$$$$$$$$$$$ Send Day Before Notice!");
                    this.SendAutoPayMessageOfType(ENAutoPayMessageType.PaymentReminder);
                    return;
                }
            }
        }

        // If there are any due today, calculate the total amount it would cost to pay them.
        if ArraySize(rentalSystemsDueToday) == 0 {
            ENLog(this.debugEnabled, this, "$$$$$$$$$$$$$$$$$$$ AutoPay: No Rental Systems Due Today!");
            return;
        }

        let totalCost: Int32 = 0;
        for rentalSystemDueToday in rentalSystemsDueToday {
            let outstandingBalance: Int32 = rentalSystemDueToday.GetRentAmount();
            ENLog(this.debugEnabled, this, "$$$$$$$$$$$$$$$$$$$ AutoPay: Rental System " + rentalSystemDueToday.GetPropertyDebugName() + " owes " + ToString(outstandingBalance));
            totalCost += outstandingBalance;
        }
        totalCost += this.Settings.costAutoPayFee;

        let paid: Bool = TryToRemovePlayerMoney(totalCost);

        if paid {
            ENLog(this.debugEnabled, this, "$$$$$$$$$$$$$$$$$$$ Payment successful!");
            for rentalSystemDueToday in rentalSystemsDueToday {
                rentalSystemDueToday.lastPaidRentCycleStartDay = this.PropertyStateService.GetCurrentRentCycleStartDay();
                rentalSystemDueToday.SetRentState(ENRentState.Paid);
            }
            this.lastPaidAmount = totalCost;
            this.SendAutoPayMessageOfType(ENAutoPayMessageType.PaymentProcessed);

        } else {
            ENLog(this.debugEnabled, this, "$$$$$$$$$$$$$$$$$$$ Payment failed!");
            // If the player doesn't have enough money, cancel AutoPay, send a message, and update Rent State on all systems.
            this.DisableAutoPay(ENAutoPayDisableReason.FromPaymentFailed);
            for rentalSystemDueToday in rentalSystemsDueToday {
                rentalSystemDueToday.UpdateRent(currentDay);
            }
        }
    }

    public final func IsAutoPayAvailable() -> Bool {
        let available: Int32 = this.QuestsSystem.GetFact(this.GetAutoPayAvailableQuestFact());
        if Equals(available, 1) {
            return true;
        } else {
            return false;
        }
    }

    public final func IsAutoPayEnabled() -> Bool {
        let enabled: Int32 = this.QuestsSystem.GetFact(this.GetAutoPayEnabledQuestFact());
        if Equals(enabled, 1) {
            return true;
        } else {
            return false;
        }
    }

    // TODO: Handle settings changes
    private final func SetAutoPayAvailable(available: Bool) -> Void {
        ENLog(this.debugEnabled, this, "SetAutoPayAvailable: " + ToString(available));
        if available {
            this.QuestsSystem.SetFact(this.GetAutoPayAvailableQuestFact(), 1);
        } else {
            this.QuestsSystem.SetFact(this.GetAutoPayAvailableQuestFact(), 0);
        }
    }

    private final func EnableAutoPay() -> Void {
        // TODO
        ENLog(this.debugEnabled, this, "!! EnableAutoPay !!");
        this.QuestsSystem.SetFact(this.GetAutoPayEnabledQuestFact(), 1);
    }

    private final func DisableAutoPay(reason: ENAutoPayDisableReason) -> Void {
        // TODO
        ENLog(this.debugEnabled, this, "!! DisableAutoPay !! reason: " + ToString(reason));
        this.QuestsSystem.SetFact(this.GetAutoPayEnabledQuestFact(), 0);

        if Equals(reason, ENAutoPayDisableReason.FromPaymentFailed) {
            this.SendAutoPayMessageOfType(ENAutoPayMessageType.DisablePaymentFailed);

        } else if Equals(reason, ENAutoPayDisableReason.FromNoProperty) {
            this.SendAutoPayMessageOfType(ENAutoPayMessageType.DisableNoProperty);
        }
    }

    private final func GetAnyPropertyHasOutstandingBalance() -> Bool {
        if this.MBH10.IsCurrentRentStateWithOutstandingBalance() {
            return true;
        }

        if this.Northside.IsCurrentRentStateWithOutstandingBalance() {
            return true;
        }

        if this.Japantown.IsCurrentRentStateWithOutstandingBalance() {
            return true;
        }

        if this.Glen.IsCurrentRentStateWithOutstandingBalance() {
            return true;
        }

        if this.CorpoPlaza.IsCurrentRentStateWithOutstandingBalance() {
            return true;
        }

        return false;
    }

    private final func FindRepeatableMessage(id: String) -> ref<JournalPhoneMessage> {
        for message in this.repeatableMessages {
            if Equals(message.id, id) {
                return message;
            }
        }

        return null;
    }

    //
    //  Action Functions
    //
    public final func SendAutoPayMessageOfType(type: ENAutoPayMessageType) -> Void {
        // Mark the message as "Unread" in the Journal. In the graph, also set "Send Notification" in the Journal Bulk Entry Update
        // to allow notifications to be sent from these messages again.
        if Equals(type, ENAutoPayMessageType.DisablePaymentFailed) {
            let message: ref<JournalPhoneMessage> = this.FindRepeatableMessage("disabled_paymentfailed");
            if IsDefined(message) {
                this.JournalManager.SetEntryVisited(message, false);
            }

        } else if Equals(type, ENAutoPayMessageType.DisableNoProperty) {
            let message: ref<JournalPhoneMessage> = this.FindRepeatableMessage("disabled_noproperty");
            if IsDefined(message) {
                this.JournalManager.SetEntryVisited(message, false);
            }

        } else if Equals(type, ENAutoPayMessageType.PaymentProcessed) {
            let message: ref<JournalPhoneMessage> = this.FindRepeatableMessage("payment_processed");
            if IsDefined(message) {
                this.JournalManager.SetEntryVisited(message, false);
            }

        }  else if Equals(type, ENAutoPayMessageType.PaymentReminder) {
            let message: ref<JournalPhoneMessage> = this.FindRepeatableMessage("payment_reminder");
            if IsDefined(message) {
                this.JournalManager.SetEntryVisited(message, false);
            }
        }

        // Send the message.
        this.QuestsSystem.SetFact(this.GetActionSendAutoPayMessageOfTypeQuestFact(), EnumInt<ENAutoPayMessageType>(type));
    }

    //
    //  Action Events
    //
    public final func OnTryToEnableAutoPay(value: Int32) -> Void {
        if Equals(value, 1) {
            if this.PropertyStateService.GetRentedPropertyCount() == 0u {
                ENLog(this.debugEnabled, this, "OnTryToEnableAutoPay: FAILED: No Property");
                this.QuestsSystem.SetFact(this.GetAutoPayEnableResultQuestFact(), EnumInt<ENAutoPayEnableResult>(ENAutoPayEnableResult.FailedNoProperty));

            } else if this.GetAnyPropertyHasOutstandingBalance() {
                ENLog(this.debugEnabled, this, "OnTryToEnableAutoPay: FAILED: Outstanding Balance");
                this.QuestsSystem.SetFact(this.GetAutoPayEnableResultQuestFact(), EnumInt<ENAutoPayEnableResult>(ENAutoPayEnableResult.FailedOutstandingBalance));

            } else {
                ENLog(this.debugEnabled, this, "OnTryToEnableAutoPay: SUCCESS");
                this.QuestsSystem.SetFact(this.GetAutoPayEnableResultQuestFact(), EnumInt<ENAutoPayEnableResult>(ENAutoPayEnableResult.Success));
                this.EnableAutoPay();
            }

            this.QuestsSystem.SetFact(this.GetActionTryToEnableAutoPayQuestFact(), 0);
        }
    }

    public final func OnDisableAutoPay(value: Int32) -> Void {
        if Equals(value, 1) {
            this.DisableAutoPay(ENAutoPayDisableReason.FromAgent);
            this.QuestsSystem.SetFact(this.GetActionDisableAutoPayQuestFact(), 0);
        }
    }

    public final func OnUpdateLastAutoPayState(value: Int32) -> Void {
        FTLog("OnUpdateLastAutoPayState value: " + ToString(value));

        if Equals(value, 1) {
            this.QuestsSystem.SetFact(this.GetLastAutoPayEnabledQuestFact(), this.QuestsSystem.GetFact(this.GetAutoPayEnabledQuestFact()));
            this.QuestsSystem.SetFact(this.GetActionUpdateLastAutoPayStateQuestFact(), 0);
        }
    }
}