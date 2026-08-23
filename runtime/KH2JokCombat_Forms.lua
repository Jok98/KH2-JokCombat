LUAGUI_NAME = "KH2 JokCombat - Sora Forms"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Unlocks every Drive Form, maxes form progression, Sora AP and native form rewards"

local kh2lib = nil
local CanExecute = false
local PatchCompleted = false
local PatchDisabled = false
local ErrorReported = false

local SORA_STORY_FLAG_OFFSET = 0x1CEA
local SORA_STORY_FLAG_MASK = 0x01

local ITEM_SET_1_OFFSET = 0x36C0
local ITEM_SET_1_FORM_MASK = 0x76
local ITEM_SET_11_OFFSET = 0x36CA
local ITEM_SET_11_LIMIT_MASK = 0x08

local CURRENT_FORM_OFFSET = 0x3524
local DRIVE_SAVE_CURRENT_OFFSET = 0x3529
local DRIVE_SAVE_MAX_OFFSET = 0x352A
local DRIVE_LIVE_PERCENT_OFFSET = 0x1B0
local DRIVE_LIVE_CURRENT_OFFSET = 0x1B1
local DRIVE_LIVE_MAX_OFFSET = 0x1B2

-- Slot1 stores Sora's live AP in one byte. 0xFF is therefore the absolute
-- representable maximum and matches established KH2 Max AP patches.
local SORA_LIVE_AP_OFFSET = 0x18E
local SORA_MAX_AP = 0xFF

local ABILITY_TABLE_OFFSET = 0x2544
local STANDARD_ABILITY_SLOT_COUNT = 69
local ABILITY_ID_MASK = 0x0FFF
local EQUIPPED_FLAG = 0x8000

-- OpenKH maps each Final Mix form block to a 0x38-byte record:
-- weapon(+0), level(+2), ability level(+3), experience(+4), 24 abilities(+8).
-- The innate target arrays below come from the vanilla 00battle.bin/plrp rows
-- for characters 129..133. Anti is unlocked only by inventory bit: Final Mix
-- drive-form index 5 is Summon, so Anti has no writable save-form record here.
local DRIVE_FORMS = {
    {
        name = "Valor",
        blockOffset = 0x32F4,
        levelled = true,
        growthName = "High Jump",
        growthMinId = 0x005E,
        growthMaxId = 0x0061,
        innateAbilities = {
            { id = 0x00D8, targetCount = 1 },
            { id = 0x00D9, targetCount = 1 },
            { id = 0x00DA, targetCount = 1 },
            { id = 0x00DB, targetCount = 1 },
            { id = 0x00F6, targetCount = 1 },
            { id = 0x00F7, targetCount = 1 },
            { id = 0x0111, targetCount = 1 },
            { id = 0x00DF, targetCount = 1 },
            { id = 0x00A2, targetCount = 1 },
            { id = 0x00A3, targetCount = 1 }
        }
    },
    {
        name = "Wisdom",
        blockOffset = 0x332C,
        levelled = true,
        growthName = "Quick Run",
        growthMinId = 0x0062,
        growthMaxId = 0x0065,
        innateAbilities = {
            { id = 0x00DC, targetCount = 1 },
            { id = 0x00DD, targetCount = 1 },
            { id = 0x00E0, targetCount = 1 },
            { id = 0x00E1, targetCount = 1 },
            { id = 0x0111, targetCount = 1 },
            { id = 0x01A6, targetCount = 2 }
        }
    },
    {
        name = "Limit",
        blockOffset = 0x3364,
        levelled = true,
        growthName = "Dodge Roll",
        growthMinId = 0x0234,
        growthMaxId = 0x0237,
        innateAbilities = {
            { id = 0x0239, targetCount = 1 },
            { id = 0x023A, targetCount = 1 },
            { id = 0x023B, targetCount = 1 },
            { id = 0x023C, targetCount = 1 },
            { id = 0x023D, targetCount = 1 },
            { id = 0x023E, targetCount = 1 },
            { id = 0x023F, targetCount = 1 },
            { id = 0x024B, targetCount = 1 },
            { id = 0x024C, targetCount = 1 },
            { id = 0x024D, targetCount = 1 },
            { id = 0x0052, targetCount = 1 },
            { id = 0x0106, targetCount = 1 },
            { id = 0x0108, targetCount = 1 },
            { id = 0x010D, targetCount = 1 },
            { id = 0x019C, targetCount = 1 },
            { id = 0x0195, targetCount = 1 },
            { id = 0x0197, targetCount = 1 },
            { id = 0x019D, targetCount = 1 }
        }
    },
    {
        name = "Master",
        blockOffset = 0x339C,
        levelled = true,
        growthName = "Aerial Dodge",
        growthMinId = 0x0066,
        growthMaxId = 0x0069,
        innateAbilities = {
            { id = 0x0101, targetCount = 1 },
            { id = 0x0102, targetCount = 1 },
            { id = 0x0105, targetCount = 1 },
            { id = 0x00DF, targetCount = 1 },
            { id = 0x0103, targetCount = 1 },
            { id = 0x01A5, targetCount = 1 },
            { id = 0x00A3, targetCount = 2 },
            { id = 0x0195, targetCount = 2 }
        }
    },
    {
        name = "Final",
        blockOffset = 0x33D4,
        levelled = true,
        growthName = "Glide",
        growthMinId = 0x006A,
        growthMaxId = 0x006D,
        innateAbilities = {
            { id = 0x0207, targetCount = 1 },
            { id = 0x00DD, targetCount = 1 },
            { id = 0x00DF, targetCount = 1 },
            { id = 0x020F, targetCount = 1 },
            { id = 0x0210, targetCount = 1 },
            { id = 0x0211, targetCount = 1 },
            { id = 0x0212, targetCount = 1 },
            { id = 0x019D, targetCount = 1 }
        }
    }
}

