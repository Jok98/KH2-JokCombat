LUAGUI_NAME = "KH2 JokCombat - Targetless Combo Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Sonda read-only del gate A/Quadrato con e senza bersaglio"

local RawConsolePrint = ConsolePrint
local LoggerLoaded, Logger = pcall(require, "KH2JokCombat_Log")
if not LoggerLoaded then
    LoggerLoaded, Logger = pcall(require, "runtime.KH2JokCombat_Log")
end
local LoggerLoadError = LoggerLoaded and nil or Logger

local CanExecute = false
local kh2lib = nil

local KH2_VERSION_STEAM_1_0_0_10 = 0x030A
local SORA_POINTER_STEAM_1_0_0_10 = 0x02AE9A28
local SORA_MOTION_ID_OFFSET = 0x0180
local SORA_MOTION_SLOT_OFFSET = 0x0184
local SORA_GROUND_STATE_OFFSET = 0x0740
local SORA_GROUND_SUBSTATE_OFFSET = 0x0744
local SORA_AIR_STATE_OFFSET = 0x0790
local PLAYER_SNAPSHOT_SIZE = 0x0E70

local BAR_MAGIC = 0x01524142
local PTYA_FILE_TYPE = 2
local PTYA_POINTER_COUNT = 70
local PTYA_LENGTH = 15172
local PTYA_ENTRY_SIZE = 0x44
local BASE_GROUP = 1
local BASE_GROUP_OFFSET = 0x120
local BASE_RECORD_COUNT = 37
local GROUND_SQUARE_RECORD = 32
local AIR_SQUARE_RECORD = 34

local RAW32_A_MASK = 0x08000004
local RAW32_SQUARE_MASK = 0x04000200
local CAPTURE_AFTER_A_FRAMES = 120
local SNAPSHOT_INTERVAL_FRAMES = 3
local OUTCOME_TIMEOUT_FRAMES = 45
local MAX_SAMPLES_PER_OUTCOME = 4
local MIN_SAMPLES_FOR_CANDIDATES = 2
local MAX_CANDIDATES_TO_LOG = 32

local REQUIRED_LIBRARY_ADDRESSES = {
    "Btl0Pointer",
    "Input",
    "React",
    "Pause",
    "Cntrl",
    "CurrentOpenMenu",
    "Now",
    "Save",
    "Slot1",
    "GameVersion"
}

local FrameNumber = 0
local LastInputRaw = nil
local LastMotionId = nil
local LastMotionSlot = nil
local LastSnapshot = nil
local LastSnapshotPlayer = 0
local CaptureFrames = 0
local SnapshotInterval = 0
local PendingTrial = nil
local TrialNumber = 0
local AcceptedSamples = {}
local RejectedSamples = {}
local GroundSquareAddress = nil
local AirSquareAddress = nil
local LastLocateFrame = -60
local LocateErrorReported = nil
local ReadErrorReported = false

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function Log(message, level)
    local category = level ~= nil and level >= 3 and "ERROR" or "PROBE"

    if LoggerLoaded then
        return Logger.Log("TargetlessProbe", category, message, level)
    end

    if category == "ERROR" then
        RawConsolePrint(
            "[TargetlessProbe][ERROR] " .. tostring(message),
            level or 3
        )
    end
end

local function ReportLoggerFailure()
    if not LoggerLoaded then
        RawConsolePrint(
            "[TargetlessProbe][ERROR] KH2JokCombat_Log non disponibile: "
            .. tostring(LoggerLoadError),
            3
        )
    end
end

local function HasButton(value, mask)
    return (value & mask) == mask
end

local function ValidateLibraryAddresses()
    for _, fieldName in ipairs(REQUIRED_LIBRARY_ADDRESSES) do
        if type(kh2lib[fieldName]) ~= "number" then
            return false, fieldName
        end
    end

    return true
end

local function GetLoadedBarSubfile(fileAddress, subfileNumber)
    if ReadInt(fileAddress, true) ~= BAR_MAGIC then
        return nil, nil
    end

    local subfileCount = ReadInt(fileAddress + 0x04, true)

    if subfileNumber < 1 or subfileNumber > subfileCount then
        return nil, nil
    end

    local subpoint = fileAddress + 0x08 + 0x10 * subfileNumber
    local relocatedOffset = ReadInt(subpoint, true)
    local length = ReadInt(subpoint + 0x04, true)
    local lookupBase = ReadInt(fileAddress + 0x08, true)

    return fileAddress + (relocatedOffset - lookupBase), length
end

local function RecordAddress(baseGroupAddress, record)
    return baseGroupAddress + 0x04 + record * PTYA_ENTRY_SIZE
end

