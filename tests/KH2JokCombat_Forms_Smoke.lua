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

function WriteByte(address, value)
    memory[address] = value
    writeCount = writeCount + 1
end

function WriteShort(address, value)
    memory[address] = value
    writeCount = writeCount + 1
end

function WriteInt(address, value)
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

local EXPECTED_FORMS = {
    {
        name = "Valor",
        blockOffset = 0x32F4,
        growthMaxId = 0x0061,
        innate = {
            0x00D8, 0x00D9, 0x00DA, 0x00DB, 0x00F6,
            0x00F7, 0x0111, 0x00DF, 0x00A2, 0x00A3
        }
    },
    {
        name = "Wisdom",
        blockOffset = 0x332C,
        growthMaxId = 0x0065,
        innate = {
            0x00DC, 0x00DD, 0x00E0, 0x00E1, 0x0111,
            0x01A6, 0x01A6
        }
    },
    {
        name = "Limit",
        blockOffset = 0x3364,
        growthMaxId = 0x0237,
        innate = {
            0x0239, 0x023A, 0x023B, 0x023C, 0x023D, 0x023E,
            0x023F, 0x024B, 0x024C, 0x024D, 0x0052, 0x0106,
            0x0108, 0x010D, 0x019C, 0x0195, 0x0197, 0x019D
        }
    },
    {
        name = "Master",
        blockOffset = 0x339C,
        growthMaxId = 0x0069,
        innate = {
            0x0101, 0x0102, 0x0105, 0x00DF, 0x0103,
            0x01A5, 0x00A3, 0x00A3, 0x0195, 0x0195
        }
    },
    {
        name = "Final",
        blockOffset = 0x33D4,
        growthMaxId = 0x006D,
        innate = {
            0x0207, 0x00DD, 0x00DF, 0x020F,
            0x0210, 0x0211, 0x0212, 0x019D
        }
    }
}

local EXPECTED_ACTIVE_REWARDS = {
    0x00A2, 0x00A2, 0x019C, 0x019D, 0x0195,
    0x0197, 0x00A3, 0x00A3, 0x018E, 0x018E
}

local EXPECTED_DISABLED_AUTOS = {
    0x0181, 0x0182, 0x0238, 0x0183, 0x0184
}

local function CountPresent(address, slotCount, targetId)
    local count = 0

    for slot = 0, slotCount - 1 do
        local value = ReadShort(address + (slot * 2))

        if (value & 0x0FFF) == targetId then
            count = count + 1
        end
    end

    return count
end

local function CountEquipped(address, slotCount, targetId)
    local count = 0

    for slot = 0, slotCount - 1 do
        local value = ReadShort(address + (slot * 2))

        if (value & 0x0FFF) == targetId
            and (value & 0x8000) ~= 0 then

            count = count + 1
        end
    end

    return count
end

local function CountTargets(targets)
    local counts = {}

    for _, targetId in ipairs(targets) do
        counts[targetId] = (counts[targetId] or 0) + 1
    end

    return counts
end

-- Ready base-Sora state with unrelated inventory/ability values that must be
-- preserved. Form records intentionally begin empty to exercise full native
-- ability initialization, not only the already-initialized vanilla path.
memory[NOW + 0x00] = 0x02
memory[NOW + 0x01] = 0x00
memory[SLOT1 + 0x004] = 20
memory[SAVE + 0x1CEA] = 0x01
memory[SAVE + 0x3524] = 0x00
memory[SAVE + 0x36C0] = 0x80
memory[SAVE + 0x36CA] = 0x10
memory[SAVE + 0x3529] = 3
memory[SAVE + 0x352A] = 3
memory[SAVE + 0x24F8] = 7
memory[SLOT1 + 0x18E] = 2
memory[SLOT1 + 0x1B0] = 25
memory[SLOT1 + 0x1B1] = 3
memory[SLOT1 + 0x1B2] = 3

memory[SAVE + 0x2544] = 0x821B
memory[SAVE + 0x2546] = 0x80A2
memory[SAVE + 0x2548] = 0x80A2
memory[SAVE + 0x254A] = 0x80A3
memory[SAVE + 0x254C] = 0x80A3
memory[SAVE + 0x254E] = 0x8181
memory[SAVE + 0x2550] = 0x8182
memory[SAVE + 0x2552] = 0x8238
memory[SAVE + 0x2554] = 0x8183
memory[SAVE + 0x2556] = 0x8184
memory[SAVE + 0x2544 + (68 * 2)] = 0x8ABC

for _, form in ipairs(EXPECTED_FORMS) do
    memory[SAVE + form.blockOffset + 0x08 + (23 * 2)] = 0x8ABC
end