-- Exact vanilla FMLV rewards earned while leveling all five normal forms.
-- Growth rewards are represented by the five dedicated base-Sora slots and by
-- each form's first ability slot. Combo Plus and Air Combo Plus intentionally
-- share the same target counts as Sora Combat Core, making both modules
-- idempotent regardless of Lua load order. Auto Form rewards remain present
-- for completeness but are deliberately written without the equipped bit.
local FORM_REWARD_ABILITIES = {
    { name = "Auto Valor", id = 0x0181, targetCount = 1, equipped = false },
    { name = "Auto Wisdom", id = 0x0182, targetCount = 1, equipped = false },
    { name = "Auto Limit", id = 0x0238, targetCount = 1, equipped = false },
    { name = "Auto Master", id = 0x0183, targetCount = 1, equipped = false },
    { name = "Auto Final", id = 0x0184, targetCount = 1, equipped = false },
    { name = "Combo Plus", id = 0x00A2, targetCount = 2 },
    { name = "MP Rage", id = 0x019C, targetCount = 1 },
    { name = "MP Haste", id = 0x019D, targetCount = 1 },
    { name = "Draw", id = 0x0195, targetCount = 1 },
    { name = "Lucky Lucky", id = 0x0197, targetCount = 1 },
    { name = "Air Combo Plus", id = 0x00A3, targetCount = 2 },
    { name = "Form Boost", id = 0x018E, targetCount = 2 }
}

local function Hex(value, width)
    return string.format("0x%0" .. tostring(width) .. "X", value or 0)
end

local function IsSoraGameplayReady()
    local world = ReadByte(kh2lib.Now + 0x00)
    local room = ReadByte(kh2lib.Now + 0x01)
    local maxHp = ReadInt(kh2lib.Slot1 + 0x004)
    local storyFlags = ReadByte(kh2lib.Save + SORA_STORY_FLAG_OFFSET)
    local isSora = (storyFlags & SORA_STORY_FLAG_MASK) ~= 0

    return isSora
        and world ~= 0xFF
        and room ~= 0xFF
        and maxHp > 0
end

local function ReadValue(kind, address)
    if kind == "byte" then
        return ReadByte(address)
    elseif kind == "short" then
        return ReadShort(address)
    elseif kind == "int" then
        return ReadInt(address)
    end

    error("Tipo lettura sconosciuto: " .. tostring(kind))
end

local function WriteValue(kind, address, value)
    if kind == "byte" then
        WriteByte(address, value)
    elseif kind == "short" then
        WriteShort(address, value)
    elseif kind == "int" then
        WriteInt(address, value)
    else
        error("Tipo scrittura sconosciuto: " .. tostring(kind))
    end