local function LocatePtya()
    if GroundSquareAddress ~= nil and AirSquareAddress ~= nil then
        return true
    end

    if FrameNumber - LastLocateFrame < 60 then
        return false
    end

    LastLocateFrame = FrameNumber

    local btl0 = ReadLong(kh2lib.Btl0Pointer)

    if btl0 == nil or btl0 == 0 or ReadInt(btl0, true) ~= BAR_MAGIC then
        return false
    end

    local subfileCount = ReadInt(btl0 + 0x04, true)

    for subfileNumber = 1, subfileCount do
        local address, length = GetLoadedBarSubfile(btl0, subfileNumber)

        if address ~= nil
            and length == PTYA_LENGTH
            and ReadInt(address, true) == PTYA_FILE_TYPE
            and ReadInt(address + 0x04, true) == PTYA_POINTER_COUNT
        then
            local groupOffset = ReadInt(
                address + 0x08 + BASE_GROUP * 0x04,
                true
            )

            if groupOffset ~= BASE_GROUP_OFFSET then
                return false
            end

            local baseGroupAddress = address + groupOffset

            if ReadInt(baseGroupAddress, true) ~= BASE_RECORD_COUNT then
                return false
            end

            GroundSquareAddress = RecordAddress(
                baseGroupAddress,
                GROUND_SQUARE_RECORD
            )
            AirSquareAddress = RecordAddress(
                baseGroupAddress,
                AIR_SQUARE_RECORD
            )

            Log(string.format(
                "PTYA read-only trovata: Ground=%s Air=%s",
                Hex(GroundSquareAddress, 16),
                Hex(AirSquareAddress, 16)
            ), 1)
            return true
        end
    end

    if LocateErrorReported ~= "NOT_FOUND" then
        LocateErrorReported = "NOT_FOUND"
        Log("PTYA verificata non ancora disponibile; nuovo tentativo automatico", 2)
    end

    return false
end

