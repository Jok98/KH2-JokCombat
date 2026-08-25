local SAVE = 0x100000
local NOW = 0x200000
local memory = {}
local writeCount = 0
local writeAttempts = 0
local failedWriteAddress = nil

local COST_OFFSET = 0x10F0A
local TARGET_LEVEL = 0x06

local function Read(address)
    return memory[address] or 0
end

function ReadByte(address)
    return Read(address)
end

function WriteByte(address, value)
    writeAttempts = writeAttempts + 1

    if address == failedWriteAddress then
        return
    end

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
        Now = NOW,
        CanExecute = true
    }
end

local function SetReadySora()
    memory[NOW + 0x00] = 0x02
    memory[NOW + 0x01] = 0x00
    memory[SAVE + 0x1CEA] = 0x01
end

SetReadySora()
memory[SAVE + COST_OFFSET] = 0x00

dofile("runtime/KH2JokCombat_GummiCost.lua")
_OnInit()
_OnFrame()

assert(memory[SAVE + COST_OFFSET] == TARGET_LEVEL, "initial limit was not raised to level 6")
assert(writeCount == 1, "initial patch performed an unexpected number of writes")

local writesAfterFirstFrame = writeCount
_OnFrame()
assert(writeCount == writesAfterFirstFrame, "second frame was not idempotent")

-- A later vanilla progression write must be repaired without requiring F1.
memory[SAVE + COST_OFFSET] = 0x02
_OnFrame()
assert(memory[SAVE + COST_OFFSET] == TARGET_LEVEL, "vanilla downgrade was not repaired")
assert(writeCount == writesAfterFirstFrame + 1, "downgrade repair wrote unexpected data")

-- Loading re-arms reporting and a different Sora save is patched safely.
memory[NOW + 0x00] = 0xFF
memory[SAVE + COST_OFFSET] = 0x01
local attemptsBeforeLoading = writeAttempts
_OnFrame()
assert(writeAttempts == attemptsBeforeLoading, "loading state received a write")

memory[NOW + 0x00] = 0x02
_OnFrame()
assert(memory[SAVE + COST_OFFSET] == TARGET_LEVEL, "new Sora save was not patched")

-- Roxas identity must block every write.
memory[SAVE + COST_OFFSET] = 0x00
memory[SAVE + 0x1CEA] = 0x00
_OnInit()
local attemptsBeforeRoxas = writeAttempts
_OnFrame()
assert(writeAttempts == attemptsBeforeRoxas, "Roxas state received a Gummi write")
assert(memory[SAVE + COST_OFFSET] == 0x00, "Roxas guard changed the limit")

-- Unknown values above the safe documented range are preserved fail-closed.
SetReadySora()
memory[SAVE + COST_OFFSET] = 0x07
_OnInit()
local attemptsBeforeForeignValue = writeAttempts
_OnFrame()
assert(writeAttempts == attemptsBeforeForeignValue, "foreign value received a write")
assert(memory[SAVE + COST_OFFSET] == 0x07, "foreign value was overwritten")

memory[SAVE + COST_OFFSET] = 0x00
_OnFrame()
assert(writeAttempts == attemptsBeforeForeignValue, "disabled module retried before F1")

-- Failed verification disables retries until F1, then a clean reload repairs.
failedWriteAddress = SAVE + COST_OFFSET
_OnInit()
_OnFrame()
assert(memory[SAVE + COST_OFFSET] == 0x00, "failed write unexpectedly succeeded")

local attemptsAfterFailure = writeAttempts
failedWriteAddress = nil
_OnFrame()
assert(writeAttempts == attemptsAfterFailure, "failed module retried before F1")

_OnInit()
_OnFrame()
assert(memory[SAVE + COST_OFFSET] == TARGET_LEVEL, "F1 did not re-enable the patch")

print(string.format(
    "OK KH2JokCombat_GummiCost smoke test (%d verified writes + guards)",
    writeCount
))
