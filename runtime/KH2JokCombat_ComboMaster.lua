LUAGUI_NAME = "KH2 JokCombat - Sora Combat Abilities"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Unlocks every Sora action; native A specials and Auto actions stay disabled"

local RawConsolePrint = ConsolePrint
local LoggerLoaded, Logger = pcall(require, "KH2JokCombat_Log")
if not LoggerLoaded then
    LoggerLoaded, Logger = pcall(require, "runtime.KH2JokCombat_Log")
end
local LoggerLoadError = LoggerLoaded and nil or Logger

local function ConsolePrint(message, level, category)
    local resolvedCategory = category or "PROGRESSION"

    if level ~= nil and level >= 3 then
        resolvedCategory = "ERROR"
    end

    if LoggerLoaded then
        return Logger.Log("CombatAbilities", resolvedCategory, message, level)
    end

    if resolvedCategory == "ERROR" then
        RawConsolePrint(
            "[CombatAbilities][ERROR] " .. tostring(message),
            level or 3
        )
    end
end

local function ReportLoggerFailure()
    if not LoggerLoaded then
        RawConsolePrint(
            "[CombatAbilities][ERROR] KH2JokCombat_Log non disponibile: "
            .. tostring(LoggerLoadError),
            3
        )
    end
end

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
local BASE_A_ONLY_PROFILE = true

