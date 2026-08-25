LUAGUI_NAME = "KH2 JokCombat - Sora Keyblades"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Unlocks Sora Keyblades and initializes empty Master/Final weapon slots"

local kh2lib = nil
local CanExecute = false
local PatchCompleted = false
local PatchDisabled = false
local ErrorReported = false

local SORA_STORY_FLAG_OFFSET = 0x1CEA
local SORA_STORY_FLAG_MASK = 0x01

-- Standard equippable Sora Keyblades in Final Mix. Debug weapons, Struggle
-- weapons, Pureblood and Kingdom Key D are intentionally outside this pool.
-- Item IDs come from the Final Mix item table; inventory offsets come from the
-- 320-byte InventoryCount array at Save+0x3580.
local KEYBLADES = {
    { name = "Kingdom Key", id = 0x0029, inventoryOffset = 0x35A1 },
    { name = "Oathkeeper", id = 0x002A, inventoryOffset = 0x35A2 },
    { name = "Oblivion", id = 0x002B, inventoryOffset = 0x35A3 },
    { name = "Star Seeker", id = 0x01E0, inventoryOffset = 0x367B },
    { name = "Hidden Dragon", id = 0x01E1, inventoryOffset = 0x367C },
    { name = "Hero's Crest", id = 0x01E4, inventoryOffset = 0x367F },
    { name = "Monochrome", id = 0x01E5, inventoryOffset = 0x3680 },
    { name = "Follow the Wind", id = 0x01E6, inventoryOffset = 0x3681 },
    { name = "Circle of Life", id = 0x01E7, inventoryOffset = 0x3682 },
    { name = "Photon Debugger", id = 0x01E8, inventoryOffset = 0x3683 },
    { name = "Gull Wing", id = 0x01E9, inventoryOffset = 0x3684 },
    { name = "Rumbling Rose", id = 0x01EA, inventoryOffset = 0x3685 },
    { name = "Guardian Soul", id = 0x01EB, inventoryOffset = 0x3686 },
    { name = "Wishing Lamp", id = 0x01EC, inventoryOffset = 0x3687 },
    { name = "Decisive Pumpkin", id = 0x01ED, inventoryOffset = 0x3688 },
    { name = "Sleeping Lion", id = 0x01EE, inventoryOffset = 0x3689 },
    { name = "Sweet Memories", id = 0x01EF, inventoryOffset = 0x368A },
    { name = "Mysterious Abyss", id = 0x01F0, inventoryOffset = 0x368B },
    { name = "Fatal Crest", id = 0x01F1, inventoryOffset = 0x368C },
    { name = "Bond of Flame", id = 0x01F2, inventoryOffset = 0x368D },
    { name = "Fenrir", id = 0x01F3, inventoryOffset = 0x368E },
    { name = "Two Become One", id = 0x021F, inventoryOffset = 0x3698 },
    { name = "Winner's Proof", id = 0x0220, inventoryOffset = 0x3699 }
}

local ULTIMA_WEAPON = {
    name = "Ultima Weapon",
    id = 0x01F4,
    inventoryOffset = 0x368F
}

-- Sora's base weapon plus the secondary weapon stored by each levelled Form.
-- A Keyblade already in one of these slots is owned even when its stock count
-- is zero. Counting these slots prevents a duplicate on F1 or save reload.
local WEAPON_SLOTS = {
    { name = "Sora", offset = 0x24F0 },
    { name = "Valor", offset = 0x32F4 },
    { name = "Wisdom", offset = 0x332C },
    { name = "Limit", offset = 0x3364 },
    { name = "Master", offset = 0x339C },
    { name = "Final", offset = 0x33D4 }
}

local TARGET_BY_ID = {}

for _, keyblade in ipairs(KEYBLADES) do
    TARGET_BY_ID[keyblade.id] = keyblade
end

