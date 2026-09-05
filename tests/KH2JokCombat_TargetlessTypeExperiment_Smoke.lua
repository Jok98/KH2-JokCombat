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

local SHADOW_GROUND_BASELINE = {
    0x21, 0x01, 0xFF, 0x00, 0x0A, 0x00, 0x00, 0x00,
    0xBF, 0x00, 0x04, 0x00, 0x00, 0x00, 0x88, 0x41,
    0x00, 0x00, 0xEA, 0x42, 0x00, 0x00, 0x88, 0x41,
    0x00, 0x00, 0x00, 0xC1, 0x00, 0x00, 0x90, 0x41,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x82, 0x43,
    0x00, 0x00, 0xDC, 0xC2, 0x00, 0x00, 0x7A, 0xC3,
    0x81, 0xFD, 0x7F, 0x3F, 0x00, 0x00, 0x80, 0x3F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5C, 0x42,
    0x61, 0x00, 0x14, 0x00
}

local SHADOW_AIR_BASELINE = {
    0x30, 0x01, 0xFF, 0x00, 0x0A, 0x00, 0x00, 0x00,
    0xC4, 0x00, 0x04, 0x00, 0x00, 0x00, 0x24, 0x42,
    0x00, 0x00, 0xEA, 0x42, 0x00, 0x00, 0x24, 0x42,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x42,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x22, 0x44,
    0x00, 0x00, 0xDC, 0xC2, 0x00, 0x00, 0x7A, 0xC3,
    0x81, 0xFD, 0x7F, 0x3F, 0x00, 0x00, 0x80, 0x3F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xD2, 0x42,
    0xB2, 0x00, 0x14, 0x00
}

local GUARD_BASELINE = {
    0x0B, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xAD, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x80, 0x3F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x05, 0x00
}

local SOURCE_GROUND_BASELINE = {
    0x0C, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xA6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x80, 0x3F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x12, 0x00, 0x05, 0x00
}

local SOURCE_AIR_BASELINE = {
    0x26, 0x00, 0xFF, 0x00, 0x01, 0x00, 0x00, 0x00,
    0xC0, 0x00, 0x04, 0x00, 0x00, 0x00, 0x60, 0x41,
    0x00, 0x00, 0xE4, 0x42, 0x00, 0x00, 0x60, 0x41,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x41,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x80, 0x3F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5C, 0x42,
    0x63, 0x00, 0x05, 0x00
}

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

function WriteByte(address, value)
    writes[#writes + 1] = {
        address = address,
        value = value & 0xFF,
        width = 1
    }
    SetByte(address, value)
end

function WriteShort(address, value)
    writes[#writes + 1] = {
        address = address,
        value = value & 0xFFFF,
        width = 2
    }
    SetShort(address, value)
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

local function CloneBytes(source)
    local result = {}

    for index = 1, #source do
        result[index] = source[index]
    end

    return result
end

local function RecordAddress(record)
    return BASE_GROUP + 0x04 + record * 0x44
end

local function SetRecord(record, bytes)
    local address = RecordAddress(record)

    for index = 1, #bytes do
        SetByte(address + index - 1, bytes[index])
    end
end

local function RecordEquals(record, bytes)
    local address = RecordAddress(record)

    for index = 1, #bytes do
        if ReadByte(address + index - 1) ~= bytes[index] then
            return false
        end
    end

    return true
end

local function BuildShadow(source)
    local result = CloneBytes(source)
    result[0x01 + 1] = 3

    for offset = 0x30, 0x37 do
        result[offset + 1] = 0
    end

    result[0x38 + 1] = 0x1C
    result[0x39 + 1] = 0xEB
    result[0x3A + 1] = 0x92
    result[0x3B + 1] = 0x40
    result[0x40 + 1] = 0
    result[0x41 + 1] = 0
    result[0x42 + 1] = 0
    result[0x43 + 1] = 0
    return result
end

local function SetInput(value)
    SetInt(INPUT, value)
end

local function SetMotion(motion, slot)
    SetInt(SORA + 0x0180, motion)
    SetInt(SORA + 0x0184, slot)
end

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

-- Simula contemporaneamente un residuo V3 sui carrier e un residuo V2 sui
-- source: _OnInit deve riconoscere e ripristinare entrambi.
SetRecord(0, BuildShadow(SOURCE_GROUND_BASELINE))
SetRecord(1, BuildShadow(SOURCE_AIR_BASELINE))
SetRecord(31, GUARD_BASELINE)
SetRecord(32, SOURCE_GROUND_BASELINE)
SetRecord(34, SOURCE_AIR_BASELINE)
SetByte(RecordAddress(32) + 0x01, 3)
SetByte(RecordAddress(34) + 0x01, 3)
SetShort(RecordAddress(32) + 0x40, 0)
SetShort(RecordAddress(34) + 0x40, 0)

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

