LUAGUI_NAME = "KH2 JokCombat - Combo Master"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Enables Combo Master for the active Roxas save"

local kh2lib = nil
local CanExecute = false
local PatchCompleted = false
local ErrorReported = false

local COMBO_MASTER_ID = 0x021B
local COMBO_MASTER_EQUIPPED = 0x821B

-- Standard player ability table used by KH2.
-- GoA scans slots 0..68 from Save + 0x2544 in 2-byte steps.
local ABILITY_TABLE_OFFSET = 0x2544
local STANDARD_ABILITY_SLOT_COUNT = 69
local ABILITY_ID_MASK = 0x0FFF
local EQUIPPED_FLAG = 0x8000

local SIMULATED_TWILIGHT_TOWN_WORLD = 0x02

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function IsRoxasGameplayReady()
    local world = ReadByte(kh2lib.Now + 0x00)
    local maxHp = ReadInt(kh2lib.Slot1 + 0x004)

    -- Avoid touching save data while the title/menu state is still loading.
    return world == SIMULATED_TWILIGHT_TOWN_WORLD and maxHp > 0
end

local function FindComboMasterOrEmptySlot()
    local firstEmptyAddress = nil
    local firstEmptyIndex = nil

    for slot = 0, STANDARD_ABILITY_SLOT_COUNT - 1 do
        local address = kh2lib.Save + ABILITY_TABLE_OFFSET + (slot * 2)
        local value = ReadShort(address)
        local abilityId = value & ABILITY_ID_MASK

        if abilityId == COMBO_MASTER_ID then
            return {
                found = true,
                index = slot,
                address = address,
                value = value
            }
        end

        if value == 0 and firstEmptyAddress == nil then
            firstEmptyAddress = address
            firstEmptyIndex = slot
        end
    end

    return {
        found = false,
        index = firstEmptyIndex,
        address = firstEmptyAddress,
        value = 0
    }
end

local function EnableComboMaster()
    if not IsRoxasGameplayReady() then
        return false
    end

    local slot = FindComboMasterOrEmptySlot()

    if slot.found then
        if (slot.value & EQUIPPED_FLAG) ~= 0 then
            ConsolePrint(string.format(
                "Combo Master gia presente ed equipaggiato: slot=%d value=%s",
                slot.index,
                Hex(slot.value, 4)
            ), 1)

            PatchCompleted = true
            return true
        end

        local equippedValue = slot.value | EQUIPPED_FLAG
        WriteShort(slot.address, equippedValue)

        local after = ReadShort(slot.address)

        if (after & ABILITY_ID_MASK) ~= COMBO_MASTER_ID
            or (after & EQUIPPED_FLAG) == 0 then

            error(
                "Verifica equip Combo Master fallita: "
                .. Hex(after, 4)
            )
        end

        ConsolePrint(string.format(
            "Combo Master equipaggiato: slot=%d %s -> %s",
            slot.index,
            Hex(slot.value, 4),
            Hex(after, 4)
        ), 1)

        PatchCompleted = true
        return true
    end

    if slot.address == nil then
        error(
            "Nessuno slot ability standard libero disponibile "
            .. "(scansionati 69 slot da Save+0x2544)"
        )
    end

    WriteShort(slot.address, COMBO_MASTER_EQUIPPED)

    local after = ReadShort(slot.address)

    if after ~= COMBO_MASTER_EQUIPPED then
        error(
            "Verifica inserimento Combo Master fallita: "
            .. Hex(after, 4)
        )
    end

    ConsolePrint(string.format(
        "Combo Master aggiunto ed equipaggiato: slot=%d value=%s",
        slot.index,
        Hex(after, 4)
    ), 1)

    ConsolePrint(
        "Nota: l'ability viene scritta nella tabella del save; salvando la partita puo diventare persistente.",
        2
    )

    PatchCompleted = true
    return true
end

function _OnInit()
    local libraryLoaded, libraryOrError = pcall(require, "kh2lib")

    if not libraryLoaded then
        ConsolePrint(
            "KH2 Lua Library non disponibile: " .. tostring(libraryOrError),
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

    PatchCompleted = false
    ErrorReported = false

    ConsolePrint(
        "Combo Master runtime module inizializzato. Attendo Roxas gameplay...",
        1
    )
end

function _OnFrame()
    if not CanExecute or PatchCompleted then
        return
    end

    local ok, resultOrError = pcall(EnableComboMaster)

    if not ok then
        if not ErrorReported then
            ConsolePrint(
                "Errore Combo Master: " .. tostring(resultOrError),
                3
            )
            ErrorReported = true
        end
        return
    end

    if resultOrError == true then
        ErrorReported = false
    end
end