-- Final Mix DriveForms[5] is Summon, not Anti. Its record must be untouched.
memory[SAVE + 0x340C + 0x02] = 6
memory[SAVE + 0x340C + 0x08] = 0x8ABC

dofile("runtime/KH2JokCombat_Forms.lua")
_OnInit()
_OnFrame()

assert(memory[SAVE + 0x36C0] == 0xF6, "ItemSet1 bits not merged")
assert(memory[SAVE + 0x36CA] == 0x18, "ItemSet11 bits not merged")
assert(memory[SAVE + 0x3529] == 9, "save Drive current not full")
assert(memory[SAVE + 0x352A] == 9, "save Drive max not full")
assert(memory[SLOT1 + 0x1B0] == 100, "live Drive percent not full")
assert(memory[SLOT1 + 0x1B1] == 9, "live Drive current not full")
assert(memory[SLOT1 + 0x1B2] == 9, "live Drive max not full")
assert(memory[SLOT1 + 0x18E] == 255, "live Sora AP not maxed")
assert(memory[SAVE + 0x24F8] == 7, "persistent AP Boost count was modified")
assert(memory[SAVE + 0x2544] == 0x821B, "Combo Master was modified")
assert(memory[SAVE + 0x2544 + (68 * 2)] == 0x8ABC, "standard extra was overwritten")
assert(memory[SAVE + 0x340C + 0x02] == 6, "Summon level was overwritten")
assert(memory[SAVE + 0x340C + 0x08] == 0x8ABC, "Summon abilities were overwritten")

for _, form in ipairs(EXPECTED_FORMS) do
    local abilityAddress = SAVE + form.blockOffset + 0x08

    if form.growthMaxId ~= nil then
        assert(ReadByte(SAVE + form.blockOffset + 0x02) == 7, form.name .. " Level")
        assert(ReadByte(SAVE + form.blockOffset + 0x03) == 4, form.name .. " AbilityLevel")
        assert(ReadInt(SAVE + form.blockOffset + 0x04) == 0, form.name .. " EXP")
        assert(ReadShort(abilityAddress) == (form.growthMaxId | 0x8000), form.name .. " growth")
    end

    for targetId, targetCount in pairs(CountTargets(form.innate)) do
        assert(
            CountEquipped(abilityAddress, 24, targetId) >= targetCount,
            string.format("%s innate 0x%04X", form.name, targetId)
        )
    end

    assert(
        memory[abilityAddress + (23 * 2)] == 0x8ABC,
        form.name .. " extra was overwritten"
    )
end

local standardAddress = SAVE + 0x2544

for targetId, targetCount in pairs(CountTargets(EXPECTED_ACTIVE_REWARDS)) do
    assert(
        CountEquipped(standardAddress, 69, targetId) >= targetCount,
        string.format("standard reward 0x%04X", targetId)
    )
end

for _, targetId in ipairs(EXPECTED_DISABLED_AUTOS) do
    assert(
        CountPresent(standardAddress, 69, targetId) >= 1,
        string.format("Auto reward 0x%04X missing", targetId)
    )
    assert(
        CountEquipped(standardAddress, 69, targetId) == 0,
        string.format("Auto reward 0x%04X still equipped", targetId)
    )
end

local writesAfterFirstFrame = writeCount
_OnFrame()
assert(writeCount == writesAfterFirstFrame, "second frame was not idempotent")

-- Slot1 is rebuilt across loads; the completed module must restore AP without
-- replaying the persistent Form patch.
memory[SLOT1 + 0x18E] = 50
local writesBeforeApRepair = writeCount
_OnFrame()
assert(memory[SLOT1 + 0x18E] == 255, "live Sora AP was not restored")
assert(writeCount == writesBeforeApRepair + 1, "AP repair changed extra fields")

local writesAfterApRepair = writeCount
_OnFrame()
assert(writeCount == writesAfterApRepair, "AP repair was not idempotent")

local successfulWriteCount = writeCount

-- A foreign value in the canonical growth slot must abort during inspection,
-- before even the inventory unlock plan is written.
memory = {}
writeCount = 0
memory[NOW + 0x00] = 0x02
memory[NOW + 0x01] = 0x00
memory[SLOT1 + 0x004] = 20
memory[SLOT1 + 0x18E] = 2
memory[SAVE + 0x1CEA] = 0x01
memory[SAVE + 0x36C0] = 0x80
memory[SAVE + 0x32F4 + 0x08] = 0x8ABC

_OnInit()
_OnFrame()

assert(writeCount == 0, "fail-closed inspection performed partial writes")
assert(memory[SAVE + 0x36C0] == 0x80, "fail-closed inspection changed inventory")

print(string.format(
    "OK KH2JokCombat_Forms smoke test (%d verified writes + fail-closed case)",
    successfulWriteCount
))