end

local function AddWrite(writes, kind, name, address, before, desired)
    if before == desired then
        return
    end

    writes[#writes + 1] = {
        kind = kind,
        name = name,
        address = address,
        before = before,
        desired = desired
    }
end

local function InspectUnlocks(writes)
    local itemSet1Address = kh2lib.Save + ITEM_SET_1_OFFSET
    local itemSet1Before = ReadByte(itemSet1Address)

    AddWrite(
        writes,
        "byte",
        "ItemSet1: Valor/Wisdom/Master/Final/Anti",
        itemSet1Address,
        itemSet1Before,
        itemSet1Before | ITEM_SET_1_FORM_MASK
    )

    local itemSet11Address = kh2lib.Save + ITEM_SET_11_OFFSET
    local itemSet11Before = ReadByte(itemSet11Address)

    AddWrite(
        writes,
        "byte",
        "ItemSet11: Limit",
        itemSet11Address,
        itemSet11Before,
        itemSet11Before | ITEM_SET_11_LIMIT_MASK
    )
end

local function InspectInnateAbilitySlots(form, writes)
    local targetById = {}
    local matchesById = {}
    local freeSlots = {}

    for _, target in ipairs(form.innateAbilities) do
        targetById[target.id] = target
        matchesById[target.id] = {}
    end

    for slot = 0, 23 do
        local address = kh2lib.Save + form.blockOffset + 0x08 + (slot * 2)
        local value = ReadShort(address)
        local abilityId = value & ABILITY_ID_MASK

        if form.growthMaxId ~= nil and slot == 0 then
            local unexpectedGrowthFlags = value & 0x7000

            if value ~= 0
                and (abilityId < form.growthMinId
                    or abilityId > form.growthMaxId
                    or unexpectedGrowthFlags ~= 0) then

                error(string.format(
                    "%s primo slot ability inatteso a Save+%s: %s",
                    form.name,
                    Hex(form.blockOffset + 0x08, 4),
                    Hex(value, 4)
                ))
            end

            AddWrite(
                writes,
                "short",
                form.name .. " " .. form.growthName .. " MAX",
                address,
                value,
                form.growthMaxId | EQUIPPED_FLAG
            )
        else
            if form.growthMaxId ~= nil
                and abilityId >= form.growthMinId
                and abilityId <= form.growthMaxId then

                error(string.format(
                    "%s contiene una growth duplicata nello slot %d: %s",
                    form.name,
                    slot,
                    Hex(value, 4)
                ))
            end

            if value == 0 then
                freeSlots[#freeSlots + 1] = {
                    index = slot,
                    address = address,
                    before = value
                }
            elseif targetById[abilityId] ~= nil then
                matchesById[abilityId][#matchesById[abilityId] + 1] = {
                    index = slot,
                    address = address,
                    before = value
                }
            end
        end
    end

    local missingTotal = 0

    for _, target in ipairs(form.innateAbilities) do
        local missing = target.targetCount - #matchesById[target.id]

        if missing > 0 then
            missingTotal = missingTotal + missing
        end
    end

    if #freeSlots < missingTotal then
        error(string.format(
            "%s non ha slot ability sufficienti: servono %d, disponibili %d",
            form.name,
            missingTotal,
            #freeSlots
        ))
    end

    local freeIndex = 1

    for _, target in ipairs(form.innateAbilities) do
        local matches = matchesById[target.id]

        for _, match in ipairs(matches) do
            if (match.before & EQUIPPED_FLAG) == 0 then
                AddWrite(
                    writes,
                    "short",
                    string.format(
                        "%s innate %s slot %d",
                        form.name,
                        Hex(target.id, 4),
                        match.index
                    ),
                    match.address,
                    match.before,
                    match.before | EQUIPPED_FLAG
                )
            end
        end

        local missing = target.targetCount - #matches

        for _ = 1, math.max(0, missing) do
            local freeSlot = freeSlots[freeIndex]
            freeIndex = freeIndex + 1

            AddWrite(
                writes,
                "short",
                string.format(
                    "%s innate %s nuovo slot %d",
                    form.name,
                    Hex(target.id, 4),
                    freeSlot.index
                ),
                freeSlot.address,
                freeSlot.before,
                target.id | EQUIPPED_FLAG
            )
        end
    end
