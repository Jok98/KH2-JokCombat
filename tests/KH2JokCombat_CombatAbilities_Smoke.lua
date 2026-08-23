local SAVE = 0x100000
local SLOT1 = 0x200000
local NOW = 0x300000
local memory = {}
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

function WriteShort(address, value)
    memory[address] = value
    writeCount = writeCount + 1
end

function ConsolePrint()
end

function RequireKH2LibraryVersion()
end

function RequirePCGameVersion()
end

package.preload.kh2lib = function()
    return {
        Save = SAVE,
        Slot1 = SLOT1,
        Now = NOW,
        CanExecute = true
    }
end

local ACTIVE_ACTIONS = {
    0x0052, 0x0089, 0x010F, 0x010B, 0x0111,
    0x0106, 0x0107, 0x022F, 0x0108, 0x0232,
    0x0109, 0x010A, 0x010D, 0x0230, 0x010E,
    0x0110, 0x0231, 0x010C, 0x00C6
}

local DISABLED_AUTOS = {
    0x0181, 0x0182, 0x0238, 0x0183, 0x0184, 0x0185
}

local COMBO_TARGETS = {
    [0x021B] = 1,
    [0x00A2] = 2,
    [0x00A3] = 2
}

local function CountPresent(targetId)
    local count = 0

    for slot = 0, 68 do
        local value = ReadShort(SAVE + 0x2544 + (slot * 2))

        if (value & 0x0FFF) == targetId then
            count = count + 1
        end
    end

    return count
end

local function CountEquipped(targetId)
    local count = 0

    for slot = 0, 68 do
        local value = ReadShort(SAVE + 0x2544 + (slot * 2))

        if (value & 0x0FFF) == targetId
            and (value & 0x8000) ~= 0 then

            count = count + 1
        end
    end

    return count
end

local function SetReadySora()
    memory[NOW + 0x00] = 0x02
    memory[NOW + 0x01] = 0x00
    memory[SLOT1 + 0x004] = 20
    memory[SAVE + 0x1CEA] = 0x01
end

SetReadySora()

-- Exercise reuse, activation, Auto deactivation, missing copies and preservation.
memory[SAVE + 0x2544] = 0x0052
memory[SAVE + 0x2546] = 0x8181
memory[SAVE + 0x2548] = 0x8238
memory[SAVE + 0x254A] = 0x80A2
memory[SAVE + 0x254C] = 0x80A3
memory[SAVE + 0x2544 + (68 * 2)] = 0x8ABC

dofile("runtime/KH2JokCombat_ComboMaster.lua")
_OnInit()
_OnFrame()

for _, targetId in ipairs(ACTIVE_ACTIONS) do
    assert(
        CountEquipped(targetId) >= 1,
        string.format("Action 0x%04X not equipped", targetId)
    )
end

for _, targetId in ipairs(DISABLED_AUTOS) do
    assert(
        CountPresent(targetId) >= 1,
        string.format("Auto 0x%04X missing", targetId)
    )
    assert(
        CountEquipped(targetId) == 0,
        string.format("Auto 0x%04X still equipped", targetId)
    )
end

for targetId, targetCount in pairs(COMBO_TARGETS) do
    assert(
        CountEquipped(targetId) >= targetCount,
        string.format("Combo support 0x%04X below target", targetId)
    )
end

assert(
    memory[SAVE + 0x2544 + (68 * 2)] == 0x8ABC,
    "unrelated standard ability was overwritten"
)

local writesAfterFirstFrame = writeCount
_OnFrame()
assert(writeCount == writesAfterFirstFrame, "second frame was not idempotent")

-- A real load passes through a not-ready frame, which must re-arm the module.
memory[NOW + 0x00] = 0xFF
_OnFrame()
memory[NOW + 0x00] = 0x02
memory[SAVE + 0x2544] = 0x0052
memory[SAVE + 0x2546] = 0x8181

local writesBeforeRepair = writeCount
_OnFrame()
assert(memory[SAVE + 0x2544] == 0x8052, "active Action was not repaired")
assert(memory[SAVE + 0x2546] == 0x0181, "Auto Action was not disabled again")
assert(writeCount == writesBeforeRepair + 2, "load repair touched extra slots")

local successfulWriteCount = writeCount

-- A full foreign table must fail during capacity inspection, before any write.
memory = {}
writeCount = 0
SetReadySora()

for slot = 0, 68 do
    memory[SAVE + 0x2544 + (slot * 2)] = 0x8ABC
end

_OnInit()
_OnFrame()

assert(writeCount == 0, "capacity failure performed partial writes")
assert(memory[SAVE + 0x2544] == 0x8ABC, "capacity failure changed the table")

print(string.format(
    "OK KH2JokCombat_CombatAbilities smoke test (%d verified writes + fail-closed case)",
    successfulWriteCount
))
