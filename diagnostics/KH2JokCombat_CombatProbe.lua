LUAGUI_NAME = "KH2 JokCombat - Combat Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Probe read-only per ownership input A/Y/Quadrato/R2 e contesto combat di Sora"

local RawConsolePrint = ConsolePrint
local LoggerLoaded, Logger = pcall(require, "KH2JokCombat_Log")
if not LoggerLoaded then
    LoggerLoaded, Logger = pcall(require, "runtime.KH2JokCombat_Log")
end
local LoggerLoadError = LoggerLoaded and nil or Logger

local CanExecute = false
local kh2lib = nil

local FrameNumber = 0
local EventNumber = 0
local ContextNumber = 0
local LastInputRaw = nil
local LastR2Signal = nil
local LastCalibratedInput = nil
local LastContextKey = nil
local LastLiveStateKey = nil
local WasReady = false
local ReadErrorReported = false
local PlayerPointerAddress = nil
local LiveEventNumber = 0

-- Controlled gameplay calibration on Steam 1.0.0.10 showed that physical A,
-- Y and Square each set a two-bit raw32 fingerprint. The old PS2-style low16
-- labels were therefore misleading for this controller path and are not used
-- for ownership anymore.
local RAW32_A_MASK = 0x08000004
local RAW32_Y_MASK = 0x02000400
local RAW32_SQUARE_MASK = 0x04000200
local RAW32_DPAD_UP = 0x00004010
local RAW32_DPAD_RIGHT = 0x00008020
local RAW32_DPAD_DOWN = 0x00010040
local RAW32_DPAD_LEFT = 0x10000080
local R2_SIGNAL_OFFSET = 0x04
local R2_SIGNAL_HELD = 0x09

-- Verified on the user's retail Steam 1.0.0.10 executable by resolving the
-- current Sora global from the executable signature, then correlating the
-- fields below against idle, native A chains, Guard and repeated jumps.  No
-- other game version is allowed to use these offsets without its own proof.
local KH2_VERSION_STEAM_1_0_0_10_VALUE = 0x030A
local SORA_POINTER_STEAM_1_0_0_10 = 0x02AE9A28
local SORA_MOTION_ID_OFFSET = 0x0180
local SORA_MOTION_SLOT_OFFSET = 0x0184
local SORA_GROUND_STATE_OFFSET = 0x0740
local SORA_GROUND_SUBSTATE_OFFSET = 0x0744
local SORA_AIR_STATE_OFFSET = 0x0790

local BASE_MOTION_NAMES = {
    [0x0000] = "NEUTRAL",
    [0x0004] = "AIRBORNE_FALL",
    [0x0005] = "LANDING",
    [0x0097] = "A300",
    [0x0098] = "A301",
    [0x0099] = "A302",
    [0x009A] = "A303_FINISHER",
    [0x009B] = "A304_FINISHER",
    [0x00A1] = "A310_UPPER_SLASH",
    [0x00A2] = "A311_SLAPSHOT",
    [0x00A3] = "A312_DODGE_SLASH",
    [0x00A4] = "A313_SLIDE_DASH",
    [0x00A5] = "A314_GUARD_BREAK",
    [0x00A6] = "A315_EXPLOSION",
    [0x00A7] = "A316_FINISHING_LEAP",
    [0x00A9] = "A318_FLASH_STEP",
    [0x00AA] = "A319_VICINITY_BREAK",
    [0x00AB] = "A317_COUNTERGUARD",
    [0x00AD] = "A322_GUARD",
    [0x00C9] = "JUMP_START",
    [0x00CA] = "JUMP_CONTINUE"
}

local DPAD_FINGERPRINT_NAMES = {
    [RAW32_DPAD_UP] = "UP",
    [RAW32_DPAD_RIGHT] = "RIGHT",
    [RAW32_DPAD_DOWN] = "DOWN",
    [RAW32_DPAD_LEFT] = "LEFT"
}

local CALIBRATED_A = 0x01
local CALIBRATED_Y = 0x02
local CALIBRATED_R2 = 0x04
local CALIBRATED_SQUARE = 0x08

