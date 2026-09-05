LUAGUI_NAME = "KH2 JokCombat - Targetless Shadow Profile V3"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Esperimento PTYA V3 reversibile con shadow carrier per A/Quadrato targetless"

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

local SHADOW_GROUND_RECORD = 0
local SHADOW_AIR_RECORD = 1
local GUARD_RECORD = 31
local SOURCE_GROUND_RECORD = 32
local SOURCE_AIR_RECORD = 34

local VANILLA_ACTION_TYPE = 0
local FREE_USE_TYPE = 3
local GROUND_NATIVE_ABILITY = 0x12
local AIR_NATIVE_ABILITY = 0x63
local RAW32_A_MASK = 0x08000004
local RAW32_SQUARE_MASK = 0x04000200
local ARM_TIMEOUT_FRAMES = 120
local OUTCOME_TIMEOUT_FRAMES = 45
local LOCATE_RETRY_FRAMES = 60

local ALLOWED_GROUND_MOTIONS = {
    [161] = true,
    [162] = true,
    [166] = true,
    [169] = true
}

local ALLOWED_AIR_MOTIONS = {
    [192] = true,
    [193] = true,
    [194] = true,
    [196] = true
}

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

-- Retail/fallback records from the hash-verified PTYA bundled by this mod.
-- Records 0/1 are the only sacrificial carriers. Records 31/32/34 are never
-- rewritten by V3, except for recovery of a signed V1/V2 eligibility residue.
local SHADOW_GROUND_BASELINE = {
    0x21, 0x01, 0xFF, 0x00, 0x0A, 0x00, 0x00, 0x00,
    0xBF, 0x00, 0x04, 0x00, 0x00, 0x00, 0x88, 0x41,
    0x00, 0x00, 0xEA, 0x42, 0x00, 0x00, 0x88, 0x41,
    0x00, 0x00, 0x00, 0xC1, 0x00, 0x00, 0x90, 0x41,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x82, 0x43,
    0x00, 0x00, 0xDC, 0xC2, 0x00, 0x00, 0x7A, 0xC3,
    0x81, 0xFD, 0x7F, 0x3F, 0x00, 0x00, 0x80, 0x3F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5C, 0x42,
    0x61, 0x00, 0x14, 0x00
}

local SHADOW_AIR_BASELINE = {
    0x30, 0x01, 0xFF, 0x00, 0x0A, 0x00, 0x00, 0x00,
    0xC4, 0x00, 0x04, 0x00, 0x00, 0x00, 0x24, 0x42,
    0x00, 0x00, 0xEA, 0x42, 0x00, 0x00, 0x24, 0x42,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x42,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x22, 0x44,
    0x00, 0x00, 0xDC, 0xC2, 0x00, 0x00, 0x7A, 0xC3,
    0x81, 0xFD, 0x7F, 0x3F, 0x00, 0x00, 0x80, 0x3F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xD2, 0x42,
    0xB2, 0x00, 0x14, 0x00
}

local GUARD_BASELINE = {
    0x0B, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xAD, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x80, 0x3F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x05, 0x00
}

local SOURCE_GROUND_BASELINE = {
    0x0C, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xA6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x80, 0x3F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x12, 0x00, 0x05, 0x00
}

local SOURCE_AIR_BASELINE = {
    0x26, 0x00, 0xFF, 0x00, 0x01, 0x00, 0x00, 0x00,
    0xC0, 0x00, 0x04, 0x00, 0x00, 0x00, 0x60, 0x41,
    0x00, 0x00, 0xE4, 0x42, 0x00, 0x00, 0x60, 0x41,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x41,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x80, 0x3F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5C, 0x42,
    0x63, 0x00, 0x05, 0x00
}

local FrameNumber = 0
local LastInputRaw = nil
local LastLocateFrame = -LOCATE_RETRY_FRAMES
local LastLocateError = nil
local FatalErrorReported = false
local ShadowGroundAddress = nil
local ShadowAirAddress = nil
local SourceGroundAddress = nil
local SourceAirAddress = nil
local OwnsShadowProfiles = false
local OwnedGroundProfile = nil
local OwnedAirProfile = nil
local ArmedFrame = nil
local ArmedMotionId = nil
local ArmedMotionSlot = nil
local RearmAfterARelease = false
local PendingTrial = nil
local TrialNumber = 0

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function Log(message, level)
    ConsolePrint("[TargetlessEligibility] " .. tostring(message), level or 0)
