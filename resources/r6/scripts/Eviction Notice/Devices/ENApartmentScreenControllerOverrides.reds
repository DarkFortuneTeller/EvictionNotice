// -----------------------------------------------------------------------------
// ENApartmentScreenControllerOverrides
// -----------------------------------------------------------------------------
//
// - Various wrappers that extend the functionality of apartment screens.
//

import EvictionNotice.Settings.ENSettings

public enum ERentStatusExtended {
    None = 0,
    Due = 1,
    Available = 2,
    Purchased = 3
}

@addField(ApartmentScreenControllerPS)
private persistent let evictionNoticeManagedScreen: Bool;

@addField(ApartmentScreenControllerPS)
private persistent let evictionNoticeIsMotelScreen: Bool;

@addField(ApartmentScreenControllerPS)
private persistent let evictionNoticeShowMessageOnPurchase: Bool;

@addMethod(ApartmentScreenControllerPS)
private final func SetEvictionNoticeManaged() -> Void {
    this.evictionNoticeManagedScreen = true;
}

@addMethod(ApartmentScreenControllerPS)
private final func SetShowMessageOnPurchase(show: Bool) -> Void {
    this.evictionNoticeShowMessageOnPurchase = show;
}

@addMethod(ApartmentScreenControllerPS)
private final func GetEvictionNoticeManaged() -> Bool {
    return this.evictionNoticeManagedScreen;
}

@addMethod(ApartmentScreenControllerPS)
private final func SetIsMotelScreen() -> Void {
    this.evictionNoticeIsMotelScreen = true;
    this.m_paidMessageRecordID = t"EvictionNoticeScreenMessages.MotelRoomRentPaid";
    this.m_overdueMessageRecordID = t"EvictionNoticeScreenMessages.MotelRoomRentOverdue";
    this.m_evictionMessageRecordID = t"EvictionNoticeScreenMessages.MotelRoomEvicted";
}

@addMethod(ApartmentScreenControllerPS)
private final func SetCurrentRentStatusExtended(baseStatus: ERentStatus, opt extendedStatus: ERentStatusExtended) -> Void {
    if NotEquals(extendedStatus, ERentStatusExtended.None) {
        let messageID: TweakDBID = this.GetMessageIDForExtendedStatus(extendedStatus);
        this.SetMessageRecordID(messageID);
    } else {
        this.SetCurrentRentStatus(baseStatus);
    }
}

@addMethod(ApartmentScreenControllerPS)
private final func GetMessageIDForExtendedStatus(extendedStatus: ERentStatusExtended) -> TweakDBID {
    if Equals(extendedStatus, ERentStatusExtended.None) {
        return t"";
    } else if Equals(extendedStatus, ERentStatusExtended.Due) {
        if this.evictionNoticeIsMotelScreen {
            return t"EvictionNoticeScreenMessages.MotelRoomRentDue";
        } else {
            return t"EvictionNoticeScreenMessages.RentDue";
        }
    } else if Equals(extendedStatus, ERentStatusExtended.Available) {
        if this.evictionNoticeIsMotelScreen {
            return t"EvictionNoticeScreenMessages.MotelRoomAvailable";
        } else {
            return t"EvictionNoticeScreenMessages.Available";
        }
    } else if Equals(extendedStatus, ERentStatusExtended.Purchased) {
        if this.evictionNoticeShowMessageOnPurchase {
            if this.evictionNoticeIsMotelScreen {
                return t"EvictionNoticeScreenMessages.MotelRoomPurchased";
            } else {
                return t"EvictionNoticeScreenMessages.Purchased";
            }
        } else {
            return t"EvictionNoticeScreenMessages.Blank";
        }
    }

    return t"";
}

@wrapMethod(ApartmentScreenControllerPS)
private final func UpdateCurrentOverdue() -> Void {
    if !this.GetEvictionNoticeManaged() {
        wrappedMethod();
    }
}

@wrapMethod(ApartmentScreenControllerPS)
private final func InitializeRentState() -> Void {
    if this.GetEvictionNoticeManaged() {
        this.m_isInitialRentStateSet = true;
    } else {
        wrappedMethod();
    }
}

@wrapMethod(ApartmentScreenControllerPS)
private final func ReEvaluateRentStatus() -> Void {
    if this.GetEvictionNoticeManaged() {
    } else {
        wrappedMethod();
    }
}

@wrapMethod(ApartmentScreenControllerPS)
private final func GetInitialOverdueValue() -> Int32 {
    this.m_maxDays = ENSettings.Get().rentalPeriodInDays - 1;

    return wrappedMethod();
}

@wrapMethod(ApartmentScreenControllerPS)
private final func GetStateChangeProbabilityValue() -> Int32 {
    this.m_maxDays = ENSettings.Get().rentalPeriodInDays - 1;

    return wrappedMethod();
}