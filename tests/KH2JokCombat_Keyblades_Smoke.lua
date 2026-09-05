local SAVE = 0x100000
local SLOT1 = 0x200000
local NOW = 0x300000
local memory = {}
local writeCount = 0
local writeAttempts = 0
local failedWriteAddress = nil
local throwAfterWriteAddress = nil
local foreignAfterWriteAddress = nil
local messages = {}

local TARGETS = {
    { name = "Kingdom Key", id = 0x0029, offset = 0x35A1 },
    { name = "Oathkeeper", id = 0x002A, offset = 0x35A2 },
    { name = "Oblivion", id = 0x002B, offset = 0x35A3 },
    { name = "Star Seeker", id = 0x01E0, offset = 0x367B },
    { name = "Hidden Dragon", id = 0x01E1, offset = 0x367C },
    { name = "Hero's Crest", id = 0x01E4, offset = 0x367F },
    { name = "Monochrome", id = 0x01E5, offset = 0x3680 },
    { name = "Follow the Wind", id = 0x01E6, offset = 0x3681 },
    { name = "Circle of Life", id = 0x01E7, offset = 0x3682 },
    { name = "Photon Debugger", id = 0x01E8, offset = 0x3683 },
    { name = "Gull Wing", id = 0x01E9, offset = 0x3684 },
    { name = "Rumbling Rose", id = 0x01EA, offset = 0x3685 },
    { name = "Guardian Soul", id = 0x01EB, offset = 0x3686 },
    { name = "Wishing Lamp", id = 0x01EC, offset = 0x3687 },
    { name = "Decisive Pumpkin", id = 0x01ED, offset = 0x3688 },
    { name = "Sleeping Lion", id = 0x01EE, offset = 0x3689 },
    { name = "Sweet Memories", id = 0x01EF, offset = 0x368A },
    { name = "Mysterious Abyss", id = 0x01F0, offset = 0x368B },
    { name = "Fatal Crest", id = 0x01F1, offset = 0x368C },
    { name = "Bond of Flame", id = 0x01F2, offset = 0x368D },
    { name = "Fenrir", id = 0x01F3, offset = 0x368E },
    { name = "Two Become One", id = 0x021F, offset = 0x3698 },
    { name = "Winner's Proof", id = 0x0220, offset = 0x3699 }
}

local WEAPON_SLOTS = {
    0x24F0,
    0x32F4,
    0x332C,
    0x3364,
    0x339C,
    0x33D4
}

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
    writeAttempts = writeAttempts + 1

    if address == failedWriteAddress then
        return
    end

    memory[address] = value
    writeCount = writeCount + 1
    if address == throwAfterWriteAddress then
        throwAfterWriteAddress = nil
        error("simulated exception after writing RAM")
    end
    if address == foreignAfterWriteAddress then
        foreignAfterWriteAddress = nil
        memory[address] = 0x7F
    end
end

function WriteShort(address, value)
    writeAttempts = writeAttempts + 1

    if address == failedWriteAddress then
        return
    end

    memory[address] = value
    writeCount = writeCount + 1
    if address == throwAfterWriteAddress then
        throwAfterWriteAddress = nil
        error("simulated exception after writing RAM")
    end
end