end

local function HasButton(value, mask)
    return (value & mask) == mask
end

local function CloneBytes(source)
    local result = {}

    for index = 1, #source do
        result[index] = source[index]
    end

    return result
end

local function ReadRecord(address)
    local result = {}

    for offset = 0, PTYA_ENTRY_SIZE - 1 do
        result[offset + 1] = ReadByte(address + offset, true)
    end

    return result
end

local function RecordsEqual(left, right)
    if left == nil or right == nil or #left ~= #right then
        return false
    end

    for index = 1, #left do
        if left[index] ~= right[index] then
            return false
        end
    end

    return true
end

local function ReadMotion(record)
    return record[0x08 + 1] | (record[0x09 + 1] << 8)
end

local function ReadAbility(record)
    return record[0x40 + 1] | (record[0x41 + 1] << 8)
end

local function MatchesTemplateExceptMotion(record, template, allowedMotions)
    if record == nil or #record ~= PTYA_ENTRY_SIZE then
        return false
    end

    if not allowedMotions[ReadMotion(record)] then
        return false
    end

    for index = 1, PTYA_ENTRY_SIZE do
        local offset = index - 1

        if offset ~= 0x08 and offset ~= 0x09
            and record[index] ~= template[index]
        then
            return false
        end
    end

    return true
end

local function IsLegacyEligibilityRecord(
    record,
    template,
    allowedMotions,
    nativeAbility
)
    if record == nil or not allowedMotions[ReadMotion(record)] then
        return false
    end

    if record[0x01 + 1] ~= FREE_USE_TYPE then
        return false
    end

    local ability = ReadAbility(record)

    if ability ~= nativeAbility and ability ~= 0 then
        return false
    end

    for index = 1, PTYA_ENTRY_SIZE do
        local offset = index - 1

        if offset ~= 0x01
            and offset ~= 0x08
            and offset ~= 0x09
            and offset ~= 0x40
            and offset ~= 0x41
            and record[index] ~= template[index]
        then
            return false
        end
    end

    return true
end

local function BuildShadowProfile(source)
    local profile = CloneBytes(source)

    profile[0x01 + 1] = FREE_USE_TYPE

    -- CommandInputs' free-use profile clears the angular eligibility window,
    -- uses its 4.5912 blend marker and removes ability/score requirements.
    for offset = 0x30, 0x37 do
        profile[offset + 1] = 0
    end

    profile[0x38 + 1] = 0x1C
    profile[0x39 + 1] = 0xEB
    profile[0x3A + 1] = 0x92
    profile[0x3B + 1] = 0x40
    profile[0x40 + 1] = 0
    profile[0x41 + 1] = 0
    profile[0x42 + 1] = 0
    profile[0x43 + 1] = 0

    return profile
end

local function IsOwnedShadow(record, sourceTemplate, allowedMotions)
    return MatchesTemplateExceptMotion(
        record,
        BuildShadowProfile(sourceTemplate),
        allowedMotions
    )
end

local function ValidateLibraryAddresses()
    for _, fieldName in ipairs(REQUIRED_LIBRARY_ADDRESSES) do
        if type(kh2lib[fieldName]) ~= "number" then
            return false, fieldName
        end
    end

    return true
end

local function DisableWithFatalError(message)
    CanExecute = false

    if not FatalErrorReported then
        FatalErrorReported = true
        Log("DISABILITATO: " .. tostring(message), 3)
    end
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

local function WriteRecordBody(address, target)
    for index = 1, PTYA_ENTRY_SIZE do
        local offset = index - 1

        if offset ~= 0x01
            and ReadByte(address + offset, true) ~= target[index]
        then
            WriteByte(address + offset, target[index], true)
        end
    end
end

local function WriteRecordType(address, target)
    if ReadByte(address + 0x01, true) ~= target[0x01 + 1] then
        WriteByte(address + 0x01, target[0x01 + 1], true)
    end
end

local function RestoreCarrierPair(
    groundAddress,
    airAddress,
    groundBaseline,
    airBaseline
)
    -- Type=1 disarms the free-use profile before the remaining bytes move.
    WriteRecordType(groundAddress, groundBaseline)
    WriteRecordType(airAddress, airBaseline)
    WriteRecordBody(groundAddress, groundBaseline)
    WriteRecordBody(airAddress, airBaseline)

    return RecordsEqual(ReadRecord(groundAddress), groundBaseline)
        and RecordsEqual(ReadRecord(airAddress), airBaseline)
