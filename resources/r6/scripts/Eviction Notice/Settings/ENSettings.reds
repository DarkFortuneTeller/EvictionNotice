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
		ENLog(this.debugEnabled, this, "Ready!");

		RegisterENSettingsListener(this);
    }

	public func OnModSettingsChange() -> Void {
		this.ReconcileSettings();
	}

	public final func ReconcileSettings() -> Void {
		ENLog(this.debugEnabled, this, "Beginning Settings Reconciliation...");
		let changedSettings: array<String>;

		if NotEquals(this._mainSystemEnabled, this.mainSystemEnabled) {
			this._mainSystemEnabled = this.mainSystemEnabled;
			ArrayPush(changedSettings, "mainSystemEnabled");
		}
		
		if ArraySize(changedSettings) > 0 {
			ENLog(this.debugEnabled, this, "        ...the following settings have changed: " + ToString(changedSettings));
			GameInstance.GetCallbackSystem().DispatchEvent(SettingChangedEvent.Create(changedSettings));
		}

		ENLog(this.debugEnabled, this, "        ...done!");
	}

	// -------------------------------------------------------------------------
	// System Settings
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryMain")
	@runtimeProperty("ModSettings.category.order", "10")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMainSystemEnabledDesc")
	public let mainSystemEnabled: Bool = true;

	// -------------------------------------------------------------------------
	// New Game
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNewGame")
	@runtimeProperty("ModSettings.category.order", "15")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingNewGameAct2Start")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingNewGameAct2StartDesc")
	@runtimeProperty("ModSettings.displayValues.Paid", "EvictionNoticeSettingNewGamePaid")
	@runtimeProperty("ModSettings.displayValues.Due", "EvictionNoticeSettingNewGameDue")
	@runtimeProperty("ModSettings.displayValues.Overdue", "EvictionNoticeSettingNewGameOverdue")
    @runtimeProperty("ModSettings.displayValues.Evicted", "EvictionNoticeSettingNewGameEvicted")
	public let H10RentStateOnNewGameAct2: ENSettingRentStateOnNewGame = ENSettingRentStateOnNewGame.Overdue;
	
	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNewGame")
	@runtimeProperty("ModSettings.category.order", "15")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingNewGamePLStart")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingNewGamePLStartDesc")
	@runtimeProperty("ModSettings.displayValues.Paid", "EvictionNoticeSettingNewGamePaid")
	@runtimeProperty("ModSettings.displayValues.Due", "EvictionNoticeSettingNewGameDue")
	@runtimeProperty("ModSettings.displayValues.Overdue", "EvictionNoticeSettingNewGameOverdue")
    @runtimeProperty("ModSettings.displayValues.Evicted", "EvictionNoticeSettingNewGameEvicted")
	public let H10RentStateOnNewGamePhantomLiberty: ENSettingRentStateOnNewGame = ENSettingRentStateOnNewGame.Due;

	// -------------------------------------------------------------------------
	// General
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGeneral")
	@runtimeProperty("ModSettings.category.order", "20")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingGeneralRentalPeriodInDays")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingGeneralRentalPeriodInDaysDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "3")
	@runtimeProperty("ModSettings.max", "30")
	public let rentalPeriodInDays: Int32 = 7;

	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGeneral")
	@runtimeProperty("ModSettings.category.order", "20")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingGeneralDaysUntilEviction")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingGeneralDaysUntilEvictionDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "3")
	@runtimeProperty("ModSettings.max", "30")
	public let daysUntilEviction: Int32 = 7;

	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGeneral")
	@runtimeProperty("ModSettings.category.order", "40")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingEZEstatesFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingEZEstatesFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "200000")
	public let costEZBobFee: Int32 = 5000;

	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGeneral")
	@runtimeProperty("ModSettings.category.order", "40")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingEZEstatesAutoPayAllowed")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingEZEstatesAutoPayAllowedDesc")
	public let autoPayAllowed: Bool = true;

	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGeneral")
	@runtimeProperty("ModSettings.category.order", "40")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingEZEstatesAutoPayFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingEZEstatesAutoPayFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "200000")
	public let costAutoPayFee: Int32 = 1000;

	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGeneral")
	@runtimeProperty("ModSettings.category.order", "40")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingEZEstatesAutoPayMinPropertyCount")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingEZEstatesAutoPayMinPropertyCountDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "5")
	public let autoPayMinimumPropertyCount: Int32 = 3;

	// -------------------------------------------------------------------------
	// Megabuilding H10
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryMBH10")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostRentBase")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostRentBaseDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "80000")
	public let costH10Rent: Int32 = 9000;

	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryMBH10")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostLateFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostLateFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "10000")
	public let costH10LateFee: Int32 = 500;

	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryMBH10")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMBH10SecurityDeposit")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMBH10SecurityDepositDesc")
	@runtimeProperty("ModSettings.step", "1000")
	@runtimeProperty("ModSettings.min", "1000")
	@runtimeProperty("ModSettings.max", "200000")
	public let costH10SecurityDeposit: Int32 = 10000;

	// -------------------------------------------------------------------------
	// Northside
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNorthside")
	@runtimeProperty("ModSettings.category.order", "60")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostRentBase")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostRentBaseDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "80000")
	public let costNorthsideRent: Int32 = 3000;

	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNorthside")
	@runtimeProperty("ModSettings.category.order", "60")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostLateFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostLateFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "10000")
	public let costNorthsideLateFee: Int32 = 500;

	/*@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryNorthside")
	@runtimeProperty("ModSettings.category.order", "60")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMainSystemEnabledDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "200000")
	public let costNorthsideSecurityDeposit: Int32 = 10000;
	*/

	// -------------------------------------------------------------------------
	// Japantown
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryJapantown")
	@runtimeProperty("ModSettings.category.order", "70")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostRentBase")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostRentBaseDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "80000")
	public let costJapantownRent: Int32 = 7000;

	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryJapantown")
	@runtimeProperty("ModSettings.category.order", "70")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostLateFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostLateFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "10000")
	public let costJapantownLateFee: Int32 = 500;

	/*@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryJapantown")
	@runtimeProperty("ModSettings.category.order", "70")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMainSystemEnabledDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "200000")
	public let costJapantownSecurityDeposit: Int32 = 30000;
	*/

	// -------------------------------------------------------------------------
	// Glen
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGlen")
	@runtimeProperty("ModSettings.category.order", "80")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostRentBase")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostRentBaseDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "80000")
	public let costGlenRent: Int32 = 15000;

	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGlen")
	@runtimeProperty("ModSettings.category.order", "80")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostLateFee")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostLateFeeDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "10000")
	public let costGlenLateFee: Int32 = 750;

	/*@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryGlen")
	@runtimeProperty("ModSettings.category.order", "80")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMainSystemEnabledDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "200000")
	public let costGlenSecurityDeposit: Int32 = 80000;
	*/

	// -------------------------------------------------------------------------
	// Corpo Plaza
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryCorpoPlaza")
	@runtimeProperty("ModSettings.category.order", "90")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingCostRentBase")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingCostRentBaseCorpoPlazaDesc")
	@runtimeProperty("ModSettings.step", "100")
	@runtimeProperty("ModSettings.min", "100")
	@runtimeProperty("ModSettings.max", "80000")
	public let costCorpoPlazaRent: Int32 = 25000;

	/*@runtimeProperty("ModSettings.mod", "Eviction Notice")
	@runtimeProperty("ModSettings.category", "EvictionNoticeSettingsCategoryCorpoPlaza")
	@runtimeProperty("ModSettings.category.order", "90")
	@runtimeProperty("ModSettings.displayName", "EvictionNoticeSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "EvictionNoticeSettingMainSystemEnabledDesc")
	@runtimeProperty("ModSettings.step", "1")
	@runtimeProperty("ModSettings.min", "1")
	@runtimeProperty("ModSettings.max", "200000")
	public let costCorpoPlazaSecurityDeposit: Int32 = 110000;
	*/
}