local REQUIRED_LIBRARY_ADDRESSES = {
    "Input",
    "React",
    "Pause",
    "Cntrl",
    "BtlTyp",
    "CurrentOpenMenu",
    "Now",
    "Save",
    "Slot1",
    "GameVersion"
}

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function HexPointer(value)
    return string.format("0x%016X", value or 0)
end

local function ProbeLog(message, level)
    local category = level ~= nil and level >= 3 and "ERROR" or "PROBE"

    if LoggerLoaded then
        return Logger.Log("CombatProbe", category, message, level)
    end

    if category == "ERROR" then
        RawConsolePrint(
            "[CombatProbe][ERROR] " .. tostring(message),
            level or 3
        )
    end
end

local function ReportLoggerFailure()
    if not LoggerLoaded then
        RawConsolePrint(
            "[CombatProbe][ERROR] KH2JokCombat_Log non disponibile: "
            .. tostring(LoggerLoadError),
            3
        )
    end
end

local function HasButton(mask, button)
    return (mask & button) == button
end

local function FormatRawBits(mask, bitCount)
    local names = {}
    local width = bitCount or 16

    for bit = 0, width - 1 do
        if HasButton(mask, 1 << bit) then
            names[#names + 1] = string.format("B%02d", bit)
        end
    end

    if #names == 0 then
        return "NONE"
    end

    return table.concat(names, "+")
end

local function FormatDpadFingerprint(raw32)
    return DPAD_FINGERPRINT_NAMES[raw32] or "NONE"
end

local function BuildCalibratedInput(raw32, r2Signal)
    local calibrated = 0

    if HasButton(raw32, RAW32_A_MASK) then
        calibrated = calibrated | CALIBRATED_A
    end

    if HasButton(raw32, RAW32_Y_MASK) then
        calibrated = calibrated | CALIBRATED_Y
    end

    if HasButton(raw32, RAW32_SQUARE_MASK) then
        calibrated = calibrated | CALIBRATED_SQUARE
    end

    -- Gameplay confirmed that Input+0x04 remains exactly 0x09 while each
    -- D-pad direction changes raw32 independently. UI values differ, so every
    -- unknown signal still fails closed.
    if r2Signal == R2_SIGNAL_HELD then
        calibrated = calibrated | CALIBRATED_R2
    end

    return calibrated
end

local function FormatCalibratedInput(mask)
    local names = {}

    if HasButton(mask, CALIBRATED_A) then
        names[#names + 1] = "A(Cross)"
    end

    if HasButton(mask, CALIBRATED_Y) then
        names[#names + 1] = "Y(Triangle)"
    end

    if HasButton(mask, CALIBRATED_R2) then
        names[#names + 1] = "R2"
    end

    if HasButton(mask, CALIBRATED_SQUARE) then
        names[#names + 1] = "Square"
    end

    if #names == 0 then
        return "NONE"
    end

    return table.concat(names, "+")
end

local function ValidateLibraryAddresses()
    for _, fieldName in ipairs(REQUIRED_LIBRARY_ADDRESSES) do
        if type(kh2lib[fieldName]) ~= "number" then
            return false, fieldName
        end
    end

    return true
end

local function ClassifyGroundAir(state)
    if state.playerPointer == 0 then
        return "UNKNOWN_NO_PLAYER_POINTER"
    end

    if state.groundState == 0x02
        and state.groundSubstate == 0x00
        and state.airState == 0x00
    then
        return "GROUND"
    end

    if state.groundState == 0x03
        and state.groundSubstate ~= 0x00
        and state.airState ~= 0x00
    then
        return "AIR"
    end

    return string.format(
        "UNKNOWN(%s/%s/%s)",
        Hex(state.groundState, 8),
        Hex(state.groundSubstate, 8),
        Hex(state.airState, 8)
    )
end

local function FormatMotion(state)
    if state.playerPointer == 0 then
        return "UNKNOWN"
    end

    local name = BASE_MOTION_NAMES[state.motionId] or "UNMAPPED"

    return string.format(
        "%s[%s] Slot=%s",
        Hex(state.motionId, 4),
        name,
        Hex(state.motionSlot, 4)
    )
end

local function ReadState()
    local storyFlags = ReadByte(kh2lib.Save + 0x1CEA)
    local inputRaw = ReadInt(kh2lib.Input) & 0xFFFFFFFF
    local playerPointer = 0

    if PlayerPointerAddress ~= nil then
        playerPointer = ReadLong(PlayerPointerAddress)
    end

    local motionId = 0
    local motionSlot = 0
    local groundState = 0
    local groundSubstate = 0
    local airState = 0

    if playerPointer ~= 0 then
        motionId = ReadInt(
            playerPointer + SORA_MOTION_ID_OFFSET,
            true
        )
        motionSlot = ReadInt(
            playerPointer + SORA_MOTION_SLOT_OFFSET,
            true
        )
        groundState = ReadInt(
            playerPointer + SORA_GROUND_STATE_OFFSET,
            true
        )
        groundSubstate = ReadInt(
            playerPointer + SORA_GROUND_SUBSTATE_OFFSET,
            true
        )
        airState = ReadInt(
            playerPointer + SORA_AIR_STATE_OFFSET,
            true
        )
    end

    return {
        inputRaw = inputRaw,
        input = inputRaw & 0xFFFF,
        inputHigh = (inputRaw >> 16) & 0xFFFF,
        r2Signal = ReadByte(kh2lib.Input + R2_SIGNAL_OFFSET) & 0xFF,

        world = ReadByte(kh2lib.Now + 0x00),
        room = ReadByte(kh2lib.Now + 0x01),
        map = ReadShort(kh2lib.Now + 0x04),
        battle = ReadShort(kh2lib.Now + 0x06),
        event = ReadShort(kh2lib.Now + 0x08),

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

        hpMax = ReadInt(kh2lib.Slot1 + 0x004),
        drivePercent = ReadByte(kh2lib.Slot1 + 0x1B0),
        driveCurrent = ReadByte(kh2lib.Slot1 + 0x1B1),
        driveMax = ReadByte(kh2lib.Slot1 + 0x1B2),

        baseKeyblade = ReadShort(kh2lib.Save + 0x24F0),
        valorKeyblade = ReadShort(kh2lib.Save + 0x32F4),
        wisdomKeyblade = ReadShort(kh2lib.Save + 0x332C),
        limitKeyblade = ReadShort(kh2lib.Save + 0x3364),
        masterKeyblade = ReadShort(kh2lib.Save + 0x339C),
        finalKeyblade = ReadShort(kh2lib.Save + 0x33D4),

        playerPointer = playerPointer,
        motionId = motionId,
        motionSlot = motionSlot,
        groundState = groundState,
        groundSubstate = groundSubstate,
        airState = airState
    }
end

local function IsSoraReady(state)
    return state.world ~= 0xFF
        and state.hpMax > 0
        and state.soraStoryFlag == 0x01
end

local function BuildContextKey(state)
    return string.format(
        "%02X:%02X:%04X:%04X:%04X:%02X:%02X:%02X:%04X:%02X:%02X:%08X:%04X:%04X:%04X:%04X:%04X:%04X:%04X:%02X:%02X",
        state.world,
        state.room,
        state.map,
        state.battle,
        state.event,
        state.pause,
        state.control,
        state.battleType,
        state.reaction,
        state.openMenu,
        state.currentForm,
        state.partyLayout,
        state.unitCharacterId,
        state.baseKeyblade,
        state.valorKeyblade,
        state.wisdomKeyblade,
        state.limitKeyblade,
        state.masterKeyblade,
        state.finalKeyblade,
        state.driveCurrent,
        state.driveMax
    )
end

local function BuildLiveStateKey(state)
    return string.format(
        "%016X:%08X:%08X:%08X:%08X:%08X:%04X",
        state.playerPointer,
        state.motionId,
        state.motionSlot,
        state.groundState,
        state.groundSubstate,
        state.airState,
        state.reaction
    )
end

local function LogLiveState(state, reason)
    LiveEventNumber = LiveEventNumber + 1

    ProbeLog(string.format(
        "LIVE #%03d frame=%d reason=%s Player=%s Motion=%s GroundAir=%s GroundRaw=%s/%s/%s Reaction=%s Input=%s",
        LiveEventNumber,
        FrameNumber,
        reason,
        HexPointer(state.playerPointer),
        FormatMotion(state),
        ClassifyGroundAir(state),
        Hex(state.groundState, 8),
        Hex(state.groundSubstate, 8),
        Hex(state.airState, 8),
        Hex(state.reaction, 4),
        Hex(state.inputRaw, 8)
    ))
end

local function LogContext(state, reason)
    ContextNumber = ContextNumber + 1

    ProbeLog(string.format(
        "CONTEXT #%03d frame=%d reason=%s World=%s Room=%s Map=%s Battle=%s Event=%s",
        ContextNumber,
        FrameNumber,
        reason,
        Hex(state.world, 2),
        Hex(state.room, 2),
        Hex(state.map, 4),
        Hex(state.battle, 4),
        Hex(state.event, 4)
    ))

    ProbeLog(string.format(
        "MODE Pause=%s Control=%s BattleType=%s Reaction=%s OpenMenu=%s",
        Hex(state.pause, 2),
        Hex(state.control, 2),
        Hex(state.battleType, 2),
        Hex(state.reaction, 4),
        Hex(state.openMenu, 2)
    ))

    ProbeLog(string.format(
        "PLAYER StoryFlags=%s SoraFlag=%s CurrentForm=%s Party=%s UnitCharacter=%s",
        Hex(state.storyFlags, 2),
        Hex(state.soraStoryFlag, 2),
        Hex(state.currentForm, 2),
        Hex(state.partyLayout, 8),
        Hex(state.unitCharacterId, 4)
    ))

    ProbeLog(string.format(
        "LOADOUT Base=%s Valor=%s Wisdom=%s Limit=%s Master=%s Final=%s Drive=%d/%d Gauge=%d",
        Hex(state.baseKeyblade, 4),
        Hex(state.valorKeyblade, 4),
        Hex(state.wisdomKeyblade, 4),
        Hex(state.limitKeyblade, 4),
        Hex(state.masterKeyblade, 4),
        Hex(state.finalKeyblade, 4),
        state.driveCurrent,
        state.driveMax,
        state.drivePercent
    ))

    -- Motion and ground/air are now verified only for Steam 1.0.0.10.  The
    -- engine action owner and live weapon attachment remain deliberately
    -- unknown; persistent Keyblade loadouts are not the live weapon state.
    ProbeLog(string.format(
        "OBSERVABILITY Action=UNKNOWN Motion=%s GroundAir=%s LiveWeaponState=UNKNOWN Player=%s",
        FormatMotion(state),
        ClassifyGroundAir(state),
        HexPointer(state.playerPointer)
    ))
end

local function ClassifyYOwner(state)
    if state.pause ~= 0 or state.openMenu ~= 0xFF then
        return "NATIVE_UI_RESERVED"
    end

    if state.reaction ~= 0 then
        return "NATIVE_REACTION_CANDIDATE"
    end

    return "UNRESOLVED_NO_REACTION"
end

local function ClassifyAOwner(state)
    if state.pause ~= 0 or state.openMenu ~= 0xFF then
        return "NATIVE_UI_RESERVED"
    end

    return "NATIVE_ATTACK_BASELINE_CANDIDATE"
end

local function ClassifyR2Owner(state)
    if state.pause ~= 0 or state.openMenu ~= 0xFF then
        return "NATIVE_UI_RESERVED"
    end

    return "CALIBRATED_GAMEPLAY_INPUT_PLUS_04"
end

local function ClassifySquareOwner(state)
    if state.pause ~= 0 or state.openMenu ~= 0xFF then
        return "NATIVE_UI_RESERVED"
    end

    if state.reaction ~= 0 then
        return "NATIVE_CONTEXT_RESERVED"
    end

    if ClassifyGroundAir(state) ~= "GROUND" then
        return "NATIVE_AIR_UNCHANGED"
    end

    if state.motionId == 0x0000 then
        return "NATIVE_GUARD_CANDIDATE"
    end

    if state.motionId == 0x0097
        or state.motionId == 0x0098
        or state.motionId == 0x0099
        or state.motionId == 0x00A2
        or state.motionId == 0x00A3
        or state.motionId == 0x00A4
        or state.motionId == 0x00A9
        or state.motionId == 0x00AA
    then
        return "NATIVE_ACTION_ABILITY_CANDIDATE"
    end

    return "NATIVE_UNRESOLVED"
end

local function LogOwnershipCandidates(state, pressed)
    if HasButton(pressed, CALIBRATED_A) then
        ProbeLog("OWNER A=" .. ClassifyAOwner(state))
    end

    if HasButton(pressed, CALIBRATED_Y) then
        ProbeLog("OWNER Y=" .. ClassifyYOwner(state))
    end

    if HasButton(pressed, CALIBRATED_R2) then
        ProbeLog("OWNER R2=" .. ClassifyR2Owner(state))
    end

    if HasButton(pressed, CALIBRATED_SQUARE) then
        ProbeLog("OWNER Square=" .. ClassifySquareOwner(state))
    end
end

local function LogInputEvent(
    state,
    pressedRaw,
    releasedRaw,
    previousR2Signal,
    calibratedPressed,
    calibratedReleased
)
    EventNumber = EventNumber + 1

    local pressedHigh = (pressedRaw >> 16) & 0xFFFF
    local releasedHigh = (releasedRaw >> 16) & 0xFFFF
    local r2SignalChanged = state.r2Signal ~= previousR2Signal

    ProbeLog(string.format(
        "INPUT #%03d frame=%d raw32=%s dpad=%s heldLow=%s[%s] heldHigh=%s[%s] pressedRaw=%s releasedRaw=%s r2Signal=%s(previous=%s) calibratedHeld=%s calibratedPressed=%s calibratedReleased=%s",
        EventNumber,
        FrameNumber,
        Hex(state.inputRaw, 8),
        FormatDpadFingerprint(state.inputRaw),
        Hex(state.input, 4),
        FormatRawBits(state.input, 16),
        Hex(state.inputHigh, 4),
        FormatRawBits(state.inputHigh, 16),
        Hex(pressedRaw, 8),
        Hex(releasedRaw, 8),
        Hex(state.r2Signal, 2),
        Hex(previousR2Signal, 2),
        FormatCalibratedInput(BuildCalibratedInput(
            state.inputRaw,
            state.r2Signal
        )),
        FormatCalibratedInput(calibratedPressed),
        FormatCalibratedInput(calibratedReleased)
    ))

    local hasCalibratedEdge =
        calibratedPressed ~= 0 or calibratedReleased ~= 0
    local hasHighEdge = pressedHigh ~= 0 or releasedHigh ~= 0

    if hasCalibratedEdge or hasHighEdge or r2SignalChanged then
        ProbeLog(
            "EDGE_SOURCE=PROBE_SAMPLED (non e un edge nativo del motore)"
        )
        LogContext(
            state,
            hasCalibratedEdge and "CALIBRATED_INPUT_EDGE"
                or (hasHighEdge and "INPUT_HIGH_EDGE" or "R2_SIGNAL_CHANGE")
        )
        LogOwnershipCandidates(state, calibratedPressed)
        return true
    end

    return false
end

function _OnInit()
    CanExecute = false
    ReportLoggerFailure()

    if not LoggerLoaded or not Logger.IsEnabled("PROBE") then
        return
    end

    local libraryLoaded, libraryOrError = pcall(require, "kh2lib")

    if not libraryLoaded then
        ProbeLog(
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

    local addressesValid, missingField = ValidateLibraryAddresses()

    if not addressesValid then
        CanExecute = false
        ProbeLog(
            "campo kh2lib richiesto non disponibile: " .. tostring(missingField),
            3
        )
        return
    end

    FrameNumber = 0
    EventNumber = 0
    ContextNumber = 0
    LastInputRaw = nil
    LastR2Signal = nil
    LastCalibratedInput = nil
    LastContextKey = nil
    LastLiveStateKey = nil
    WasReady = false
    ReadErrorReported = false
    LiveEventNumber = 0

    if kh2lib.GameVersion == KH2_VERSION_STEAM_1_0_0_10_VALUE then
        PlayerPointerAddress = SORA_POINTER_STEAM_1_0_0_10
    else
        PlayerPointerAddress = nil
    end

    ProbeLog("inizializzato: READ-ONLY, nessuna scrittura memoria.", 1)
    ProbeLog("Calibrazione Steam: A raw32=0x08000004 Y raw32=0x02000400 Square raw32=0x04000200")
    ProbeLog("R2 gameplay calibrato: Input+0x04 vale esattamente 0x09.")
    ProbeLog("D-pad raw32: UP=0x00004010 RIGHT=0x00008020 DOWN=0x00010040 LEFT=0x10000080")
    if PlayerPointerAddress ~= nil then
        ProbeLog(
            "Live state Steam 1.0.0.10: Sora*=0x02AE9A28 Motion=+0x180 Slot=+0x184 Ground=+0x740/+0x744/+0x790"
        )
    else
        ProbeLog(
            "Live motion/ground-air disabilitati: versione non calibrata.",
            2
        )
    end
    ProbeLog("Attendo Sora in un mondo valido per acquisire la baseline.")
end

function _OnFrame()
    if not CanExecute then
        return
    end

    FrameNumber = FrameNumber + 1

    local readSucceeded, stateOrError = pcall(ReadState)

    if not readSucceeded then
        if not ReadErrorReported then
            ProbeLog("errore durante la lettura: " .. tostring(stateOrError), 3)
            ReadErrorReported = true
        end

        return
    end

    ReadErrorReported = false

    local state = stateOrError

    if not IsSoraReady(state) then
        if WasReady then
            ProbeLog("Sora non pronto: baseline input azzerata.", 2)
        end

        WasReady = false
        LastInputRaw = nil
        LastR2Signal = nil
        LastCalibratedInput = nil
        LastContextKey = nil
        LastLiveStateKey = nil
        return
    end

    local contextKey = BuildContextKey(state)

    if not WasReady then
        WasReady = true
        LastInputRaw = state.inputRaw
        LastR2Signal = state.r2Signal
        LastCalibratedInput = BuildCalibratedInput(
            state.inputRaw,
            state.r2Signal
        )
        LastContextKey = contextKey
        LastLiveStateKey = BuildLiveStateKey(state)

        ProbeLog(string.format(
            "BASELINE frame=%d raw32=%s dpad=%s heldLow=%s[%s] heldHigh=%s[%s] r2Signal=%s calibratedHeld=%s",
            FrameNumber,
            Hex(state.inputRaw, 8),
            FormatDpadFingerprint(state.inputRaw),
            Hex(state.input, 4),
            FormatRawBits(state.input, 16),
            Hex(state.inputHigh, 4),
            FormatRawBits(state.inputHigh, 16),
            Hex(state.r2Signal, 2),
            FormatCalibratedInput(LastCalibratedInput)
        ))
        LogContext(state, "BASELINE")
        LogLiveState(state, "BASELINE")
        return
    end

    local pressedRaw = state.inputRaw & (~LastInputRaw & 0xFFFFFFFF)
    local releasedRaw = LastInputRaw & (~state.inputRaw & 0xFFFFFFFF)
    local calibratedInput = BuildCalibratedInput(
        state.inputRaw,
        state.r2Signal
    )
    local calibratedPressed =
        calibratedInput & (~LastCalibratedInput & 0xFF)
    local calibratedReleased =
        LastCalibratedInput & (~calibratedInput & 0xFF)
    local contextLogged = false
    local liveStateKey = BuildLiveStateKey(state)

    if pressedRaw ~= 0
        or releasedRaw ~= 0
        or state.r2Signal ~= LastR2Signal
        or calibratedPressed ~= 0
        or calibratedReleased ~= 0
    then
        contextLogged = LogInputEvent(
            state,
            pressedRaw,
            releasedRaw,
            LastR2Signal,
            calibratedPressed,
            calibratedReleased
        )
    end

    if contextKey ~= LastContextKey and not contextLogged then
        LogContext(state, "STATE_CHANGE")
    end

    if liveStateKey ~= LastLiveStateKey then
        LogLiveState(state, "TRANSITION")
    end

    LastInputRaw = state.inputRaw
    LastR2Signal = state.r2Signal
    LastCalibratedInput = calibratedInput
    LastContextKey = contextKey
    LastLiveStateKey = liveStateKey
end
