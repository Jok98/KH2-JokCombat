LUAGUI_NAME = "KH2 JokCombat - Ability Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Read-only probe for Sora progression, Keyblades and abilities"

local RawConsolePrint = ConsolePrint
local LoggerLoaded, Logger = pcall(require, "KH2JokCombat_Log")
if not LoggerLoaded then
    LoggerLoaded, Logger = pcall(require, "runtime.KH2JokCombat_Log")
end
local LoggerLoadError = LoggerLoaded and nil or Logger

local function ConsolePrint(message, level)
    local category = level ~= nil and level >= 3 and "ERROR" or "PROBE"

    if LoggerLoaded then
        return Logger.Log("AbilityProbe", category, message, level)
    end

    if category == "ERROR" then
        RawConsolePrint("[AbilityProbe][ERROR] " .. tostring(message), level or 3)
    end
end

local function ReportLoggerFailure()
    if not LoggerLoaded then
        RawConsolePrint(
            "[AbilityProbe][ERROR] KH2JokCombat_Log non disponibile: "
            .. tostring(LoggerLoadError),
            3
        )
    end
end

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
local SORA_AP_BOOST_COUNT_OFFSET = 0x24F8
local SORA_LIVE_AP_OFFSET = 0x18E
local SORA_MAX_AP = 0xFF

local DRIVE_FORMS = {
    { name = "Valor", blockOffset = 0x32F4 },
    { name = "Wisdom", blockOffset = 0x332C },
    { name = "Limit", blockOffset = 0x3364 },
    { name = "Master", blockOffset = 0x339C },
    { name = "Final", blockOffset = 0x33D4 }
}

local KEYBLADES = {
    { name = "Kingdom Key", id = 0x0029, inventoryOffset = 0x35A1 },
    { name = "Oathkeeper", id = 0x002A, inventoryOffset = 0x35A2 },
    { name = "Oblivion", id = 0x002B, inventoryOffset = 0x35A3 },
    { name = "Star Seeker", id = 0x01E0, inventoryOffset = 0x367B },
    { name = "Hidden Dragon", id = 0x01E1, inventoryOffset = 0x367C },
    { name = "Hero's Crest", id = 0x01E4, inventoryOffset = 0x367F },
    { name = "Monochrome", id = 0x01E5, inventoryOffset = 0x3680 },
    { name = "Follow the Wind", id = 0x01E6, inventoryOffset = 0x3681 },
    { name = "Circle of Life", id = 0x01E7, inventoryOffset = 0x3682 },
    { name = "Photon Debugger", id = 0x01E8, inventoryOffset = 0x3683 },
    { name = "Gull Wing", id = 0x01E9, inventoryOffset = 0x3684 },
    { name = "Rumbling Rose", id = 0x01EA, inventoryOffset = 0x3685 },
    { name = "Guardian Soul", id = 0x01EB, inventoryOffset = 0x3686 },
    { name = "Wishing Lamp", id = 0x01EC, inventoryOffset = 0x3687 },
    { name = "Decisive Pumpkin", id = 0x01ED, inventoryOffset = 0x3688 },
    { name = "Sleeping Lion", id = 0x01EE, inventoryOffset = 0x3689 },
    { name = "Sweet Memories", id = 0x01EF, inventoryOffset = 0x368A },
    { name = "Mysterious Abyss", id = 0x01F0, inventoryOffset = 0x368B },
    { name = "Fatal Crest", id = 0x01F1, inventoryOffset = 0x368C },
    { name = "Bond of Flame", id = 0x01F2, inventoryOffset = 0x368D },
    { name = "Fenrir", id = 0x01F3, inventoryOffset = 0x368E },
    { name = "Two Become One", id = 0x021F, inventoryOffset = 0x3698 },
    { name = "Winner's Proof", id = 0x0220, inventoryOffset = 0x3699 }
}

local ULTIMA_WEAPON = {
    name = "Ultima Weapon",
    id = 0x01F4,
    inventoryOffset = 0x368F
}

