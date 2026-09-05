LUAGUI_NAME = "KH2 JokCombat - Sora Movement"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Keeps all five Sora growth abilities equipped at MAX"

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
        return Logger.Log("Movement", resolvedCategory, message, level)
    end

    if resolvedCategory == "ERROR" then
        RawConsolePrint("[Movement][ERROR] " .. tostring(message), level or 3)
    end
end

local function ReportLoggerFailure()
    if not LoggerLoaded then
        RawConsolePrint(
            "[Movement][ERROR] KH2JokCombat_Log non disponibile: "
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
local ABILITY_ID_MASK = 0x0FFF
local EQUIPPED_FLAG = 0x8000

-- KH2 stores the five growth abilities in dedicated consecutive save slots.
-- Each family has four levels; the last ID is the MAX version.
local GROWTH_ABILITIES = {
    {
        name = "High Jump",
        slotOffset = 0x25CE,
        minId = 0x005E,
        maxId = 0x0061
    },
    {
        name = "Quick Run",
        slotOffset = 0x25D0,
        minId = 0x0062,
        maxId = 0x0065
    },
    {
        name = "Dodge Roll",
        slotOffset = 0x25D2,
        minId = 0x0234,
        maxId = 0x0237
    },
    {
        name = "Aerial Dodge",
        slotOffset = 0x25D4,
        minId = 0x0066,
        maxId = 0x0069
    },
    {
        name = "Glide",
        slotOffset = 0x25D6,
        minId = 0x006A,
        maxId = 0x006D
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

local function GetDesiredGrowthValue(ability)
    return ability.maxId | EQUIPPED_FLAG
end

-- Read and validate every slot before writing any of them. This prevents an
-- unrelated or modded value in one slot from leaving a partially applied set.
local function InspectGrowthSlots()
    local slots = {}

    for index, ability in ipairs(GROWTH_ABILITIES) do
        local address = kh2lib.Save + ability.slotOffset
        local before = ReadShort(address)
        local abilityId = before & ABILITY_ID_MASK

        if before ~= 0
            and (abilityId < ability.minId or abilityId > ability.maxId) then

            error(string.format(
                "%s slot Save+%s contiene un valore inatteso: %s",
                ability.name,
                Hex(ability.slotOffset, 4),
                Hex(before, 4)
            ))
        end

        slots[index] = {
            ability = ability,
            address = address,
            before = before,
            desired = GetDesiredGrowthValue(ability)
        }
    end

    return slots
end

local function ApplyMovementProfile()
    local slots = InspectGrowthSlots()
    local changedCount = 0

    for _, slot in ipairs(slots) do
        if slot.before ~= slot.desired then
            WriteShort(slot.address, slot.desired)

            local after = ReadShort(slot.address)

            if after ~= slot.desired then
                error(string.format(
                    "Verifica %s MAX fallita: %s",
                    slot.ability.name,
                    Hex(after, 4)
                ))
            end

            changedCount = changedCount + 1

            ConsolePrint(string.format(
                "%s MAX equipaggiato: Save+%s %s -> %s",
                slot.ability.name,
                Hex(slot.ability.slotOffset, 4),
                Hex(slot.before, 4),
                Hex(after, 4)
            ), 1)
        end
    end

    ConsolePrint(string.format(
        "Sora Movement pronto: tutte le 5 growth MAX sono equipaggiate (%d aggiornate).",
        changedCount
    ), 1)

    ConsolePrint(
        "Nota: livelli e stato equipaggiato sono nella save RAM; salvando la partita diventano persistenti.",
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
        "Sora Movement inizializzato: attendo gameplay Sora.",
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
                "Errore controllo Sora Movement: "
                .. tostring(readyOrError),
                3
            )
            ErrorReported = true
        end
        return
    end

    if not readyOrError then
        -- Re-arm after title/loading so a different Sora save is inspected.
        PatchCompleted = false
        ErrorReported = false
        return
    end

    if PatchCompleted then
        return
    end

    local patchOk, patchError = pcall(ApplyMovementProfile)

    if not patchOk then
        ConsolePrint(
            "Errore Sora Movement; modulo disabilitato fino a F1: "
            .. tostring(patchError),
            3
        )
        ErrorReported = true
        PatchDisabled = true
        return
    end

    ErrorReported = false
end