end

local function InstallCarrierPair(groundProfile, airProfile)
    -- Build both records while their vanilla Type=1 remains active, then
    -- publish Type=3 last so the engine never observes a half-built profile.
    WriteRecordBody(ShadowGroundAddress, groundProfile)
    WriteRecordBody(ShadowAirAddress, airProfile)
    WriteRecordType(ShadowGroundAddress, groundProfile)
    WriteRecordType(ShadowAirAddress, airProfile)

    return RecordsEqual(ReadRecord(ShadowGroundAddress), groundProfile)
        and RecordsEqual(ReadRecord(ShadowAirAddress), airProfile)
end

local function RecoverLegacyEligibility(groundAddress, airAddress)
    local ground = ReadRecord(groundAddress)
    local air = ReadRecord(airAddress)
    local groundBaseline = MatchesTemplateExceptMotion(
        ground,
        SOURCE_GROUND_BASELINE,
        ALLOWED_GROUND_MOTIONS
    )
    local airBaseline = MatchesTemplateExceptMotion(
        air,
        SOURCE_AIR_BASELINE,
        ALLOWED_AIR_MOTIONS
    )
    local groundLegacy = IsLegacyEligibilityRecord(
        ground,
        SOURCE_GROUND_BASELINE,
        ALLOWED_GROUND_MOTIONS,
        GROUND_NATIVE_ABILITY
    )
    local airLegacy = IsLegacyEligibilityRecord(
        air,
        SOURCE_AIR_BASELINE,
        ALLOWED_AIR_MOTIONS,
        AIR_NATIVE_ABILITY
    )

    if groundBaseline and airBaseline then
        return true
    end

    if not (groundBaseline or groundLegacy)
        or not (airBaseline or airLegacy)
    then
        return false
    end

    if groundLegacy then
        WriteByte(groundAddress + 0x01, VANILLA_ACTION_TYPE, true)
        WriteShort(groundAddress + 0x40, GROUND_NATIVE_ABILITY, true)
    end

    if airLegacy then
        WriteByte(airAddress + 0x01, VANILLA_ACTION_TYPE, true)
        WriteShort(airAddress + 0x40, AIR_NATIVE_ABILITY, true)
    end

    ground = ReadRecord(groundAddress)
    air = ReadRecord(airAddress)

    if not MatchesTemplateExceptMotion(
        ground,
        SOURCE_GROUND_BASELINE,
        ALLOWED_GROUND_MOTIONS
    ) or not MatchesTemplateExceptMotion(
        air,
        SOURCE_AIR_BASELINE,
        ALLOWED_AIR_MOTIONS
    ) then
        return false
    end

    Log("RECOVER V1/V2 eligibility residue -> Square source baseline", 2)
    return true
end

local function RecoverShadowResidue(groundAddress, airAddress)
    local ground = ReadRecord(groundAddress)
    local air = ReadRecord(airAddress)
    local groundBaseline = RecordsEqual(ground, SHADOW_GROUND_BASELINE)
    local airBaseline = RecordsEqual(air, SHADOW_AIR_BASELINE)
    local groundOwned = IsOwnedShadow(
        ground,
        SOURCE_GROUND_BASELINE,
        ALLOWED_GROUND_MOTIONS
    )
    local airOwned = IsOwnedShadow(
        air,
        SOURCE_AIR_BASELINE,
        ALLOWED_AIR_MOTIONS
    )

    if groundBaseline and airBaseline then
        return true
    end

    if not (groundBaseline or groundOwned)
        or not (airBaseline or airOwned)
    then
        return false
    end

    if not RestoreCarrierPair(
        groundAddress,
        airAddress,
        SHADOW_GROUND_BASELINE,
        SHADOW_AIR_BASELINE
    ) then
        return false
    end

    Log("RECOVER V3 shadow residue -> Aerial Sweep/Dive baseline", 2)
    return true
end

