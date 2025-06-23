// -----------------------------------------------------------------------------
// ENMainSystem
// -----------------------------------------------------------------------------
//
// - The Eviction Notice Main System.
// - Handles mod-wide system startup and shutdown.
//

// Credits: Psiberx, MisterChedda, Bill, Deceptious
// Fixed the aspect ratio of the apartment preview images on World Map tooltips
// Idea: Option to start the game evicted from MBH10 (kicked out as soon as you leave from the shower).
// Idea: Rent increases after moving out or eviction
// Idea: Permanent forfeiture of security deposit if evicted (harsh)

module EvictionNotice.Main

import EvictionNotice.Logging.*
import EvictionNotice.Settings.*
import EvictionNotice.Services.{
    ENGameStateService,
    ENPropertyStateService
}
import EvictionNotice.Gameplay.{
    ENBillPaySystem,
    ENEZEstatesAgentSystem,
    ENRentSystemMBH10,
    ENRentSystemNorthside,
    ENRentSystemJapantown,
    ENRentSystemGlen,
    ENRentSystemCorpoPlaza
}

public struct ENTimeSkipData {
    public let hoursSkipped: Int32;
}

@wrapMethod(RadialWheelController)
protected cb func OnLateInit(evt: ref<LateInit>) -> Bool {
	let val: Bool = wrappedMethod(evt);

	// Now that we know that the Radial Wheel is done initializing, it's now safe to act on systems
    // that might apply status effects.
	ENMainSystem.Get().OnRadialWheelLateInitDone();

	return val;
}

@wrapMethod(DeathMenuGameController)
protected cb func OnInitialize() -> Bool {
	let val: Bool = wrappedMethod();
	
	let ENMainSystem: ref<ENMainSystem> = ENMainSystem.Get();
	ENMainSystem.DispatchPlayerDeathEvent();

	return val;
}

public class MainSystemPlayerDeathEvent extends CallbackSystemEvent {
    static func Create() -> ref<MainSystemPlayerDeathEvent> {
        return new MainSystemPlayerDeathEvent();
    }
}

public class MainSystemTimeSkipFinishedEvent extends CallbackSystemEvent {
    private let data: ENTimeSkipData;

    public func GetData() -> ENTimeSkipData {
        return this.data;
    }

    static func Create(data: ENTimeSkipData) -> ref<MainSystemTimeSkipFinishedEvent> {
        let event = new MainSystemTimeSkipFinishedEvent();
        event.data = data;
        return event;
    }
}

public class MainSystemLifecycleInitEvent extends CallbackSystemEvent {
    static func Create() -> ref<MainSystemLifecycleInitEvent> {
        return new MainSystemLifecycleInitEvent();
    }
}

public class MainSystemLifecycleInitDoneEvent extends CallbackSystemEvent {
    static func Create() -> ref<MainSystemLifecycleInitDoneEvent> {
        return new MainSystemLifecycleInitDoneEvent();
    }
}

public class MainSystemLifecycleResumeEvent extends CallbackSystemEvent {
    static func Create() -> ref<MainSystemLifecycleResumeEvent> {
        return new MainSystemLifecycleResumeEvent();
    }
}

public class MainSystemLifecycleResumeDoneEvent extends CallbackSystemEvent {
    static func Create() -> ref<MainSystemLifecycleResumeDoneEvent> {
        return new MainSystemLifecycleResumeDoneEvent();
    }
}

public class MainSystemLifecycleSuspendEvent extends CallbackSystemEvent {
    static func Create() -> ref<MainSystemLifecycleSuspendEvent> {
        return new MainSystemLifecycleSuspendEvent();
    }
}

public class MainSystemLifecycleSuspendDoneEvent extends CallbackSystemEvent {
    static func Create() -> ref<MainSystemLifecycleSuspendDoneEvent> {
        return new MainSystemLifecycleSuspendDoneEvent();
    }
}

