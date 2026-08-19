LUAGUI_NAME = "KH2 JokCombat - Roxas Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Probe read-only per osservare KH2 e identificare le entry MEMT di Roxas (absolute-pointer fix)"

local CanExecute = false
local kh2lib = nil

local LastContextKey = nil
local SnapshotNumber = 0
local ReadErrorReported = false
local MemtScanCompleted = false
local MemtScanErrorReported = false

local ROXAS_NORMAL_OBJECT_ID = 0x005A
local ROXAS_DUAL_WIELD_OBJECT_ID = 0x0323

local MEMT_VERSION = 5
local MEMT_ENTRY_SIZE_FINAL_MIX = 0x34
local MEMT_MEMBER_COUNT_FINAL_MIX = 18
local MEMT_MEMBER_INDEX_TABLE_COUNT = 7


-- Converts a number to an uppercase hexadecimal string for logging.
-- Examples:
--   Hex(10, 2)                         -> "0x0A"
--   1 byte  = 2 hex digits:
--     Hex(state.world, 2)              -> "0x02"
--   1 short (16 bits) = 4 hex digits:
--     Hex(state.event, 4)              -> "0x001A"
--
-- Fixed-width hex values make KH2 IDs and snapshots easier to compare.
--
-- If width = 2, the format specifier is "%02X":
--   % -> starts the placeholder
--   0 -> pads the value with leading zeros
--   2 -> requires at least 2 digits
--   X -> converts the value to uppercase hexadecimal
--
-- If value is nil, `value or 0` uses 0.

local function Hex(value, width)
	return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end


-- Resolves one BAR sub-file from a BAR already loaded in KH2 memory.
-- `fileAddress` is an absolute process address on PC, so every dereference
-- in this helper uses Absolute=true.
-- The game relocates the BAR lookup address at runtime, so this follows
-- the same address calculation used by established KH2 Lua mods.
--
-- `subfileNumber` is 1-based here:
--   1 = BAR entry index 0
--   2 = BAR entry index 1
--   ...
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

    -- At runtime +0x08 is used as the BAR relocation/lookup base.
    -- For a 1-based subfile number, +0x08 + 0x10*N points to that
    -- entry's relocated offset field; +0x04 from there is its size.
    local subpoint = fileAddress + 0x08 + 0x10 * subfileNumber
    local relocatedOffset = ReadInt(subpoint, true)
    local subfileLength = ReadInt(subpoint + 0x04, true)
    local runtimeLookupBase = ReadInt(fileAddress + 0x08, true)

    return fileAddress + (relocatedOffset - runtimeLookupBase), subfileLength
end


-- Finds MEMT inside the currently loaded 03system.bin without assuming a
-- hard-coded BAR entry index. A Final Mix MEMT is identified by:
--   version 5
--   52-byte entries
--   7 trailing 4-byte MemberIndices records
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
        local subfileAddress, subfileLength = GetLoadedBarSubfile(sys3, subfileNumber)

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
                        sys3 = sys3,
                        address = subfileAddress,
                        length = subfileLength,
                        subfileNumber = subfileNumber,
                        entryCount = entryCount
                    }
                end
            end
        end
    end

    return nil, "MEMT Final Mix non trovata nel 03system.bin caricato"
end


local function ReadMemtMembers(entryAddress)
    local members = {}

    for memberIndex = 0, MEMT_MEMBER_COUNT_FINAL_MIX - 1 do
        members[memberIndex + 1] = ReadShort(
            entryAddress + 0x10 + memberIndex * 0x02,
            true
        )
    end

    return members
end


