local BTL0_POINTER = 0x600000
local BTL0 = 0x700000
local PTYA = 0x701000
local BASE_GROUP = PTYA + 0x120
local SAVE = 0x100000
local SLOT1 = 0x200000
local NOW = 0x300000
local INPUT = 0x400000
local MENU1 = 0x410000
local REACT = 0x410052
local PAUSE = 0x420000
local CONTROL = 0x430000
local OPEN_MENU = 0x440000
local SORA_POINTER = 0x02AE9A28
local SORA = 0x500000

local memory = {}
local messages = {}
local readArrayCalls = 0
local readArrayIndexBase = 1
local writeCalls = 0

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

function ReadArray(address, length)
    readArrayCalls = readArrayCalls + 1
    local bytes = {}

    for offset = 0, length - 1 do
        bytes[offset + readArrayIndexBase] = ReadByte(address + offset)
    end

    return bytes
end

function WriteByte()
    writeCalls = writeCalls + 1
end

function WriteShort()
    writeCalls = writeCalls + 1
end

function WriteInt()
    writeCalls = writeCalls + 1
end

function WriteLong()
    writeCalls = writeCalls + 1
end

function WriteArray()
    writeCalls = writeCalls + 1
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

local function SetRecord(record, selector, motion, ability)
    local address = RecordAddress(record)
    SetByte(address + 0x00, selector)
    SetByte(address + 0x01, 0)
    SetShort(address + 0x08, motion)
    SetShort(address + 0x40, ability)
end

local function SetInput(value)
    SetInt(INPUT, value)
end

local function SetMotion(motion, slot)
    SetInt(SORA + 0x0180, motion)
    SetInt(SORA + 0x0184, slot or 0)
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
SetRecord(31, 11, 170, 0x01)
SetRecord(32, 12, 161, 0x12)

SetLong(SORA_POINTER, SORA)
SetMotion(0, 0)
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
        Menu1 = MENU1,
        GameVersion = 0x030A,
        CanExecute = true
    }
end

local Logger = require("runtime.KH2JokCombat_Log")
Logger.SetEnabled("DISPATCH", true)

dofile("diagnostics/KH2JokCombat_ActionProbe.lua")
_OnInit()
AssertMessage("READ-ONLY M-03C")
AssertMessage("TEST M-03E")

_OnFrame()
AssertMessage("BASELINE")

local function PrimeAttack(marker, motion, slot)
    SetByte(SORA + 0x0200, marker)

    if marker == 1 then
        SetLong(SORA + 0x0098, 0x00007FF612345678)
        SetLong(SORA + 0x00A0, 0)
        SetByte(SORA + 0x0123, 0x02)
        SetInt(SORA + 0x018C, 0x00000400)
        SetInt(SORA + 0x05B8, 0)
        SetInt(SORA + 0x0900, 0x00030000)
        SetLong(SORA + 0x0BF8, 0x0000000085000000)
        SetInt(SORA + 0x0C04, 6)
        SetLong(SORA + 0x0C90, 0)
        SetLong(SORA + 0x0C98, 0)
    else
        SetLong(SORA + 0x0098, 0)
        SetLong(SORA + 0x00A0, 0)
        SetByte(SORA + 0x0123, 0)
        SetInt(SORA + 0x018C, 0)
        SetInt(SORA + 0x05B8, 1)
        SetInt(SORA + 0x0900, 0x00020000)
        SetLong(SORA + 0x0BF8, 0)
        SetInt(SORA + 0x0C04, 0xFFFFFFFF)
        SetLong(SORA + 0x0C90, 0x00007FF623456789)
        SetLong(SORA + 0x0C98, 0)
    end

    SetMotion(motion or 151, slot or 0x025C)
    SetInput(0)
    _OnFrame()
end

local function ResetIdle()
    SetMotion(0, 0)
    SetInput(0)
    _OnFrame()
end

local function AfterAAccepted(marker, motion, slot)
    PrimeAttack(marker, motion, slot)
    SetMotion(161, 0x0284)
    SetInput(0x04000200)
    _OnFrame()
    ResetIdle()
end

