LUAGUI_NAME = "KH2 JokCombat - Sora Movement"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Keeps Sora growth abilities safe for the active story outfit"

local kh2lib = nil
local CanExecute = false
local AppliedProfile = nil
local PatchDisabled = false
local ErrorReported = false

local SORA_STORY_FLAG_OFFSET = 0x1CEA
local SORA_STORY_FLAG_MASK = 0x01
local ITEM_SET_1_OFFSET = 0x36C0
local VALOR_FORM_MASK = 0x02

local ABILITY_ID_MASK = 0x0FFF
local EQUIPPED_FLAG = 0x8000
local PROFILE_KH1_OUTFIT = "kh1-outfit"
local PROFILE_KH2_OUTFIT = "kh2-outfit"

-- KH2 stores the five growth abilities in dedicated consecutive save slots.
-- Each family has four levels; the last ID is the MAX version.
local GROWTH_ABILITIES = {
    {
        name = "High Jump",
        slotOffset = 0x25CE,
        minId = 0x005E,
        maxId = 0x0061,
        kh1Safe = true
    },
    {
        name = "Quick Run",
        slotOffset = 0x25D0,
        minId = 0x0062,
        maxId = 0x0065,
        kh1Safe = false
    },
    {
        name = "Dodge Roll",
        slotOffset = 0x25D2,
        minId = 0x0234,
        maxId = 0x0237,
        kh1Safe = false
    },
    {
        name = "Aerial Dodge",
        slotOffset = 0x25D4,
        minId = 0x0066,
        maxId = 0x0069,
        kh1Safe = false
    },
    {
        name = "Glide",
        slotOffset = 0x25D6,
        minId = 0x006A,
        maxId = 0x006D,
        kh1Safe = false
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

-- In the vanilla story Valor Form is granted together with Sora's KH2
-- clothes. The inventory bit is persistent and is a safer gate than world or
-- room IDs; until it exists, default to the KH1-safe movement profile.
local function GetMovementProfile()
    local itemSet1 = ReadByte(kh2lib.Save + ITEM_SET_1_OFFSET)
    local hasValor = (itemSet1 & VALOR_FORM_MASK) ~= 0

    if hasValor then
        return PROFILE_KH2_OUTFIT, itemSet1
    end

    return PROFILE_KH1_OUTFIT, itemSet1
end

local function GetDesiredGrowthValue(ability, profile)
    local desired = ability.maxId

    if profile == PROFILE_KH2_OUTFIT or ability.kh1Safe then
        desired = desired | EQUIPPED_FLAG
    end

    return desired
end

-- Read and validate every slot before writing any of them. This prevents an
-- unrelated or modded value in one slot from leaving a partially applied set.
local function InspectGrowthSlots(profile)
    if profile ~= PROFILE_KH1_OUTFIT and profile ~= PROFILE_KH2_OUTFIT then
        error("Profilo movement sconosciuto: " .. tostring(profile))
    end

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
            desired = GetDesiredGrowthValue(ability, profile)
        }
    end

    return slots
end

local function ApplyMovementProfile(profile, itemSet1)
    local slots = InspectGrowthSlots(profile)
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

            if (slot.desired & EQUIPPED_FLAG) ~= 0 then
                ConsolePrint(string.format(
                    "%s MAX equipaggiato: Save+%s %s -> %s",
                    slot.ability.name,
                    Hex(slot.ability.slotOffset, 4),
                    Hex(slot.before, 4),
                    Hex(after, 4)
                ), 1)
            else
                ConsolePrint(string.format(
                    "%s MAX lasciato in lista ma disabilitato: Save+%s %s -> %s",
                    slot.ability.name,
                    Hex(slot.ability.slotOffset, 4),
                    Hex(slot.before, 4),
                    Hex(after, 4)
                ), 1)
            end
        end
    end

    if profile == PROFILE_KH1_OUTFIT then
        ConsolePrint(string.format(
            "Profilo costume KH1 pronto: High Jump MAX attivo; altre 4 growth MAX in lista ma disabilitate (%d aggiornate, ItemSet1=%s).",
            changedCount,
            Hex(itemSet1, 2)
        ), 1)
    else
        ConsolePrint(string.format(
            "Profilo costume KH2 pronto: 5 growth ability MAX equipaggiate (%d aggiornate, ItemSet1=%s).",
            changedCount,
            Hex(itemSet1, 2)
        ), 1)
    end

    ConsolePrint(
        "Nota: livelli e stato equipaggiato sono nella save RAM; salvando la partita diventano persistenti.",
        2
    )

    AppliedProfile = profile
end

function _OnInit()
    CanExecute = false
    AppliedProfile = nil
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
        AppliedProfile = nil
        ErrorReported = false
        return
    end

    local profileOk, profileOrError, itemSet1 = pcall(GetMovementProfile)

    if not profileOk then
        if not ErrorReported then
            ConsolePrint(
                "Errore lettura profilo Sora Movement: "
                .. tostring(profileOrError),
                3
            )
            ErrorReported = true
        end
        return
    end

    local profile = profileOrError

    if AppliedProfile == profile then
        return
    end

    local patchOk, patchError = pcall(
        ApplyMovementProfile,
        profile,
        itemSet1
    )

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