local function LocatePtya()
    if ShadowGroundAddress ~= nil
        and ShadowAirAddress ~= nil
        and SourceGroundAddress ~= nil
        and SourceAirAddress ~= nil
    then
        return true
    end

    if FrameNumber - LastLocateFrame < LOCATE_RETRY_FRAMES then
        return false
    end

    LastLocateFrame = FrameNumber
    local btl0 = ReadLong(kh2lib.Btl0Pointer)

    if btl0 == nil or btl0 == 0 or ReadInt(btl0, true) ~= BAR_MAGIC then
        return false
    end

    local subfileCount = ReadInt(btl0 + 0x04, true)

    if subfileCount < 1 or subfileCount > 128 then
        DisableWithFatalError("numero subfile 00battle inatteso")
        return false
    end

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
                DisableWithFatalError("offset gruppo Base PTYA inatteso")
                return false
            end

            local baseGroupAddress = address + groupOffset

            if ReadInt(baseGroupAddress, true) ~= BASE_RECORD_COUNT then
                DisableWithFatalError("record count Base PTYA inatteso")
                return false
            end

            local shadowGround = RecordAddress(
                baseGroupAddress,
                SHADOW_GROUND_RECORD
            )
            local shadowAir = RecordAddress(baseGroupAddress, SHADOW_AIR_RECORD)
            local guard = RecordAddress(baseGroupAddress, GUARD_RECORD)
            local sourceGround = RecordAddress(
                baseGroupAddress,
                SOURCE_GROUND_RECORD
            )
            local sourceAir = RecordAddress(baseGroupAddress, SOURCE_AIR_RECORD)

            if not RecordsEqual(ReadRecord(guard), GUARD_BASELINE) then
                DisableWithFatalError("record 31 Guardia non corrisponde alla baseline")
                return false
            end

            if not RecoverLegacyEligibility(sourceGround, sourceAir) then
                DisableWithFatalError("record source 32/34 PTYA inattesi")
                return false
            end

            if not RecoverShadowResidue(shadowGround, shadowAir) then
                DisableWithFatalError("shadow carrier 0/1 PTYA non riconosciuti")
                return false
            end

            ShadowGroundAddress = shadowGround
            ShadowAirAddress = shadowAir
            SourceGroundAddress = sourceGround
            SourceAirAddress = sourceAir
            LastLocateError = nil

            Log(string.format(
                "PTYA V3 verificata: Shadow=%s/%s Source=%s/%s Guard=byte-identica",
                Hex(shadowGround, 16),
                Hex(shadowAir, 16),
                Hex(sourceGround, 16),
                Hex(sourceAir, 16)
            ), 1)
            return true
        end
    end

    if LastLocateError ~= "NOT_FOUND" then
        LastLocateError = "NOT_FOUND"
        Log("PTYA in attesa; nuovo tentativo automatico", 2)
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

local function RestoreShadowProfiles(reason)
    if not OwnsShadowProfiles then
        ArmedFrame = nil
        ArmedMotionId = nil
        ArmedMotionSlot = nil
        PendingTrial = nil
        return true
    end

    local groundOwned = RecordsEqual(
        ReadRecord(ShadowGroundAddress),
        OwnedGroundProfile
    )
    local airOwned = RecordsEqual(
        ReadRecord(ShadowAirAddress),
        OwnedAirProfile
    )

    if not groundOwned or not airOwned then
        -- Restore only records that are still exactly ours. Unknown external
        -- data is never overwritten.
        if groundOwned then
            WriteRecordType(ShadowGroundAddress, SHADOW_GROUND_BASELINE)
            WriteRecordBody(ShadowGroundAddress, SHADOW_GROUND_BASELINE)
        end
        if airOwned then
            WriteRecordType(ShadowAirAddress, SHADOW_AIR_BASELINE)
            WriteRecordBody(ShadowAirAddress, SHADOW_AIR_BASELINE)
        end

        OwnsShadowProfiles = false
        OwnedGroundProfile = nil
        OwnedAirProfile = nil
        ArmedFrame = nil
        ArmedMotionId = nil
        ArmedMotionSlot = nil
        PendingTrial = nil
        DisableWithFatalError("rollback V3 rifiutato: shadow carrier modificato esternamente")
        return false
    end

    if not RestoreCarrierPair(
        ShadowGroundAddress,
        ShadowAirAddress,
        SHADOW_GROUND_BASELINE,
        SHADOW_AIR_BASELINE
    ) then
        DisableWithFatalError("verifica rollback V3 shadow carrier fallita")
        return false
    end

    OwnsShadowProfiles = false
    OwnedGroundProfile = nil
    OwnedAirProfile = nil
    ArmedFrame = nil
    ArmedMotionId = nil
    ArmedMotionSlot = nil
    PendingTrial = nil
    Log("RESTORE V3 shadow carrier reason=" .. tostring(reason))
    return true