function ConsolePrint(message)
    messages[#messages + 1] = tostring(message)
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

local function IsEquipped(targetId)
    for _, offset in ipairs(WEAPON_SLOTS) do
        if memory[SAVE + offset] == targetId then
            return true
        end
    end

    return false
end

local function AssertAllTargetsAvailable()
    for _, target in ipairs(TARGETS) do
        local count = memory[SAVE + target.offset] or 0

        assert(
            count > 0 or IsEquipped(target.id),
            target.name .. " was not unlocked"
        )
    end
end

memory[NOW + 0x00] = 0x02
memory[NOW + 0x01] = 0x00
memory[SLOT1 + 0x004] = 20
memory[SAVE + 0x1CEA] = 0x01

-- Equipped Keyblades count as owned and must not be duplicated in stock.
-- Master and Final start empty, reproducing the early-unlock crash state.
memory[SAVE + 0x24F0] = 0x0029
memory[SAVE + 0x32F4] = 0x01EE
memory[SAVE + 0x332C] = 0x0047
memory[SAVE + 0x35A2] = 2
memory[SAVE + 0x35A3] = 1
memory[SAVE + 0x368D] = 1
memory[SAVE + 0x368F] = 4

local weaponBefore = {}

for _, offset in ipairs(WEAPON_SLOTS) do
    weaponBefore[offset] = memory[SAVE + offset] or 0
end

local Logger = require("runtime.KH2JokCombat_Log")
Logger.SetEnabled("PROGRESSION", true)

dofile("runtime/KH2JokCombat_Keyblades.lua")
_OnInit()
_OnFrame()

AssertAllTargetsAvailable()
assert(memory[SAVE + 0x35A1] == nil, "equipped Kingdom Key was duplicated")
assert(memory[SAVE + 0x35A2] == 2, "existing Oathkeeper count was overwritten")
assert(memory[SAVE + 0x3689] == nil, "equipped Sleeping Lion was duplicated")
assert(memory[SAVE + 0x339C] == 0x01F2, "Master did not receive Bond of Flame")
assert(memory[SAVE + 0x33D4] == 0x002B, "Final did not receive Oblivion")
assert(memory[SAVE + 0x368D] == 0, "Master did not consume Bond of Flame stock")
assert(memory[SAVE + 0x35A3] == 0, "Final did not consume Oblivion stock")
assert(memory[SAVE + 0x368F] == 4, "Ultima Weapon inventory was modified")
assert(writeCount == 22, "unexpected first-frame write count")

for _, offset in ipairs({ 0x24F0, 0x32F4, 0x332C, 0x3364 }) do
    assert(
        (memory[SAVE + offset] or 0) == weaponBefore[offset],
        "non-default weapon slot was modified"
    )
end

local writesAfterFirstFrame = writeCount
_OnFrame()
assert(writeCount == writesAfterFirstFrame, "second frame was not idempotent")

-- Loading re-arms the module and repairs a newly missing unequipped target.
memory[SAVE + 0x367B] = 0
memory[NOW + 0x00] = 0xFF
_OnFrame()
memory[NOW + 0x00] = 0x02
_OnFrame()
assert(memory[SAVE + 0x367B] == 1, "load repair did not restore Star Seeker")
assert(writeCount == writesAfterFirstFrame + 1, "load repair wrote unexpected data")

-- Non-empty Master/Final slots are player choices and must be preserved.
memory[SAVE + 0x339C] = 0x002A
memory[SAVE + 0x33D4] = 0x01F3
memory[SAVE + 0x35A2] = 1
memory[SAVE + 0x368E] = 0
memory[SAVE + 0x368D] = 1
memory[SAVE + 0x35A3] = 1
memory[NOW + 0x00] = 0xFF
_OnFrame()
memory[NOW + 0x00] = 0x02
local writesBeforeManualPreservation = writeCount
_OnFrame()
assert(memory[SAVE + 0x339C] == 0x002A, "Master player choice was overwritten")
assert(memory[SAVE + 0x33D4] == 0x01F3, "Final player choice was overwritten")
assert(writeCount == writesBeforeManualPreservation, "preserving player choices wrote data")

-- A later empty Master slot is repaired on F1 and consumes one stock copy.
memory[SAVE + 0x339C] = 0
memory[SAVE + 0x35A2] = 2
_OnInit()
local writesBeforeMasterRepair = writeCount
_OnFrame()
assert(memory[SAVE + 0x339C] == 0x01F2, "F1 did not restore Master default")
assert(memory[SAVE + 0x368D] == 0, "Master repair did not consume Bond of Flame")
assert(writeCount == writesBeforeMasterRepair + 2, "Master repair wrote unexpected data")

-- Roxas identity must block every inventory write.
memory[SAVE + 0x367C] = 0
memory[SAVE + 0x1CEA] = 0x00
_OnInit()
local attemptsBeforeRoxas = writeAttempts
_OnFrame()
assert(writeAttempts == attemptsBeforeRoxas, "Roxas state received a Keyblade write")
assert(memory[SAVE + 0x367C] == 0, "Roxas guard changed Hidden Dragon")

-- A failed verification disables the module until F1 and preserves Ultima.
memory[SAVE + 0x1CEA] = 0x01
failedWriteAddress = SAVE + 0x367C
_OnInit()
_OnFrame()
assert(memory[SAVE + 0x367C] == 0, "failed write unexpectedly succeeded")
assert(memory[SAVE + 0x368F] == 4, "failure path changed Ultima Weapon")

local attemptsAfterFailure = writeAttempts
failedWriteAddress = nil
_OnFrame()
assert(writeAttempts == attemptsAfterFailure, "disabled module retried before F1")

_OnInit()
_OnFrame()
assert(memory[SAVE + 0x367C] == 1, "F1 did not re-enable repair")
AssertAllTargetsAvailable()

local successfulWriteCount = writeCount

-- Never duplicate a default Keyblade already equipped elsewhere when no
-- stock copy exists: reject the whole plan before its first write.
memory = {}
writeCount = 0
writeAttempts = 0
failedWriteAddress = nil
memory[NOW + 0x00] = 0x02
memory[NOW + 0x01] = 0x00
memory[SLOT1 + 0x004] = 20
memory[SAVE + 0x1CEA] = 0x01
memory[SAVE + 0x32F4] = 0x01F2
memory[SAVE + 0x35A3] = 1

_OnInit()
_OnFrame()
assert(writeCount == 0, "duplicate-default conflict performed partial writes")
assert(memory[SAVE + 0x339C] == nil, "duplicate-default conflict changed Master")
assert(memory[SAVE + 0x32F4] == 0x01F2, "duplicate-default conflict changed Valor")

local function SeedTransferCase()
    memory = {}
    writeCount = 0
    writeAttempts = 0
    messages = {}
    failedWriteAddress = nil
    throwAfterWriteAddress = nil
    foreignAfterWriteAddress = nil
    memory[NOW] = 0x02
    memory[NOW + 1] = 0
    memory[SLOT1 + 4] = 20
    memory[SAVE + 0x1CEA] = 1
    memory[SAVE + 0x368F] = 4
    for _, target in ipairs(TARGETS) do
        memory[SAVE + target.offset] = 1
    end
    _OnInit()
end

local function AssertTransferRolledBack()
    assert(ReadShort(SAVE + 0x339C) == 0, "failed transfer left Master equipped")
    assert(ReadShort(SAVE + 0x33D4) == 0, "failed transfer left Final equipped")
    for _, target in ipairs(TARGETS) do
        assert(ReadByte(SAVE + target.offset) == 1,
            "rollback changed stock: " .. target.name)
    end
    assert(ReadByte(SAVE + 0x368F) == 4, "rollback touched Ultima")
end

-- Fail each of the four transfer writes, including failures after both slots
-- have been equipped. Retry after F1 must transfer exactly one copy per slot.
for _, offset in ipairs({ 0x339C, 0x33D4, 0x35A3, 0x368D }) do
    SeedTransferCase()
    failedWriteAddress = SAVE + offset
    _OnFrame()
    AssertTransferRolledBack()
    local attemptsBeforeDisabledFrame = writeAttempts
    failedWriteAddress = nil
    _OnFrame()
    assert(writeAttempts == attemptsBeforeDisabledFrame, "failure retried before F1")
    _OnInit()
    _OnFrame()
    assert(ReadShort(SAVE + 0x339C) == 0x01F2)
    assert(ReadShort(SAVE + 0x33D4) == 0x002B)
    assert(ReadByte(SAVE + 0x368D) == 0, "reload duplicated Bond of Flame")
    assert(ReadByte(SAVE + 0x35A3) == 0, "reload duplicated Oblivion")
end

-- A backend may throw after performing the write: the attempted operation
-- must already be in the journal so its side effect is restored as well.
for _, offset in ipairs({ 0x33D4, 0x368D }) do
    SeedTransferCase()
    throwAfterWriteAddress = SAVE + offset
    _OnFrame()
    AssertTransferRolledBack()
end

-- Rollback owns only before/desired values and must preserve foreign changes.
SeedTransferCase()
foreignAfterWriteAddress = SAVE + 0x35A3
_OnFrame()
assert(ReadByte(SAVE + 0x35A3) == 0x7F, "rollback overwrote foreign stock")
assert(ReadShort(SAVE + 0x339C) == 0)
assert(ReadShort(SAVE + 0x33D4) == 0)
assert(ReadByte(SAVE + 0x368D) == 1)
assert(string.find(table.concat(messages, "\n"), "rollback incompleto", 1, true),
    "incomplete rollback was not reported")

print(string.format(
    "OK KH2JokCombat_Keyblades smoke test (23 targets, %d verified writes + transaction rollback/guards)",
    successfulWriteCount
))