end

local function InspectDriveForms(writes)
    for _, form in ipairs(DRIVE_FORMS) do
        if form.levelled then
            local levelAddress = kh2lib.Save + form.blockOffset + 0x02
            local abilityLevelAddress = kh2lib.Save + form.blockOffset + 0x03
            local experienceAddress = kh2lib.Save + form.blockOffset + 0x04

            local levelBefore = ReadByte(levelAddress)
            local abilityLevelBefore = ReadByte(abilityLevelAddress)
            local experienceBefore = ReadInt(experienceAddress)

            if levelBefore > 7 then
                error(string.format(
                    "%s Level inatteso a Save+%s: %d",
                    form.name,
                    Hex(form.blockOffset + 0x02, 4),
                    levelBefore
                ))
            end

            if abilityLevelBefore > 4 then
                error(string.format(
                    "%s AbilityLevel inatteso a Save+%s: %d",
                    form.name,
                    Hex(form.blockOffset + 0x03, 4),
                    abilityLevelBefore
                ))
            end

            if experienceBefore < 0 or experienceBefore > 10000000 then
                error(string.format(
                    "%s EXP inattesa a Save+%s: %d",
                    form.name,
                    Hex(form.blockOffset + 0x04, 4),
                    experienceBefore
                ))
            end

            AddWrite(
                writes,
                "byte",
                form.name .. " Level",
                levelAddress,
                levelBefore,
                7
            )
            AddWrite(
                writes,
                "byte",
                form.name .. " AbilityLevel",
                abilityLevelAddress,
                abilityLevelBefore,
                4
            )
            AddWrite(
                writes,
                "int",
                form.name .. " EXP",
                experienceAddress,
                experienceBefore,
                0
            )
        end

        InspectInnateAbilitySlots(form, writes)
    end
end

local function ValidateGaugeByte(name, value, maximum)
    if value < 0 or value > maximum then
        error(string.format(
            "%s fuori intervallo 0..%d: %d",
            name,
            maximum,
            value
        ))
    end
end

local function InspectDriveGauge(writes)
    local saveMaxAddress = kh2lib.Save + DRIVE_SAVE_MAX_OFFSET
    local saveCurrentAddress = kh2lib.Save + DRIVE_SAVE_CURRENT_OFFSET
    local liveMaxAddress = kh2lib.Slot1 + DRIVE_LIVE_MAX_OFFSET
    local liveCurrentAddress = kh2lib.Slot1 + DRIVE_LIVE_CURRENT_OFFSET
    local livePercentAddress = kh2lib.Slot1 + DRIVE_LIVE_PERCENT_OFFSET

    local saveMaxBefore = ReadByte(saveMaxAddress)
    local saveCurrentBefore = ReadByte(saveCurrentAddress)
    local liveMaxBefore = ReadByte(liveMaxAddress)
    local liveCurrentBefore = ReadByte(liveCurrentAddress)
    local livePercentBefore = ReadByte(livePercentAddress)

    ValidateGaugeByte("Drive save max", saveMaxBefore, 9)
    ValidateGaugeByte("Drive save corrente", saveCurrentBefore, 9)
    ValidateGaugeByte("Drive live max", liveMaxBefore, 9)
    ValidateGaugeByte("Drive live corrente", liveCurrentBefore, 9)
    ValidateGaugeByte("Drive live percentuale", livePercentBefore, 100)

    -- Raise the caps before filling the corresponding current values.
    AddWrite(writes, "byte", "Drive save max", saveMaxAddress, saveMaxBefore, 9)
    AddWrite(writes, "byte", "Drive save corrente", saveCurrentAddress, saveCurrentBefore, 9)
    AddWrite(writes, "byte", "Drive live max", liveMaxAddress, liveMaxBefore, 9)
    AddWrite(writes, "byte", "Drive live corrente", liveCurrentAddress, liveCurrentBefore, 9)
    AddWrite(writes, "byte", "Drive live percentuale", livePercentAddress, livePercentBefore, 100)
end