class ENMainSystemEventListeners extends ScriptableService {
    private func GetSystemInstance() -> wref<ENMainSystem> {
		return ENMainSystem.Get();
	}

	private cb func OnLoad() {
        GameInstance.GetCallbackSystem().RegisterCallback(n"EvictionNotice.Settings.SettingChangedEvent", this, n"OnSettingChangedEvent", true);
    }

    private cb func OnSettingChangedEvent(event: ref<SettingChangedEvent>) {
		this.GetSystemInstance().OnSettingChanged(event.GetData());
	}
}

public final class ENMainSystem extends ScriptableSystem {
    private persistent let oneTimeSetupDone: Bool = false;
    
    private let debugEnabled: Bool = true;

    private let player: ref<PlayerPuppet>;

    // Callback Handles
    private let playerAttachedCallbackID: Uint32;

    private let lateInitDone: Bool = false;


    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENMainSystem> {
		let instance: ref<ENMainSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"EvictionNotice.Main.ENMainSystem") as ENMainSystem;
		return instance;
	}

    public final static func Get() -> ref<ENMainSystem> {
        return ENMainSystem.GetInstance(GetGameInstance());
	}

    //
    //  Startup and Shutdown
    //
    private func OnAttach() -> Void {
        ENLog(this.debugEnabled, this, "OnAttach");
        this.playerAttachedCallbackID = GameInstance.GetPlayerSystem(GetGameInstance()).RegisterPlayerPuppetAttachedCallback(this, n"PlayerAttachedCallback");
    }

    private final func PlayerAttachedCallback(playerPuppet: ref<GameObject>) -> Void {
		if IsDefined(playerPuppet) {
            ENLog(this.debugEnabled, this, "PlayerAttachedCallback playerPuppet TweakDBID: " + TDBID.ToStringDEBUG((playerPuppet as PlayerPuppet).GetRecord().GetID()));
            this.player = playerPuppet as PlayerPuppet;

            // Player Replacer / Act 2 Handling - If Late Init is already Done, start all systems.
            if this.lateInitDone {
                this.StartAll();
            }
        }
    }

    public final func OnRadialWheelLateInitDone() -> Void {
        if !this.lateInitDone {
            this.lateInitDone = true;
            this.StartAll();
        }
	}

    private final func StartAll() -> Void {
        let gameInstance = GetGameInstance();
        if !IsDefined(this.player) {
            ENLog(true, this, "ERROR: PLAYER NOT DEFINED ON ENMainSystem:StartAll()", ENLogLevel.Error);
            return;
        }
        ENLog(this.debugEnabled, this, "!!!!! ENMainSystem:StartAll !!!!!");

        // Settings
        ENSettings.GetInstance(gameInstance).Init(this.player);

        // Lifecycle Hook - Start
        this.DispatchLifecycleInitEvent();

        // Services
        ENGameStateService.GetInstance(gameInstance).Init(this.player);
        ENPropertyStateService.GetInstance(gameInstance).Init(this.player);

        // Systems
        ENRentSystemMBH10.GetInstance(gameInstance).Init(this.player);
        ENRentSystemNorthside.GetInstance(gameInstance).Init(this.player);
        ENRentSystemJapantown.GetInstance(gameInstance).Init(this.player);
        ENRentSystemGlen.GetInstance(gameInstance).Init(this.player);
        ENRentSystemCorpoPlaza.GetInstance(gameInstance).Init(this.player);
        ENEZEstatesAgentSystem.GetInstance(gameInstance).Init(this.player);
        ENBillPaySystem.GetInstance(gameInstance).Init(this.player);

        // Reconcile settings changes
        ENSettings.GetInstance(gameInstance).ReconcileSettings();

        // One-Time Setup
        if !this.oneTimeSetupDone {
            ENPropertyStateService.GetInstance(gameInstance).UpdateRentedPropertyCount();
            this.oneTimeSetupDone = true;
        }

        // Lifecycle Hook - Done
        this.DispatchLifecycleInitDoneEvent();
    }

    private final func ResumeAll() -> Void {
        ENLog(this.debugEnabled, this, "!!!!! ENMainSystem:ResumeAll !!!!!");
        let gameInstance = GetGameInstance();

        // Lifecycle Hook - Start
        this.DispatchLifecycleResumeEvent();

        // Services
        ENGameStateService.GetInstance(gameInstance).Resume();
        ENPropertyStateService.GetInstance(gameInstance).Resume();

        // Systems
        ENRentSystemMBH10.GetInstance(gameInstance).Resume();
        ENRentSystemNorthside.GetInstance(gameInstance).Resume();
        ENRentSystemJapantown.GetInstance(gameInstance).Resume();
        ENRentSystemGlen.GetInstance(gameInstance).Resume();
        ENRentSystemCorpoPlaza.GetInstance(gameInstance).Resume();
        ENEZEstatesAgentSystem.GetInstance(gameInstance).Resume();
        ENBillPaySystem.GetInstance(gameInstance).Resume();

        // Lifecycle Hook - Done
        this.DispatchLifecycleResumeDoneEvent();
    }

    private final func SuspendAll() -> Void {
        ENLog(this.debugEnabled, this, "!!!!! ENMainSystem:SuspendAll !!!!!");

        let gameInstance = GetGameInstance();

        // Lifecycle Hook - Start
        this.DispatchLifecycleSuspendEvent();

        // Systems
        ENBillPaySystem.GetInstance(gameInstance).Suspend();
        ENEZEstatesAgentSystem.GetInstance(gameInstance).Suspend();
        ENRentSystemCorpoPlaza.GetInstance(gameInstance).Suspend();
        ENRentSystemGlen.GetInstance(gameInstance).Suspend();
        ENRentSystemJapantown.GetInstance(gameInstance).Suspend();
        ENRentSystemNorthside.GetInstance(gameInstance).Suspend();
        ENRentSystemMBH10.GetInstance(gameInstance).Suspend();

        // Services
        ENPropertyStateService.GetInstance(gameInstance).Suspend();
        ENGameStateService.GetInstance(gameInstance).Suspend();

        // Lifecycle Hook - Done
        this.DispatchLifecycleSuspendDoneEvent();
    }

    public final func OnSettingChanged(changedSettings: array<String>) -> Void {
        let settings: ref<ENSettings> = ENSettings.Get();

        if ArrayContains(changedSettings, "mainSystemEnabled") {
            if settings.mainSystemEnabled {
                this.ResumeAll();
            } else {
                this.SuspendAll();
            }
        }
    }

    public final func DispatchPlayerDeathEvent() -> Void {
        ENLog(this.debugEnabled, this, "!!!!! ENMainSystem:DispatchPlayerDeathEvent !!!!!");
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemPlayerDeathEvent.Create());
    }

    public final func DispatchTimeSkipFinishedEvent(data: ENTimeSkipData) -> Void {
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemTimeSkipFinishedEvent.Create(data));
    }

    //
    //  Lifecycle Events for Eviction Notice Add-Ons and Mods
    //
    public final func DispatchLifecycleInitEvent() -> Void {
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleInitEvent.Create());
    }

    public final func DispatchLifecycleInitDoneEvent() -> Void {
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleInitDoneEvent.Create());
    }

    public final func DispatchLifecycleResumeEvent() -> Void {
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleResumeEvent.Create());
    }

    public final func DispatchLifecycleResumeDoneEvent() -> Void {
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleResumeDoneEvent.Create());
    }

    public final func DispatchLifecycleSuspendEvent() -> Void {
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleSuspendEvent.Create());
    }

    public final func DispatchLifecycleSuspendDoneEvent() -> Void {
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleSuspendDoneEvent.Create());
    }
}
