LUAGUI_NAME = "KH2 JokCombat - Sora Combo Core"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Enables Combo Master and every ground/air Combo Plus on Sora"

local kh2lib = nil
local CanExecute = false
local PatchCompleted = false
local PatchDisabled = false
local ErrorReported = false

local SORA_STORY_FLAG_OFFSET = 0x1CEA
local SORA_STORY_FLAG_MASK = 0x01

-- Standard player ability table used by KH2.
-- GoA scans slots 0..68 from Save + 0x2544 in 2-byte steps.
local ABILITY_TABLE_OFFSET = 0x2544
local STANDARD_ABILITY_SLOT_COUNT = 69
local ABILITY_ID_MASK = 0x0FFF
local EQUIPPED_FLAG = 0x8000

-- Native Sora support-ability pool: one Combo Master and two copies of each
-- Combo Plus family. Every existing matching copy is equipped as well, so a
-- modded save with additional copies remains internally consistent.
local COMBO_ABILITIES = {
    {
        name = "Combo Master",
        id = 0x021B,
        targetCount = 1
    },
    {
        name = "Combo Plus",
        id = 0x00A2,
        targetCount = 2
    },
    {
        name = "Air Combo Plus",
        id = 0x00A3,
        targetCount = 2
    }
}

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function IsSoraGameplayReady()
    local world = ReadByte(kh2lib.Now + 0x00)
    local room = ReadByte(kh2lib.Now + 0x01)
    local maxHp = ReadInt(kh2lib.Slot1 + 0x004)
    local storyFlags = ReadByte(kh2lib.Save + SORA_STORY_FLAG_OFFSET)
    local isSora = (storyFlags & SORA_STORY_FLAG_MASK) ~= 0

    return isSora
        and world ~= 0xFF
        and room ~= 0xFF
        and maxHp > 0
end

local function BuildComboPlan()
    local abilityById = {}
    local matchesById = {}
    local freeSlots = {}

    for _, ability in ipairs(COMBO_ABILITIES) do
        abilityById[ability.id] = ability
        matchesById[ability.id] = {}
    end

    for slot = 0, STANDARD_ABILITY_SLOT_COUNT - 1 do
        local address = kh2lib.Save + ABILITY_TABLE_OFFSET + (slot * 2)
        local value = ReadShort(address)

        if value == 0 then
            freeSlots[#freeSlots + 1] = {
                index = slot,
                address = address,
                before = value
            }
        else
            local abilityId = value & ABILITY_ID_MASK

            if abilityById[abilityId] ~= nil then
                matchesById[abilityId][#matchesById[abilityId] + 1] = {
                    index = slot,
                    address = address,
                    before = value
                }
            end
        end
    end

    local missingTotal = 0

    for _, ability in ipairs(COMBO_ABILITIES) do
        local missing = ability.targetCount - #matchesById[ability.id]

        if missing > 0 then
            missingTotal = missingTotal + missing
        end
    end

    if #freeSlots < missingTotal then
        error(string.format(
            "Slot ability insufficienti: servono %d slot liberi, disponibili %d "
            .. "(scansionati 69 slot da Save+0x2544)",
            missingTotal,
            #freeSlots
        ))
    end

    local changes = {}
    local freeIndex = 1

    for _, ability in ipairs(COMBO_ABILITIES) do
        local matches = matchesById[ability.id]

        -- Equip every copy already present, including any extra copy from a
        -- modded save. No duplicate is added until the native target is short.
        for _, match in ipairs(matches) do
            if (match.before & EQUIPPED_FLAG) == 0 then
                changes[#changes + 1] = {
                    ability = ability,
                    index = match.index,
                    address = match.address,
                    before = match.before,
                    desired = match.before | EQUIPPED_FLAG,
                    added = false
                }
            end
        end

        local missing = ability.targetCount - #matches

        for _ = 1, math.max(0, missing) do
            local freeSlot = freeSlots[freeIndex]
            freeIndex = freeIndex + 1

            changes[#changes + 1] = {
                ability = ability,
                index = freeSlot.index,
                address = freeSlot.address,
                before = freeSlot.before,
                desired = ability.id | EQUIPPED_FLAG,
                added = true
            }
        end
    end

    return changes
end

