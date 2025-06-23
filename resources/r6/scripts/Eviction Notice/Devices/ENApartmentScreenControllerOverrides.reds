public enum ERentStatusExtended {
    None = 0,
    Due = 1,
    Available = 2
}

@addField(ApartmentScreenControllerPS)
private persistent let evictionNoticeManagedScreen: Bool;

@addField(ApartmentScreenControllerPS)
private persistent let evictionNoticeIsMotelScreen: Bool;

@addMethod(ApartmentScreenControllerPS)
private final func SetEvictionNoticeManaged() -> Void {
    this.evictionNoticeManagedScreen = true;
}

@addMethod(ApartmentScreenControllerPS)
private final func GetEvictionNoticeManaged() -> Bool {
    return this.evictionNoticeManagedScreen;
}

@addMethod(ApartmentScreenControllerPS)
private final func SetIsMotelScreen() -> Void {
    FTLog("Setting Motel Screen");
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
        FTLog("We are eviction notice managed on InitializeRentState, ignore.");
        this.m_isInitialRentStateSet = true;
    } else {
        wrappedMethod();
    }
}

@wrapMethod(ApartmentScreenControllerPS)
private final func ReEvaluateRentStatus() -> Void {
    if this.GetEvictionNoticeManaged() {
        FTLog("We are eviction notice managed on ReEvaluateRentStatus, ignore.");
    } else {
        wrappedMethod();
    }
}
