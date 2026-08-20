LUAGUI_NAME = "KH2 JokCombat - Movement"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Movement prototype - High Jump MAX only"

local kh2lib = nil
local CanExecute = false
local PatchCompleted = false
local ErrorReported = false

local HIGH_JUMP_SLOT_OFFSET = 0x25CE
local HIGH_JUMP_LV1 = 0x005E
local HIGH_JUMP_MAX = 0x0061
local HIGH_JUMP_MAX_EQUIPPED = 0x8061

local ABILITY_ID_MASK = 0x0FFF
local EQUIPPED_FLAG = 0x8000

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function IsGameplayReady()
    local world = ReadByte(kh2lib.Now + 0x00)
    local room = ReadByte(kh2lib.Now + 0x01)
    local maxHp = ReadInt(kh2lib.Slot1 + 0x004)

    return world ~= 0xFF
        and room ~= 0xFF
        and maxHp > 0
end

local function ApplyHighJumpMax()
    if not IsGameplayReady() then
        return false
    end

    local address = kh2lib.Save + HIGH_JUMP_SLOT_OFFSET
    local before = ReadShort(address)
    local abilityId = before & ABILITY_ID_MASK

    if before == HIGH_JUMP_MAX_EQUIPPED then
        ConsolePrint(
            "High Jump MAX gia presente ed equipaggiato: "
            .. Hex(before, 4),
            1
        )

        PatchCompleted = true
        return true
    end

    -- This is a dedicated growth slot. Accept either an empty slot or
    -- an existing High Jump level, but refuse to overwrite unrelated data.
    if before ~= 0
        and (abilityId < HIGH_JUMP_LV1 or abilityId > HIGH_JUMP_MAX) then

        error(
            "Save+0x25CE contiene un valore inatteso: "
            .. Hex(before, 4)
        )
    end

    WriteShort(address, HIGH_JUMP_MAX_EQUIPPED)

    local after = ReadShort(address)

    if after ~= HIGH_JUMP_MAX_EQUIPPED then
        error(
            "Verifica High Jump MAX fallita: "
            .. Hex(after, 4)
        )
    end

    ConsolePrint(string.format(
        "High Jump MAX attivato: Save+0x25CE %s -> %s",
        Hex(before, 4),
        Hex(after, 4)
    ), 1)

    ConsolePrint(
        "Test corrente: SOLO High Jump MAX. Nessun'altra growth ability modificata.",
        0
    )

    ConsolePrint(
        "Nota: il valore e nella save RAM; salvando la partita puo diventare persistente.",
        2
    )

    PatchCompleted = true
    return true
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

    PatchCompleted = false
    ErrorReported = false

    ConsolePrint(
        "Movement module inizializzato: High Jump MAX test.",
        1
    )
end

function _OnFrame()
    if not CanExecute or PatchCompleted then
        return
    end

    local ok, resultOrError = pcall(ApplyHighJumpMax)

    if not ok then
        if not ErrorReported then
            ConsolePrint(
                "Errore Movement/High Jump: "
                .. tostring(resultOrError),
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
