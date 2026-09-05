LUAGUI_NAME = "KH2 JokCombat - Normal Combo Grammar"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Branch A/Quadrato Base; Vicinity Break targetless standalone e record 32 nativo"

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
local FINISHING_LEAP_RECORD = 33
local AIR_SQUARE_RECORD = 34
local COUNTERGUARD_RECORD = 35
local RETALIATING_SLASH_RECORD = 36

local GUARD_MOTION = 173
local VICINITY_BREAK_MOTION = 170
local ENABLE_VICINITY_GUARD_CARRIER = true
local GUARD_SELECTOR = 11
local GUARD_ABILITY_SELECTOR = 0x01
local GROUND_SQUARE_NATIVE_SELECTOR = 12
local GROUND_SQUARE_NATIVE_ABILITY_SELECTOR = 0x12

local RAW32_A_MASK = 0x08000004
local RAW32_SQUARE_MASK = 0x04000200
local IDLE_RESET_FRAMES = 10
local ROUTE_TIMEOUT_FRAMES = 240
local LOCATE_RETRY_FRAMES = 60
local A_CONFIRM_TIMEOUT_FRAMES = 30
local SQUARE_CONFIRM_TIMEOUT_FRAMES = 30

-- Primo proof profile della grammatica approvata. Tutte le motion sono gia
-- presenti nel carrier Sora Base P_EX100; A e la pressione fisica di Quadrato
-- restano interamente del motore. Il record Guardia conserva selector e
-- ownership nativi, ma usa A319/Vicinity Break come carrier targetless ground.
-- Il clone Guard nel record 32 e stato falsificato dal gameplay e non viene
-- piu armato; l'unica eccezione residua serve a recuperare una firma V5
-- lasciata in RAM da un F1 eseguito mentre il vecchio proof era attivo.
local PROFILE_BY_DEPTH = {
    [0] = {
        ground = 166,
        groundName = "A315 Explosion (fallback asset)",
        air = 192,
        airName = "A341 Aerial Spiral (fallback asset)"
    },
    [1] = {
        ground = 161,
        groundName = "A310 Upper Slash",
        air = 192,
        airName = "A341 Aerial Spiral"
    },
    [2] = {
        ground = 162,
        groundName = "A311 Slapshot",
        air = 193,
        airName = "A342 Horizontal Slash"
    },
    [3] = {
        ground = 169,
        groundName = "A318 Flash Step",
        air = 196,
        airName = "A345 Aerial Dive"
    },
    [4] = {
        ground = 166,
        groundName = "A315 Explosion",
        air = 194,
        airName = "A343 Aerial Finish"
    }
}

local ALLOWED_GROUND_MOTIONS = {
    [161] = true,
    [162] = true,
    [166] = true,
    [169] = true
}