-- Complete Final Mix Sora Action Ability pool in native menu order. All six
-- Auto actions stay owned by the game/save but are deliberately disabled.
-- With BASE_A_ONLY_PROFILE, Type 1/2/3 PTYA abilities remain unlocked but OFF:
-- A therefore uses the native A300/A301/A302 chain, while Type 0 Square
-- carriers can still launch the selected motions for the custom combo.
local COMBAT_ABILITIES = {
    { name = "Guard", id = 0x0052, targetCount = 1, equipped = true, group = "SQUARE" },
    { name = "Upper Slash", id = 0x0089, targetCount = 1, equipped = true, group = "SQUARE" },
    { name = "Horizontal Slash", id = 0x010F, targetCount = 1, equipped = true, group = "SQUARE" },
    { name = "Finishing Leap", id = 0x010B, targetCount = 1, equipped = true, group = "SQUARE" },
    { name = "Retaliating Slash", id = 0x0111, targetCount = 1, equipped = true, group = "SQUARE" },
    { name = "Slapshot", id = 0x0106, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Dodge Slash", id = 0x0107, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Flash Step", id = 0x022F, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Slide Dash", id = 0x0108, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Vicinity Break", id = 0x0232, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Guard Break", id = 0x0109, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Explosion", id = 0x010A, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Aerial Sweep", id = 0x010D, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Aerial Dive", id = 0x0230, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Aerial Spiral", id = 0x010E, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Aerial Finish", id = 0x0110, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Magnet Burst", id = 0x0231, targetCount = 1, equipped = not BASE_A_ONLY_PROFILE, group = "A_SPECIAL" },
    { name = "Counterguard", id = 0x010C, targetCount = 1, equipped = true, group = "SQUARE" },
    { name = "Auto Valor", id = 0x0181, targetCount = 1, equipped = false, group = "AUTO" },
    { name = "Auto Wisdom", id = 0x0182, targetCount = 1, equipped = false, group = "AUTO" },
    { name = "Auto Limit", id = 0x0238, targetCount = 1, equipped = false, group = "AUTO" },
    { name = "Auto Master", id = 0x0183, targetCount = 1, equipped = false, group = "AUTO" },
    { name = "Auto Final", id = 0x0184, targetCount = 1, equipped = false, group = "AUTO" },
    { name = "Auto Summon", id = 0x0185, targetCount = 1, equipped = false, group = "AUTO" },
    { name = "Trinity Limit", id = 0x00C6, targetCount = 1, equipped = true, group = "COMMAND" },
    { name = "Combo Master", id = 0x021B, targetCount = 1, equipped = true, group = "SUPPORT" },
    { name = "Combo Plus", id = 0x00A2, targetCount = 2, equipped = true, group = "SUPPORT" },
    { name = "Air Combo Plus", id = 0x00A3, targetCount = 2, equipped = true, group = "SUPPORT" }
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

local function DesiredAbilityValue(ability, value)
    if ability.equipped then
        return value | EQUIPPED_FLAG
    end

    return value & 0x7FFF
end

local function BuildCombatPlan()
    local abilityById = {}
    local matchesById = {}
    local freeSlots = {}

    for _, ability in ipairs(COMBAT_ABILITIES) do
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

    for _, ability in ipairs(COMBAT_ABILITIES) do
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

    for _, ability in ipairs(COMBAT_ABILITIES) do
        local matches = matchesById[ability.id]

        -- Keep every matching copy in the requested state. This also disables
        -- Auto actions already equipped by the save or another mod.
        for _, match in ipairs(matches) do
            local desired = DesiredAbilityValue(ability, match.before)

            if desired ~= match.before then
                changes[#changes + 1] = {
                    ability = ability,
                    index = match.index,
                    address = match.address,
                    before = match.before,
                    desired = desired,
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
                desired = ability.id
                    | (ability.equipped and EQUIPPED_FLAG or 0),
                added = true
            }
        end
    end

    return changes
end

local function VerifyCombatAbilities()
    local presentCounts = {}
    local equippedCounts = {}

    for _, ability in ipairs(COMBAT_ABILITIES) do
        presentCounts[ability.id] = 0
        equippedCounts[ability.id] = 0
    end

    for slot = 0, STANDARD_ABILITY_SLOT_COUNT - 1 do
        local address = kh2lib.Save + ABILITY_TABLE_OFFSET + (slot * 2)
        local value = ReadShort(address)
        local abilityId = value & ABILITY_ID_MASK

        if presentCounts[abilityId] ~= nil then
            presentCounts[abilityId] = presentCounts[abilityId] + 1

            if (value & EQUIPPED_FLAG) ~= 0 then
                equippedCounts[abilityId] = equippedCounts[abilityId] + 1
            end
        end
    end

    for _, ability in ipairs(COMBAT_ABILITIES) do
        if presentCounts[ability.id] < ability.targetCount then
            error(string.format(
                "Verifica %s fallita: %d presenti, attese almeno %d",
                ability.name,
                presentCounts[ability.id],
                ability.targetCount
            ))
        end

        if ability.equipped
            and equippedCounts[ability.id] < ability.targetCount then

            error(string.format(
                "Verifica %s fallita: %d equipaggiate, attese almeno %d",
                ability.name,
                equippedCounts[ability.id],
                ability.targetCount
            ))
        elseif not ability.equipped
            and equippedCounts[ability.id] ~= 0 then

            error(string.format(
                "Verifica %s fallita: %d copie ancora equipaggiate",
                ability.name,
                equippedCounts[ability.id]
            ))
        end
    end

    return presentCounts, equippedCounts
end

local function GroupCounts(equippedCounts, group)
    local targetCount = 0
    local equippedCount = 0

    for _, ability in ipairs(COMBAT_ABILITIES) do
        if ability.group == group then
            targetCount = targetCount + ability.targetCount
            equippedCount = equippedCount + equippedCounts[ability.id]
        end
    end

    return targetCount, equippedCount
end

local function EnableSoraCombatAbilities()
    -- Capacity and all current values are inspected before the first write.
    local changes = BuildCombatPlan()

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

        local isEquipped = (after & EQUIPPED_FLAG) ~= 0

        if (after & ABILITY_ID_MASK) ~= change.ability.id
            or isEquipped ~= change.ability.equipped then

            error(string.format(
                "Verifica %s slot %d fallita: %s",
                change.ability.name,
                change.index,
                Hex(after, 4)
            ))
        end

        ConsolePrint(string.format(
            "%s %s e %s: slot=%d %s -> %s",
            change.ability.name,
            change.added and "aggiunto" or "trovato",
            change.ability.equipped and "equipaggiato" or "disabilitato",
            change.index,
            Hex(change.before, 4),
            Hex(after, 4)
        ), 1)
    end

    local _, equippedCounts = VerifyCombatAbilities()
    local squareTarget, squareEquipped = GroupCounts(
        equippedCounts,
        "SQUARE"
    )
    local aSpecialTarget, aSpecialEquipped = GroupCounts(
        equippedCounts,
        "A_SPECIAL"
    )
    local autoTarget, autoEquipped = GroupCounts(equippedCounts, "AUTO")

    ConsolePrint(string.format(
        "Sora Combat pronto: profilo A-base=%s; carrier Quadrato %d/%d ON, Action A-special %d/%d ON, Auto %d/%d ON; Trinity ON, Combo Master x%d, Combo Plus x%d, Air Combo Plus x%d (%d aggiornamenti).",
        BASE_A_ONLY_PROFILE and "ON" or "OFF",
        squareEquipped,
        squareTarget,
        aSpecialEquipped,
        aSpecialTarget,
        autoEquipped,
        autoTarget,
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
    ReportLoggerFailure()
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
        "Sora Combat Abilities inizializzato: attendo gameplay Sora.",
        1,
        "SYSTEM"
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
                "Errore controllo Sora Combat Abilities: "
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

    local patchOk, patchError = pcall(EnableSoraCombatAbilities)

    if not patchOk then
        ConsolePrint(
            "Errore Sora Combat Abilities; modulo disabilitato fino a F1: "
            .. tostring(patchError),
            3
        )
        ErrorReported = true
        PatchDisabled = true
        return
    end

    ErrorReported = false
end
