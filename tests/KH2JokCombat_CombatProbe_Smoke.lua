local SAVE = 0x100000
local SLOT1 = 0x200000
local NOW = 0x300000
local INPUT = 0x400000
local REACT = 0x400010
local PAUSE = 0x400020
local CONTROL = 0x400030
local BATTLE_TYPE = 0x400040
local OPEN_MENU = 0x400050
local SORA_POINTER = 0x02AE9A28
local SORA = 0x500000

local memory = {}
local messages = {}
local writeCount = 0

local function Read(address)
    return memory[address] or 0
end

function ReadByte(address)
    return Read(address)
end

function ReadShort(address)
    return Read(address)
end

function ReadInt(address)
    return Read(address)
end

function ReadLong(address)
    return Read(address)
end

local function UnexpectedWrite(address, value)
    writeCount = writeCount + 1
    error(string.format(
        "Combat Probe attempted a memory write at 0x%X = 0x%X",
        address,
        value
    ))
end

function WriteByte(address, value)
    UnexpectedWrite(address, value)
end

function WriteShort(address, value)
    UnexpectedWrite(address, value)
end

function WriteInt(address, value)
    UnexpectedWrite(address, value)
end

function ConsolePrint(message)
    messages[#messages + 1] = tostring(message)
end

function RequireKH2LibraryVersion()
end

function RequirePCGameVersion()
end

package.loaded.kh2lib = nil
package.preload.kh2lib = function()
    return {
        Save = SAVE,
        Slot1 = SLOT1,
        Now = NOW,
        Input = INPUT,
        React = REACT,
        Pause = PAUSE,
        Cntrl = CONTROL,
        BtlTyp = BATTLE_TYPE,
        CurrentOpenMenu = OPEN_MENU,
        CanExecute = true,
        GameVersion = 0x030A,
        GameVersionString = "SMOKE"
    }
end

local function ClearMessages()
    messages = {}
end

local function HasMessage(fragment)
    for _, message in ipairs(messages) do
        if string.find(message, fragment, 1, true) then
            return true
        end
    end

    return false
end

local function AssertMessage(fragment)
    assert(
        HasMessage(fragment),
        "missing probe log fragment: " .. fragment
    )
end

memory[NOW + 0x00] = 0x02
memory[NOW + 0x01] = 0x01
memory[NOW + 0x04] = 0x0033
memory[NOW + 0x06] = 0x0044
memory[NOW + 0x08] = 0x0055
memory[SAVE + 0x1CEA] = 0x01
memory[SAVE + 0x3524] = 0x00
memory[SAVE + 0x353C] = 0x01020304
memory[SLOT1 + 0x004] = 20
memory[SLOT1 + 0x260] = 0x0054
memory[SLOT1 + 0x1B0] = 100
memory[SLOT1 + 0x1B1] = 9
memory[SLOT1 + 0x1B2] = 9
memory[SAVE + 0x24F0] = 0x002A
memory[SAVE + 0x32F4] = 0x002B
memory[SAVE + 0x332C] = 0x002C
memory[SAVE + 0x3364] = 0x002D
memory[SAVE + 0x339C] = 0x002E
memory[SAVE + 0x33D4] = 0x002F
memory[INPUT] = 0x0000
memory[INPUT + 0x04] = 0x00
memory[OPEN_MENU] = 0x00FF
memory[SORA_POINTER] = SORA
memory[SORA + 0x0180] = 0x0097
memory[SORA + 0x0184] = 0x025C
memory[SORA + 0x0740] = 0x0002
memory[SORA + 0x0744] = 0x0000
memory[SORA + 0x0790] = 0x0000

local Logger = require("runtime.KH2JokCombat_Log")
Logger.SetEnabled("PROBE", true)

dofile("diagnostics/KH2JokCombat_CombatProbe.lua")
_OnInit()
_OnFrame()

AssertMessage("READ-ONLY")
AssertMessage("BASELINE")
AssertMessage("raw32=0x00000000")
AssertMessage("dpad=NONE")
AssertMessage("r2Signal=0x00")
AssertMessage("Action=UNKNOWN Motion=0x0097[A300] Slot=0x025C")
AssertMessage("GroundAir=GROUND")
AssertMessage("LIVE #001")

-- Uncalibrated raw bits stay visible but do not emit five
-- redundant context lines on every movement/camera edge.
ClearMessages()
memory[INPUT] = 0x0004
_OnFrame()
AssertMessage("pressedRaw=0x00000004")
AssertMessage("heldLow=0x0004[B02]")
AssertMessage("calibratedPressed=NONE")
assert(not HasMessage("CONTEXT #"), "untracked input emitted noisy context")
memory[INPUT] = 0x0000
_OnFrame()

ClearMessages()
memory[INPUT] = 0x08000004
_OnFrame()
AssertMessage("calibratedPressed=A(Cross)")
AssertMessage("OWNER A=NATIVE_ATTACK_BASELINE_CANDIDATE")
AssertMessage("EDGE_SOURCE=PROBE_SAMPLED")

ClearMessages()
memory[SORA + 0x0180] = 0x00A1
memory[SORA + 0x0184] = 0x0284
_OnFrame()
AssertMessage("reason=TRANSITION")
AssertMessage("Motion=0x00A1[A310_UPPER_SLASH] Slot=0x0284")
AssertMessage("GroundAir=GROUND")

ClearMessages()
memory[SORA + 0x0180] = 0x0004
memory[SORA + 0x0184] = 0x0012
memory[SORA + 0x0740] = 0x0003
memory[SORA + 0x0744] = 0x0001
memory[SORA + 0x0790] = 0x0001
_OnFrame()
AssertMessage("Motion=0x0004[AIRBORNE_FALL] Slot=0x0012")
AssertMessage("GroundAir=AIR")

ClearMessages()
memory[INPUT] = 0x0000
_OnFrame()
AssertMessage("calibratedReleased=A(Cross)")

ClearMessages()
memory[SORA + 0x0180] = 0x0000
memory[SORA + 0x0184] = 0x0000
memory[SORA + 0x0740] = 0x0002
memory[SORA + 0x0744] = 0x0000
memory[SORA + 0x0790] = 0x0000
memory[INPUT] = 0x04000200
_OnFrame()
AssertMessage("calibratedPressed=Square")
AssertMessage("OWNER Square=NATIVE_GUARD_CANDIDATE")

memory[INPUT] = 0x0000
_OnFrame()

ClearMessages()
memory[SORA + 0x0180] = 0x0097
memory[SORA + 0x0184] = 0x025C
memory[INPUT] = 0x04000200
_OnFrame()
AssertMessage("calibratedPressed=Square")
AssertMessage("OWNER Square=NATIVE_ACTION_ABILITY_CANDIDATE")

memory[INPUT] = 0x0000
_OnFrame()

ClearMessages()
memory[REACT] = 0x0000
memory[INPUT] = 0x02000400
_OnFrame()
AssertMessage("calibratedPressed=Y(Triangle)")
AssertMessage("OWNER Y=UNRESOLVED_NO_REACTION")

memory[INPUT] = 0x0000
_OnFrame()

ClearMessages()
memory[REACT] = 0x0123
memory[INPUT] = 0x02000400
_OnFrame()
AssertMessage("calibratedPressed=Y(Triangle)")
AssertMessage("Reaction=0x0123")
AssertMessage("OWNER Y=NATIVE_REACTION_CANDIDATE")

memory[INPUT] = 0x0000
_OnFrame()

ClearMessages()
memory[REACT] = 0x0000
memory[OPEN_MENU] = 0x000A
memory[INPUT] = 0x02000400
_OnFrame()
AssertMessage("OWNER Y=NATIVE_UI_RESERVED")

memory[INPUT] = 0x0000
_OnFrame()
memory[OPEN_MENU] = 0x00FF

-- Controlled gameplay found the current R2 signal at Input+0x04: exact 0x09
-- while held and 0x00 after release. The raw32 field stays unchanged.
ClearMessages()
memory[INPUT + 0x04] = 0x09
_OnFrame()
AssertMessage("pressedRaw=0x00000000")
AssertMessage("r2Signal=0x09(previous=0x00)")
AssertMessage("calibratedPressed=R2")
AssertMessage("OWNER R2=CALIBRATED_GAMEPLAY_INPUT_PLUS_04")
AssertMessage("reason=CALIBRATED_INPUT_EDGE")

ClearMessages()
_OnFrame()
assert(not HasMessage("INPUT #"), "held R2 emitted a repeated press")

-- R2 remains the exact 0x09 signal while the four independently calibrated
-- Steam D-pad fingerprints change raw32. None may manufacture another R2 edge.
local dpadCases = {
    { raw = 0x00004010, name = "UP" },
    { raw = 0x00008020, name = "RIGHT" },
    { raw = 0x00010040, name = "DOWN" },
    { raw = 0x10000080, name = "LEFT" }
}

for _, dpadCase in ipairs(dpadCases) do
    ClearMessages()
    memory[INPUT] = dpadCase.raw
    _OnFrame()
    AssertMessage("dpad=" .. dpadCase.name)
    AssertMessage("r2Signal=0x09(previous=0x09)")
    AssertMessage("calibratedHeld=R2")
    AssertMessage("calibratedPressed=NONE")

    memory[INPUT] = 0x00000000
    _OnFrame()
end

ClearMessages()
memory[INPUT + 0x04] = 0x00
_OnFrame()
AssertMessage("r2Signal=0x00(previous=0x09)")
AssertMessage("calibratedReleased=R2")

-- Unknown adjacent values remain logged and fail closed after calibration.
ClearMessages()
memory[INPUT + 0x04] = 0x19
_OnFrame()
AssertMessage("r2Signal=0x19(previous=0x00)")
AssertMessage("calibratedPressed=NONE")
AssertMessage("reason=R2_SIGNAL_CHANGE")
assert(not HasMessage("OWNER R2="), "unknown R2 signal claimed ownership")
memory[INPUT + 0x04] = 0x00
_OnFrame()

-- ReadInt is intentional: Steam 1.0.0.10 must expose any adjacent high
-- input bits instead of silently discarding them. Unknown bits stay raw-only.
ClearMessages()
memory[INPUT] = 0x00010210
_OnFrame()
AssertMessage("raw32=0x00010210")
AssertMessage("heldHigh=0x0001[B00]")
AssertMessage("calibratedPressed=NONE")
AssertMessage("reason=INPUT_HIGH_EDGE")

-- Re-entering gameplay while a button is held must establish a baseline,
-- not manufacture a new press edge.
ClearMessages()
memory[SLOT1 + 0x004] = 0
_OnFrame()
memory[INPUT + 0x04] = 0x09
memory[SLOT1 + 0x004] = 20
_OnFrame()
AssertMessage("BASELINE")
AssertMessage("calibratedHeld=R2")
assert(not HasMessage("INPUT #"), "re-entry produced a false input edge")

assert(writeCount == 0, "Combat Probe performed memory writes")

print("OK KH2JokCombat_CombatProbe smoke test (calibrated A/Y/Square/R2 + D-pad fingerprints)")