local function VerifyComboCore()
    local equippedCounts = {}

    for _, ability in ipairs(COMBO_ABILITIES) do
        equippedCounts[ability.id] = 0
    end

    for slot = 0, STANDARD_ABILITY_SLOT_COUNT - 1 do
        local address = kh2lib.Save + ABILITY_TABLE_OFFSET + (slot * 2)
        local value = ReadShort(address)
        local abilityId = value & ABILITY_ID_MASK

        if equippedCounts[abilityId] ~= nil
            and (value & EQUIPPED_FLAG) ~= 0 then

            equippedCounts[abilityId] = equippedCounts[abilityId] + 1
        end
    end

    for _, ability in ipairs(COMBO_ABILITIES) do
        if equippedCounts[ability.id] < ability.targetCount then
            error(string.format(
                "Verifica %s fallita: %d equipaggiate, attese almeno %d",
                ability.name,
                equippedCounts[ability.id],
                ability.targetCount
            ))
        end
    end

    return equippedCounts
end

local function EnableSoraComboCore()
    -- Capacity and all current values are inspected before the first write.
    local changes = BuildComboPlan()

    for _, change in ipairs(changes) do
        local current = ReadShort(change.address)

        if current ~= change.before then
            error(string.format(
                "%s slot %d cambiato durante la preparazione: %s -> %s",
                change.ability.name,
                change.index,
                Hex(change.before, 4),
                Hex(current, 4)
            ))
        end

        WriteShort(change.address, change.desired)

        local after = ReadShort(change.address)

        if (after & ABILITY_ID_MASK) ~= change.ability.id
            or (after & EQUIPPED_FLAG) == 0 then

            error(string.format(
                "Verifica %s slot %d fallita: %s",
                change.ability.name,
                change.index,
                Hex(after, 4)
            ))
        end

        ConsolePrint(string.format(
            "%s %s ed equipaggiato: slot=%d %s -> %s",
            change.ability.name,
            change.added and "aggiunto" or "trovato",
            change.index,
            Hex(change.before, 4),
            Hex(after, 4)
        ), 1)
    end

    local equippedCounts = VerifyComboCore()

    ConsolePrint(string.format(
        "Sora Combo Core pronto: Combo Master x%d, Combo Plus x%d, Air Combo Plus x%d equipaggiati (%d aggiornamenti).",
        equippedCounts[0x021B],
        equippedCounts[0x00A2],
        equippedCounts[0x00A3],
        #changes
    ), 1)

    ConsolePrint(
        "Nota: le ability sono nella save RAM; salvando la partita diventano persistenti.",
        2
    )

    PatchCompleted = true
end

function _OnInit()
    CanExecute = false
    PatchCompleted = false
    PatchDisabled = false
    ErrorReported = false

    local libraryLoaded, libraryOrError = pcall(require, "kh2lib")

    if not libraryLoaded then
        ConsolePrint(
            "KH2 Lua Library non disponibile: "
            .. tostring(libraryOrError),
            3
        )
        return
    end

    kh2lib = libraryOrError

    RequireKH2LibraryVersion(2)
    RequirePCGameVersion()

    CanExecute = kh2lib.CanExecute == true

    if not CanExecute then
        return
    end

    ConsolePrint(
        "Sora Combo Core inizializzato: attendo gameplay Sora.",
        1
    )
end

function _OnFrame()
    if not CanExecute or PatchDisabled then
        return
    end

    local readyOk, readyOrError = pcall(IsSoraGameplayReady)

    if not readyOk then
        if not ErrorReported then
            ConsolePrint(
                "Errore controllo Sora Combo Core: "
                .. tostring(readyOrError),
                3
            )
            ErrorReported = true
        end
        return
    end

    if not readyOrError then
        -- Re-arm after title/loading so another Sora save is initialized too.
        PatchCompleted = false
        ErrorReported = false
        return
    end

    if PatchCompleted then
        return
    end

    local patchOk, patchError = pcall(EnableSoraComboCore)

    if not patchOk then
        ConsolePrint(
            "Errore Sora Combo Core; modulo disabilitato fino a F1: "
            .. tostring(patchError),
            3
        )
        ErrorReported = true
        PatchDisabled = true
        return
    end

    ErrorReported = false
end
