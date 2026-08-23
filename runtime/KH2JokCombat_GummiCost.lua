LUAGUI_NAME = "KH2 JokCombat - Gummi Cost Limit"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Keeps the Gummi Ship construction Cost Limit at the safe maximum of 1200"

local kh2lib = nil
local CanExecute = false
local PatchDisabled = false
local PatchReported = false
local ErrorReported = false

local SORA_STORY_FLAG_OFFSET = 0x1CEA
local SORA_STORY_FLAG_MASK = 0x01

-- Persistent Gummi editor cost-limit upgrade byte. The documented Final Mix
-- range ends at level 6, which corresponds to a total Cost Limit of 1200.
-- Higher values are deliberately rejected instead of risking invalid ships.
local GUMMI_COST_LIMIT_OFFSET = 0x10F0A
local GUMMI_COST_LIMIT_MAX_SAFE_LEVEL = 0x06
local GUMMI_COST_LIMIT_MAX_SAFE_TOTAL = 1200

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function IsLoadedSoraSave()
    local world = ReadByte(kh2lib.Now + 0x00)
    local room = ReadByte(kh2lib.Now + 0x01)
    local storyFlags = ReadByte(kh2lib.Save + SORA_STORY_FLAG_OFFSET)
    local isSora = (storyFlags & SORA_STORY_FLAG_MASK) ~= 0

    -- Slot1 is not required here: the Gummi editor has no live Sora actor.
    return isSora and world ~= 0xFF and room ~= 0xFF
end

local function EnsureGummiCostLimit()
    local address = kh2lib.Save + GUMMI_COST_LIMIT_OFFSET
    local before = ReadByte(address)

    if before > GUMMI_COST_LIMIT_MAX_SAFE_LEVEL then
        error(string.format(
            "valore estraneo %s a Save+%s preservato; massimo sicuro noto %s",
            Hex(before, 2),
            Hex(GUMMI_COST_LIMIT_OFFSET, 5),
            Hex(GUMMI_COST_LIMIT_MAX_SAFE_LEVEL, 2)
        ))
    end

    if before == GUMMI_COST_LIMIT_MAX_SAFE_LEVEL then
        if not PatchReported then
            ConsolePrint(string.format(
                "Gummi Cost Limit gia al massimo sicuro: %d.",
                GUMMI_COST_LIMIT_MAX_SAFE_TOTAL
            ), 1)
            ConsolePrint(
                "Inventario blocchi, missioni e limite Teeny Ship restano invariati.",
                2
            )
            PatchReported = true
        end
        return
    end

    -- Re-read immediately before the write so another mod cannot change the
    -- field between inspection and application without being detected.
    local current = ReadByte(address)

    if current ~= before then
        error(string.format(
            "Cost Limit cambiato prima della patch: %s -> %s",
            Hex(before, 2),
            Hex(current, 2)
        ))
    end

    WriteByte(address, GUMMI_COST_LIMIT_MAX_SAFE_LEVEL)

    local after = ReadByte(address)

    if after ~= GUMMI_COST_LIMIT_MAX_SAFE_LEVEL then
        error(string.format(
            "verifica fallita a Save+%s: atteso %s, trovato %s",
            Hex(GUMMI_COST_LIMIT_OFFSET, 5),
            Hex(GUMMI_COST_LIMIT_MAX_SAFE_LEVEL, 2),
            Hex(after, 2)
        ))
    end

    ConsolePrint(string.format(
        "Gummi Cost Limit: livello %d -> %d, massimo sicuro %d.",
        before,
        after,
        GUMMI_COST_LIMIT_MAX_SAFE_TOTAL
    ), 1)
    ConsolePrint(
        "Inventario blocchi, missioni e limite Teeny Ship restano invariati; salvando, il valore persiste.",
        2
    )
    PatchReported = true
end

function _OnInit()
    CanExecute = false
    PatchDisabled = false
    PatchReported = false
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
        "Gummi Cost Limit inizializzato: attendo una save Sora caricata.",
        1
    )
end

function _OnFrame()
    if not CanExecute or PatchDisabled then
        return
    end

    local readyOk, readyOrError = pcall(IsLoadedSoraSave)

    if not readyOk then
        if not ErrorReported then
            ConsolePrint(
                "Errore controllo Gummi Cost Limit: "
                .. tostring(readyOrError),
                3
            )
            ErrorReported = true
        end
        return
    end

    if not readyOrError then
        PatchReported = false
        ErrorReported = false
        return
    end

    local patchOk, patchError = pcall(EnsureGummiCostLimit)

    if not patchOk then
        ConsolePrint(
            "Errore Gummi Cost Limit; modulo disabilitato fino a F1: "
            .. tostring(patchError),
            3
        )
        ErrorReported = true
        PatchDisabled = true
        return
    end

    ErrorReported = false
end