local function AfterARejected(marker, motion, slot)
    local sourceMotion = motion or 151
    local sourceSlot = slot or 0x025C
    PrimeAttack(marker, sourceMotion, sourceSlot)
    SetMotion(sourceMotion, sourceSlot)
    SetInput(0x04000200)
    _OnFrame()
    SetInput(0)
    _OnFrame()
    ResetIdle()
end

AfterAAccepted(1)
AfterAAccepted(1)
AfterARejected(2)
AfterARejected(2)

AssertMessage("RESULT #001 ACCEPTED source=AFTER_A")
AssertMessage("RESULT #002 ACCEPTED source=AFTER_A")
AssertMessage("RESULT #003 REJECTED source=AFTER_A")
AssertMessage("RESULT #004 REJECTED source=AFTER_A")
AssertMessage("BUCKET motion=0x0097 slot=0x025C window=EARLY accepted=2 rejected=2")
AssertMessage("CANDIDATES PRE_EDGE motion=0x0097 slot=0x025C window=EARLY")
AssertMessage("PLAYER+0x0200:0x01>0x02")
AssertMessage("M03D SAMPLE #001 base=A300 outcome=ACCEPTED")
AssertMessage("target=TARGET_PRESENT")
AssertMessage("F120=0x02000000/bit25=1")
AssertMessage("FC04=6/0x00000006")
AssertMessage("M03D SAMPLE #003 base=A300 outcome=REJECTED")
AssertMessage("target=NO_TARGET_POINTER")
AssertMessage("F120=0x00000000/bit25=0")
AssertMessage("FC04=-1/0xFFFFFFFF")
AssertMessage("M03E START")

-- A delayed acceptance can coincide with a new physical Square edge. It must
-- resolve the existing trial without creating the duplicate seen in live #012.
PrimeAttack(3)
SetInput(0x04000200)
_OnFrame()
SetInput(0)
_OnFrame()
SetMotion(161, 0x0284)
SetInput(0x04000200)
_OnFrame()
AssertMessage("RESULT #005 ACCEPTED source=AFTER_A")
AssertMessage("SQUARE_EDGE IGNORED_RESOLVED_TRIAL")

-- A later Square press while A310 is already active is not a new sample (#013).
SetInput(0)
_OnFrame()
SetInput(0x04000200)
_OnFrame()
AssertMessage("SQUARE_EDGE IGNORED_ALREADY_EXPECTED motion=0x00A1")
assert(not HasMessage("EDGE #006"), "duplicate Square edge created trial #006")

-- M-03D must cover every native Base attack, not only A300.
SetInput(0)
ResetIdle()
AfterAAccepted(1, 0x0098, 0x0260)
AfterARejected(2, 0x0099, 0x0264)
AssertMessage("M03D SAMPLE #006 base=A301 outcome=ACCEPTED")
AssertMessage("M03D SAMPLE #007 base=A302 outcome=REJECTED")

-- M-03E reports only meaningful bit-25 transitions inside a Base attack.
ResetIdle()
PrimeAttack(2, 0x0097, 0x025C)
SetByte(SORA + 0x0200, 0x5A)
SetInt(SORA + 0x0120, 0x02000000)
_OnFrame()
SetInt(SORA + 0x0120, 0)
_OnFrame()
ResetIdle()
AssertMessage("M03E BIT25")
AssertMessage("old=0 new=1")
AssertMessage("old=1 new=0")

assert(readArrayCalls > 0, "probe did not use ReadArray snapshots")
assert(writeCalls == 0, "read-only probe invoked a write API")
assert(ReadByte(SORA + 0x0200) == 0x5A, "probe changed PLAYER memory")
assert(ReadShort(RecordAddress(31) + 0x08) == 170, "probe changed Guard PTYA")
assert(ReadShort(RecordAddress(32) + 0x08) == 161, "probe changed Square PTYA")

-- LuaBackend container adapters can expose arrays with either conventional
-- Lua indexing or native zero-based indexing. Both must fail safe.
readArrayIndexBase = 0
SetInput(0)
SetMotion(0, 0)
_OnInit()
_OnFrame()
assert(not HasMessage("snapshot pre-edge fallito"), "zero-based ReadArray rejected")
assert(writeCalls == 0, "zero-based snapshot path invoked a write API")

print("OK KH2JokCombat_ActionProbe smoke test (pre-edge exact buckets + zero-write)")
