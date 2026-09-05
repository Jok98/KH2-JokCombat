LUAGUI_NAME = "KH2 JokCombat - Roxas Dual Wield"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Enables native Roxas Dual-Wield and replaces Struggle Wand with Oblivion"

local RawConsolePrint = ConsolePrint
local LoggerLoaded, Logger = pcall(require, "KH2JokCombat_Log")
if not LoggerLoaded then
    LoggerLoaded, Logger = pcall(require, "runtime.KH2JokCombat_Log")
end
local LoggerLoadError = LoggerLoaded and nil or Logger

local function ConsolePrint(message, level)
    local category = level ~= nil and level >= 3 and "ERROR" or "SYSTEM"

    if LoggerLoaded then
        return Logger.Log("RoxasDualWield", category, message, level)
    end

    if category == "ERROR" then
        RawConsolePrint(
            "[RoxasDualWield][ERROR] " .. tostring(message),
            level or 3
        )
    end
end

local function ReportLoggerFailure()
    if not LoggerLoaded then
        RawConsolePrint(
            "[RoxasDualWield][ERROR] KH2JokCombat_Log non disponibile: "
            .. tostring(LoggerLoadError),
            3
        )
    end
end

local kh2lib = nil
local CanExecute = false
local MemtPatchCompleted = false
local WeaponPatchCompleted = false
local MemtErrorReported = false
local WeaponErrorReported = false

local ROXAS_NORMAL_OBJECT_ID = 0x005A
local ROXAS_DUAL_WIELD_OBJECT_ID = 0x0323

local STRUGGLE_WAND_ITEM_ID = 0x01F5
local OBLIVION_ITEM_ID = 0x002B

local TARGET_MEMT_INDEX = 3
local MEMT_VERSION = 5
local MEMT_ENTRY_SIZE_FINAL_MIX = 0x34
local MEMT_MEMBER_INDEX_TABLE_COUNT = 7

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

-- Resolves one subfile from a BAR already loaded at an absolute PC address.
local function GetLoadedBarSubfile(fileAddress, subfileNumber)
    if ReadInt(fileAddress, true) ~= 0x01524142 then
        error("BAR header non valido a " .. Hex(fileAddress, 16))
    end

    local subfileCount = ReadInt(fileAddress + 0x04, true)

    if subfileNumber < 1 or subfileNumber > subfileCount then
        error(string.format(
            "BAR subfile fuori range: %d (count=%d)",
            subfileNumber,
            subfileCount
        ))
    end

    local subpoint = fileAddress + 0x08 + 0x10 * subfileNumber
    local relocatedOffset = ReadInt(subpoint, true)
    local subfileLength = ReadInt(subpoint + 0x04, true)
    local runtimeLookupBase = ReadInt(fileAddress + 0x08, true)

    return fileAddress + (relocatedOffset - runtimeLookupBase), subfileLength
end

-- Finds the Final Mix MEMT structurally inside the loaded 03system.bin.
local function FindLoadedMemt()
    local sys3 = ReadLong(kh2lib.Sys3Pointer)

    if not sys3 or sys3 == 0 then
        return nil, "03system.bin non ancora caricato"
    end

    if ReadInt(sys3, true) ~= 0x01524142 then
        return nil, "Sys3Pointer non punta a un BAR valido: " .. Hex(sys3, 16)
    end

    local subfileCount = ReadInt(sys3 + 0x04, true)

    for subfileNumber = 1, subfileCount do
        local subfileAddress, subfileLength =
            GetLoadedBarSubfile(sys3, subfileNumber)

        if subfileLength >= 0x24 then
            local version = ReadInt(subfileAddress, true)
            local entryCount = ReadInt(subfileAddress + 0x04, true)

            if version == MEMT_VERSION and entryCount > 0 and entryCount < 512 then
                local expectedLength =
                    0x08
                    + entryCount * MEMT_ENTRY_SIZE_FINAL_MIX
                    + MEMT_MEMBER_INDEX_TABLE_COUNT * 0x04

                if expectedLength == subfileLength then
                    return {
                        address = subfileAddress,
                        entryCount = entryCount,
                        subfileNumber = subfileNumber
                    }
                end
            end
        end
    end

    return nil, "MEMT Final Mix non trovata nel 03system.bin caricato"
end