end

local function SetShadowProfiles(state)
    if not LocatePtya() then
        return false
    end

    if OwnsShadowProfiles then
        return true
    end

    if not RecordsEqual(
        ReadRecord(ShadowGroundAddress),
        SHADOW_GROUND_BASELINE
    ) or not RecordsEqual(
        ReadRecord(ShadowAirAddress),
        SHADOW_AIR_BASELINE
    ) then
        DisableWithFatalError("pre-write shadow carrier fuori baseline")
        return false
    end

    local sourceGround = ReadRecord(SourceGroundAddress)
    local sourceAir = ReadRecord(SourceAirAddress)

    if not MatchesTemplateExceptMotion(
        sourceGround,
        SOURCE_GROUND_BASELINE,
        ALLOWED_GROUND_MOTIONS
    ) or not MatchesTemplateExceptMotion(
        sourceAir,
        SOURCE_AIR_BASELINE,
        ALLOWED_AIR_MOTIONS
    ) then
        DisableWithFatalError("source Square 32/34 cambiati prima dell'arm")
        return false
    end

    local groundProfile = BuildShadowProfile(sourceGround)
    local airProfile = BuildShadowProfile(sourceAir)

    if not InstallCarrierPair(groundProfile, airProfile) then
        RestoreCarrierPair(
            ShadowGroundAddress,
            ShadowAirAddress,
            SHADOW_GROUND_BASELINE,
            SHADOW_AIR_BASELINE
        )
        DisableWithFatalError("verifica installazione V3 shadow carrier fallita")
        return false
    end

    OwnsShadowProfiles = true
    OwnedGroundProfile = groundProfile
    OwnedAirProfile = airProfile
    ArmedFrame = FrameNumber
    ArmedMotionId = state.motionId
    ArmedMotionSlot = state.motionSlot

    Log(string.format(
        "ARM V3 r0<-r32 selector=%s motion=%s r1<-r34 selector=%s motion=%s",
        Hex(groundProfile[1], 2),
        Hex(ReadMotion(groundProfile), 4),
        Hex(airProfile[1], 2),
        Hex(ReadMotion(airProfile), 4)
    ))
    return true
end

local function DetectUncommandedShadow(state, squarePressed)
    if not OwnsShadowProfiles
        or PendingTrial ~= nil
        or squarePressed
        or ArmedMotionId == nil
        or ArmedMotionSlot == nil
    then
        return false
    end

    local expectedGround = ReadMotion(OwnedGroundProfile)
    local expectedAir = ReadMotion(OwnedAirProfile)
    local changed = state.motionId ~= ArmedMotionId
        or state.motionSlot ~= ArmedMotionSlot
    local shadowMotion = state.motionId == expectedGround
        or state.motionId == expectedAir

    if not changed or not shadowMotion then
        return false
    end

    Log(string.format(
        "CANDIDATO V3 RESPINTO: shadow action prima di Square motion=%s slot=%s",
        Hex(state.motionId, 4),
        Hex(state.motionSlot, 4)
    ), 3)
    RestoreShadowProfiles("HIJACK_BEFORE_SQUARE")
    RearmAfterARelease = false
    CanExecute = false
    return true
end

local function CompleteTrial(outcome, state)
    local trial = PendingTrial

    Log(string.format(
        "RESULT #%03d %s V3 domain=%s expected=%s before=%s/%s after=%s/%s",
        trial.number,
        outcome,
        trial.domain,
        Hex(trial.expectedMotion, 4),
        Hex(trial.beforeMotion, 4),
        Hex(trial.beforeSlot, 4),
        Hex(state.motionId, 4),
        Hex(state.motionSlot, 4)
    ), outcome == "ACCEPTED" and 1 or 2)

    RestoreShadowProfiles("RESULT_" .. outcome)
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
        CompleteTrial("ACCEPTED", state)
    elseif PendingTrial.age >= OUTCOME_TIMEOUT_FRAMES then
        CompleteTrial("REJECTED", state)
    end
