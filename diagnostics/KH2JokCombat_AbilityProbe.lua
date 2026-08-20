LUAGUI_NAME = "KH2 JokCombat - Ability Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Read-only probe for Roxas movement and combo-core abilities"

local kh2lib = nil
local CanExecute = false
local SnapshotDone = false
local ErrorReported = false

local ABILITY_TABLE_OFFSET = 0x2544
local STANDARD_ABILITY_SLOT_COUNT = 69

local ABILITY_ID_MASK = 0x0FFF
local EQUIPPED_FLAG = 0x8000

local MOVEMENT = {
    {
        name = "High Jump",
        addressOffset = 0x25CE,
        minId = 0x005E,
        maxId = 0x0061,
        maxAbilityId = 0x0061
    },
    {
        name = "Quick Run",
        addressOffset = 0x25D0,
        minId = 0x0062,
        maxId = 0x0065,
        maxAbilityId = 0x0065
    },
    {
        name = "Dodge Roll",
        addressOffset = 0x25D2,
        minId = 0x0234,
        maxId = 0x0237,
        maxAbilityId = 0x0237
    },
    {
        name = "Aerial Dodge",
        addressOffset = 0x25D4,
        minId = 0x0066,
        maxId = 0x0069,
        maxAbilityId = 0x0069
    },
    {
        name = "Glide",
        addressOffset = 0x25D6,
        minId = 0x006A,
        maxId = 0x006D,
        maxAbilityId = 0x006D
    }
}

local STANDARD_ABILITIES = {
    { name = "Aerial Recovery", id = 0x009E },
    { name = "Combo Master", id = 0x021B },
    { name = "Combo Plus", id = 0x00A2 },
    { name = "Air Combo Plus", id = 0x00A3 },
    { name = "Finishing Plus", id = 0x0189 }
}

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function IsEquipped(value)
    return (value & EQUIPPED_FLAG) ~= 0
end

local function AbilityId(value)
    return value & ABILITY_ID_MASK
end

local function IsGameplayReady()
    local world = ReadByte(kh2lib.Now + 0x00)
    local room = ReadByte(kh2lib.Now + 0x01)
    local maxHp = ReadInt(kh2lib.Slot1 + 0x004)

    return world ~= 0xFF
        and room ~= 0xFF
        and maxHp > 0
end

local function GetGrowthLevel(entry, abilityId)
    if abilityId < entry.minId or abilityId > entry.maxId then
        return nil
    end

    return abilityId - entry.minId + 1
end

local function LogGrowthAbilities()
    ConsolePrint("=== MOVEMENT / GROWTH ===", 0)

    for _, entry in ipairs(MOVEMENT) do
        local address = kh2lib.Save + entry.addressOffset
        local value = ReadShort(address)
        local id = AbilityId(value)
        local level = GetGrowthLevel(entry, id)

        if level == nil then
            ConsolePrint(string.format(
                "%-13s ABSENT  slot=Save+%s value=%s",
                entry.name,
                Hex(entry.addressOffset, 4),
                Hex(value, 4)
            ), 0)
        else
            local isMax = id == entry.maxAbilityId
            local state = IsEquipped(value) and "EQUIPPED" or "PRESENT"

            ConsolePrint(string.format(
                "%-13s %-8s LV%d%s id=%s value=%s slot=Save+%s",
                entry.name,
                state,
                level,
                isMax and " [MAX]" or "",
                Hex(id, 4),
                Hex(value, 4),
                Hex(entry.addressOffset, 4)
            ), 0)
        end
    end
end

local function FindStandardAbility(targetId)
    local matches = {}

    for slot = 0, STANDARD_ABILITY_SLOT_COUNT - 1 do
        local address =
            kh2lib.Save
            + ABILITY_TABLE_OFFSET
            + (slot * 2)

        local value = ReadShort(address)
        local id = AbilityId(value)

        if id == targetId then
            table.insert(matches, {
                slot = slot,
                address = address,
                value = value,
                equipped = IsEquipped(value)
            })
        end
    end

    return matches
end

local function LogStandardAbilities()
    ConsolePrint("=== COMBO CORE / STANDARD ===", 0)

    for _, ability in ipairs(STANDARD_ABILITIES) do
        local matches = FindStandardAbility(ability.id)

        if #matches == 0 then
            ConsolePrint(string.format(
                "%-16s ABSENT id=%s",
                ability.name,
                Hex(ability.id, 4)
            ), 0)
        else
            for _, match in ipairs(matches) do
                ConsolePrint(string.format(
                    "%-16s %-8s id=%s value=%s slot=%d",
                    ability.name,
                    match.equipped and "EQUIPPED" or "PRESENT",
                    Hex(ability.id, 4),
                    Hex(match.value, 4),
                    match.slot
                ), 0)
            end
        end
    end
end

local function LogAbilitySnapshot()
    local world = ReadByte(kh2lib.Now + 0x00)
    local room = ReadByte(kh2lib.Now + 0x01)

    ConsolePrint("############################################", 0)
    ConsolePrint("KH2 JokCombat Ability Snapshot [READ-ONLY]", 1)
    ConsolePrint(string.format(
        "World=%s Room=%s",
        Hex(world, 2),
        Hex(room, 2)
    ), 0)

    LogGrowthAbilities()
    LogStandardAbilities()

    ConsolePrint(
        "Nessuna WriteByte/WriteShort/WriteInt eseguita.",
        1
    )
    ConsolePrint("############################################", 0)
end

function _OnInit()
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

    SnapshotDone = false
    ErrorReported = false

    ConsolePrint(
        "Ability Probe read-only inizializzata; attendo gameplay...",
        1
    )
end

function _OnFrame()
    if not CanExecute or SnapshotDone then
        return
    end

    local readyOk, readyOrError = pcall(IsGameplayReady)

    if not readyOk then
        if not ErrorReported then
            ConsolePrint(
                "Errore Ability Probe: " .. tostring(readyOrError),
                3
            )
            ErrorReported = true
        end
        return
    end

    if not readyOrError then
        return
    end

    local snapshotOk, snapshotError = pcall(LogAbilitySnapshot)

    if not snapshotOk then
        if not ErrorReported then
            ConsolePrint(
                "Errore snapshot Ability Probe: "
                .. tostring(snapshotError),
                3
            )
            ErrorReported = true
        end
        return
    end

    ErrorReported = false
    SnapshotDone = true
end