local function InspectSoraAp(writes)
    local address = kh2lib.Slot1 + SORA_LIVE_AP_OFFSET
    local before = ReadByte(address)

    AddWrite(
        writes,
        "byte",
        "Sora AP live",
        address,
        before,
        SORA_MAX_AP
    )
end

local function InspectFormRewards(writes)
    local abilityById = {}
    local matchesById = {}
    local freeSlots = {}

    for _, ability in ipairs(FORM_REWARD_ABILITIES) do
        abilityById[ability.id] = ability
        matchesById[ability.id] = {}
    end

    for slot = 0, STANDARD_ABILITY_SLOT_COUNT - 1 do
        local address = kh2lib.Save + ABILITY_TABLE_OFFSET + (slot * 2)
        local value = ReadShort(address)

        if value == 0 then
            freeSlots[#freeSlots + 1] = {
                index = slot,
                address = address,
                before = value
            }
        else
            local abilityId = value & ABILITY_ID_MASK

            if abilityById[abilityId] ~= nil then
                matchesById[abilityId][#matchesById[abilityId] + 1] = {
                    index = slot,
                    address = address,
                    before = value
                }
            end
        end
    end

    local missingTotal = 0

    for _, ability in ipairs(FORM_REWARD_ABILITIES) do
        local missing = ability.targetCount - #matchesById[ability.id]

        if missing > 0 then
            missingTotal = missingTotal + missing
        end
    end

    if #freeSlots < missingTotal then
        error(string.format(
            "Slot ability insufficienti per le ricompense Form: servono %d, disponibili %d",
            missingTotal,
            #freeSlots
        ))
    end

    local freeIndex = 1

    for _, ability in ipairs(FORM_REWARD_ABILITIES) do
        local matches = matchesById[ability.id]
        local shouldEquip = ability.equipped ~= false

        for _, match in ipairs(matches) do
            local desired = shouldEquip
                and (match.before | EQUIPPED_FLAG)
                or (match.before & 0x7FFF)

            if desired ~= match.before then
                AddWrite(
                    writes,
                    "short",
                    ability.name .. " slot " .. tostring(match.index),
                    match.address,
                    match.before,
                    desired
                )
            end
        end

        local missing = ability.targetCount - #matches

        for _ = 1, math.max(0, missing) do
            local freeSlot = freeSlots[freeIndex]
            freeIndex = freeIndex + 1

            AddWrite(
                writes,
                "short",
                ability.name .. " nuovo slot " .. tostring(freeSlot.index),
                freeSlot.address,
                freeSlot.before,
                ability.id | (shouldEquip and EQUIPPED_FLAG or 0)
            )
        end
    end
end

local function BuildPatchPlan()
    local writes = {}

    InspectUnlocks(writes)
    InspectDriveForms(writes)
    InspectDriveGauge(writes)
    InspectSoraAp(writes)
    InspectFormRewards(writes)

    return writes
end

local function ApplyPatchPlan(writes)
    for _, write in ipairs(writes) do
        local current = ReadValue(write.kind, write.address)

        if current ~= write.before then
            error(string.format(
                "%s cambiato durante la preparazione: %s -> %s",
                write.name,
                Hex(write.before, write.kind == "byte" and 2 or 4),
                Hex(current, write.kind == "byte" and 2 or 4)
            ))
        end

        WriteValue(write.kind, write.address, write.desired)

        local after = ReadValue(write.kind, write.address)

        if after ~= write.desired then
            error(string.format(
                "Verifica %s fallita: atteso %s, letto %s",
                write.name,
                Hex(write.desired, write.kind == "byte" and 2 or 4),
                Hex(after, write.kind == "byte" and 2 or 4)
            ))
        end

        ConsolePrint(string.format(
            "%s: %s -> %s",
            write.name,
            Hex(write.before, write.kind == "byte" and 2 or 4),
            Hex(after, write.kind == "byte" and 2 or 4)
        ), 1)
    end
end

local function VerifyUnlocks()
    local itemSet1 = ReadByte(kh2lib.Save + ITEM_SET_1_OFFSET)
    local itemSet11 = ReadByte(kh2lib.Save + ITEM_SET_11_OFFSET)

    if (itemSet1 & ITEM_SET_1_FORM_MASK) ~= ITEM_SET_1_FORM_MASK then
        error("Verifica sblocco ItemSet1 fallita: " .. Hex(itemSet1, 2))
    end

    if (itemSet11 & ITEM_SET_11_LIMIT_MASK) ~= ITEM_SET_11_LIMIT_MASK then
        error("Verifica sblocco Limit fallita: " .. Hex(itemSet11, 2))
    end
