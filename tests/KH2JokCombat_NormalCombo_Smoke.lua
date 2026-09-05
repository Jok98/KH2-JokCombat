local BTL0_POINTER = 0x600000
local BTL0 = 0x700000
local PTYA = 0x701000
local BASE_GROUP = PTYA + 0x120
local SAVE = 0x100000
local SLOT1 = 0x200000
local NOW = 0x300000
local INPUT = 0x400000
local REACT = 0x400010
local PAUSE = 0x400020
local CONTROL = 0x400030
local OPEN_MENU = 0x400050
local SORA_POINTER = 0x02AE9A28
local SORA = 0x500000

local memory = {}
local messages = {}
local writes = {}

local function SetByte(address, value)
    memory[address] = value & 0xFF
end

local function SetShort(address, value)
    SetByte(address, value)
    SetByte(address + 1, value >> 8)
end

local function SetInt(address, value)
    SetShort(address, value)
    SetShort(address + 2, value >> 16)
end

local function SetLong(address, value)
    SetInt(address, value)
    SetInt(address + 4, value >> 32)
end

function ReadByte(address)
    return memory[address] or 0
end

function ReadShort(address)
    return ReadByte(address) | (ReadByte(address + 1) << 8)
end

function ReadInt(address)
    return ReadShort(address) | (ReadShort(address + 2) << 16)
end

function ReadLong(address)
    return ReadInt(address) | (ReadInt(address + 4) << 32)
end