-- Master and Final are dual-wield Forms. Unlocking them before the vanilla
-- progression event can leave their persistent secondary weapon slot empty,
-- which makes the equipment menu unsafe. Only initialize an empty slot: once
-- the player has selected any weapon, that choice remains authoritative.
local FORM_WEAPON_DEFAULTS = {
    {
        slotName = "Master",
        slotOffset = 0x339C,
        keyblade = TARGET_BY_ID[0x01F2] -- Bond of Flame
    },
    {
        slotName = "Final",
        slotOffset = 0x33D4,
        keyblade = TARGET_BY_ID[0x002B] -- Oblivion
    }
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

local function SnapshotWeaponSlots()
    local equippedById = {}
    local snapshots = {}
    local snapshotByOffset = {}

    for _, slot in ipairs(WEAPON_SLOTS) do
        local address = kh2lib.Save + slot.offset
        local value = ReadShort(address)

        local snapshot = {
            slot = slot,
            address = address,
            before = value
        }

        snapshots[#snapshots + 1] = snapshot
        snapshotByOffset[slot.offset] = snapshot

        if TARGET_BY_ID[value] ~= nil then
            equippedById[value] = equippedById[value] or {}
            equippedById[value][#equippedById[value] + 1] = slot.name
        end
    end

    return equippedById, snapshots, snapshotByOffset
end

local function BuildPatchPlan()
    local equippedById, weaponSnapshots, snapshotByOffset =
        SnapshotWeaponSlots()
    local inventoryBeforeById = {}
    local inventoryDesiredById = {}
    local weaponWrites = {}
    local expectedWeaponByOffset = {}
    local defaultStatuses = {}
    local inventoryWrites = {}
    local unlockedNames = {}
    local alreadyAvailable = 0

    for _, keyblade in ipairs(KEYBLADES) do
        local address = kh2lib.Save + keyblade.inventoryOffset
        local count = ReadByte(address)

        inventoryBeforeById[keyblade.id] = count
        inventoryDesiredById[keyblade.id] = count
    end

    for _, default in ipairs(FORM_WEAPON_DEFAULTS) do
        local snapshot = snapshotByOffset[default.slotOffset]

        if snapshot == nil then
            error("Weapon slot Form non censito: " .. default.slotName)
        end

        if snapshot.before == 0 then
            local keybladeId = default.keyblade.id
            local stock = inventoryDesiredById[keybladeId]
            local equippedElsewhere = equippedById[keybladeId]

            if stock == 0 and equippedElsewhere ~= nil then
                error(string.format(
                    "%s non inizializzabile: %s e gia equipaggiata in [%s] e non esiste una copia in stock",
                    default.slotName,
                    default.keyblade.name,
                    table.concat(equippedElsewhere, ",")
                ))
            end

            weaponWrites[#weaponWrites + 1] = {
                default = default,
                address = snapshot.address,
                before = snapshot.before,
                desired = default.keyblade.id
            }
            expectedWeaponByOffset[default.slotOffset] = default.keyblade.id

            if stock > 0 then
                inventoryDesiredById[keybladeId] = stock - 1
            end

            equippedById[keybladeId] = equippedById[keybladeId] or {}
            equippedById[keybladeId][#equippedById[keybladeId] + 1] =
                default.slotName

            defaultStatuses[#defaultStatuses + 1] = string.format(
                "%s=%s [inizializzata]",
                default.slotName,
                default.keyblade.name
            )
        else
            expectedWeaponByOffset[default.slotOffset] = snapshot.before
            local current = TARGET_BY_ID[snapshot.before]

            defaultStatuses[#defaultStatuses + 1] = string.format(
                "%s=%s [preservata]",
                default.slotName,
                current and current.name or Hex(snapshot.before, 4)
            )
        end
    end

    for _, keyblade in ipairs(KEYBLADES) do
        local before = inventoryBeforeById[keyblade.id]
        local desired = inventoryDesiredById[keyblade.id]
        local equipped = equippedById[keyblade.id] ~= nil

        if desired == 0 and not equipped then
            desired = 1
            inventoryDesiredById[keyblade.id] = desired
            unlockedNames[#unlockedNames + 1] = keyblade.name
        else
            alreadyAvailable = alreadyAvailable + 1
        end

        if desired ~= before then
            inventoryWrites[#inventoryWrites + 1] = {
                keyblade = keyblade,
                address = kh2lib.Save + keyblade.inventoryOffset,
                before = before,
                desired = desired
            }
        end
    end

    return {
        weaponWrites = weaponWrites,
        inventoryWrites = inventoryWrites,
        unlockedNames = unlockedNames,
        alreadyAvailable = alreadyAvailable,
        weaponSnapshots = weaponSnapshots,
        expectedWeaponByOffset = expectedWeaponByOffset,
        defaultStatuses = defaultStatuses,
        ultimaBefore = ReadByte(
            kh2lib.Save + ULTIMA_WEAPON.inventoryOffset
        )
    }
end

local function VerifyOwnership(plan)
    for _, snapshot in ipairs(plan.weaponSnapshots) do
        local after = ReadShort(snapshot.address)
        local expected = plan.expectedWeaponByOffset[snapshot.slot.offset]
            or snapshot.before

        if after ~= expected then
            error(string.format(
                "Weapon slot %s inatteso dopo la patch: atteso %s, trovato %s",
                snapshot.slot.name,
                Hex(expected, 4),
                Hex(after, 4)
            ))
        end
    end

    local ultimaAfter = ReadByte(
        kh2lib.Save + ULTIMA_WEAPON.inventoryOffset
    )

    if ultimaAfter ~= plan.ultimaBefore then
        error(string.format(
            "Ultima Weapon modificata: %d -> %d",
            plan.ultimaBefore,
            ultimaAfter
        ))
    end
end

local function VerifyTargets()
    local equippedById = SnapshotWeaponSlots()

    for _, keyblade in ipairs(KEYBLADES) do
        local count = ReadByte(
            kh2lib.Save + keyblade.inventoryOffset
        )

        if count == 0 and equippedById[keyblade.id] == nil then
            error(keyblade.name .. " non risulta posseduta dopo la patch")
        end
    end
end

local function ApplyKeybladeInventory()
    local plan = BuildPatchPlan()

    -- Recheck every value before the first write. If another mod changes one
    -- of the inspected slots between planning and application, fail closed.
    for _, write in ipairs(plan.weaponWrites) do
        local current = ReadShort(write.address)

        if current ~= write.before then
            error(string.format(
                "Weapon slot %s cambiato prima della patch: %s -> %s",
                write.default.slotName,
                Hex(write.before, 4),
                Hex(current, 4)
            ))
        end
    end

    for _, write in ipairs(plan.inventoryWrites) do
        local current = ReadByte(write.address)

        if current ~= write.before then
            error(string.format(
                "%s cambiata prima della patch: %d -> %d",
                write.keyblade.name,
                write.before,
                current
            ))
        end
    end

    for _, write in ipairs(plan.weaponWrites) do
        WriteShort(write.address, write.desired)

        local after = ReadShort(write.address)

        if after ~= write.desired then
            error(string.format(
                "Verifica weapon slot %s fallita a Save+%s: %s",
                write.default.slotName,
                Hex(write.default.slotOffset, 4),
                Hex(after, 4)
            ))
        end
    end

    for _, write in ipairs(plan.inventoryWrites) do
        WriteByte(write.address, write.desired)

        local after = ReadByte(write.address)

        if after ~= write.desired then
            error(string.format(
                "Verifica %s fallita a Save+%s: %d",
                write.keyblade.name,
                Hex(write.keyblade.inventoryOffset, 4),
                after
            ))
        end
    end

    VerifyOwnership(plan)
    VerifyTargets()

    ConsolePrint(string.format(
        "Keyblade Sora pronte: 23/23 standard, %d aggiunte e %d gia possedute/equipaggiate.",
        #plan.unlockedNames,
        plan.alreadyAvailable
    ), 1)

    if #plan.unlockedNames > 0 then
        ConsolePrint(
            "Aggiunte: " .. table.concat(plan.unlockedNames, ", "),
            1
        )
    end

    ConsolePrint(
        "Weapon slot Form: " .. table.concat(plan.defaultStatuses, "; "),
        1
    )

    ConsolePrint(string.format(
        "Ultima Weapon esclusa e preservata (stock=%d); gli slot non vuoti restano invariati.",
        plan.ultimaBefore
    ), 2)

    ConsolePrint(
        "Nota: l'inventario Keyblade e nella save RAM; salvando la partita diventa persistente.",
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
        "Sora Keyblades inizializzato: attendo gameplay Sora.",
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
                "Errore controllo Sora Keyblades: "
                .. tostring(readyOrError),
                3
            )
            ErrorReported = true
        end
        return
    end

    if not readyOrError then
        -- Re-arm after title/loading so a different Sora save is inspected.
        PatchCompleted = false
        ErrorReported = false
        return
    end

    if PatchCompleted then
        return
    end

    local patchOk, patchError = pcall(ApplyKeybladeInventory)

    if not patchOk then
        ConsolePrint(
            "Errore Sora Keyblades; modulo disabilitato fino a F1: "
            .. tostring(patchError),
            3
        )
        ErrorReported = true
        PatchDisabled = true
        return
    end

    ErrorReported = false
end