end

local function VerifyDriveForms()
    for _, form in ipairs(DRIVE_FORMS) do
        if form.levelled then
            local level = ReadByte(kh2lib.Save + form.blockOffset + 0x02)
            local abilityLevel = ReadByte(kh2lib.Save + form.blockOffset + 0x03)
            local experience = ReadInt(kh2lib.Save + form.blockOffset + 0x04)
            local growth = ReadShort(kh2lib.Save + form.blockOffset + 0x08)
            local desiredGrowth = form.growthMaxId | EQUIPPED_FLAG

            if level ~= 7
                or abilityLevel ~= 4
                or experience ~= 0
                or growth ~= desiredGrowth then

                error(string.format(
                    "Verifica %s fallita: Level=%d AbilityLevel=%d EXP=%d Growth=%s",
                    form.name,
                    level,
                    abilityLevel,
                    experience,
                    Hex(growth, 4)
                ))
            end
        end

        local equippedCounts = {}

        for _, target in ipairs(form.innateAbilities) do
            equippedCounts[target.id] = 0
        end

        for slot = 0, 23 do
            local value = ReadShort(
                kh2lib.Save + form.blockOffset + 0x08 + (slot * 2)
            )
            local abilityId = value & ABILITY_ID_MASK

            if equippedCounts[abilityId] ~= nil
                and (value & EQUIPPED_FLAG) ~= 0 then

                equippedCounts[abilityId] = equippedCounts[abilityId] + 1
            end
        end

        for _, target in ipairs(form.innateAbilities) do
            if equippedCounts[target.id] < target.targetCount then
                error(string.format(
                    "Verifica %s innate %s fallita: %d equipaggiate, attese %d",
                    form.name,
                    Hex(target.id, 4),
                    equippedCounts[target.id],
                    target.targetCount
                ))
            end
        end
    end
end

local function VerifyDriveGauge()
    local saveCurrent = ReadByte(kh2lib.Save + DRIVE_SAVE_CURRENT_OFFSET)
    local saveMax = ReadByte(kh2lib.Save + DRIVE_SAVE_MAX_OFFSET)
    local livePercent = ReadByte(kh2lib.Slot1 + DRIVE_LIVE_PERCENT_OFFSET)
    local liveCurrent = ReadByte(kh2lib.Slot1 + DRIVE_LIVE_CURRENT_OFFSET)
    local liveMax = ReadByte(kh2lib.Slot1 + DRIVE_LIVE_MAX_OFFSET)

    if saveCurrent ~= 9
        or saveMax ~= 9
        or livePercent ~= 100
        or liveCurrent ~= 9
        or liveMax ~= 9 then

        error(string.format(
            "Verifica barra Drive fallita: save=%d/%d live=%d/%d percent=%d",
            saveCurrent,
            saveMax,
            liveCurrent,
            liveMax,
            livePercent
        ))
    end
end

local function VerifySoraAp()
    local current = ReadByte(kh2lib.Slot1 + SORA_LIVE_AP_OFFSET)

    if current ~= SORA_MAX_AP then
        error(string.format(
            "Verifica Sora AP fallita: letti %d, attesi %d",
            current,
            SORA_MAX_AP
        ))
    end
end

local function EnsureSoraMaxAp()
    local address = kh2lib.Slot1 + SORA_LIVE_AP_OFFSET
    local before = ReadByte(address)

    if before == SORA_MAX_AP then
        return
    end

    WriteByte(address, SORA_MAX_AP)

    local after = ReadByte(address)

    if after ~= SORA_MAX_AP then
        error(string.format(
            "Ripristino Sora AP fallito: prima %d, dopo %d, attesi %d",
            before,
            after,
            SORA_MAX_AP
        ))
    end
end

