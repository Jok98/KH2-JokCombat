LUAGUI_NAME = "KH2 JokCombat - Roxas Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Probe read-only per osservare lo stato di KH2"

local CanExecute = false
local kh2lib = nil

local LastContextKey = nil
local SnapshotNumber = 0
local ReadErrorReported = false


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
    local contextKey = BuildContextKey(state)

    if contextKey ~= LastContextKey then
        local reason = LastContextKey == nil and "INITIAL" or "STATE_CHANGE"
        LastContextKey = contextKey
        LogSnapshot(state, reason)
    end
end