dofile("experiments/KH2JokCombat_TargetlessTypeExperiment.lua")
_OnInit()
assert(HasMessage("EXPERIMENTAL WRITE V3"))
assert(HasMessage("RECOVER V1/V2 eligibility residue"))
assert(HasMessage("RECOVER V3 shadow residue"))
assert(HasMessage("PTYA V3 verificata"))
assert(RecordEquals(0, SHADOW_GROUND_BASELINE))
assert(RecordEquals(1, SHADOW_AIR_BASELINE))
assert(ReadByte(RecordAddress(32) + 0x01) == 0)
assert(ReadByte(RecordAddress(34) + 0x01) == 0)
assert(ReadShort(RecordAddress(32) + 0x40) == 0x12)
assert(ReadShort(RecordAddress(34) + 0x40) == 0x63)
_OnFrame()

-- Il primo A non arma durante l'hold: i carrier restano vanilla finché A non
-- viene rilasciato, poi diventano copie complete dei selector Square.
SetMotion(0x0097, 0x025C)
SetInput(0x08000004)
_OnFrame()
assert(RecordEquals(0, SHADOW_GROUND_BASELINE))
assert(RecordEquals(1, SHADOW_AIR_BASELINE))
SetInput(0)
_OnFrame()
local expectedGroundShadow = BuildShadow(SOURCE_GROUND_BASELINE)
local expectedAirShadow = BuildShadow(SOURCE_AIR_BASELINE)
assert(RecordEquals(0, expectedGroundShadow))
assert(RecordEquals(1, expectedAirShadow))
assert(ReadByte(RecordAddress(0) + 0x00) == 12)
assert(ReadByte(RecordAddress(1) + 0x00) == 38)
assert(ReadByte(RecordAddress(0) + 0x01) == 3)
assert(ReadByte(RecordAddress(1) + 0x01) == 3)
assert(ReadShort(RecordAddress(0) + 0x40) == 0)
assert(ReadShort(RecordAddress(1) + 0x40) == 0)
assert(ReadShort(RecordAddress(0) + 0x42) == 0)
assert(ReadShort(RecordAddress(1) + 0x42) == 0)

SetInput(0x04000200)
_OnFrame()
assert(HasMessage("TRIAL #001 V3 Square shadow"))
SetInput(0)
SetMotion(166, 0x0284)
_OnFrame()
assert(HasMessage("RESULT #001 ACCEPTED V3"))
assert(RecordEquals(0, SHADOW_GROUND_BASELINE))
assert(RecordEquals(1, SHADOW_AIR_BASELINE))

-- Regressione AA: un nuovo edge A ripristina i carrier prima del rearm; solo
-- dopo il rilascio viene copiato il nuovo MotionId preparato da NormalCombo.
SetInput(0x08000004)
_OnFrame()
SetInput(0)
_OnFrame()
assert(ReadByte(RecordAddress(0) + 0x01) == 3)
SetInput(0x08000004)
_OnFrame()
assert(HasMessage("RESTORE V3 shadow carrier reason=A_EDGE_BEFORE_REARM"))
assert(RecordEquals(0, SHADOW_GROUND_BASELINE))
assert(RecordEquals(1, SHADOW_AIR_BASELINE))
SetShort(RecordAddress(32) + 0x08, 162)
SetInput(0)
_OnFrame()
assert(ReadShort(RecordAddress(0) + 0x08) == 162)
assert(ReadByte(RecordAddress(0) + 0x01) == 3)

-- Reaction/UI priority disarma sempre il profilo completo.
SetShort(REACT, 0x001E)
_OnFrame()
assert(HasMessage("RESTORE V3 shadow carrier reason=CONTEXT"))
assert(RecordEquals(0, SHADOW_GROUND_BASELINE))
assert(RecordEquals(1, SHADOW_AIR_BASELINE))
assert(RecordEquals(31, GUARD_BASELINE))

-- Se uno shadow carrier parte senza edge Square, il candidato si auto-respinge
-- e ripristina entrambi i record invece di continuare a contaminare la catena A.
SetShort(REACT, 0)
SetMotion(0, 0)
SetInput(0)
_OnFrame()
SetMotion(151, 0x025C)
SetInput(0x08000004)
_OnFrame()
SetInput(0)
_OnFrame()
assert(ReadByte(RecordAddress(0) + 0x01) == 3)
SetMotion(162, 0x02A0)
_OnFrame()
assert(HasMessage("CANDIDATO V3 RESPINTO"))
assert(HasMessage("RESTORE V3 shadow carrier reason=HIJACK_BEFORE_SQUARE"))
assert(RecordEquals(0, SHADOW_GROUND_BASELINE))
assert(RecordEquals(1, SHADOW_AIR_BASELINE))

for _, write in ipairs(writes) do
    local inShadowGround = write.address >= RecordAddress(0)
        and write.address < RecordAddress(0) + 0x44
    local inShadowAir = write.address >= RecordAddress(1)
        and write.address < RecordAddress(1) + 0x44
    local legacyGround = write.address == RecordAddress(32) + 0x01
        or write.address == RecordAddress(32) + 0x40
    local legacyAir = write.address == RecordAddress(34) + 0x01
        or write.address == RecordAddress(34) + 0x40

    assert(
        inShadowGround or inShadowAir or legacyGround or legacyAir,
        string.format("unexpected write address 0x%X", write.address)
    )
end

print("OK KH2JokCombat_TargetlessTypeExperiment V3 smoke test (shadow carrier + full rollback)")
