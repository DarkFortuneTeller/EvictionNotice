// -----------------------------------------------------------------------------
// ENCommon
// -----------------------------------------------------------------------------
//
// - Catch-all of general utilities, including RunGuard.
//

module EvictionNotice.Utils

import EvictionNotice.Logging.*
import EvictionNotice.System.{
    ENSystem,
    ENSystemState
}
import EvictionNotice.Settings.ENSettings

public func HoursToGameTimeSeconds(hours: Int32) -> Float {
    return Int32ToFloat(hours) * 3600.0;
}

public func GameTimeSecondsToHours(seconds: Float) -> Int32 {
    return FloatToInt32(seconds / 3600.0);
}

public func Int32ToFloat(value: Int32) -> Float {
    return Cast<Float>(value);
}

public func FloatToInt32(value: Float) -> Int32 {
    return Cast<Int32>(value);
}

public func IsCoinFlipSuccessful() -> Bool {
    return RandRange(1, 100) >= 50;
}

public func RunGuard(system: ref<ENSystem>, opt suppressLog: Bool) -> Bool {
    //  Protects functions that should only be called when a given system is running.
    //  Typically, these are functions that change state on the player or system,
    //  or retrieve data that relies on system state in order to be valid.
    //
    //	Intended use:
    //  private func MyFunc() -> Void {
    //      if RunGuard(this) { return; }
    //      ...
    //  }
    //
    if NotEquals(system.state, ENSystemState.Running) {
        if !suppressLog {
            //ENLog(true, system, "############## System not running, exiting function call.", ENLogLevel.Warning);
        }
        return true;
    } else {
        return false;
    }
}

public func IsGameTimeAfter(maybeBefore: GameTime, maybeAfter: GameTime) -> Bool {
    // GameTime.IsAfter() does not work, and returns true no matter what is passed in.
    // This is a working implementation.
    return maybeAfter.GetSeconds() > maybeBefore.GetSeconds();
}

public func GetPlayerMoney() -> Int32 {
    let gameInstance = GetGameInstance();
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gameInstance).GetLocalPlayerControlledGameObject() as PlayerPuppet;
    let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gameInstance);
    return transactionSystem.GetItemQuantity(player, MarketSystem.Money());
}

public func PlayerHasMoney(amount: Int32) -> Bool {
    return GetPlayerMoney() > amount;
}

public func GivePlayerMoney(amount: Int32) -> Void {
    let gameInstance = GetGameInstance();
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gameInstance).GetLocalPlayerControlledGameObject() as PlayerPuppet;
    let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gameInstance);
    transactionSystem.GiveMoney(player, amount, n"money");
}

public func RemovePlayerMoney(amount: Int32) -> Bool {
    let gameInstance = GetGameInstance();
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gameInstance).GetLocalPlayerControlledGameObject() as PlayerPuppet;
    let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gameInstance);
    return transactionSystem.RemoveItem(player, MarketSystem.Money(), amount);
}

public func TryToRemovePlayerMoney(amount: Int32) -> Bool {
    if PlayerHasMoney(amount) {
        return RemovePlayerMoney(amount);
    } else {
        return false;
    }
}

public func GetHalfDaysUntilEviction() -> Int32 {
    return FloorF(Cast<Float>(ENSettings.Get().daysUntilEviction) * 0.5);
}