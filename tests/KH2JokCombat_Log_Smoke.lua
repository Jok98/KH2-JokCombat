local messages = {}

function ConsolePrint(message, level)
    messages[#messages + 1] = {
        message = tostring(message),
        level = level
    }
end

local function CountMessages()
    return #messages
end

local function LastMessageContains(fragment)
    local last = messages[#messages]
    return last ~= nil
        and string.find(last.message, fragment, 1, true) ~= nil
end

local Logger = require("runtime.KH2JokCombat_Log")

assert(Logger.IsEnabled("ERROR"), "ERROR must always be enabled")
assert(Logger.IsEnabled("WARNING"), "WARNING must always be enabled")
assert(not Logger.IsEnabled("COMBAT"), "COMBAT should be quiet during M-03B")
assert(Logger.IsEnabled("DISPATCH"), "DISPATCH should be the default focus")
assert(not Logger.IsEnabled("SYSTEM"), "SYSTEM should be quiet by default")
assert(not Logger.IsEnabled("PROGRESSION"), "PROGRESSION should be quiet by default")
assert(not Logger.IsEnabled("GUMMI"), "GUMMI should be quiet by default")
assert(not Logger.IsEnabled("PROBE"), "PROBE should be quiet by default")
assert(not Logger.IsEnabled("TRACE"), "TRACE should be quiet by default")

assert(Logger.Log("Test", "ERROR", "fatal"))
assert(LastMessageContains("[Test][ERROR] fatal"))
assert(messages[#messages].level == 3)

assert(Logger.Log("Test", "WARNING", "careful"))
assert(LastMessageContains("[Test][WARNING] careful"))
assert(messages[#messages].level == 2)

assert(not Logger.Log("Test", "COMBAT", "hidden branch"))
assert(Logger.Log("Test", "DISPATCH", "probe"))
assert(LastMessageContains("[Test][DISPATCH] probe"))

assert(Logger.SetEnabled("COMBAT", true))
assert(Logger.Log("Test", "COMBAT", "branch"))
assert(LastMessageContains("[Test][COMBAT] branch"))

local beforeQuiet = CountMessages()
assert(not Logger.Log("Test", "PROBE", "hidden"))
assert(not Logger.Log("Test", "TRACE", "hidden"))
assert(not Logger.Log("Test", "TYPO", "hidden"))
assert(CountMessages() == beforeQuiet, "disabled categories emitted output")

assert(Logger.SetEnabled("PROBE", true))
assert(Logger.Log("Test", "PROBE", "visible"))
assert(LastMessageContains("[Test][PROBE] visible"))

assert(Logger.SetEnabled("TRACE", true))
assert(Logger.Once("Test", "TRACE", "edge", "once"))
assert(not Logger.Once("Test", "TRACE", "edge", "twice"))
assert(LastMessageContains("[Test][TRACE] once"))

assert(not Logger.SetEnabled("ERROR", false), "ERROR must not be mutable")
assert(Logger.IsEnabled("ERROR"), "ERROR was disabled")
assert(not Logger.SetEnabled("TYPO", true), "unknown category was accepted")

print("OK KH2JokCombat_Log smoke test (category defaults + toggles + always-on severity)")
