LUAGUI_NAME = "KH2 JokCombat - Sora Keyblades"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Unlocks every standard Sora Keyblade except Ultima Weapon"

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

    for _, slot in ipairs(WEAPON_SLOTS) do
        local address = kh2lib.Save + slot.offset
        local value = ReadShort(address)

        snapshots[#snapshots + 1] = {
            slot = slot,
            address = address,
            before = value
        }

        if TARGET_BY_ID[value] ~= nil then
            equippedById[value] = equippedById[value] or {}
            equippedById[value][#equippedById[value] + 1] = slot.name
        end
    end

    return equippedById, snapshots
end

local function BuildPatchPlan()
    local equippedById, weaponSnapshots = SnapshotWeaponSlots()
    local writes = {}
    local alreadyAvailable = 0

    for _, keyblade in ipairs(KEYBLADES) do
        local address = kh2lib.Save + keyblade.inventoryOffset
        local count = ReadByte(address)
        local equipped = equippedById[keyblade.id] ~= nil

        if count == 0 and not equipped then
            writes[#writes + 1] = {
                keyblade = keyblade,
                address = address,
                before = count,
                desired = 1
            }
        else
            alreadyAvailable = alreadyAvailable + 1
        end
    end

    return {
        writes = writes,
        alreadyAvailable = alreadyAvailable,
        weaponSnapshots = weaponSnapshots,
        ultimaBefore = ReadByte(
            kh2lib.Save + ULTIMA_WEAPON.inventoryOffset
        )
    }
end

local function VerifyUnchangedOwnership(plan)
    for _, snapshot in ipairs(plan.weaponSnapshots) do
        local after = ReadShort(snapshot.address)

        if after ~= snapshot.before then
            error(string.format(
                "Weapon slot %s cambiato durante la patch: %s -> %s",
                snapshot.slot.name,
                Hex(snapshot.before, 4),
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
    -- of the missing entries between inspection and application, fail closed.
    for _, write in ipairs(plan.writes) do
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

    local addedNames = {}

    for _, write in ipairs(plan.writes) do
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

        addedNames[#addedNames + 1] = write.keyblade.name
    end

    VerifyUnchangedOwnership(plan)
    VerifyTargets()

    ConsolePrint(string.format(
        "Keyblade Sora pronte: 23/23 standard, %d aggiunte e %d gia possedute/equipaggiate.",
        #plan.writes,
        plan.alreadyAvailable
    ), 1)

    if #addedNames > 0 then
        ConsolePrint("Aggiunte: " .. table.concat(addedNames, ", "), 1)
    end

    ConsolePrint(string.format(
        "Ultima Weapon esclusa e preservata (stock=%d); weapon slot Sora/Form invariati.",
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