local ALLOWED_GUARD_MOTIONS = {
    [GUARD_MOTION] = true,
    [VICINITY_BREAK_MOTION] = true
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

local ObservedBtl0Address = nil
local PtyaNeedsBaseline = false
local PtyaAddress = nil
local BaseGroupAddress = nil
local GuardAddress = nil
local GroundSquareAddress = nil
local AirSquareAddress = nil
local FrameNumber = 0
local LastLocateFrame = -LOCATE_RETRY_FRAMES
local LastLocateError = nil
local LastInputRaw = nil
local Depth = 0
local IdleFrames = 0
local RouteAge = 0
local WasSoraReady = false
local FatalErrorReported = false
local LastMotionId = nil
local PendingA = nil
local GuardCarrierAnnounced = false
local PendingSquare = nil

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function LogMessage(message, level, category)
    local resolvedCategory = category or "COMBAT"

    if level ~= nil and level >= 3 then
        resolvedCategory = "ERROR"
    end

    if LoggerLoaded then
        return Logger.Log("NormalCombo", resolvedCategory, message, level)
    end

    if resolvedCategory == "ERROR" or resolvedCategory == "WARNING" then
        RawConsolePrint(
            "[NormalCombo][" .. resolvedCategory .. "] " .. tostring(message),
            level or (resolvedCategory == "ERROR" and 3 or 2)
        )
    end
end

local function ReportLoggerFailure()
    if not LoggerLoaded then
        RawConsolePrint(
            "[NormalCombo][ERROR] KH2JokCombat_Log non disponibile: "
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
        return nil, nil, "BAR header non valido"
    end

    local subfileCount = ReadInt(fileAddress + 0x04, true)

    if subfileNumber < 1 or subfileNumber > subfileCount then
        return nil, nil, "BAR subfile fuori range"
    end

    local subpoint = fileAddress + 0x08 + 0x10 * subfileNumber
    local relocatedOffset = ReadInt(subpoint, true)
    local subfileLength = ReadInt(subpoint + 0x04, true)
    local runtimeLookupBase = ReadInt(fileAddress + 0x08, true)

    return fileAddress + (relocatedOffset - runtimeLookupBase), subfileLength
end

local function RecordAddress(baseGroupAddress, record)
    return baseGroupAddress + 0x04 + record * PTYA_ENTRY_SIZE
end

local function ValidateRecord(address, expected, allowedMotions)
    local actualMotion = ReadShort(address + 0x08, true)

    if ReadByte(address + 0x00, true) ~= expected.selector
        or ReadByte(address + 0x01, true) ~= expected.type
        or ReadByte(address + 0x02, true) ~= 0xFF
        or ReadByte(address + 0x03, true) ~= expected.comboOffset
        or ReadInt(address + 0x04, true) ~= expected.flags
        or ReadShort(address + 0x0A, true) ~= expected.nextMotion
        or ReadShort(address + 0x40, true) ~= expected.ability
        or ReadShort(address + 0x42, true) ~= 5
    then
        return false, "campi immutabili inattesi"
    end

    if allowedMotions ~= nil and not allowedMotions[actualMotion] then
        return false, "MotionId non autorizzato " .. Hex(actualMotion, 4)
    end

    if allowedMotions == nil and actualMotion ~= expected.motion then
        return false, string.format(
            "MotionId inatteso %s (atteso %s)",
            Hex(actualMotion, 4),
            Hex(expected.motion, 4)
        )
    end

    return true
end

local function IsGroundSquareIdentityAllowed(selector, ability)
    return (selector == GROUND_SQUARE_NATIVE_SELECTOR
            and ability == GROUND_SQUARE_NATIVE_ABILITY_SELECTOR)
        or (selector == GUARD_SELECTOR
            and ability == GUARD_ABILITY_SELECTOR)
end

local function ValidateBaseRecords(baseGroupAddress)
    local specs = {
        [GUARD_RECORD] = {
            selector = GUARD_SELECTOR, type = 0, comboOffset = 0, flags = 0,
            nextMotion = 0, ability = GUARD_ABILITY_SELECTOR
        },
        [GROUND_SQUARE_RECORD] = {
            selector = GROUND_SQUARE_NATIVE_SELECTOR,
            type = 0, comboOffset = 0, flags = 0,
            nextMotion = 0,
            ability = GROUND_SQUARE_NATIVE_ABILITY_SELECTOR
        },
        [FINISHING_LEAP_RECORD] = {
            selector = 37, type = 0, comboOffset = 1, flags = 4,
            motion = 167, nextMotion = 4, ability = 0x5F
        },
        [AIR_SQUARE_RECORD] = {
            selector = 38, type = 0, comboOffset = 0, flags = 1,
            nextMotion = 4, ability = 0x63
        },
        [COUNTERGUARD_RECORD] = {
            selector = 39, type = 0, comboOffset = 0, flags = 0,
            motion = 171, nextMotion = 0, ability = 0x60
        },
        [RETALIATING_SLASH_RECORD] = {
            selector = 40, type = 0, comboOffset = 0, flags = 1,
            motion = 172, nextMotion = 4, ability = 0x65
        }
    }

    for record, spec in pairs(specs) do
        local allowedMotions = nil

        if record == GUARD_RECORD then
            allowedMotions = ALLOWED_GUARD_MOTIONS
        elseif record == GROUND_SQUARE_RECORD then
            local recordAddress = RecordAddress(baseGroupAddress, record)
            local selector = ReadByte(recordAddress + 0x00, true)
            local ability = ReadShort(recordAddress + 0x40, true)

            if not IsGroundSquareIdentityAllowed(selector, ability) then
                return false, string.format(
                    "record Base %d identita inattesa Selector=%s Ability=%s",
                    record,
                    Hex(selector, 2),
                    Hex(ability, 4)
                )
            end

            -- ValidateRecord continues to enforce every common field while
            -- accepting either the native Upper Slash identity or the exact
            -- Guard clone left by an F1/reload during an armed proof.
            spec.selector = selector
            spec.ability = ability
            allowedMotions = ALLOWED_GROUND_MOTIONS
        elseif record == AIR_SQUARE_RECORD then
            allowedMotions = ALLOWED_AIR_MOTIONS
        end

        local valid, validationError = ValidateRecord(
            RecordAddress(baseGroupAddress, record),
            spec,
            allowedMotions
        )

        if not valid then
            return false, string.format(
                "record Base %d non valido: %s",
                record,
                validationError
            )
        end
    end

    return true
end

local function FindLoadedPtya(btl0)
    if btl0 == nil or btl0 == 0 then
        return nil, "00battle.bin non ancora caricato", false
    end

    if ReadInt(btl0, true) ~= BAR_MAGIC then
        return nil, "Btl0Pointer non punta a un BAR valido", false
    end

    local subfileCount = ReadInt(btl0 + 0x04, true)

    if subfileCount < 1 or subfileCount > 128 then
        return nil, "numero subfile 00battle inatteso", true
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
                return nil, "offset gruppo Base PTYA inatteso", true
            end

            local baseGroupAddress = address + groupOffset

            if ReadInt(baseGroupAddress, true) ~= BASE_RECORD_COUNT then
                return nil, "record count Base PTYA inatteso", true
            end

            local recordsValid, recordError = ValidateBaseRecords(
                baseGroupAddress
            )

            if not recordsValid then
                return nil, recordError, true
            end

            return {
                address = address,
                baseGroupAddress = baseGroupAddress,
                subfileNumber = subfileNumber,
                guardAddress = RecordAddress(
                    baseGroupAddress,
                    GUARD_RECORD
                ),
                groundSquareAddress = RecordAddress(
                    baseGroupAddress,
                    GROUND_SQUARE_RECORD
                ),
                airSquareAddress = RecordAddress(
                    baseGroupAddress,
                    AIR_SQUARE_RECORD
                )
            }, nil, false
        end
    end

    return nil, "subfile PTYA verificata non trovata", false
end

local function DisableWithFatalError(message)
    CanExecute = false

    if not FatalErrorReported then
        FatalErrorReported = true
        LogMessage("DISABILITATO: " .. tostring(message), 3)
    end
end

local function InvalidatePtyaCache()
    -- Discard references and pending input without restoring freed/old RAM.
    PtyaAddress = nil
    BaseGroupAddress = nil
    GuardAddress = nil
    GroundSquareAddress = nil
    AirSquareAddress = nil
    PtyaNeedsBaseline = false
    LastLocateFrame = FrameNumber - LOCATE_RETRY_FRAMES
    LastLocateError = nil
    LastInputRaw = nil
    LastMotionId = nil
    WasSoraReady = false
    Depth = 0
    IdleFrames = 0
    RouteAge = 0
    PendingA = nil
    PendingSquare = nil
    GuardCarrierAnnounced = false
end

local function LocatePtyaIfNeeded()
    -- Read the owner pointer before any cached record can be used this frame.
    local pointerOk, btl0 = pcall(ReadLong, kh2lib.Btl0Pointer)

    if not pointerOk then
        InvalidatePtyaCache()
        DisableWithFatalError("lettura Btl0Pointer fallita: " .. tostring(btl0))
        return false
    end

    if btl0 ~= ObservedBtl0Address then
        InvalidatePtyaCache()
        ObservedBtl0Address = btl0
    end

    if PtyaAddress ~= nil then
        return true
    end

    if FrameNumber - LastLocateFrame < LOCATE_RETRY_FRAMES then
        return false
    end

    LastLocateFrame = FrameNumber

    local locateOk, located, locateError, fatal = pcall(FindLoadedPtya, btl0)

    if not locateOk then
        DisableWithFatalError("lettura BAR/PTYA fallita: " .. tostring(located))
        return false
    end

    if located == nil then
        if fatal then
            DisableWithFatalError(locateError)
        elseif locateError ~= LastLocateError then
            LastLocateError = locateError
            LogMessage(
                "PTYA in attesa: " .. tostring(locateError),
                2,
                "SYSTEM"
            )
        end

        return false
    end

    PtyaAddress = located.address
    BaseGroupAddress = located.baseGroupAddress
    GuardAddress = located.guardAddress
    GroundSquareAddress = located.groundSquareAddress
    AirSquareAddress = located.airSquareAddress
    PtyaNeedsBaseline = true
    LastLocateError = nil

    LogMessage(string.format(
        "PTYA trovata: Address=%s Base=%s BARSubfile=%d GuardRecord=%s GroundRecord=%s AirRecord=%s",
        Hex(PtyaAddress, 16),
        Hex(BaseGroupAddress, 16),
        located.subfileNumber,
        Hex(GuardAddress, 16),
        Hex(GroundSquareAddress, 16),
        Hex(AirSquareAddress, 16)
    ), 1, "SYSTEM")

    return true
end

local function SetGuardCarrier(reason)
    if GuardAddress == nil then
        DisableWithFatalError("indirizzo record Guardia non disponibile")
        return false
    end

    local before = ReadShort(GuardAddress + 0x08, true)

    if not ALLOWED_GUARD_MOTIONS[before] then
        DisableWithFatalError(
            "pre-write Guardia inattesa Motion=" .. Hex(before, 4)
        )
        return false
    end

    local target = ENABLE_VICINITY_GUARD_CARRIER
        and VICINITY_BREAK_MOTION
        or GUARD_MOTION

    if before ~= target then
        WriteShort(GuardAddress + 0x08, target, true)
    end

    local after = ReadShort(GuardAddress + 0x08, true)

    if after ~= target then
        if ALLOWED_GUARD_MOTIONS[before] then
            WriteShort(GuardAddress + 0x08, before, true)
        end

        DisableWithFatalError(string.format(
            "verifica carrier Guardia fallita Before=%s After=%s Target=%s",
            Hex(before, 4),
            Hex(after, 4),
            Hex(target, 4)
        ))
        return false
    end

    if not GuardCarrierAnnounced then
        GuardCarrierAnnounced = true

        if ENABLE_VICINITY_GUARD_CARRIER then
            LogMessage(string.format(
                "TARGETLESS GROUND PROOF: record 31 Guard usa %s[A319 Vicinity Break] reason=%s; selector/ability restano Guard",
                Hex(target, 4),
                tostring(reason)
            ))
        else
            LogMessage(
                "TARGETLESS GROUND PROOF disattivato: record 31 ripristinato ad A322 Guard"
            )
        end
    end

    return true
end

local function RestoreGroundSquareNativeIdentity(reason)
    if GroundSquareAddress == nil then
        DisableWithFatalError("indirizzo record 32 non disponibile")
        return false
    end

    local selectorBefore = ReadByte(GroundSquareAddress + 0x00, true)
    local typeBefore = ReadByte(GroundSquareAddress + 0x01, true)
    local abilityBefore = ReadShort(GroundSquareAddress + 0x40, true)

    if typeBefore ~= 0
        or not IsGroundSquareIdentityAllowed(selectorBefore, abilityBefore)
    then
        DisableWithFatalError(string.format(
            "identita record 32 inattesa Selector=%s Type=%s Ability=%s",
            Hex(selectorBefore, 2),
            Hex(typeBefore, 2),
            Hex(abilityBefore, 4)
        ))
        return false
    end

    local selectorTarget = GROUND_SQUARE_NATIVE_SELECTOR
    local abilityTarget = GROUND_SQUARE_NATIVE_ABILITY_SELECTOR

    if selectorBefore ~= selectorTarget then
        -- Type is verified zero and is rewritten atomically with the selector.
        WriteShort(GroundSquareAddress + 0x00, selectorTarget, true)
    end

    if abilityBefore ~= abilityTarget then
        WriteShort(GroundSquareAddress + 0x40, abilityTarget, true)
    end

    local selectorAfter = ReadByte(GroundSquareAddress + 0x00, true)
    local typeAfter = ReadByte(GroundSquareAddress + 0x01, true)
    local abilityAfter = ReadShort(GroundSquareAddress + 0x40, true)

    if selectorAfter ~= selectorTarget
        or typeAfter ~= 0
        or abilityAfter ~= abilityTarget
    then
        -- Full best-effort rollback to the exact identity observed before.
        WriteShort(
            GroundSquareAddress + 0x00,
            selectorBefore | (typeBefore << 8),
            true
        )
        WriteShort(GroundSquareAddress + 0x40, abilityBefore, true)

        DisableWithFatalError(string.format(
            "verifica ripristino nativo record 32 fallita Before=%s/%s After=%s/%s",
            Hex(selectorBefore, 2),
            Hex(abilityBefore, 4),
            Hex(selectorAfter, 2),
            Hex(abilityAfter, 4)
        ))
        return false
    end

    local changed = selectorBefore ~= selectorAfter
        or abilityBefore ~= abilityAfter
    if changed then
        LogMessage(string.format(
            "V5 GUARD32 RITIRATA: record 32 ripristinato Selector=%s Ability=%s reason=%s",
            Hex(selectorAfter, 2),
            Hex(abilityAfter, 4),
            tostring(reason)
        ))
    end

    return true
end

local function SetProfile(depth, reason)
    local profile = PROFILE_BY_DEPTH[depth]

    if profile == nil or GroundSquareAddress == nil or AirSquareAddress == nil then
        DisableWithFatalError("profilo o indirizzi PTYA non disponibili")
        return false
    end

    local groundSelector = ReadByte(GroundSquareAddress + 0x00, true)
    local groundType = ReadByte(GroundSquareAddress + 0x01, true)
    local groundAbility = ReadShort(GroundSquareAddress + 0x40, true)
    local groundBefore = ReadShort(GroundSquareAddress + 0x08, true)
    local airBefore = ReadShort(AirSquareAddress + 0x08, true)

    if groundType ~= 0
        or groundSelector ~= GROUND_SQUARE_NATIVE_SELECTOR
        or groundAbility ~= GROUND_SQUARE_NATIVE_ABILITY_SELECTOR
        or not ALLOWED_GROUND_MOTIONS[groundBefore]
        or not ALLOWED_AIR_MOTIONS[airBefore]
    then
        DisableWithFatalError(string.format(
            "pre-write PTYA inattesa GroundIdentity=%s/%s/%s Ground=%s Air=%s",
            Hex(groundSelector, 2),
            Hex(groundType, 2),
            Hex(groundAbility, 4),
            Hex(groundBefore, 4),
            Hex(airBefore, 4)
        ))
        return false
    end

    if groundBefore ~= profile.ground then
        WriteShort(GroundSquareAddress + 0x08, profile.ground, true)
    end

    if airBefore ~= profile.air then
        WriteShort(AirSquareAddress + 0x08, profile.air, true)
    end

    local groundAfter = ReadShort(GroundSquareAddress + 0x08, true)
    local airAfter = ReadShort(AirSquareAddress + 0x08, true)

    if groundAfter ~= profile.ground or airAfter ~= profile.air then
        -- Best-effort rollback to the values observed before this transaction.
        if ALLOWED_GROUND_MOTIONS[groundBefore] then
            WriteShort(GroundSquareAddress + 0x08, groundBefore, true)
        end
        if ALLOWED_AIR_MOTIONS[airBefore] then
            WriteShort(AirSquareAddress + 0x08, airBefore, true)
        end

        DisableWithFatalError(string.format(
            "verifica write PTYA fallita Ground=%s Air=%s",
            Hex(groundAfter, 4),
            Hex(airAfter, 4)
        ))
        return false
    end

    if groundBefore ~= groundAfter or airBefore ~= airAfter then
        LogMessage(string.format(
            "PROFILE A%d reason=%s Ground=%s[%s] Air=%s[%s]",
            depth,
            tostring(reason),
            Hex(profile.ground, 4),
            profile.groundName,
            Hex(profile.air, 4),
            profile.airName
        ), nil, "TRACE")
    end

    return true
end

local function PreparePtya(reason)
    if not LocatePtyaIfNeeded() or not SetGuardCarrier(reason) then
        return false
    end

    if PtyaNeedsBaseline then
        -- A newly loaded table may contain a previous profile or legacy V5.
        -- Recover only after discovery has validated all six records again.
        if not RestoreGroundSquareNativeIdentity(reason .. "_RECOVERY")
            or not SetProfile(0, reason)
        then
            return false
        end
        PtyaNeedsBaseline = false
    end

    return true
end

local function ReadState()
    local playerPointer = ReadLong(SORA_POINTER_STEAM_1_0_0_10)
    local motionId = 0
    local groundState = 0
    local groundSubstate = 0
    local airState = 0

    if playerPointer ~= nil and playerPointer ~= 0 then
        motionId = ReadInt(playerPointer + SORA_MOTION_ID_OFFSET, true)
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
        inputRaw = ReadInt(kh2lib.Input) & 0xFFFFFFFF,
        world = ReadByte(kh2lib.Now + 0x00),
        pause = ReadByte(kh2lib.Pause),
        control = ReadByte(kh2lib.Cntrl),
        reaction = ReadShort(kh2lib.React),
        openMenu = ReadByte(kh2lib.CurrentOpenMenu),
        storyFlags = ReadByte(kh2lib.Save + 0x1CEA),
        currentForm = ReadByte(kh2lib.Save + 0x3524),
        hpMax = ReadInt(kh2lib.Slot1 + 0x004),
        playerPointer = playerPointer or 0,
        motionId = motionId,
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

local function IsComboMotion(motionId)
    -- Sora Base standard/action ground motions A300-A322 (Guard excluded)
    -- plus the Base aerial family A330-A346.  This is used only to confirm
    -- that a physical A edge actually became an engine-owned attack.
    return (motionId >= 151 and motionId <= 172)
        or (motionId >= 181 and motionId <= 197)
end

local function ResetRoute(reason)
    local previousDepth = Depth
    local pendingSquareBeforeReset = PendingSquare

    if GroundSquareAddress ~= nil and CanExecute then
        if not RestoreGroundSquareNativeIdentity(reason) then
            return
        end
    end

    if previousDepth ~= 0 and GroundSquareAddress ~= nil and CanExecute then
        if not SetProfile(0, reason) then
            return
        end

        LogMessage(string.format(
            "RESET reason=%s depth=%d->0",
            tostring(reason),
            previousDepth
        ), nil, "TRACE")
    end

    if pendingSquareBeforeReset ~= nil then
        LogMessage(string.format(
            "SQUARE_RESULT REJECTED depth=%d domain=%s expected=%s[%s] reason=RESET_%s",
            pendingSquareBeforeReset.depth,
            pendingSquareBeforeReset.domain,
            Hex(pendingSquareBeforeReset.expectedMotion, 4),
            pendingSquareBeforeReset.expectedName,
            tostring(reason)
        ))
    end

    Depth = 0
    IdleFrames = 0
    RouteAge = 0
    PendingA = nil
    PendingSquare = nil
end

local function AcceptADepth(state, newDepth, reason)
    if not SetProfile(newDepth, reason) then
        return
    end

    LogMessage(string.format(
        "DEPTH A accepted reason=%s Motion=%s %d->%d",
        tostring(reason),
        Hex(state.motionId, 4),
        Depth,
        newDepth
    ), nil, "TRACE")

    Depth = newDepth
    IdleFrames = 0
    RouteAge = 0
    PendingA = nil
    PendingSquare = nil
end

local function QueueOrAcceptA(state)
    local newDepth

    -- A da neutrale apre sempre una nuova famiglia. A dopo un ramo Quadrato
    -- o durante una catena conserva invece la profondita virtuale e la porta
    -- avanti, saturando a quattro come da contratto.
    if state.motionId == 0 or Depth == 0 then
        newDepth = 1
    else
        newDepth = math.min(Depth + 1, 4)
    end

    -- Se il callback vede gia una nuova motion d'attacco, il motore ha
    -- consumato l'edge nello stesso frame. Il primo A da neutrale e comunque
    -- sicuro da preparare subito: in assenza di hit sara la dispatch nativa di
    -- Quadrato a non aprire il ramo.
    if Depth == 0
        or state.motionId == 0
        or (IsComboMotion(state.motionId)
            and LastMotionId ~= nil
            and state.motionId ~= LastMotionId)
    then
        AcceptADepth(state, newDepth, "IMMEDIATE")
        return
    end

    PendingA = {
        sourceMotion = state.motionId,
        targetDepth = newDepth,
        age = 0
    }

    LogMessage(string.format(
        "A_PENDING Motion=%s targetDepth=%d",
        Hex(state.motionId, 4),
        newDepth
    ), nil, "TRACE")
end

local function UpdatePendingA(state)
    if PendingA == nil then
        return
    end

    PendingA.age = PendingA.age + 1

    if state.motionId ~= PendingA.sourceMotion then
        if IsComboMotion(state.motionId) then
            AcceptADepth(state, PendingA.targetDepth, "MOTION_CONFIRMED")
        else
            LogMessage(string.format(
                "A_CANCEL source=%s destination=%s",
                Hex(PendingA.sourceMotion, 4),
                Hex(state.motionId, 4)
            ), nil, "TRACE")
            PendingA = nil
        end
    elseif PendingA.age >= A_CONFIRM_TIMEOUT_FRAMES then
        LogMessage(string.format(
            "A_CANCEL timeout source=%s",
            Hex(PendingA.sourceMotion, 4)
        ), nil, "TRACE")
        PendingA = nil
    end
end

local function UpdatePendingSquare(state)
    if PendingSquare == nil then
        return
    end

    PendingSquare.age = PendingSquare.age + 1

    if state.motionId == PendingSquare.expectedMotion then
        LogMessage(string.format(
            "SQUARE_RESULT ACCEPTED depth=%d domain=%s Motion=%s[%s]",
            PendingSquare.depth,
            PendingSquare.domain,
            Hex(PendingSquare.expectedMotion, 4),
            PendingSquare.expectedName
        ))
        PendingSquare = nil
        IdleFrames = 0
        RouteAge = 0
    elseif PendingSquare.age >= SQUARE_CONFIRM_TIMEOUT_FRAMES then
        LogMessage(string.format(
            "SQUARE_RESULT REJECTED depth=%d domain=%s expected=%s[%s] current=%s reason=TIMEOUT",
            PendingSquare.depth,
            PendingSquare.domain,
            Hex(PendingSquare.expectedMotion, 4),
            PendingSquare.expectedName,
            Hex(state.motionId, 4)
        ))
        PendingSquare = nil
        ResetRoute("SQUARE_REJECTED")
    end
end

local function LogSquareBranch(state)
    if Depth == 0 then
        LogMessage(
            "SQUARE depth=0 prepared=0x00AA[A319 Vicinity Break] owner=GUARD_CARRIER acceptance=GAMEPLAY_PENDING"
        )
        return
    end

    local profile = PROFILE_BY_DEPTH[Depth]
    local domain = IsAirborne(state) and "AIR" or "GROUND"
    local motion = IsAirborne(state) and profile.air or profile.ground
    local motionName = IsAirborne(state)
        and profile.airName
        or profile.groundName

    LogMessage(string.format(
        "SQUARE depth=%d domain=%s prepared=%s[%s] owner=%s acceptance=GAMEPLAY_PENDING",
        Depth,
        domain,
        Hex(motion, 4),
        motionName,
        "NATIVE_DISPATCH"
    ))

    if state.motionId == motion then
        LogMessage(string.format(
            "SQUARE_RESULT ACCEPTED depth=%d domain=%s Motion=%s[%s] same-frame=true",
            Depth,
            domain,
            Hex(motion, 4),
            motionName
        ))
        PendingSquare = nil
    else
        PendingSquare = {
            sourceMotion = state.motionId,
            expectedMotion = motion,
            expectedName = motionName,
            depth = Depth,
            domain = domain,
            age = 0
        }
    end

    IdleFrames = 0
    RouteAge = 0
end

function _OnInit()
    ReportLoggerFailure()
    local libraryLoaded, libraryOrError = pcall(require, "kh2lib")

    if not libraryLoaded then
        LogMessage(
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
        DisableWithFatalError(
            "campo kh2lib mancante: " .. tostring(missingField)
        )
        return
    end

    if kh2lib.GameVersion ~= KH2_VERSION_STEAM_1_0_0_10 then
        DisableWithFatalError(
            "supportata solo Steam 1.0.0.10; versione="
            .. Hex(kh2lib.GameVersion, 4)
        )
        return
    end

    FrameNumber = 0
    ObservedBtl0Address = nil
    InvalidatePtyaCache()
    FatalErrorReported = false

    LogMessage(
        "inizializzato: A resta nativa; Quadrato neutrale usa Guard->A319; record 32 conserva l'identita nativa; nessun input viene sintetizzato.",
        1,
        "SYSTEM"
    )
    LogMessage(
        "GROUND A1=A310 A2=A311 A3=A318 A4=A315",
        nil,
        "SYSTEM"
    )
    LogMessage(
        "AIR A1=A341 A2=A342 A3=A345 A4=A343",
        nil,
        "SYSTEM"
    )

    PreparePtya("INIT")
end

function _OnFrame()
    if not CanExecute then
        return
    end

    FrameNumber = FrameNumber + 1

    if not PreparePtya("FRAME") then
        return
    end

    local readSucceeded, stateOrError = pcall(ReadState)

    if not readSucceeded then
        DisableWithFatalError("lettura stato fallita: " .. tostring(stateOrError))
        return
    end

    local state = stateOrError

    if not IsSoraReady(state) then
        if WasSoraReady then
            ResetRoute("SORA_NOT_READY")
        end

        WasSoraReady = false
        LastInputRaw = nil
        LastMotionId = nil
        PendingA = nil
        PendingSquare = nil
        return
    end

    if not WasSoraReady then
        WasSoraReady = true
        LastInputRaw = state.inputRaw
        LastMotionId = state.motionId
        ResetRoute("SORA_READY_BASELINE")
        LogMessage(string.format(
            "BASELINE Input=%s Motion=%s",
            Hex(state.inputRaw, 8),
            Hex(state.motionId, 4)
        ), nil, "TRACE")
        return
    end

    if not IsRoutingAllowed(state) then
        LastInputRaw = state.inputRaw
        LastMotionId = state.motionId
        ResetRoute("NATIVE_CONTEXT_PRIORITY")

        return
    end

    local pressedRaw = state.inputRaw & (~LastInputRaw & 0xFFFFFFFF)
    local aPressed = HasButton(pressedRaw, RAW32_A_MASK)
    local squarePressed = HasButton(pressedRaw, RAW32_SQUARE_MASK)

    UpdatePendingA(state)

    if not CanExecute then
        return
    end

    UpdatePendingSquare(state)

    if not CanExecute then
        return
    end

    if aPressed then
        QueueOrAcceptA(state)
    end

    if CanExecute and squarePressed then
        LogSquareBranch(state)
    end

    if not CanExecute then
        return
    end

    if aPressed or squarePressed then
        IdleFrames = 0
        RouteAge = 0
    else
        RouteAge = RouteAge + 1

        if state.motionId == 0 then
            IdleFrames = IdleFrames + 1
        else
            IdleFrames = 0
        end

        if Depth ~= 0 and IdleFrames >= IDLE_RESET_FRAMES then
            ResetRoute("IDLE")
        elseif Depth ~= 0 and RouteAge >= ROUTE_TIMEOUT_FRAMES then
            ResetRoute("TIMEOUT")
        end
    end

    LastInputRaw = state.inputRaw
    LastMotionId = state.motionId
end
