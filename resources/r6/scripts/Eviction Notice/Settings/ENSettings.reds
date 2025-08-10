// -----------------------------------------------------------------------------
// ENSettings
// -----------------------------------------------------------------------------
//
// - Mod Settings configuration.
//

module EvictionNotice.Settings

import EvictionNotice.Logging.*

public enum ENSettingRentStateOnNewGame {
	Paid = 0,
	Due = 1,
	Overdue = 2,
	Evicted = 3
}

//	ModSettings - Register if Mod Settings installed
//
@if(ModuleExists("ModSettingsModule")) 
public func RegisterENSettingsListener(listener: ref<IScriptable>) {
	ModSettings.RegisterListenerToClass(listener);
  	ModSettings.RegisterListenerToModifications(listener);
}

@if(ModuleExists("ModSettingsModule")) 
public func UnregisterENSettingsListener(listener: ref<IScriptable>) {
	ModSettings.UnregisterListenerToClass(listener);
  	ModSettings.UnregisterListenerToModifications(listener);
}

//	ModSettings - No-op if Mod Settings not installed
//
@if(!ModuleExists("ModSettingsModule")) 
public func RegisterENSettingsListener(listener: ref<IScriptable>) {
	//FTLog("WARN: Mod Settings was not installed, or not installed correctly; listener registration aborted.");
}
@if(!ModuleExists("ModSettingsModule")) 
public func UnregisterENSettingsListener(listener: ref<IScriptable>) {
	//FTLog("WARN: Mod Settings was not installed, or not installed correctly; listener unregistration aborted.");
}

public class SettingChangedEvent extends CallbackSystemEvent {
	let changedSettings: array<String>;

	public final func GetData() -> array<String> {
		return this.changedSettings;
	}

    static func Create(data: array<String>) -> ref<SettingChangedEvent> {
		let self: ref<SettingChangedEvent> = new SettingChangedEvent();
		self.changedSettings = data;
        return self;
    }
}

//
//	Eviction Notice Settings
//
public class ENSettings extends ScriptableSystem {
	private let debugEnabled: Bool = true;

	//
	//	CHANGE TRACKING
	//
	// Internal change tracking use only. DO NOT USE.
	// Internal change tracking use only. DO NOT USE.
	private let _mainSystemEnabled: Bool = true;
	private let _rentalPeriodInDays: Int32 = 7;
	private let _autoPayAllowed: Bool = true;
	private let _glenPaymentsUntilQuest: Int32 = 2;
	private let _glenPurchaseAllowed: Bool = true;
	private let _glenLoyaltyDiscountPct: Int32 = 10;
	// Internal change tracking use only. DO NOT USE.
	// Internal change tracking use only. DO NOT USE.