local function FormatMemtMembers(members)
    local parts = {}

    for index = 1, #members do
        parts[#parts + 1] = Hex(members[index], 4)
    end

    return table.concat(parts, ",")
end


-- Dumps only MEMT entries whose normal-player member is Roxas (0x005A)
-- or native Dual-Wield Roxas (0x0323). No memory is written.
local function ScanRoxasMemtEntries()
    local memt, memtError = FindLoadedMemt()

    if not memt then
        return false, memtError
    end

    LogMessage(string.format(
        "MEMT FOUND Sys3=%s MEMT=%s BARSubfile=%d EntryCount=%d Length=%s",
        Hex(memt.sys3, 16),
        Hex(memt.address, 16),
        memt.subfileNumber,
        memt.entryCount,
        Hex(memt.length, 8)
    ))

    local relevantCount = 0

    for index = 0, memt.entryCount - 1 do
        local entryAddress =
            memt.address
            + 0x08
            + index * MEMT_ENTRY_SIZE_FINAL_MIX

        local members = ReadMemtMembers(entryAddress)
        local playerObjectId = members[1]

        if playerObjectId == ROXAS_NORMAL_OBJECT_ID
            or playerObjectId == ROXAS_DUAL_WIELD_OBJECT_ID then

            relevantCount = relevantCount + 1

            LogMessage(string.format(
                "MEMT ROXAS Index=%d World=%s Story=%s StoryNeg=%s Area=%s Player=%s",
                index,
                Hex(ReadShort(entryAddress + 0x00, true), 4),
                Hex(ReadShort(entryAddress + 0x02, true), 4),
                Hex(ReadShort(entryAddress + 0x04, true), 4),
                Hex(ReadByte(entryAddress + 0x06, true), 2),
                Hex(playerObjectId, 4)
            ))

            Log(string.format(
                "MEMT MEMBERS Index=%d [%s]",
                index,
                FormatMemtMembers(members)
            ))

            Log(string.format(
                "MEMT SIZES Index=%d PlayerSize=%s FriendSize=%s",
                index,
                Hex(ReadInt(entryAddress + 0x08, true), 8),
                Hex(ReadInt(entryAddress + 0x0C, true), 8)
            ))
        end
    end

    LogSuccess(string.format(
        "MEMT scan completata: %d entry Roxas/Dual-Wield trovate.",
        relevantCount
    ))

    return true
end


-- Reads a read-only snapshot of the current KH2 runtime state.
-- Memory addresses are calculated as: base address + field offset.
--
-- `kh2lib.Now` contains location, map, battle and event data.
-- `kh2lib.Slot1` contains stats for unit slot 1, normally the player.
--
-- `place` and `previousPlace` combine room and world as 0xRRWW.
-- The returned table can be accessed with `state.world`, `state.event`, etc.
local function ReadState()
	-- This byte contains multiple story flags.
    -- Bit 0: 0 = play as Roxas, 1 = play as Sora.
    local storyFlags = ReadByte(kh2lib.Save + 0x1CEA)
	
    return {
        world = ReadByte(kh2lib.Now + 0x00),
        room = ReadByte(kh2lib.Now + 0x01),
        place = ReadShort(kh2lib.Now + 0x00),
        door = ReadShort(kh2lib.Now + 0x02),
        map = ReadShort(kh2lib.Now + 0x04),
        battle = ReadShort(kh2lib.Now + 0x06),
        event = ReadShort(kh2lib.Now + 0x08),
        previousPlace = ReadShort(kh2lib.Now + 0x30),

        pause = ReadByte(kh2lib.Pause),
        control = ReadByte(kh2lib.Cntrl),
        battleType = ReadByte(kh2lib.BtlTyp),
        reaction = ReadShort(kh2lib.React),
        openMenu = ReadByte(kh2lib.CurrentOpenMenu),
		storyFlags = storyFlags,
        soraStoryFlag = storyFlags & 0x01,
        currentForm = ReadByte(kh2lib.Save + 0x3524),
        partyLayout = ReadInt(kh2lib.Save + 0x353C),
        unitCharacterId = ReadShort(kh2lib.Slot1 + 0x260),
        mainKeybladeId = ReadShort(kh2lib.Save + 0x24F0),

        hpCurrent = ReadInt(kh2lib.Slot1 + 0x000),
        hpMax = ReadInt(kh2lib.Slot1 + 0x004),
        mpCurrent = ReadInt(kh2lib.Slot1 + 0x180),
        mpMax = ReadInt(kh2lib.Slot1 + 0x184),
        drivePercent = ReadByte(kh2lib.Slot1 + 0x1B0),
        driveCurrent = ReadByte(kh2lib.Slot1 + 0x1B1),
        driveMax = ReadByte(kh2lib.Slot1 + 0x1B2)
    }
end
	


-- Builds a key from every state value that should trigger a snapshot.
-- When one component changes, the resulting string also changes.
local function BuildContextKey(state)
    return string.format(
        "%04X:%04X:%04X:%04X:%04X:%04X:%02X:%02X:%02X:%02X:%02X:%02X:%08X:%04X:%04X",
        state.place,
        state.door,
        state.map,
        state.battle,
        state.event,
        state.previousPlace,
        state.pause,
        state.control,
        state.battleType,
        state.openMenu,
        state.soraStoryFlag,
        state.currentForm,
        state.partyLayout,
        state.unitCharacterId,
        state.mainKeybladeId
    )
end


-- Logs a numbered snapshot of the current game state.
-- `state` comes from ReadState(); `reason` describes why it was logged.
-- This function only updates SnapshotNumber and prints to the console;
local function LogSnapshot(state, reason)
    SnapshotNumber = SnapshotNumber + 1

    LogMessage(string.format(
        "SNAPSHOT #%03d [%s]",
        SnapshotNumber,
        reason
    ))

    Log(string.format(
        "LOCATION World=%s Room=%s Place=%s Door=%s Map=%s Battle=%s Event=%s PreviousPlace=%s",
        Hex(state.world, 2),
        Hex(state.room, 2),
        Hex(state.place, 4),
        Hex(state.door, 4),
        Hex(state.map, 4),
        Hex(state.battle, 4),
        Hex(state.event, 4),
        Hex(state.previousPlace, 4)
    ))

    Log(string.format(
        "MODE Pause=%s Control=%s BattleType=%s Reaction=%s OpenMenu=%s",
        Hex(state.pause, 2),
        Hex(state.control, 2),
        Hex(state.battleType, 2),
        Hex(state.reaction, 4),
        Hex(state.openMenu, 2)
    ))
	
	    Log(string.format(
        "IDENTITY StoryFlags=%s SoraFlag=%s Form=%s Party=%s UnitCharacter=%s MainKeyblade=%s",
        Hex(state.storyFlags, 2),
        Hex(state.soraStoryFlag, 2),
        Hex(state.currentForm, 2),
        Hex(state.partyLayout, 8),
        Hex(state.unitCharacterId, 4),
        Hex(state.mainKeybladeId, 4)
    ))

    Log(string.format(
        "SLOT1 HP=%d/%d MP=%d/%d Drive=%d/%d Gauge=%d",
        state.hpCurrent,
        state.hpMax,
        state.mpCurrent,
        state.mpMax,
        state.driveCurrent,
        state.driveMax,
        state.drivePercent
    ))
end



-- Called by LuaBackend when the script loads and again after an F1 reload.
-- Loads kh2lib and checks library and game compatibility.
-- Sets CanExecute and resets the internal probe state.
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

    LastContextKey = nil
    SnapshotNumber = 0
    ReadErrorReported = false
    MemtScanCompleted = false
    MemtScanErrorReported = false

    LogSuccess("Roxas Probe read-only inizializzata.")
    LogMessage("Game version = " .. tostring(kh2lib.GameVersionString))
    LogMessage("Nessuna WriteByte/WriteShort/WriteInt e attiva.")
end


-- Called repeatedly by LuaBackend at the configured execution frequency.
-- Stops immediately if initialization or compatibility checks failed.
-- Safely reads the game state and reports each continuous read error only once.
-- Logs a snapshot only when the context key changes.
function _OnFrame()
    if not CanExecute then
        return
    end

    local readSucceeded, stateOrError = pcall(ReadState)

    if not readSucceeded then
        if not ReadErrorReported then
            LogError("Errore durante la lettura: " .. tostring(stateOrError))
            ReadErrorReported = true
        end

        return
    end

    ReadErrorReported = false

    local state = stateOrError

    -- Once KH2 has entered a real world, inspect the loaded MEMT exactly once.
    -- If 03system.bin is not ready yet, retry on subsequent frames.
    if not MemtScanCompleted and state.world ~= 0xFF then
        local scanSucceeded, scanResult, scanError = pcall(ScanRoxasMemtEntries)

        if scanSucceeded and scanResult == true then
            MemtScanCompleted = true
            MemtScanErrorReported = false
        elseif scanSucceeded then
            if not MemtScanErrorReported then
                LogWarning("MEMT scan rimandata: " .. tostring(scanError))
                MemtScanErrorReported = true
            end
        else
            if not MemtScanErrorReported then
                LogError("Errore MEMT scan: " .. tostring(scanResult))
                MemtScanErrorReported = true
            end
        end
    end

    local contextKey = BuildContextKey(state)

    if contextKey ~= LastContextKey then
        local reason = LastContextKey == nil and "INITIAL" or "STATE_CHANGE"
        LastContextKey = contextKey
        LogSnapshot(state, reason)
    end
end