local function VerifyFormRewards()
    local presentCounts = {}
    local equippedCounts = {}

    for _, ability in ipairs(FORM_REWARD_ABILITIES) do
        presentCounts[ability.id] = 0
        equippedCounts[ability.id] = 0
    end

    for slot = 0, STANDARD_ABILITY_SLOT_COUNT - 1 do
        local value = ReadShort(
            kh2lib.Save + ABILITY_TABLE_OFFSET + (slot * 2)
        )
        local abilityId = value & ABILITY_ID_MASK

        if presentCounts[abilityId] ~= nil then
            presentCounts[abilityId] = presentCounts[abilityId] + 1

            if (value & EQUIPPED_FLAG) ~= 0 then
                equippedCounts[abilityId] = equippedCounts[abilityId] + 1
            end
        end
    end

    for _, ability in ipairs(FORM_REWARD_ABILITIES) do
        local shouldEquip = ability.equipped ~= false

        if presentCounts[ability.id] < ability.targetCount then
            error(string.format(
                "Verifica %s fallita: %d presenti, attese almeno %d",
                ability.name,
                presentCounts[ability.id],
                ability.targetCount
            ))
        end

        if shouldEquip and equippedCounts[ability.id] < ability.targetCount then
            error(string.format(
                "Verifica %s fallita: %d equipaggiate, attese almeno %d",
                ability.name,
                equippedCounts[ability.id],
                ability.targetCount
            ))
        elseif not shouldEquip and equippedCounts[ability.id] ~= 0 then
            error(string.format(
                "Verifica %s fallita: %d copie ancora equipaggiate",
                ability.name,
                equippedCounts[ability.id]
            ))
        end
    end
end

local function EnableAllForms()
    if ReadByte(kh2lib.Save + CURRENT_FORM_OFFSET) ~= 0 then
        error("Sora ha cambiato Form durante la preparazione")
    end

    -- Inspect every owned field and table capacity before the first write.
    local writes = BuildPatchPlan()

    ApplyPatchPlan(writes)
    VerifyUnlocks()
    VerifyDriveForms()
    VerifyDriveGauge()
    VerifySoraAp()
    VerifyFormRewards()

    ConsolePrint(string.format(
        "Sora Forms pronto: Valor/Wisdom/Limit/Master/Final LV7, Anti sbloccata, Drive 9/9, AP 255; tutte le Auto Form sono presenti ma disabilitate (%d aggiornamenti).",
        #writes
    ), 1)

    ConsolePrint(
        "Gli array da 24 slot preservano gli extra e garantiscono tutte le innate vanilla; le cinque growth interne sono a MAX.",
        2
    )

    ConsolePrint(
        "Form, ability e Drive sono nella save RAM; gli AP live vengono ripristinati dal modulo a ogni caricamento di Sora.",
        2
    )

    PatchCompleted = true
end

function _OnInit()
    CanExecute = false
    PatchCompleted = false
    PatchDisabled = false
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
        "Sora Forms inizializzato: attendo Sora in forma base.",
        1
    )
end

function _OnFrame()
    if not CanExecute or PatchDisabled then
        return
    end

    local readyOk, readyOrError = pcall(IsSoraGameplayReady)

    if not readyOk then
        if not ErrorReported then
            ConsolePrint(
                "Errore controllo Sora Forms: "
                .. tostring(readyOrError),
                3
            )
            ErrorReported = true
        end
        return
    end

    if not readyOrError then
        -- Re-arm only across title/loading or a different save, not while a
        -- Drive Form is active after this patch completed.
        PatchCompleted = false
        ErrorReported = false
        return
    end

    if ReadByte(kh2lib.Save + CURRENT_FORM_OFFSET) ~= 0 then
        return
    end

    if PatchCompleted then
        local apOk, apError = pcall(EnsureSoraMaxAp)

        if not apOk then
            ConsolePrint(
                "Errore ripristino Sora AP; modulo disabilitato fino a F1: "
                .. tostring(apError),
                3
            )
            ErrorReported = true
            PatchDisabled = true
        end

        return
    end

    local patchOk, patchError = pcall(EnableAllForms)

    if not patchOk then
        ConsolePrint(
            "Errore Sora Forms; modulo disabilitato fino a F1: "
            .. tostring(patchError),
            3
        )
        ErrorReported = true
        PatchDisabled = true
        return
    end

    ErrorReported = false
end