	public final static func GetInstance(gameInstance: GameInstance) -> ref<ENSettings> {
		let instance: ref<ENSettings> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"EvictionNotice.Settings.ENSettings") as ENSettings;
		return instance;
	}

	public final static func Get() -> ref<ENSettings> {
		return ENSettings.GetInstance(GetGameInstance());
	}
	
	private func OnDetach() -> Void {
		UnregisterENSettingsListener(this);
	}

	public func Init(attachedPlayer: ref<PlayerPuppet>) -> Void {
		ENLogNoSystem(this.debugEnabled, this, "Ready!");

		RegisterENSettingsListener(this);
    }

	public func OnModSettingsChange() -> Void {
		this.ReconcileSettings();
	}

	public final func ReconcileSettings() -> Void {
		ENLogNoSystem(this.debugEnabled, this, "Beginning Settings Reconciliation...");
		let changedSettings: array<String>;

		if NotEquals(this._mainSystemEnabled, this.mainSystemEnabled) {
			this._mainSystemEnabled = this.mainSystemEnabled;
			ArrayPush(changedSettings, "mainSystemEnabled");
		}

		if NotEquals(this._rentalPeriodInDays, this.rentalPeriodInDays) {
			this._rentalPeriodInDays = this.rentalPeriodInDays;
			ArrayPush(changedSettings, "rentalPeriodInDays");
		}

		if NotEquals(this._autoPayAllowed, this.autoPayAllowed) {
			this._autoPayAllowed = this.autoPayAllowed;
			ArrayPush(changedSettings, "autoPayAllowed");
		}

		if NotEquals(this._glenPaymentsUntilQuest, this.glenPaymentsUntilQuest) {
			this._glenPaymentsUntilQuest = this.glenPaymentsUntilQuest;
			ArrayPush(changedSettings, "glenPaymentsUntilQuest");
		}

		if NotEquals(this._glenPurchaseAllowed, this.glenPurchaseAllowed) {
			this._glenPurchaseAllowed = this.glenPurchaseAllowed;
			ArrayPush(changedSettings, "glenPurchaseAllowed");
		}

		if NotEquals(this._glenLoyaltyDiscountPct, this.glenLoyaltyDiscountPct) {
			this._glenLoyaltyDiscountPct = this.glenLoyaltyDiscountPct;
			ArrayPush(changedSettings, "glenLoyaltyDiscountPct");
		}
		
		if ArraySize(changedSettings) > 0 {
			ENLogNoSystem(this.debugEnabled, this, "        ...the following settings have changed: " + ToString(changedSettings));
			GameInstance.GetCallbackSystem().DispatchEvent(SettingChangedEvent.Create(changedSettings));
		}

		ENLogNoSystem(this.debugEnabled, this, "        ...done!");
	}

	// -------------------------------------------------------------------------
	// System Settings
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryMain")
	@runtimeProperty("ModSettings.category.order", "10")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMainSystemEnabledDesc")
	public let mainSystemEnabled: Bool = true;

	// -------------------------------------------------------------------------
	// New Game
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNewGame")
	@runtimeProperty("ModSettings.category.order", "15")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingNewGameAct2Start")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingNewGameAct2StartDesc")
	@runtimeProperty("ModSettings.displayValues.Paid", "EvictionNoticeSettingNewGamePaid")
	@runtimeProperty("ModSettings.displayValues.Due", "EvictionNoticeSettingNewGameDue")
	@runtimeProperty("ModSettings.displayValues.Overdue", "EvictionNoticeSettingNewGameOverdue")
    @runtimeProperty("ModSettings.displayValues.Evicted", "EvictionNoticeSettingNewGameEvicted")
	public let H10RentStateOnNewGameAct2: ENSettingRentStateOnNewGame = ENSettingRentStateOnNewGame.Overdue;
	
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNewGame")
	@runtimeProperty("ModSettings.category.order", "15")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingNewGamePLStart")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingNewGamePLStartDesc")
	@runtimeProperty("ModSettings.displayValues.Paid", "EvictionNoticeSettingNewGamePaid")
	@runtimeProperty("ModSettings.displayValues.Due", "EvictionNoticeSettingNewGameDue")
	@runtimeProperty("ModSettings.displayValues.Overdue", "EvictionNoticeSettingNewGameOverdue")
    @runtimeProperty("ModSettings.displayValues.Evicted", "EvictionNoticeSettingNewGameEvicted")
	public let H10RentStateOnNewGamePhantomLiberty: ENSettingRentStateOnNewGame = ENSettingRentStateOnNewGame.Overdue;

	// -------------------------------------------------------------------------
	// General
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGeneral")
	@runtimeProperty("ModSettings.category.order", "20")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingGeneralRentalPeriodInDays")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingGeneralRentalPeriodInDaysDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "2")
	@runtimeProperty("ModSettings.max", "30")
	public let rentalPeriodInDays: Int32 = 7;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGeneral")
	@runtimeProperty("ModSettings.category.order", "20")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingGeneralEvictionLockoutDays")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingGeneralEvictionLockoutDaysDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "0")
	@runtimeProperty("ModSettings.max", "30")
	public let evictionLockoutDays: Int32 = 7;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGeneral")
	@runtimeProperty("ModSettings.category.order", "40")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingEZEstatesFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingEZEstatesFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "20000")
	public let costEZBobFee: Int32 = 3000;

	// -------------------------------------------------------------------------
	// Auto-Pay
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryAutoPay")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingEZEstatesAutoPayAllowed")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingEZEstatesAutoPayAllowedDesc")
	public let autoPayAllowed: Bool = true;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryAutoPay")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingEZEstatesAutoPayFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingEZEstatesAutoPayFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "20000")
	public let costAutoPayFee: Int32 = 2000;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryAutoPay")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingEZEstatesAutoPayMinPropertyCount")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingEZEstatesAutoPayMinPropertyCountDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "5")
	public let autoPayMinimumPropertyCount: Int32 = 3;

	// -------------------------------------------------------------------------
	// Megabuilding H10
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryMBH10")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostRentBase")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostRentBaseDesc")
	@runtimeProperty("ModSettings.step", "500")
	@runtimeProperty("ModSettings.min", "1000")
	@runtimeProperty("ModSettings.max", "200000")
	public let costH10Rent: Int32 = 18000;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryMBH10")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostLateFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostLateFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "10000")
	public let costH10LateFee: Int32 = 2000;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryMBH10")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMBH10SecurityDeposit")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMBH10SecurityDepositDesc")
	@runtimeProperty("ModSettings.step", "1000")
	@runtimeProperty("ModSettings.min", "1000")
	@runtimeProperty("ModSettings.max", "200000")
	public let costH10SecurityDeposit: Int32 = 50000;

	/*
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryMBH10")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingPurchaseCost")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingPurchaseCostDesc")
	@runtimeProperty("ModSettings.step", "10000")
	@runtimeProperty("ModSettings.min", "10000")
	@runtimeProperty("ModSettings.max", "10000000")
	public let costH10Purchase: Int32 = 700000;
	*/

	// -------------------------------------------------------------------------
	// Northside
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNorthside")
	@runtimeProperty("ModSettings.category.order", "60")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostRentBase")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostRentBaseDesc")
	@runtimeProperty("ModSettings.step", "500")
	@runtimeProperty("ModSettings.min", "1000")
	@runtimeProperty("ModSettings.max", "200000")
	public let costNorthsideRent: Int32 = 8000;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNorthside")
	@runtimeProperty("ModSettings.category.order", "60")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostLateFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostLateFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "10000")
	public let costNorthsideLateFee: Int32 = 1000;

	/*@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNorthside")
	@runtimeProperty("ModSettings.category.order", "60")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMainSystemEnabledDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "200000")
	public let costNorthsideSecurityDeposit: Int32 = 10000;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNorthside")
	@runtimeProperty("ModSettings.category.order", "60")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingPurchaseCost")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingPurchaseCostDesc")
	@runtimeProperty("ModSettings.step", "10000")
	@runtimeProperty("ModSettings.min", "10000")
	@runtimeProperty("ModSettings.max", "10000000")
	public let costNorthsidePurchase: Int32 = 300000;
	*/

	// -------------------------------------------------------------------------
	// Japantown
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryJapantown")
	@runtimeProperty("ModSettings.category.order", "70")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostRentBase")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostRentBaseDesc")
	@runtimeProperty("ModSettings.step", "500")
	@runtimeProperty("ModSettings.min", "1000")
	@runtimeProperty("ModSettings.max", "200000")
	public let costJapantownRent: Int32 = 15000;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryJapantown")
	@runtimeProperty("ModSettings.category.order", "70")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostLateFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostLateFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "10000")
	public let costJapantownLateFee: Int32 = 1500;

	/*@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryJapantown")
	@runtimeProperty("ModSettings.category.order", "70")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMainSystemEnabledDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "200000")
	public let costJapantownSecurityDeposit: Int32 = 30000;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryJapantown")
	@runtimeProperty("ModSettings.category.order", "70")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingPurchaseCost")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingPurchaseCostDesc")
	@runtimeProperty("ModSettings.step", "10000")
	@runtimeProperty("ModSettings.min", "10000")
	@runtimeProperty("ModSettings.max", "10000000")
	public let costJapantownPurchase: Int32 = 500000;
	*/

	// -------------------------------------------------------------------------
	// Glen
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGlen")
	@runtimeProperty("ModSettings.category.order", "80")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostRentBase")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostRentBaseDesc")
	@runtimeProperty("ModSettings.step", "500")
	@runtimeProperty("ModSettings.min", "1000")
	@runtimeProperty("ModSettings.max", "200000")
	public let costGlenRent: Int32 = 27000;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGlen")
	@runtimeProperty("ModSettings.category.order", "80")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostLateFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostLateFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "10000")
	public let costGlenLateFee: Int32 = 2500;

	/*@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGlen")
	@runtimeProperty("ModSettings.category.order", "80")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMainSystemEnabledDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "200000")
	public let costGlenSecurityDeposit: Int32 = 200000;
	*/

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGlen")
	@runtimeProperty("ModSettings.category.order", "80")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingLoyaltyQuestRentPaidCount")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingLoyaltyQuestRentPaidCountDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "10")
	public let glenPaymentsUntilQuest: Int32 = 2;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGlen")
	@runtimeProperty("ModSettings.category.order", "80")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingLoyaltyQuestDiscount")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingLoyaltyQuestDiscountDesc")
	@runtimeProperty("ModSettings.step", "5")
	@runtimeProperty("ModSettings.min", "0")
	@runtimeProperty("ModSettings.max", "95")
	public let glenLoyaltyDiscountPct: Int32 = 10;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGlen")
	@runtimeProperty("ModSettings.category.order", "80")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingPurchaseAllowed")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingPurchaseAllowedDesc")
	public let glenPurchaseAllowed: Bool = true;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGlen")
	@runtimeProperty("ModSettings.category.order", "80")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingPurchaseCost")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingPurchaseCostDesc")
	@runtimeProperty("ModSettings.step", "10000")
	@runtimeProperty("ModSettings.min", "10000")
	@runtimeProperty("ModSettings.max", "5000000")
	public let costGlenPurchase: Int32 = 200000;

	// -------------------------------------------------------------------------
	// Corpo Plaza
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryCorpoPlaza")
	@runtimeProperty("ModSettings.category.order", "90")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostRentBase")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostRentBaseDesc")
	@runtimeProperty("ModSettings.step", "500")
	@runtimeProperty("ModSettings.min", "1000")
	@runtimeProperty("ModSettings.max", "200000")
	public let costCorpoPlazaRent: Int32 = 40000;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryCorpoPlaza")
	@runtimeProperty("ModSettings.category.order", "90")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostLateFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostLateFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "10000")
	public let costCorpoPlazaLateFee: Int32 = 3500;

	/*@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryCorpoPlaza")
	@runtimeProperty("ModSettings.category.order", "90")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMainSystemEnabledDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "200000")
	public let costCorpoPlazaSecurityDeposit: Int32 = 110000;

	@runtimeProperty("ModSettings.mod", "EvictionNoticeModName")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryCorpoPlaza")
	@runtimeProperty("ModSettings.category.order", "90")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingPurchaseCost")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingPurchaseCostDesc")
	@runtimeProperty("ModSettings.step", "10000")
	@runtimeProperty("ModSettings.min", "10000")
	@runtimeProperty("ModSettings.max", "10000000")
	public let costCorpoPlazaPurchase: Int32 = 1800000;
	*/
}
