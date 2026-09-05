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
local HIT_GATE = SORA + 0x0450

local memory = {}
local messages = {}

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

function ConsolePrint(message)
    messages[#messages + 1] = tostring(message)
end

function RequireKH2LibraryVersion()
end

function RequirePCGameVersion()
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

local function RecordAddress(record)
    return BASE_GROUP + 0x04 + record * 0x44
end

local function SetInput(value)
    SetInt(INPUT, value)
end

local function SetMotion(motion, slot)
    SetInt(SORA + 0x0180, motion)
    SetInt(SORA + 0x0184, slot)
end

-- One-entry loaded 00battle BAR containing the verified Base PTYA group.
SetInt(BTL0, 0x01524142)
SetInt(BTL0 + 0x04, 1)
SetInt(BTL0 + 0x08, 0x100)
SetInt(BTL0 + 0x18, 0x1100)
SetInt(BTL0 + 0x1C, 15172)
SetLong(BTL0_POINTER, BTL0)
SetInt(PTYA, 2)
SetInt(PTYA + 0x04, 70)
SetInt(PTYA + 0x08 + 0x04, 0x120)
SetInt(BASE_GROUP, 37)
SetShort(RecordAddress(32) + 0x08, 161)
SetShort(RecordAddress(34) + 0x08, 192)

SetLong(SORA_POINTER, SORA)
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
SetMotion(0, 0)

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
Logger.SetEnabled("PROBE", true)

dofile("diagnostics/KH2JokCombat_TargetlessProbe.lua")
_OnInit()
AssertMessage("READ-ONLY")
AssertMessage("PTYA read-only trovata")
_OnFrame()

local function PrepareSquare(gateValue, baseSlot)
    SetByte(HIT_GATE, gateValue)
    SetMotion(169, baseSlot)
    SetInput(0x08000004)
    _OnFrame()
    SetInput(0)

    for _ = 1, 3 do
        _OnFrame()
    end
end

local function RunAccepted(baseSlot)
    PrepareSquare(1, baseSlot)
    SetMotion(161, baseSlot + 1)
    SetInput(0x04000200)
    _OnFrame()
    SetInput(0)
    SetMotion(0, 0)
    _OnFrame()
end

local function RunRejected(baseSlot)
    PrepareSquare(0, baseSlot)
    SetInput(0x04000200)
    _OnFrame()
    SetInput(0)

    for _ = 1, 45 do
        _OnFrame()
    end

    SetMotion(0, 0)
    _OnFrame()
end

RunAccepted(0x0100)
RunAccepted(0x0200)
RunRejected(0x0300)
RunRejected(0x0400)

AssertMessage("RESULT #001 ACCEPTED")
AssertMessage("RESULT #002 ACCEPTED")
AssertMessage("RESULT #003 REJECTED")
AssertMessage("RESULT #004 REJECTED")
AssertMessage("CANDIDATES accepted=2 rejected=2")
AssertMessage("+0x0450:0x00>0x01")

print("OK KH2JokCombat_TargetlessProbe smoke test (read-only classifier + stable candidate)")
