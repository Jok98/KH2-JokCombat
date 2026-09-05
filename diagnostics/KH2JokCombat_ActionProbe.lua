LUAGUI_NAME = "KH2 JokCombat - Action Dispatcher Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Sonda read-only del contesto che accetta o rifiuta Quadrato"

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

local BAR_MAGIC = 0x01524142
local PTYA_FILE_TYPE = 2
local PTYA_POINTER_COUNT = 70
local PTYA_LENGTH = 15172
local PTYA_ENTRY_SIZE = 0x44
local BASE_GROUP = 1
local BASE_GROUP_OFFSET = 0x120
local BASE_RECORD_COUNT = 37
local GUARD_RECORD = 31
local GROUND_SQUARE_RECORD = 32

local RAW32_A_MASK = 0x08000004
local RAW32_SQUARE_MASK = 0x04000200
local OUTCOME_TIMEOUT_FRAMES = 45
local MAX_TIMING_EVENTS = 12
local MAX_SAMPLES_PER_OUTCOME = 4
local MIN_SAMPLES_FOR_COMPARISON = 2
local MAX_CANDIDATES_TO_LOG = 48
local CANDIDATES_PER_LINE = 12
local TIMING_EARLY_MAX = 7
local TIMING_MID_MAX = 15
local M03D_BASE_ATTACKS = {
    [0x0097] = { name = "A300", slot = 0x025C },
    [0x0098] = { name = "A301", slot = 0x0260 },
    [0x0099] = { name = "A302", slot = 0x0264 }
}
local M03E_PLAYER_FLAGS_OFFSET = 0x0120
local M03E_EVENT_ELIGIBILITY_BIT25 = 0x02000000

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
    "Menu1",
    "GameVersion"
}

local SNAPSHOT_SEGMENTS = {
    {
        name = "PLAYER",
        size = 0x0E70,
        absolute = true
    },
    {
        name = "MENU",
        size = 0x0100,
        absolute = false
    },
    {
        name = "CONTROL",
        size = 0x0060,
        absolute = false
    },
    {
        name = "INPUT",
        size = 0x0040,
        absolute = false
    }
}

local SEGMENT_ORDER = { "PLAYER", "MENU", "CONTROL", "INPUT" }

local FrameNumber = 0
local LastInputRaw = nil
local LastMotionId = nil
local LastMotionSlot = nil
local MotionRunStartFrame = nil
local WasSoraReady = false
local ReadErrorReported = false
local SnapshotErrorReported = false
local GuardAddress = nil
local GroundSquareAddress = nil
local PendingTrial = nil
local PreviousFrameSnapshot = nil
local PreviousSnapshotPlayerPointer = nil
local TrialNumber = 0
local SampleBuckets = {}
local ComparisonRevisions = {}
local M03EActiveAttack = nil
local M03ELastBit25 = nil

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function Log(message, level)
    local category = level ~= nil and level >= 3 and "ERROR" or "DISPATCH"

    if LoggerLoaded then
        return Logger.Log("ActionProbe", category, message, level)
    end

    if category == "ERROR" then
        RawConsolePrint(
            "[ActionProbe][ERROR] " .. tostring(message),
            level or 3
        )
    end
end

local function Trace(message)
    if LoggerLoaded then
        return Logger.Log("ActionProbe", "TRACE", message)
    end
end