local function ReadState()
    local playerPointer = ReadLong(SORA_POINTER_STEAM_1_0_0_10) or 0
    local motionId = 0
    local motionSlot = 0
    local groundState = 0
    local groundSubstate = 0
    local airState = 0

    if playerPointer ~= 0 then
        motionId = ReadInt(playerPointer + SORA_MOTION_ID_OFFSET, true)
        motionSlot = ReadInt(playerPointer + SORA_MOTION_SLOT_OFFSET, true)
        groundState = ReadInt(playerPointer + SORA_GROUND_STATE_OFFSET, true)
        groundSubstate = ReadInt(
            playerPointer + SORA_GROUND_SUBSTATE_OFFSET,
            true
        )
        airState = ReadInt(playerPointer + SORA_AIR_STATE_OFFSET, true)
    end

    return {
        inputRaw = ReadInt(kh2lib.Input) & 0xFFFFFFFF,
        world = ReadByte(kh2lib.Now + 0x00),
        pause = ReadByte(kh2lib.Pause),
        control = ReadByte(kh2lib.Cntrl),
        reaction = ReadShort(kh2lib.React),
        openMenu = ReadByte(kh2lib.CurrentOpenMenu),
        storyFlags = ReadByte(kh2lib.Save + 0x1CEA),
        currentForm = ReadByte(kh2lib.Save + 0x3524),
        hpMax = ReadInt(kh2lib.Slot1 + 0x004),
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
        and (state.storyFlags & 0x01) == 0x01
        and state.currentForm == 0
        and state.playerPointer ~= 0
end

local function IsRoutingAllowed(state)
    return state.pause == 0
        and state.control == 0
        and state.reaction == 0
        and state.openMenu == 0xFF
end

local function IsAirborne(state)
    return state.groundState == 0x03
        and state.groundSubstate ~= 0
        and state.airState ~= 0
end

local function CaptureSnapshot(playerPointer)
    local words = {}

    for offset = 0, PLAYER_SNAPSHOT_SIZE - 4, 4 do
        words[offset] = ReadInt(playerPointer + offset, true) & 0xFFFFFFFF
    end

    return words
end

local function ByteAt(snapshot, offset)
    local wordOffset = offset - (offset % 4)
    local shift = (offset % 4) * 8
    return (snapshot[wordOffset] >> shift) & 0xFF
end

local function CandidatePriority(offset, rejectedValue, acceptedValue)
    local bitLike = {
        [0] = true, [1] = true, [2] = true, [3] = true,
        [4] = true, [5] = true, [8] = true, [16] = true,
        [32] = true, [64] = true, [128] = true, [255] = true
    }
    local score = 0

    if bitLike[rejectedValue] and bitLike[acceptedValue] then
        score = score + 100
    end

    if (offset >= 0x0390 and offset < 0x0600)
        or (offset >= 0x0700 and offset < 0x0900)
        or offset >= 0x0CB8
    then
        score = score + 20
    end

    return score
end

local function StableByte(samples, offset)
    local first = ByteAt(samples[1].snapshot, offset)

    for index = 2, #samples do
        if ByteAt(samples[index].snapshot, offset) ~= first then
            return nil
        end
    end

    return first
end

local function LogCandidates()
    if #AcceptedSamples < MIN_SAMPLES_FOR_CANDIDATES
        or #RejectedSamples < MIN_SAMPLES_FOR_CANDIDATES
    then
        Log(string.format(
            "RACCOLTA accepted=%d/%d rejected=%d/%d",
            #AcceptedSamples,
            MIN_SAMPLES_FOR_CANDIDATES,
            #RejectedSamples,
            MIN_SAMPLES_FOR_CANDIDATES
        ))
        return
    end

    local candidates = {}

    for offset = 0, PLAYER_SNAPSHOT_SIZE - 1 do
        local acceptedValue = StableByte(AcceptedSamples, offset)
        local rejectedValue = StableByte(RejectedSamples, offset)

        if acceptedValue ~= nil
            and rejectedValue ~= nil
            and acceptedValue ~= rejectedValue
        then
            candidates[#candidates + 1] = {
                offset = offset,
                rejected = rejectedValue,
                accepted = acceptedValue,
                priority = CandidatePriority(
                    offset,
                    rejectedValue,
                    acceptedValue
                )
            }
        end
    end

    table.sort(candidates, function(left, right)
        if left.priority ~= right.priority then
            return left.priority > right.priority
        end

        return left.offset < right.offset
    end)

    local formatted = {}

    for index = 1, math.min(#candidates, MAX_CANDIDATES_TO_LOG) do
        local candidate = candidates[index]
        formatted[#formatted + 1] = string.format(
            "+%s:%s>%s",
            Hex(candidate.offset, 4),
            Hex(candidate.rejected, 2),
            Hex(candidate.accepted, 2)
        )
    end

    Log(string.format(
        "CANDIDATES accepted=%d rejected=%d stable=%d top=[%s]",
        #AcceptedSamples,
        #RejectedSamples,
        #candidates,
        table.concat(formatted, ",")
    ), 1)
end

local function SaveOutcome(outcome, trial, state)
    local samples = outcome == "ACCEPTED"
        and AcceptedSamples
        or RejectedSamples

    if #samples < MAX_SAMPLES_PER_OUTCOME then
        samples[#samples + 1] = {
            snapshot = trial.snapshot,
            frame = trial.frame,
            expectedMotion = trial.expectedMotion
        }
    end

    Log(string.format(
        "RESULT #%03d %s domain=%s expected=%s before=%s/%s after=%s/%s samples=%d/%d",
        trial.number,
        outcome,
        trial.domain,
        Hex(trial.expectedMotion, 4),
        Hex(trial.beforeMotion, 4),
        Hex(trial.beforeSlot, 4),
        Hex(state.motionId, 4),
        Hex(state.motionSlot, 4),
        #AcceptedSamples,
        #RejectedSamples
    ), outcome == "ACCEPTED" and 1 or 2)

    PendingTrial = nil
    LogCandidates()
end

local function UpdatePendingTrial(state)
    if PendingTrial == nil then
        return
    end

    PendingTrial.age = PendingTrial.age + 1

    if state.motionId == PendingTrial.expectedMotion
        and (state.motionId ~= PendingTrial.beforeMotion
            or state.motionSlot ~= PendingTrial.beforeSlot)
    then
        SaveOutcome("ACCEPTED", PendingTrial, state)
    elseif PendingTrial.age >= OUTCOME_TIMEOUT_FRAMES then
        SaveOutcome("REJECTED", PendingTrial, state)
    end
end

local function StartTrial(state)
    if PendingTrial ~= nil then
        Log(string.format(
            "SQUARE ignorato: trial #%03d ancora in osservazione",
            PendingTrial.number
        ), 2)
        return
    end

    if CaptureFrames <= 0
        or LastSnapshot == nil
        or LastSnapshotPlayer ~= state.playerPointer
    then
        Log("SQUARE non campionato: eseguire prima A e poi Quadrato", 2)
        return
    end

    if not LocatePtya() then
        Log("SQUARE non campionato: PTYA non disponibile", 2)
        return
    end

    TrialNumber = TrialNumber + 1
    local airborne = IsAirborne(state)
    local recordAddress = airborne and AirSquareAddress or GroundSquareAddress

    PendingTrial = {
        number = TrialNumber,
        frame = FrameNumber,
        age = 0,
        domain = airborne and "AIR" or "GROUND",
        expectedMotion = ReadShort(recordAddress + 0x08, true),
        beforeMotion = LastMotionId or state.motionId,
        beforeSlot = LastMotionSlot or state.motionSlot,
        snapshot = LastSnapshot
    }

    Log(string.format(
        "TRIAL #%03d edge=%d domain=%s expected=%s before=%s/%s",
        PendingTrial.number,
        FrameNumber,
        PendingTrial.domain,
        Hex(PendingTrial.expectedMotion, 4),
        Hex(PendingTrial.beforeMotion, 4),
        Hex(PendingTrial.beforeSlot, 4)
    ))

    -- The callback can observe an already-dispatched action in this frame.
    UpdatePendingTrial(state)
end

local function ResetCapture()
    LastSnapshot = nil
    LastSnapshotPlayer = 0
    CaptureFrames = 0
    SnapshotInterval = 0
    PendingTrial = nil
end

function _OnInit()
    CanExecute = false
    ReportLoggerFailure()

    if not LoggerLoaded or not Logger.IsEnabled("PROBE") then
        return
    end

    local loaded, libraryOrError = pcall(require, "kh2lib")

    if not loaded then
        Log("KH2 Lua Library non disponibile: " .. tostring(libraryOrError), 3)
        return
    end

    kh2lib = libraryOrError
    RequireKH2LibraryVersion(2)
    RequirePCGameVersion()
    CanExecute = kh2lib.CanExecute == true

    if not CanExecute then
        return
    end

    local valid, missingField = ValidateLibraryAddresses()

    if not valid then
        Log("DISABILITATO: campo kh2lib mancante: " .. tostring(missingField), 3)
        CanExecute = false
        return
    end

    if kh2lib.GameVersion ~= KH2_VERSION_STEAM_1_0_0_10 then
        Log(
            "DISABILITATO: supportata solo Steam 1.0.0.10; versione="
            .. Hex(kh2lib.GameVersion, 4),
            3
        )
        CanExecute = false
        return
    end

    FrameNumber = 0
    LastInputRaw = nil
    LastMotionId = nil
    LastMotionSlot = nil
    ResetCapture()
    TrialNumber = 0
    AcceptedSamples = {}
    RejectedSamples = {}
    GroundSquareAddress = nil
    AirSquareAddress = nil
    LastLocateFrame = -60
    LocateErrorReported = nil
    ReadErrorReported = false

    Log("READ-ONLY: nessuna WriteByte/WriteShort/WriteInt/WriteFloat eseguita.", 1)
    Log("Test minimo: A->Quadrato 2-3 volte a vuoto e 2-3 volte colpendo un nemico; attendere il risultato tra i tentativi.")
    LocatePtya()
end

function _OnFrame()
    if not CanExecute then
        return
    end

    FrameNumber = FrameNumber + 1

    local readSucceeded, stateOrError = pcall(ReadState)

    if not readSucceeded then
        if not ReadErrorReported then
            ReadErrorReported = true
            Log("lettura stato fallita: " .. tostring(stateOrError), 3)
        end
        return
    end

    local state = stateOrError

    if not IsSoraReady(state) or not IsRoutingAllowed(state) then
        LastInputRaw = state.inputRaw
        LastMotionId = state.motionId
        LastMotionSlot = state.motionSlot
        ResetCapture()
        return
    end

    if LastInputRaw == nil then
        LastInputRaw = state.inputRaw
        LastMotionId = state.motionId
        LastMotionSlot = state.motionSlot
        return
    end

    UpdatePendingTrial(state)

    local pressedRaw = state.inputRaw & (~LastInputRaw & 0xFFFFFFFF)
    local aPressed = HasButton(pressedRaw, RAW32_A_MASK)
    local squarePressed = HasButton(pressedRaw, RAW32_SQUARE_MASK)

    if aPressed then
        CaptureFrames = CAPTURE_AFTER_A_FRAMES
        SnapshotInterval = SNAPSHOT_INTERVAL_FRAMES
        Log(string.format(
            "ARM frame=%d Motion=%s Slot=%s",
            FrameNumber,
            Hex(state.motionId, 4),
            Hex(state.motionSlot, 4)
        ))
    end

    if squarePressed then
        StartTrial(state)
    end

    if CaptureFrames > 0 then
        SnapshotInterval = SnapshotInterval + 1

        if SnapshotInterval >= SNAPSHOT_INTERVAL_FRAMES then
            local snapshotSucceeded, snapshotOrError = pcall(
                CaptureSnapshot,
                state.playerPointer
            )

            if snapshotSucceeded then
                LastSnapshot = snapshotOrError
                LastSnapshotPlayer = state.playerPointer
                SnapshotInterval = 0
            elseif not ReadErrorReported then
                ReadErrorReported = true
                Log("snapshot PLAYER fallito: " .. tostring(snapshotOrError), 3)
                ResetCapture()
            end
        end

        CaptureFrames = CaptureFrames - 1
    end

    LastInputRaw = state.inputRaw
    LastMotionId = state.motionId
    LastMotionSlot = state.motionSlot
end
