LUAGUI_NAME = "KH2 JokCombat - Ability Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Read-only probe for Sora movement, Drive Forms and standard abilities"

local kh2lib = nil
local CanExecute = false
local SnapshotDone = false
local ErrorReported = false

local ABILITY_TABLE_OFFSET = 0x2544
local STANDARD_ABILITY_SLOT_COUNT = 69

local ABILITY_ID_MASK = 0x0FFF
local EQUIPPED_FLAG = 0x8000

local SORA_STORY_FLAG_OFFSET = 0x1CEA
local SORA_STORY_FLAG_MASK = 0x01

local ITEM_SET_1_OFFSET = 0x36C0
local ITEM_SET_1_FORM_MASK = 0x76
local ITEM_SET_11_OFFSET = 0x36CA
local ITEM_SET_11_LIMIT_MASK = 0x08
local CURRENT_FORM_OFFSET = 0x3524
local DRIVE_SAVE_CURRENT_OFFSET = 0x3529
local DRIVE_SAVE_MAX_OFFSET = 0x352A
local DRIVE_LIVE_PERCENT_OFFSET = 0x1B0
local DRIVE_LIVE_CURRENT_OFFSET = 0x1B1
local DRIVE_LIVE_MAX_OFFSET = 0x1B2

local DRIVE_FORMS = {
    { name = "Valor", blockOffset = 0x32F4 },
    { name = "Wisdom", blockOffset = 0x332C },
    { name = "Limit", blockOffset = 0x3364 },
    { name = "Master", blockOffset = 0x339C },
    { name = "Final", blockOffset = 0x33D4 }
}

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
    { name = "Finishing Plus", id = 0x0189 },
    { name = "Auto Valor", id = 0x0181 },
    { name = "Auto Wisdom", id = 0x0182 },
    { name = "Auto Limit", id = 0x0238 },
    { name = "Auto Master", id = 0x0183 },
    { name = "Auto Final", id = 0x0184 },
    { name = "MP Rage", id = 0x019C },
    { name = "MP Haste", id = 0x019D },
    { name = "Draw", id = 0x0195 },
    { name = "Lucky Lucky", id = 0x0197 },
    { name = "Form Boost", id = 0x018E }
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
    local storyFlags = ReadByte(kh2lib.Save + SORA_STORY_FLAG_OFFSET)
    local isSora = (storyFlags & SORA_STORY_FLAG_MASK) ~= 0

    return isSora
        and world ~= 0xFF
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

local function LogDriveForms()
    local itemSet1 = ReadByte(kh2lib.Save + ITEM_SET_1_OFFSET)
    local itemSet11 = ReadByte(kh2lib.Save + ITEM_SET_11_OFFSET)
    local currentForm = ReadByte(kh2lib.Save + CURRENT_FORM_OFFSET)
    local saveCurrent = ReadByte(kh2lib.Save + DRIVE_SAVE_CURRENT_OFFSET)
    local saveMax = ReadByte(kh2lib.Save + DRIVE_SAVE_MAX_OFFSET)
    local livePercent = ReadByte(kh2lib.Slot1 + DRIVE_LIVE_PERCENT_OFFSET)
    local liveCurrent = ReadByte(kh2lib.Slot1 + DRIVE_LIVE_CURRENT_OFFSET)
    local liveMax = ReadByte(kh2lib.Slot1 + DRIVE_LIVE_MAX_OFFSET)

    ConsolePrint("=== DRIVE FORMS ===", 0)
    ConsolePrint(string.format(
        "Unlocks ItemSet1=%s target=%s ItemSet11=%s Limit=%s CurrentForm=%s",
        Hex(itemSet1, 2),
        (itemSet1 & ITEM_SET_1_FORM_MASK) == ITEM_SET_1_FORM_MASK
            and "YES" or "NO",
        Hex(itemSet11, 2),
        (itemSet11 & ITEM_SET_11_LIMIT_MASK) == ITEM_SET_11_LIMIT_MASK
            and "YES" or "NO",
        Hex(currentForm, 2)
    ), 0)
    ConsolePrint(string.format(
        "Drive save=%d/%d live=%d/%d percent=%d",
        saveCurrent,
        saveMax,
        liveCurrent,
        liveMax,
        livePercent
    ), 0)

    for _, form in ipairs(DRIVE_FORMS) do
        local weapon = ReadShort(kh2lib.Save + form.blockOffset)
        local level = ReadByte(kh2lib.Save + form.blockOffset + 0x02)
        local abilityLevel = ReadByte(kh2lib.Save + form.blockOffset + 0x03)
        local experience = ReadInt(kh2lib.Save + form.blockOffset + 0x04)
        local firstAbility = ReadShort(kh2lib.Save + form.blockOffset + 0x08)
        local nonzeroAbilities = 0

        for slot = 0, 23 do
            if ReadShort(
                kh2lib.Save + form.blockOffset + 0x08 + (slot * 2)
            ) ~= 0 then
                nonzeroAbilities = nonzeroAbilities + 1
            end
        end

        ConsolePrint(string.format(
            "%-7s Level=%d AbilityLevel=%d EXP=%d Weapon=%s FirstAbility=%s AbilitySlots=%d/24",
            form.name,
            level,
            abilityLevel,
            experience,
            Hex(weapon, 4),
            Hex(firstAbility, 4),
            nonzeroAbilities
        ), 0)
    end

    ConsolePrint(string.format(
        "Anti    unlocked=%s innate PLRP=[0x80F8,0x80F9,0x8194] (index 5 e Summon)",
        (itemSet1 & 0x20) ~= 0 and "YES" or "NO"
    ), 0)
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
    ConsolePrint("=== STANDARD SORA ABILITIES ===", 0)

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

    LogDriveForms()
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
        "Ability Probe read-only inizializzata; attendo gameplay Sora...",
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