end

local function StartTrial(state)
    if not OwnsShadowProfiles or ArmedFrame == nil then
        return
    end

    TrialNumber = TrialNumber + 1
    local airborne = IsAirborne(state)
    local profile = airborne and OwnedAirProfile or OwnedGroundProfile

    PendingTrial = {
        number = TrialNumber,
        age = 0,
        domain = airborne and "AIR" or "GROUND",
        expectedMotion = ReadMotion(profile),
        beforeMotion = state.motionId,
        beforeSlot = state.motionSlot
    }

    Log(string.format(
        "TRIAL #%03d V3 Square shadow domain=%s expected=%s before=%s/%s",
        PendingTrial.number,
        PendingTrial.domain,
        Hex(PendingTrial.expectedMotion, 4),
        Hex(PendingTrial.beforeMotion, 4),
        Hex(PendingTrial.beforeSlot, 4)
    ))

    UpdatePendingTrial(state)
end

function _OnInit()
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
    LastLocateFrame = -LOCATE_RETRY_FRAMES
    LastLocateError = nil
    FatalErrorReported = false
    ShadowGroundAddress = nil
    ShadowAirAddress = nil
    SourceGroundAddress = nil
    SourceAirAddress = nil
    OwnsShadowProfiles = false
    OwnedGroundProfile = nil
    OwnedAirProfile = nil
    ArmedFrame = nil
    ArmedMotionId = nil
    ArmedMotionSlot = nil
    RearmAfterARelease = false
    PendingTrial = nil
    TrialNumber = 0

    Log("EXPERIMENTAL WRITE V3: PTYA shadow carrier r0/r1 con selector Square 12/38.", 2)
    Log("A arma solo dopo il rilascio; ogni nuovo A ripristina r0/r1 prima del rearm.")
    Log("Guardia r31, input, target e source MotionId r32/r34 non vengono scritti.")
    LocatePtya()
end

function _OnFrame()
    if not CanExecute then
        return
    end

    FrameNumber = FrameNumber + 1
    local readSucceeded, stateOrError = pcall(ReadState)

    if not readSucceeded then
        DisableWithFatalError("lettura stato fallita: " .. tostring(stateOrError))
        return
    end

    local state = stateOrError

    if not IsSoraReady(state) or not IsRoutingAllowed(state) then
        if OwnsShadowProfiles then
            RestoreShadowProfiles("CONTEXT")
        end
        RearmAfterARelease = false
        LastInputRaw = state.inputRaw
        return
    end

    if not LocatePtya() then
        LastInputRaw = state.inputRaw
        return
    end

    if LastInputRaw == nil then
        LastInputRaw = state.inputRaw
        return
    end

    local pressedRaw = state.inputRaw & (~LastInputRaw & 0xFFFFFFFF)
    local aPressed = HasButton(pressedRaw, RAW32_A_MASK)
    local squarePressed = HasButton(pressedRaw, RAW32_SQUARE_MASK)
    local aHeld = HasButton(state.inputRaw, RAW32_A_MASK)

    UpdatePendingTrial(state)

    if not CanExecute
        or DetectUncommandedShadow(state, squarePressed)
    then
        return
    end

    if aPressed then
        if OwnsShadowProfiles then
            if not RestoreShadowProfiles("A_EDGE_BEFORE_REARM") then
                return
            end
        end

        RearmAfterARelease = true
        Log("A_EDGE: shadow baseline durante A; rearm rinviato al rilascio")
    end

    if squarePressed then
        if OwnsShadowProfiles and PendingTrial == nil then
            StartTrial(state)
        elseif not OwnsShadowProfiles then
            Log("SQUARE senza shadow arm: ownership nativa")
        end
    end

    if not CanExecute then
        return
    end

    if RearmAfterARelease
        and not aHeld
        and not squarePressed
        and PendingTrial == nil
        and not OwnsShadowProfiles
    then
        if SetShadowProfiles(state) then
            RearmAfterARelease = false
        end
    end

    if OwnsShadowProfiles
        and PendingTrial == nil
        and ArmedFrame ~= nil
        and FrameNumber - ArmedFrame >= ARM_TIMEOUT_FRAMES
    then
        RestoreShadowProfiles("ARM_TIMEOUT")
        RearmAfterARelease = false
    end

    LastInputRaw = state.inputRaw
end