local function ReportLoggerFailure()
    if not LoggerLoaded then
        RawConsolePrint(
            "[ActionProbe][ERROR] KH2JokCombat_Log non disponibile: "
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
    if GuardAddress ~= nil and GroundSquareAddress ~= nil then
        return true
    end

    local btl0 = ReadLong(kh2lib.Btl0Pointer)

    if btl0 == nil or btl0 == 0 or ReadInt(btl0, true) ~= BAR_MAGIC then
        return false
    end

    local subfileCount = ReadInt(btl0 + 0x04, true)

    if subfileCount < 1 or subfileCount > 128 then
        return false
    end

    for subfileNumber = 1, subfileCount do
        local address, length = GetLoadedBarSubfile(btl0, subfileNumber)

        if address ~= nil
            and length == PTYA_LENGTH
            and ReadInt(address, true) == PTYA_FILE_TYPE
            and ReadInt(address + 0x04, true) == PTYA_POINTER_COUNT
            and ReadInt(address + 0x08 + BASE_GROUP * 0x04, true)
                == BASE_GROUP_OFFSET
        then
            local baseGroupAddress = address + BASE_GROUP_OFFSET

            if ReadInt(baseGroupAddress, true) ~= BASE_RECORD_COUNT then
                return false
            end

            GuardAddress = RecordAddress(baseGroupAddress, GUARD_RECORD)
            GroundSquareAddress = RecordAddress(
                baseGroupAddress,
                GROUND_SQUARE_RECORD
            )
            Log(string.format(
                "PTYA read-only trovata: Guard=%s GroundSquare=%s",
                Hex(GuardAddress, 16),
                Hex(GroundSquareAddress, 16)
            ), 1)
            return true
        end
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
        groundState = ReadInt(
            playerPointer + SORA_GROUND_STATE_OFFSET,
            true
        )
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

local function IsObservationAllowed(state)
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

local function IsBaseAttackMotion(motionId)
    return (motionId >= 151 and motionId <= 172)
        or (motionId >= 181 and motionId <= 197)
end

local function SegmentBase(segmentName, state)
    if segmentName == "PLAYER" then
        return state.playerPointer
    elseif segmentName == "MENU" then
        return kh2lib.Menu1 - 0x10
    elseif segmentName == "CONTROL" then
        return kh2lib.Cntrl - 0x20
    elseif segmentName == "INPUT" then
        return kh2lib.Input
    end

    return nil
end

local function ReadSnapshotBytes(base, size, absolute, segmentName)
    local raw = ReadArray(base, size, absolute)

    if raw == nil then
        error("ReadArray ha restituito nil: " .. segmentName)
    end

    local function HasNumericIndex(index)
        local succeeded, value = pcall(function()
            return raw[index]
        end)

        return succeeded and type(value) == "number"
    end

    local indexBase

    if HasNumericIndex(1) and HasNumericIndex(size) then
        indexBase = 1
    elseif HasNumericIndex(0) and HasNumericIndex(size - 1) then
        indexBase = 0
    else
        error("ReadArray non indicizzabile: " .. segmentName)
    end

    local bytes = {}

    for offset = 0, size - 1 do
        local value = raw[offset + indexBase]

        if type(value) ~= "number" then
            error(string.format(
                "ReadArray incompleto: %s offset=%s",
                segmentName,
                Hex(offset, 4)
            ))
        end

        bytes[offset] = value & 0xFF
    end

    return bytes
end

local function CaptureSnapshot(state)
    local snapshot = {}

    for _, definition in ipairs(SNAPSHOT_SEGMENTS) do
        local base = SegmentBase(definition.name, state)

        if base == nil or base == 0 then
            error("base snapshot non disponibile: " .. definition.name)
        end

        snapshot[definition.name] = {
            base = base,
            size = definition.size,
            bytes = ReadSnapshotBytes(
                base,
                definition.size,
                definition.absolute,
                definition.name
            )
        }
    end

    return snapshot
end

local function StableByte(samples, segmentName, offset)
    local firstSegment = samples[1].snapshot[segmentName]

    if firstSegment == nil or offset >= firstSegment.size then
        return nil
    end

    local first = firstSegment.bytes[offset]

    for index = 2, #samples do
        local segment = samples[index].snapshot[segmentName]

        if segment == nil
            or offset >= segment.size
            or segment.bytes[offset] ~= first
        then
            return nil
        end
    end

    return first
end

local function SnapshotByte(snapshot, segmentName, offset)
    local segment = snapshot ~= nil and snapshot[segmentName] or nil

    if segment == nil or offset < 0 or offset >= segment.size then
        return nil
    end

    return segment.bytes[offset]
end

local function SnapshotU32(snapshot, segmentName, offset)
    local value = 0

    for index = 0, 3 do
        local byte = SnapshotByte(snapshot, segmentName, offset + index)

        if byte == nil then
            return nil
        end

        value = value | (byte << (index * 8))
    end

    return value
end

local function SnapshotI32(snapshot, segmentName, offset)
    local value = SnapshotU32(snapshot, segmentName, offset)

    if value == nil then
        return nil
    end

    if value >= 0x80000000 then
        return value - 0x100000000
    end

    return value
end

local function SnapshotHex(snapshot, segmentName, offset, size)
    local bytes = {}

    for index = size - 1, 0, -1 do
        local byte = SnapshotByte(snapshot, segmentName, offset + index)

        if byte == nil then
            return "UNAVAILABLE"
        end

        bytes[#bytes + 1] = string.format("%02X", byte)
    end

    return "0x" .. table.concat(bytes)
end


local function M03DBaseAttackName(motion, slot)
    local attack = M03D_BASE_ATTACKS[motion]

    if attack ~= nil and attack.slot == slot then
        return attack.name
    end

    return nil
end

local function M03EBit25(snapshot)
    local flags = SnapshotU32(
        snapshot,
        "PLAYER",
        M03E_PLAYER_FLAGS_OFFSET
    )

    if flags == nil then
        return nil, nil
    end

    local bit25 = (flags & M03E_EVENT_ELIGIBILITY_BIT25) ~= 0 and 1 or 0
    return bit25, flags
end

local function M03DFieldSummary(snapshot)
    local target98 = SnapshotHex(snapshot, "PLAYER", 0x0098, 8)
    local targetA0 = SnapshotHex(snapshot, "PLAYER", 0x00A0, 8)
    local hasTarget = target98 ~= "0x0000000000000000"
        or targetA0 ~= "0x0000000000000000"
    local targetClass = hasTarget and "TARGET_PRESENT" or "NO_TARGET_POINTER"
    local field123 = SnapshotByte(snapshot, "PLAYER", 0x0123) or 0
    local field18C = SnapshotU32(snapshot, "PLAYER", 0x018C) or 0
    local field18D = SnapshotByte(snapshot, "PLAYER", 0x018D) or 0
    local field5B8 = SnapshotU32(snapshot, "PLAYER", 0x05B8) or 0
    local field900 = SnapshotU32(snapshot, "PLAYER", 0x0900) or 0
    local field902 = SnapshotByte(snapshot, "PLAYER", 0x0902) or 0
    local fieldBFB = SnapshotByte(snapshot, "PLAYER", 0x0BFB) or 0
    local fieldC04 = SnapshotI32(snapshot, "PLAYER", 0x0C04) or 0
    local bit25, field120 = M03EBit25(snapshot)

    return string.format(
        "target=%s T98=%s TA0=%s F120=%s/bit25=%d F123=%s F18C=%s/b1=%s F5B8=%s F900=%s/b2=%s FBF8=%s/b3=%s FC04=%d/%s FC90=%s FC98=%s",
        targetClass,
        target98,
        targetA0,
        Hex(field120, 8),
        bit25 or 0,
        Hex(field123, 2),
        Hex(field18C, 8),
        Hex(field18D, 2),
        Hex(field5B8, 8),
        Hex(field900, 8),
        Hex(field902, 2),
        SnapshotHex(snapshot, "PLAYER", 0x0BF8, 8),
        Hex(fieldBFB, 2),
        fieldC04,
        SnapshotHex(snapshot, "PLAYER", 0x0C04, 4),
        SnapshotHex(snapshot, "PLAYER", 0x0C90, 8),
        SnapshotHex(snapshot, "PLAYER", 0x0C98, 8)
    )
end

local function UpdateM03ETrace(state, snapshot)
    local attackName = M03DBaseAttackName(state.motionId, state.motionSlot)
    local bit25, flags = M03EBit25(snapshot)

    if bit25 == nil then
        return
    end

    if attackName ~= nil then
        local sameAttack = M03EActiveAttack ~= nil
            and M03EActiveAttack.motion == state.motionId
            and M03EActiveAttack.slot == state.motionSlot

        if not sameAttack then
            M03EActiveAttack = {
                name = attackName,
                motion = state.motionId,
                slot = state.motionSlot,
                frame = FrameNumber
            }
            M03ELastBit25 = bit25
            Log(string.format(
                "M03E START frame=%d base=%s motion=%s slot=%s bit25=%d flags120=%s",
                FrameNumber,
                attackName,
                Hex(state.motionId, 4),
                Hex(state.motionSlot, 4),
                bit25,
                Hex(flags, 8)
            ))
        elseif M03ELastBit25 ~= bit25 then
            Log(string.format(
                "M03E BIT25 frame=%d base=%s age=%d old=%d new=%d flags120=%s",
                FrameNumber,
                attackName,
                FrameNumber - M03EActiveAttack.frame,
                M03ELastBit25,
                bit25,
                Hex(flags, 8)
            ), bit25 == 1 and 1 or nil)
            M03ELastBit25 = bit25
        end

        return
    end

    if M03EActiveAttack ~= nil then
        if M03ELastBit25 == 1 or M03ELastBit25 ~= bit25 then
            Log(string.format(
                "M03E EXIT frame=%d from=%s age=%d bit25=%d>%d flags120=%s next=%s/%s",
                FrameNumber,
                M03EActiveAttack.name,
                FrameNumber - M03EActiveAttack.frame,
                M03ELastBit25,
                bit25,
                Hex(flags, 8),
                Hex(state.motionId, 4),
                Hex(state.motionSlot, 4)
            ))
        end

        M03EActiveAttack = nil
        M03ELastBit25 = nil
    end
end

local function IsSmallStateValue(value)
    return value <= 8 or value == 0x10 or value == 0x20
        or value == 0x40 or value == 0x80 or value == 0xFF
end

local function CandidatePriority(segmentName, offset, leftValue, rightValue)
    local priority = 0

    if IsSmallStateValue(leftValue) and IsSmallStateValue(rightValue) then
        priority = priority + 100
    end

    if segmentName == "MENU" or segmentName == "CONTROL" then
        priority = priority + 50
    elseif segmentName == "INPUT" then
        priority = priority + 25
    elseif offset < 0x0160
        or (offset >= 0x0188 and offset < 0x0390)
        or (offset >= 0x0700 and offset < 0x0900)
    then
        priority = priority + 20
    end

    -- Motion, slot, ground/air and the two target pointers are already known;
    -- keep them visible only after less obvious state candidates.
    if segmentName == "PLAYER"
        and ((offset >= 0x0098 and offset < 0x00A8)
            or (offset >= 0x016C and offset < 0x0188)
            or (offset >= 0x0740 and offset < 0x0748)
            or (offset >= 0x0790 and offset < 0x0794)
            or (offset >= 0x0290 and offset < 0x02A0))
    then
        priority = priority - 100
    end

    return priority
end

local function BuildCandidates(leftSamples, rightSamples)
    local candidates = {}

    for _, segmentName in ipairs(SEGMENT_ORDER) do
        local size = leftSamples[1].snapshot[segmentName].size

        for offset = 0, size - 1 do
            local leftValue = StableByte(leftSamples, segmentName, offset)
            local rightValue = StableByte(rightSamples, segmentName, offset)

            if leftValue ~= nil
                and rightValue ~= nil
                and leftValue ~= rightValue
            then
                candidates[#candidates + 1] = {
                    segment = segmentName,
                    offset = offset,
                    left = leftValue,
                    right = rightValue,
                    priority = CandidatePriority(
                        segmentName,
                        offset,
                        leftValue,
                        rightValue
                    )
                }
            end
        end
    end

    table.sort(candidates, function(left, right)
        if left.priority ~= right.priority then
            return left.priority > right.priority
        end

        if left.segment ~= right.segment then
            return left.segment < right.segment
        end

        return left.offset < right.offset
    end)

    return candidates
end

local function TimingWindow(age)
    if age <= TIMING_EARLY_MAX then
        return "EARLY"
    elseif age <= TIMING_MID_MAX then
        return "MID"
    end

    return "LATE"
end

local function BucketKey(motion, slot, window)
    return string.format("%04X/%04X/%s", motion, slot, window)
end

local function GetSampleBucket(trial)
    local key = BucketKey(
        trial.beforeMotion,
        trial.beforeSlot,
        trial.timingWindow
    )
    local bucket = SampleBuckets[key]

    if bucket == nil then
        bucket = {
            key = key,
            motion = trial.beforeMotion,
            slot = trial.beforeSlot,
            window = trial.timingWindow,
            accepted = {},
            rejected = {}
        }
        SampleBuckets[key] = bucket
    end

    return bucket
end

local function LogBucketStatus(bucket)
    Log(string.format(
        "BUCKET motion=%s slot=%s window=%s accepted=%d rejected=%d need=%d/%d",
        Hex(bucket.motion, 4),
        Hex(bucket.slot, 4),
        bucket.window,
        #bucket.accepted,
        #bucket.rejected,
        MIN_SAMPLES_FOR_COMPARISON,
        MIN_SAMPLES_FOR_COMPARISON
    ))
end

local function LogCandidateComparison(bucket)
    local leftSamples = bucket.accepted
    local rightSamples = bucket.rejected

    if #leftSamples < MIN_SAMPLES_FOR_COMPARISON
        or #rightSamples < MIN_SAMPLES_FOR_COMPARISON
    then
        return
    end

    local revision = tostring(#leftSamples) .. "/" .. tostring(#rightSamples)

    if ComparisonRevisions[bucket.key] == revision then
        return
    end

    ComparisonRevisions[bucket.key] = revision
    local candidates = BuildCandidates(leftSamples, rightSamples)
    local shown = math.min(#candidates, MAX_CANDIDATES_TO_LOG)
    local parts = math.max(1, math.ceil(shown / CANDIDATES_PER_LINE))

    if shown == 0 then
        Log(string.format(
            "CANDIDATES PRE_EDGE motion=%s slot=%s window=%s accepted=%d rejected=%d stable=0",
            Hex(bucket.motion, 4),
            Hex(bucket.slot, 4),
            bucket.window,
            #leftSamples,
            #rightSamples
        ), 1)
        return
    end

    for part = 1, parts do
        local formatted = {}
        local first = (part - 1) * CANDIDATES_PER_LINE + 1
        local last = math.min(first + CANDIDATES_PER_LINE - 1, shown)

        for index = first, last do
            local candidate = candidates[index]
            formatted[#formatted + 1] = string.format(
                "%s+%s:%s>%s",
                candidate.segment,
                Hex(candidate.offset, 4),
                Hex(candidate.left, 2),
                Hex(candidate.right, 2)
            )
        end

        Log(string.format(
            "CANDIDATES PRE_EDGE motion=%s slot=%s window=%s accepted=%d rejected=%d stable=%d part=%d/%d [%s]",
            Hex(bucket.motion, 4),
            Hex(bucket.slot, 4),
            bucket.window,
            #leftSamples,
            #rightSamples,
            #candidates,
            part,
            parts,
            table.concat(formatted, ",")
        ), 1)
    end
end

local function StateSignature(state)
    return table.concat({
        tostring(state.motionId),
        tostring(state.motionSlot),
        tostring(state.groundState),
        tostring(state.groundSubstate),
        tostring(state.airState),
        tostring(state.control),
        tostring(state.reaction),
        tostring(state.inputRaw)
    }, "/")
end

local function LogTiming(trial, state, reason)
    if trial.timingEvents >= MAX_TIMING_EVENTS then
        return
    end

    local signature = StateSignature(state)

    if signature == trial.lastTimingSignature and reason ~= "EDGE" then
        return
    end

    trial.lastTimingSignature = signature
    trial.timingEvents = trial.timingEvents + 1
    Trace(string.format(
        "TIMING #%03d +%d reason=%s Motion=%s Slot=%s Ground=%s/%s/%s Control=%s Reaction=%s Input=%s",
        trial.number,
        trial.age,
        tostring(reason),
        Hex(state.motionId, 4),
        Hex(state.motionSlot, 4),
        Hex(state.groundState, 2),
        Hex(state.groundSubstate, 2),
        Hex(state.airState, 2),
        Hex(state.control, 2),
        Hex(state.reaction, 4),
        Hex(state.inputRaw, 8)
    ))
end

local function FinishTrial(outcome, reason, state, sampleEligible)
    local trial = PendingTrial

    if trial == nil then
        return false
    end

    local bucket = nil
    local sampleCount = 0

    if sampleEligible ~= false
        and trial.source == "AFTER_A"
        and trial.preSnapshot ~= nil
    then
        bucket = GetSampleBucket(trial)
        local outcomeSamples = outcome == "ACCEPTED"
            and bucket.accepted
            or bucket.rejected

        if #outcomeSamples < MAX_SAMPLES_PER_OUTCOME then
            outcomeSamples[#outcomeSamples + 1] = {
                snapshot = trial.preSnapshot,
                frame = trial.frame,
                age = trial.beforeAge
            }
        end

        sampleCount = #outcomeSamples
    end

    Log(string.format(
        "RESULT #%03d %s source=%s expected=%s before=%s/%s age=%d window=%s after=%s/%s reason=%s sample=%d",
        trial.number,
        outcome,
        trial.source,
        Hex(trial.expectedMotion, 4),
        Hex(trial.beforeMotion, 4),
        Hex(trial.beforeSlot, 4),
        trial.beforeAge,
        trial.timingWindow,
        Hex(state.motionId, 4),
        Hex(state.motionSlot, 4),
        tostring(reason),
        sampleCount
    ), outcome == "ACCEPTED" and 1 or nil)

    local baseAttackName = M03DBaseAttackName(
        trial.beforeMotion,
        trial.beforeSlot
    )

    if trial.source == "AFTER_A"
        and baseAttackName ~= nil
        and trial.preSnapshot ~= nil
    then
        Log(string.format(
            "M03D SAMPLE #%03d base=%s outcome=%s age=%d window=%s %s",
            trial.number,
            baseAttackName,
            outcome,
            trial.beforeAge,
            trial.timingWindow,
            M03DFieldSummary(trial.preSnapshot)
        ), outcome == "ACCEPTED" and 1 or nil)
    end

    PendingTrial = nil

    if bucket ~= nil then
        LogBucketStatus(bucket)
        LogCandidateComparison(bucket)
    end

    return true
end

local function UpdatePendingTrial(state)
    if PendingTrial == nil then
        return false
    end

    PendingTrial.age = PendingTrial.age + 1
    LogTiming(PendingTrial, state, "STATE_CHANGE")

    if state.motionId == PendingTrial.expectedMotion
        and (state.motionId ~= PendingTrial.beforeMotion
            or state.motionSlot ~= PendingTrial.beforeSlot)
    then
        return FinishTrial("ACCEPTED", "EXPECTED_MOTION", state)
    elseif PendingTrial.source == "AFTER_A"
        and PendingTrial.age >= 2
        and state.motionId == 0
    then
        return FinishTrial("REJECTED", "RESET_IDLE", state)
    elseif PendingTrial.age >= OUTCOME_TIMEOUT_FRAMES then
        return FinishTrial("REJECTED", "TIMEOUT", state)
    end

    return false
end

local function StartTrial(state, preSnapshot, beforeAge)
    if PendingTrial ~= nil then
        Log(string.format(
            "SQUARE_EDGE IGNORED_PENDING trial=#%03d",
            PendingTrial.number
        ))
        return false
    end

    if IsAirborne(state) then
        Log("SQUARE_EDGE IGNORED_AIRBORNE: M-03C osserva soltanto il dispatcher ground")
        return false
    end

    if not LocatePtya() then
        Log("SQUARE non campionato: PTYA non disponibile")
        return false
    end

    local beforeMotion = LastMotionId or state.motionId
    local beforeSlot = LastMotionSlot or state.motionSlot
    local source
    local recordAddress

    if beforeMotion == 0 then
        source = "NEUTRAL"
        recordAddress = GuardAddress
    elseif IsBaseAttackMotion(beforeMotion) then
        source = "AFTER_A"
        recordAddress = GroundSquareAddress
    else
        source = "OTHER"
        recordAddress = GroundSquareAddress
    end

    local expectedMotion = ReadShort(recordAddress + 0x08, true)

    if beforeMotion == expectedMotion then
        Log(string.format(
            "SQUARE_EDGE IGNORED_ALREADY_EXPECTED motion=%s slot=%s",
            Hex(beforeMotion, 4),
            Hex(beforeSlot, 4)
        ))
        return false
    end

    if source == "AFTER_A" and preSnapshot == nil then
        Log("SQUARE_EDGE IGNORED_NO_PRE_EDGE_SNAPSHOT")
        return false
    end

    beforeAge = beforeAge or 0
    TrialNumber = TrialNumber + 1
    PendingTrial = {
        number = TrialNumber,
        frame = FrameNumber,
        age = 0,
        source = source,
        expectedMotion = expectedMotion,
        beforeMotion = beforeMotion,
        beforeSlot = beforeSlot,
        beforeAge = beforeAge,
        timingWindow = TimingWindow(beforeAge),
        preSnapshot = preSnapshot,
        timingEvents = 0,
        lastTimingSignature = nil
    }

    Log(string.format(
        "EDGE #%03d frame=%d source=%s expected=%s before=%s/%s age=%d window=%s current=%s/%s",
        PendingTrial.number,
        FrameNumber,
        source,
        Hex(PendingTrial.expectedMotion, 4),
        Hex(beforeMotion, 4),
        Hex(beforeSlot, 4),
        beforeAge,
        PendingTrial.timingWindow,
        Hex(state.motionId, 4),
        Hex(state.motionSlot, 4)
    ))
    LogTiming(PendingTrial, state, "EDGE")
    return UpdatePendingTrial(state)
end

local function ResetObservation()
    LastInputRaw = nil
    LastMotionId = nil
    LastMotionSlot = nil
    MotionRunStartFrame = nil
    PendingTrial = nil
    PreviousFrameSnapshot = nil
    PreviousSnapshotPlayerPointer = nil
    M03EActiveAttack = nil
    M03ELastBit25 = nil
end

function _OnInit()
    CanExecute = false
    ReportLoggerFailure()

    if not LoggerLoaded or not Logger.IsEnabled("DISPATCH") then
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

    if type(ReadArray) ~= "function" then
        Log("DISABILITATO: LuaBackend ReadArray non disponibile", 3)
        CanExecute = false
        return
    end

    FrameNumber = 0
    WasSoraReady = false
    ReadErrorReported = false
    SnapshotErrorReported = false
    GuardAddress = nil
    GroundSquareAddress = nil
    TrialNumber = 0
    SampleBuckets = {}
    ComparisonRevisions = {}
    ResetObservation()

    Log("READ-ONLY M-03C/M-03D/M-03E: nessuna memoria viene modificata; ReadArray conserva soltanto lo snapshot del frame precedente.", 1)
    Log("TEST M-03E: A300/A301/A302 producono M03D SAMPLE e una traccia compatta START/BIT25/EXIT del bit 25 in PLAYER+0x120.", 1)
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

    if not IsSoraReady(state) or not IsObservationAllowed(state) then
        if PendingTrial ~= nil then
            FinishTrial("REJECTED", "NATIVE_CONTEXT", state, false)
        end

        WasSoraReady = false
        ResetObservation()
        return
    end

    if PreviousSnapshotPlayerPointer ~= nil
        and PreviousSnapshotPlayerPointer ~= state.playerPointer
    then
        ResetObservation()
        WasSoraReady = false
    end

    local snapshotSucceeded, snapshotOrError = pcall(CaptureSnapshot, state)

    if not snapshotSucceeded then
        if not SnapshotErrorReported then
            SnapshotErrorReported = true
            Log("snapshot pre-edge fallito: " .. tostring(snapshotOrError), 3)
        end

        WasSoraReady = false
        ResetObservation()
        return
    end

    local currentSnapshot = snapshotOrError

    if not WasSoraReady
        or LastInputRaw == nil
        or PreviousFrameSnapshot == nil
    then
        WasSoraReady = true
        LastInputRaw = state.inputRaw
        LastMotionId = state.motionId
        LastMotionSlot = state.motionSlot
        MotionRunStartFrame = FrameNumber
        PreviousFrameSnapshot = currentSnapshot
        PreviousSnapshotPlayerPointer = state.playerPointer
        UpdateM03ETrace(state, currentSnapshot)
        Log(string.format(
            "BASELINE frame=%d Input=%s Motion=%s Slot=%s",
            FrameNumber,
            Hex(state.inputRaw, 8),
            Hex(state.motionId, 4),
            Hex(state.motionSlot, 4)
        ))
        return
    end

    local beforeAge = 0

    if MotionRunStartFrame ~= nil then
        beforeAge = math.max(0, (FrameNumber - 1) - MotionRunStartFrame)
    end

    UpdateM03ETrace(state, currentSnapshot)

    local trialResolvedThisFrame = UpdatePendingTrial(state)

    local pressedRaw = state.inputRaw & (~LastInputRaw & 0xFFFFFFFF)
    local aPressed = HasButton(pressedRaw, RAW32_A_MASK)
    local squarePressed = HasButton(pressedRaw, RAW32_SQUARE_MASK)

    if aPressed then
        Trace(string.format(
            "A_EDGE frame=%d before=%s/%s current=%s/%s",
            FrameNumber,
            Hex(LastMotionId, 4),
            Hex(LastMotionSlot, 4),
            Hex(state.motionId, 4),
            Hex(state.motionSlot, 4)
        ))
    end

    if squarePressed then
        if trialResolvedThisFrame then
            Log("SQUARE_EDGE IGNORED_RESOLVED_TRIAL: edge gia attribuito al trial precedente")
        else
            StartTrial(state, PreviousFrameSnapshot, beforeAge)
        end
    end

    if state.motionId ~= LastMotionId or state.motionSlot ~= LastMotionSlot then
        MotionRunStartFrame = FrameNumber
    end

    LastInputRaw = state.inputRaw
    LastMotionId = state.motionId
    LastMotionSlot = state.motionSlot
    PreviousFrameSnapshot = currentSnapshot
    PreviousSnapshotPlayerPointer = state.playerPointer
end