local function ApplyRoxasDualWield()
    local memt, memtError = FindLoadedMemt()

    if not memt then
        return false, memtError
    end

    if TARGET_MEMT_INDEX >= memt.entryCount then
        error(string.format(
            "MEMT Index %d fuori range (count=%d)",
            TARGET_MEMT_INDEX,
            memt.entryCount
        ))
    end

    local entryAddress =
        memt.address
        + 0x08
        + TARGET_MEMT_INDEX * MEMT_ENTRY_SIZE_FINAL_MIX

    -- Safety guard: Index 3 must still be the native Simulated Twilight Town
    -- Roxas entry that was identified during the read-only probe.
    local world = ReadShort(entryAddress + 0x00, true)
    local story = ReadShort(entryAddress + 0x02, true)
    local storyNeg = ReadShort(entryAddress + 0x04, true)
    local area = ReadByte(entryAddress + 0x06, true)

    if world ~= 0x0002
        or story ~= 0x08DB
        or storyNeg ~= 0x08D0
        or area ~= 0x00 then

        error(string.format(
            "Firma MEMT Index 3 inattesa: World=%s Story=%s StoryNeg=%s Area=%s",
            Hex(world, 4),
            Hex(story, 4),
            Hex(storyNeg, 4),
            Hex(area, 2)
        ))
    end

    local playerAddress = entryAddress + 0x10
    local before = ReadShort(playerAddress, true)

    if before == ROXAS_DUAL_WIELD_OBJECT_ID then
        ConsolePrint(
            "Roxas Dual-Wield gia attivo: MEMT Index 3 Player=0x0323.",
            1
        )
        MemtPatchCompleted = true
        return true
    end

    if before ~= ROXAS_NORMAL_OBJECT_ID then
        error(
            "MEMT Index 3 Player inatteso: "
            .. Hex(before, 4)
            .. " (atteso 0x005A)"
        )
    end

    WriteShort(
        playerAddress,
        ROXAS_DUAL_WIELD_OBJECT_ID,
        true
    )

    local after = ReadShort(playerAddress, true)

    if after ~= ROXAS_DUAL_WIELD_OBJECT_ID then
        error(
            "Verifica write fallita: Player="
            .. Hex(after, 4)
        )
    end

    ConsolePrint(string.format(
        "Roxas Dual-Wield attivato: MEMT Index=%d Player=%s -> %s BARSubfile=%d",
        TARGET_MEMT_INDEX,
        Hex(before, 4),
        Hex(after, 4),
        memt.subfileNumber
    ), 1)

    MemtPatchCompleted = true
    return true
end


local function ApplyOblivion()
    local weaponAddress = kh2lib.Save + 0x24F0
    local before = ReadShort(weaponAddress)

    -- Do not touch any other equipped weapon. During the Roxas prologue,
    -- 0x01F5 is the Struggle Wand. We wait until that exact value appears.
    if before == OBLIVION_ITEM_ID then
        WeaponPatchCompleted = true
        return true
    end

    if before ~= STRUGGLE_WAND_ITEM_ID then
        return false
    end

    WriteShort(
        weaponAddress,
        OBLIVION_ITEM_ID
    )

    local after = ReadShort(weaponAddress)

    if after ~= OBLIVION_ITEM_ID then
        error(
            "Verifica weapon write fallita: EquippedKeyblade="
            .. Hex(after, 4)
        )
    end

    ConsolePrint(string.format(
        "Roxas weapon sostituita: Struggle Wand %s -> Oblivion %s",
        Hex(before, 4),
        Hex(after, 4)
    ), 1)

    WeaponPatchCompleted = true
    return true
end

function _OnInit()
    ReportLoggerFailure()
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

    MemtPatchCompleted = false
    WeaponPatchCompleted = false
    MemtErrorReported = false
    WeaponErrorReported = false

    ConsolePrint("Roxas Dual-Wield runtime module inizializzato.", 1)
end

function _OnFrame()
    if not CanExecute then
        return
    end

    if not MemtPatchCompleted then
        local ok, resultOrError = pcall(ApplyRoxasDualWield)

        if not ok then
            if not MemtErrorReported then
                ConsolePrint(
                    "Errore Roxas Dual-Wield: " .. tostring(resultOrError),
                    3
                )
                MemtErrorReported = true
            end
        elseif resultOrError == true then
            MemtErrorReported = false
        end
    end

    if not WeaponPatchCompleted then
        local ok, resultOrError = pcall(ApplyOblivion)

        if not ok then
            if not WeaponErrorReported then
                ConsolePrint(
                    "Errore Roxas Oblivion: " .. tostring(resultOrError),
                    3
                )
                WeaponErrorReported = true
            end
        elseif resultOrError == true then
            WeaponErrorReported = false
        end
    end
end
