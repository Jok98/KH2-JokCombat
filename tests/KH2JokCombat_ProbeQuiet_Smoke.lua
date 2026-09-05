local messages = {}
local kh2libLoads = 0

function ConsolePrint(message)
    messages[#messages + 1] = tostring(message)
end

package.preload.kh2lib = function()
    kh2libLoads = kh2libLoads + 1
    error("a disabled probe must not load kh2lib")
end

local Logger = require("runtime.KH2JokCombat_Log")
assert(not Logger.IsEnabled("PROBE"), "PROBE must be disabled by default")
assert(Logger.SetEnabled("DISPATCH", false))

local probes = {
    "diagnostics/KH2JokCombat_AbilityProbe.lua",
    "diagnostics/KH2JokCombat_ActionProbe.lua",
    "diagnostics/KH2JokCombat_CombatProbe.lua",
    "diagnostics/KH2JokCombat_RoxasProbe.lua",
    "diagnostics/KH2JokCombat_TargetlessProbe.lua"
}

for _, probe in ipairs(probes) do
    dofile(probe)
    _OnInit()
    _OnFrame()
end

assert(kh2libLoads == 0, "disabled probes loaded kh2lib")
assert(#messages == 0, "disabled probes emitted console output")

print("OK KH2JokCombat probes quiet smoke test (PROBE/DISPATCH off: no logs, kh2lib or frame work)")