local KEYBLADE_WEAPON_SLOTS = {
    { name = "Sora", offset = 0x24F0 },
    { name = "Valor", offset = 0x32F4 },
    { name = "Wisdom", offset = 0x332C },
    { name = "Limit", offset = 0x3364 },
    { name = "Master", offset = 0x339C },
    { name = "Final", offset = 0x33D4 }
}

local FORM_WEAPON_DEFAULTS = {
    {
        formName = "Master",
        offset = 0x339C,
        keybladeName = "Bond of Flame",
        keybladeId = 0x01F2
    },
    {
        formName = "Final",
        offset = 0x33D4,
        keybladeName = "Oblivion",
        keybladeId = 0x002B
    }
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
    { name = "Guard", id = 0x0052, targetCount = 1, equipped = true },
    { name = "Upper Slash", id = 0x0089, targetCount = 1, equipped = true },
    { name = "Horizontal Slash", id = 0x010F, targetCount = 1, equipped = true },
    { name = "Finishing Leap", id = 0x010B, targetCount = 1, equipped = true },
    { name = "Retaliating Slash", id = 0x0111, targetCount = 1, equipped = true },
    { name = "Slapshot", id = 0x0106, targetCount = 1, equipped = true },
    { name = "Dodge Slash", id = 0x0107, targetCount = 1, equipped = true },
    { name = "Flash Step", id = 0x022F, targetCount = 1, equipped = true },
    { name = "Slide Dash", id = 0x0108, targetCount = 1, equipped = true },
    { name = "Vicinity Break", id = 0x0232, targetCount = 1, equipped = true },
    { name = "Guard Break", id = 0x0109, targetCount = 1, equipped = true },
    { name = "Explosion", id = 0x010A, targetCount = 1, equipped = true },
    { name = "Aerial Sweep", id = 0x010D, targetCount = 1, equipped = true },
    { name = "Aerial Dive", id = 0x0230, targetCount = 1, equipped = true },
    { name = "Aerial Spiral", id = 0x010E, targetCount = 1, equipped = true },
    { name = "Aerial Finish", id = 0x0110, targetCount = 1, equipped = true },
    { name = "Magnet Burst", id = 0x0231, targetCount = 1, equipped = true },
    { name = "Counterguard", id = 0x010C, targetCount = 1, equipped = true },
    { name = "Auto Valor", id = 0x0181, targetCount = 1, equipped = false },
    { name = "Auto Wisdom", id = 0x0182, targetCount = 1, equipped = false },
    { name = "Auto Limit", id = 0x0238, targetCount = 1, equipped = false },
    { name = "Auto Master", id = 0x0183, targetCount = 1, equipped = false },
    { name = "Auto Final", id = 0x0184, targetCount = 1, equipped = false },
    { name = "Auto Summon", id = 0x0185, targetCount = 1, equipped = false },
    { name = "Trinity Limit", id = 0x00C6, targetCount = 1, equipped = true },
    { name = "Combo Master", id = 0x021B, targetCount = 1, equipped = true },
    { name = "Combo Plus", id = 0x00A2, targetCount = 2, equipped = true },
    { name = "Air Combo Plus", id = 0x00A3, targetCount = 2, equipped = true },
    { name = "MP Rage", id = 0x019C, targetCount = 1, equipped = true },
    { name = "MP Haste", id = 0x019D, targetCount = 1, equipped = true },
    { name = "Draw", id = 0x0195, targetCount = 1, equipped = true },
    { name = "Lucky Lucky", id = 0x0197, targetCount = 2, equipped = true },
    { name = "Form Boost", id = 0x018E, targetCount = 2, equipped = true }
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

    for _, default in ipairs(FORM_WEAPON_DEFAULTS) do
        local weapon = ReadShort(kh2lib.Save + default.offset)
        local status = weapon == default.keybladeId and "READY"
            or (weapon == 0 and "EMPTY" or "CUSTOM")

        ConsolePrint(string.format(
            "%-7s weapon default=%s target=%s current=%s status=%s",
            default.formName,
            default.keybladeName,
            Hex(default.keybladeId, 4),
            Hex(weapon, 4),
            status
        ), 0)
    end

    ConsolePrint(string.format(
        "Anti    unlocked=%s innate PLRP=[0x80F8,0x80F9,0x8194] (index 5 e Summon)",
        (itemSet1 & 0x20) ~= 0 and "YES" or "NO"
    ), 0)
end

local function LogSoraAp()
    local liveAp = ReadByte(kh2lib.Slot1 + SORA_LIVE_AP_OFFSET)
    local appliedBoosts = ReadByte(
        kh2lib.Save + SORA_AP_BOOST_COUNT_OFFSET
    )

    ConsolePrint("=== SORA AP ===", 0)
    ConsolePrint(string.format(
        "AP live=%d target=%d status=%s APBoost applicati(save)=%d [preservati]",
        liveAp,
        SORA_MAX_AP,
        liveAp == SORA_MAX_AP and "MAX" or "LOW",
        appliedBoosts
    ), 0)
end

local function GetEquippedKeyblades()
    local equippedById = {}

    for _, slot in ipairs(KEYBLADE_WEAPON_SLOTS) do
        local value = ReadShort(kh2lib.Save + slot.offset)

        equippedById[value] = equippedById[value] or {}
        equippedById[value][#equippedById[value] + 1] = slot.name
    end

    return equippedById
end

local function LogKeyblades()
    local equippedById = GetEquippedKeyblades()

    ConsolePrint("=== SORA KEYBLADES ===", 0)

    for _, keyblade in ipairs(KEYBLADES) do
        local count = ReadByte(
            kh2lib.Save + keyblade.inventoryOffset
        )
        local equipped = equippedById[keyblade.id] or {}
        local ready = count > 0 or #equipped > 0

        ConsolePrint(string.format(
            "%-19s %-7s id=%s stock=%d equipped=[%s] Save+%s",
            keyblade.name,
            ready and "READY" or "MISSING",
            Hex(keyblade.id, 4),
            count,
            table.concat(equipped, ","),
            Hex(keyblade.inventoryOffset, 4)
        ), 0)
    end

    local ultimaCount = ReadByte(
        kh2lib.Save + ULTIMA_WEAPON.inventoryOffset
    )
    local ultimaEquipped = equippedById[ULTIMA_WEAPON.id] or {}

    ConsolePrint(string.format(
        "%-19s EXCLUDED id=%s stock=%d equipped=[%s] [preserved]",
        ULTIMA_WEAPON.name,
        Hex(ULTIMA_WEAPON.id, 4),
        ultimaCount,
        table.concat(ultimaEquipped, ",")
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
    ConsolePrint("=== SORA ACTION / COMBO / FORM REWARDS ===", 0)

    for _, ability in ipairs(STANDARD_ABILITIES) do
        local matches = FindStandardAbility(ability.id)
        local equippedCount = 0
        local slots = {}

        for _, match in ipairs(matches) do
            if match.equipped then
                equippedCount = equippedCount + 1
            end

            slots[#slots + 1] = string.format(
                "%d:%s",
                match.slot,
                match.equipped and "ON" or "OFF"
            )
        end

        local shouldEquip = ability.equipped ~= false
        local ready = #matches >= ability.targetCount
            and (
                (shouldEquip and equippedCount >= ability.targetCount)
                or (not shouldEquip and equippedCount == 0)
            )

        ConsolePrint(string.format(
            "%-18s %-8s id=%s target=%s x%d present=%d equipped=%d slots=[%s]",
            ability.name,
            ready and "READY" or "MISMATCH",
            Hex(ability.id, 4),
            shouldEquip and "ON" or "OFF",
            ability.targetCount,
            #matches,
            equippedCount,
            table.concat(slots, ",")
        ), 0)
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

    LogSoraAp()
    LogDriveForms()
    LogKeyblades()
    LogGrowthAbilities()
    LogStandardAbilities()

    ConsolePrint(
        "Nessuna WriteByte/WriteShort/WriteInt eseguita.",
        1
    )
    ConsolePrint("############################################", 0)
end

function _OnInit()
    CanExecute = false
    ReportLoggerFailure()

    if not LoggerLoaded or not Logger.IsEnabled("PROBE") then
        return
    end

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