function WriteShort(address, value)
    writes[#writes + 1] = { address = address, value = value }
    SetShort(address, value)
end

function ConsolePrint(message)
    messages[#messages + 1] = tostring(message)
end

function RequireKH2LibraryVersion()
end

function RequirePCGameVersion()
end

local function RecordAddress(record)
    return BASE_GROUP + 0x04 + record * 0x44
end

local function SetRecord(
    record,
    selector,
    comboOffset,
    flags,
    motion,
    nextMotion,
    ability
)
    local address = RecordAddress(record)
    SetByte(address + 0x00, selector)
    SetByte(address + 0x01, 0)
    SetByte(address + 0x02, 0xFF)
    SetByte(address + 0x03, comboOffset)
    SetInt(address + 0x04, flags)
    SetShort(address + 0x08, motion)
    SetShort(address + 0x0A, nextMotion)
    SetShort(address + 0x40, ability)
    SetShort(address + 0x42, 5)
end

local function SetInput(value)
    SetInt(INPUT, value)
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
    assert(HasMessage(fragment), "missing log fragment: " .. fragment)
end

-- One-entry loaded 00battle BAR. The runtime relocation arithmetic mirrors
-- the production helper: address = BAR + (relocated - lookupBase).
SetInt(BTL0, 0x01524142)
SetInt(BTL0 + 0x04, 1)
SetInt(BTL0 + 0x08, 0x100)
SetInt(BTL0 + 0x18, 0x1100)
SetInt(BTL0 + 0x1C, 15172)
SetLong(BTL0_POINTER, BTL0)

SetInt(PTYA, 2)
SetInt(PTYA + 0x04, 70)
SetInt(PTYA + 0x08 + 1 * 0x04, 0x120)
SetInt(BASE_GROUP, 37)
SetRecord(31, 11, 0, 0, 173, 0, 0x01)
SetRecord(32, 12, 0, 0, 166, 0, 0x12)
SetRecord(33, 37, 1, 4, 167, 4, 0x5F)
SetRecord(34, 38, 0, 1, 192, 4, 0x63)
SetRecord(35, 39, 0, 0, 171, 0, 0x60)
SetRecord(36, 40, 0, 1, 172, 4, 0x65)

SetLong(SORA_POINTER, SORA)
SetInt(SORA + 0x0180, 0)
SetInt(SORA + 0x0740, 2)
SetInt(SORA + 0x0744, 0)
SetInt(SORA + 0x0790, 0)
SetByte(NOW, 0x02)
SetByte(SAVE + 0x1CEA, 0x01)
SetByte(SAVE + 0x3524, 0)
SetInt(SLOT1 + 0x004, 20)
SetByte(PAUSE, 0)
SetByte(CONTROL, 0)
SetShort(REACT, 0)
SetByte(OPEN_MENU, 0xFF)
SetInput(0)

package.loaded.kh2lib = nil
package.preload.kh2lib = function()
    return {
        Btl0Pointer = BTL0_POINTER,
        Input = INPUT,
        React = REACT,
        Pause = PAUSE,
        Cntrl = CONTROL,
        CurrentOpenMenu = OPEN_MENU,
        Now = NOW,
        Save = SAVE,
        Slot1 = SLOT1,
        GameVersion = 0x030A,
        CanExecute = true
    }
end

local Logger = require("runtime.KH2JokCombat_Log")
Logger.SetEnabled("COMBAT", true)
Logger.SetEnabled("SYSTEM", true)
Logger.SetEnabled("TRACE", true)

dofile("runtime/KH2JokCombat_NormalCombo.lua")
_OnInit()
AssertMessage("nessun input viene sintetizzato")
AssertMessage("PTYA trovata")
AssertMessage("TARGETLESS GROUND PROOF")
assert(ReadShort(RecordAddress(31) + 0x08) == 170)
assert(ReadByte(RecordAddress(31) + 0x00) == 11)
assert(ReadShort(RecordAddress(31) + 0x40) == 0x01)
assert(ReadShort(RecordAddress(32) + 0x08) == 166)
assert(ReadByte(RecordAddress(32) + 0x00) == 12)
assert(ReadShort(RecordAddress(32) + 0x40) == 0x12)
assert(ReadShort(RecordAddress(34) + 0x08) == 192)

-- F1/reload must accept the already-installed carrier without another write.
local writesAfterCarrierInstall = #writes
ClearMessages()
package.loaded.kh2lib = nil
dofile("runtime/KH2JokCombat_NormalCombo.lua")
_OnInit()
AssertMessage("TARGETLESS GROUND PROOF")
assert(#writes == writesAfterCarrierInstall)
assert(ReadShort(RecordAddress(31) + 0x08) == 170)

_OnFrame()
AssertMessage("BASELINE")

-- Neutral Square is still dispatched by the native Guard selector, but the
-- carrier now points at A319/Vicinity Break without touching input or ability.
ClearMessages()
SetInput(0x04000200)
_OnFrame()
AssertMessage("SQUARE depth=0")
AssertMessage("A319 Vicinity Break")
assert(ReadShort(RecordAddress(31) + 0x08) == 170)
SetInput(0)
_OnFrame()

-- A from neutral opens depth 1 before the later physical Square dispatch.
ClearMessages()
SetInput(0x08000004)
_OnFrame()
AssertMessage("DEPTH A accepted reason=IMMEDIATE Motion=0x0000 0->1")
assert(not HasMessage("TARGETLESS COMBO PROOF ARMED"))
assert(ReadShort(RecordAddress(32) + 0x08) == 161)
assert(ReadByte(RecordAddress(32) + 0x00) == 12)
assert(ReadShort(RecordAddress(32) + 0x40) == 0x12)
assert(ReadShort(RecordAddress(34) + 0x08) == 192)

SetInput(0)
SetInt(SORA + 0x0180, 0x0097)
_OnFrame()

-- A inside the native chain is buffered until a different attack motion
-- proves that the engine actually accepted it.
ClearMessages()
SetInput(0x08000004)
_OnFrame()
AssertMessage("A_PENDING Motion=0x0097 targetDepth=2")
assert(ReadShort(RecordAddress(32) + 0x08) == 161)

SetInput(0)
SetInt(SORA + 0x0180, 0x0098)
_OnFrame()
AssertMessage("DEPTH A accepted reason=MOTION_CONFIRMED Motion=0x0098 1->2")
assert(ReadShort(RecordAddress(32) + 0x08) == 162)
assert(ReadByte(RecordAddress(32) + 0x00) == 12)
assert(ReadShort(RecordAddress(32) + 0x40) == 0x12)
assert(ReadShort(RecordAddress(34) + 0x08) == 193)

-- Square never gets synthesized or counted as A; it consumes the profile
-- already prepared by the previous accepted physical A edge.
ClearMessages()
SetInput(0x04000200)
_OnFrame()
AssertMessage("SQUARE depth=2 domain=GROUND")
AssertMessage("prepared=0x00A2[A311 Slapshot]")
assert(ReadShort(RecordAddress(32) + 0x08) == 162)

SetInput(0)
SetInt(SORA + 0x0180, 0x00A2)
_OnFrame()
AssertMessage("SQUARE_RESULT ACCEPTED depth=2 domain=GROUND")

-- A after a Square branch continues the virtual depth.
ClearMessages()
SetInput(0x08000004)
_OnFrame()
AssertMessage("A_PENDING Motion=0x00A2 targetDepth=3")
assert(ReadShort(RecordAddress(32) + 0x08) == 162)

SetInput(0)
SetInt(SORA + 0x0180, 0x0099)
_OnFrame()
AssertMessage("DEPTH A accepted reason=MOTION_CONFIRMED Motion=0x0099 2->3")
assert(ReadShort(RecordAddress(32) + 0x08) == 169)
assert(ReadShort(RecordAddress(34) + 0x08) == 196)

SetInput(0x08000004)
_OnFrame()
AssertMessage("A_PENDING Motion=0x0099 targetDepth=4")
SetInput(0)
SetInt(SORA + 0x0180, 0x009A)
_OnFrame()
assert(ReadShort(RecordAddress(32) + 0x08) == 166)
assert(ReadShort(RecordAddress(34) + 0x08) == 194)

-- More A presses in an active chain saturate at depth 4.
ClearMessages()
SetInput(0x08000004)
_OnFrame()
AssertMessage("A_PENDING Motion=0x009A targetDepth=4")
SetInput(0)
SetInt(SORA + 0x0180, 0x009B)
_OnFrame()
AssertMessage("Motion=0x009B 4->4")

-- Returning to true neutral restores the verified static fallback profile.
SetInput(0)
SetInt(SORA + 0x0180, 0)
ClearMessages()
for _ = 1, 10 do
    _OnFrame()
end
AssertMessage("RESET reason=IDLE depth=4->0")
assert(ReadShort(RecordAddress(32) + 0x08) == 166)
assert(ReadByte(RecordAddress(32) + 0x00) == 12)
assert(ReadShort(RecordAddress(32) + 0x40) == 0x12)
assert(ReadShort(RecordAddress(34) + 0x08) == 192)

-- Native Reaction ownership suppresses A counting and all profile writes.
local writesBeforeReaction = #writes
SetShort(REACT, 0x123)
SetInput(0x08000004)
_OnFrame()
SetShort(REACT, 0)
SetInput(0)
_OnFrame()
assert(#writes == writesBeforeReaction, "Reaction context changed PTYA")

-- F1/reload must recover the exact legacy V5 identity if an older script left
-- it armed in RAM, then keep the record native for every later A depth.
ClearMessages()
SetShort(RecordAddress(32) + 0x00, 11)
SetShort(RecordAddress(32) + 0x40, 0x01)
SetShort(RecordAddress(32) + 0x08, 161)

SetInput(0)
SetInt(SORA + 0x0180, 0)
package.loaded.kh2lib = nil
dofile("runtime/KH2JokCombat_NormalCombo.lua")
_OnInit()
AssertMessage("V5 GUARD32 RITIRATA")
assert(ReadByte(RecordAddress(32) + 0x00) == 12)
assert(ReadShort(RecordAddress(32) + 0x40) == 0x12)
assert(ReadShort(RecordAddress(32) + 0x08) == 166)
assert(ReadShort(RecordAddress(31) + 0x08) == 170)

_OnFrame()
AssertMessage("BASELINE")

-- A Square branch whose expected motion never appears is reported as rejected
-- when the route returns to neutral; preparation alone is not a gameplay pass.
SetInput(0x08000004)
_OnFrame()
SetInput(0)
SetInt(SORA + 0x0180, 0x0097)
_OnFrame()
ClearMessages()
SetInput(0x04000200)
_OnFrame()
AssertMessage("SQUARE depth=1 domain=GROUND")
SetInput(0)
SetInt(SORA + 0x0180, 0)
for _ = 1, 10 do
    _OnFrame()
end
AssertMessage("SQUARE_RESULT REJECTED depth=1 domain=GROUND")
AssertMessage("reason=RESET_IDLE")
assert(ReadByte(RecordAddress(32) + 0x00) == 12)
assert(ReadShort(RecordAddress(32) + 0x40) == 0x12)

-- A new route never re-arms the retired V5 identity.
SetInput(0x08000004)
_OnFrame()
assert(ReadByte(RecordAddress(32) + 0x00) == 12)
assert(ReadShort(RecordAddress(32) + 0x40) == 0x12)
assert(ReadShort(RecordAddress(32) + 0x08) == 161)

-- Relocation drops the old route and revalidates a new BAR before any write.
local function RelocateBattle(delta)
    for address = BTL0, PTYA + 15171 do
        memory[address + delta] = memory[address]
    end
    SetShort(RecordAddress(31) + delta + 0x08, 173)
    SetShort(RecordAddress(32) + delta + 0x08, 169)
    SetShort(RecordAddress(34) + delta + 0x08, 194)
    SetLong(BTL0_POINTER, BTL0 + delta)
end

local relocationDelta = 0x100000
RelocateBattle(relocationDelta)
local writesBeforeRelocation = #writes
_OnFrame()
assert(ReadShort(RecordAddress(31) + relocationDelta + 0x08) == 170)
assert(ReadShort(RecordAddress(32) + relocationDelta + 0x08) == 166,
    "relocated table did not reset to the baseline")
assert(ReadShort(RecordAddress(34) + relocationDelta + 0x08) == 192)
_OnFrame()
assert(ReadShort(RecordAddress(32) + relocationDelta + 0x08) == 166,
    "held A became a new edge across relocation")
SetInput(0)
_OnFrame()
SetInput(0x08000004)
_OnFrame()
assert(ReadShort(RecordAddress(32) + relocationDelta + 0x08) == 161,
    "fresh A did not route through the relocated table")
for index = writesBeforeRelocation + 1, #writes do
    assert(writes[index].address >= PTYA + relocationDelta
        and writes[index].address < PTYA + relocationDelta + 15172,
        "relocation wrote through a stale PTYA pointer")
end

-- An unloaded BAR must never be restored through stale pointers. The next
-- pointer change retries immediately, even inside the normal discovery delay.
SetLong(BTL0_POINTER, 0)
local writesBeforeUnload = #writes
_OnFrame()
_OnFrame()
assert(#writes == writesBeforeUnload, "unloaded BAR received a write")
RelocateBattle(0x200000)
_OnFrame()
assert(ReadShort(RecordAddress(32) + 0x200000 + 0x08) == 166,
    "new BAR was not prepared immediately after unload")

-- An invalid replacement must be rejected before even Guard is patched.
RelocateBattle(0x300000)
SetByte(RecordAddress(32) + 0x300000, 0xEE)
ClearMessages()
local writesBeforeInvalidReplacement = #writes
_OnFrame()
AssertMessage("DISABILITATO: record Base 32 identita inattesa")
assert(#writes == writesBeforeInvalidReplacement,
    "invalid replacement BAR triggered a write")

-- A backend failure reading the owner pointer disables routing without writes.
SetLong(BTL0_POINTER, BTL0)
dofile("runtime/KH2JokCombat_NormalCombo.lua")
_OnInit()
local ReadLongBeforeFailure = ReadLong
function ReadLong(address)
    if address == BTL0_POINTER then
        error("simulated Btl0Pointer read failure")
    end
    return ReadLongBeforeFailure(address)
end
ClearMessages()
local writesBeforePointerFailure = #writes
assert(pcall(_OnFrame), "owner pointer read failure escaped the frame callback")
AssertMessage("DISABILITATO: lettura Btl0Pointer fallita")
assert(#writes == writesBeforePointerFailure, "pointer read failure triggered a write")
ReadLong = ReadLongBeforeFailure

-- A changed immutable selector makes the next initialization fail closed.
SetByte(RecordAddress(32), 0xEE)
ClearMessages()
local writesBeforeInvalid = #writes
package.loaded.kh2lib = nil
dofile("runtime/KH2JokCombat_NormalCombo.lua")
_OnInit()
AssertMessage("DISABILITATO: record Base 32 identita inattesa")
assert(#writes == writesBeforeInvalid, "invalid PTYA triggered a write")

-- Unknown Guard motion must fail closed before the carrier can write.
SetByte(RecordAddress(32), 12)
SetShort(RecordAddress(31) + 0x08, 0xDEAD)
ClearMessages()
local writesBeforeInvalidGuard = #writes
package.loaded.kh2lib = nil
dofile("runtime/KH2JokCombat_NormalCombo.lua")
_OnInit()
AssertMessage("DISABILITATO: record Base 31 non valido")
assert(#writes == writesBeforeInvalidGuard, "invalid Guard motion triggered a write")

print("OK KH2JokCombat_NormalCombo smoke test (A-depth + V5 recovery + BAR relocation/unload + rollback/fail-closed)")
