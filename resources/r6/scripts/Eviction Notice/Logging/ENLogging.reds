// -----------------------------------------------------------------------------
// ENLogging
// -----------------------------------------------------------------------------
//
// - Helper function for logging.
//

module EvictionNotice.Logging

enum ENLogLevel {
    Debug = 0,
    Warning = 1,
    Error = 2
}

public func ENLog(enabled: Bool, class: ref<IScriptable>, message: String, opt level: ENLogLevel) {
    let verbose: Bool = false;

    if enabled {
        let curr: String = "";
        let old: String = "";
        let oldest: String = "";
        let trace: String = "";

        if verbose {
            let callStack: array<StackTraceEntry> = GetStackTrace(3, true);
        
            if ArraySize(callStack) >= 1 {
                curr = NameToString(callStack[0].function);
            }
            if ArraySize(callStack) >= 2 {
                old = NameToString(callStack[1].function);
            }
            if ArraySize(callStack) >= 3 {
                oldest = NameToString(callStack[2].function);
            }

            trace = ":[" + oldest + "]->[" + old + "]->[" + curr + "]";
        }
        
        switch level {
            case ENLogLevel.Warning:
                LogChannelWarning(n"DEBUG", "[EvictionNotice]$WARN$ class[" + NameToString(class.GetClassName()) + "]" + trace + ": " + message);
                break;
            case ENLogLevel.Error:
                LogChannelError(n"DEBUG", "[EvictionNotice]!ERR~! class[" + NameToString(class.GetClassName()) + "]" + trace + ": " + message);
                break;
            default:
                LogChannel(n"DEBUG", "[EvictionNotice]#INFO# class[" + NameToString(class.GetClassName()) + "]" + trace + ": " + message);
                break;
        }
    }
}