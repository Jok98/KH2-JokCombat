local SAVE = 0x100000
local SLOT1 = 0x200000
local NOW = 0x300000
local memory = {}
local writeCount = 0

local function Read(address)
    return memory[address] or 0
end

function ReadByte(address)
    return Read(address)
end

function ReadShort(address)
    return Read(address)
end

function ReadInt(address)
    return Read(address)
end

function WriteByte(address, value)
    memory[address] = value
    writeCount = writeCount + 1
end

function WriteShort(address, value)
    memory[address] = value
    writeCount = writeCount + 1
end

function WriteInt(address, value)
    memory[address] = value
    writeCount = writeCount + 1
end

function ConsolePrint()
end

function RequireKH2LibraryVersion()
end

function RequirePCGameVersion()
end

package.preload.kh2lib = function()
    return {
        Save = SAVE,
        Slot1 = SLOT1,
        Now = NOW,
        CanExecute = true
    }
end

memory[NOW + 0x00] = 0x02
memory[NOW + 0x01] = 0x00
memory[SLOT1 + 0x004] = 20
memory[SAVE + 0x1CEA] = 0x01

-- Every Form bit is already present. Movement must not interpret Valor as the
-- KH2 outfit and must actively remove the equipped flag from unsafe growths.
memory[SAVE + 0x36C0] = 0xF6
memory[SAVE + 0x25CE] = 0x005E
memory[SAVE + 0x25D0] = 0x8062
memory[SAVE + 0x25D2] = 0x8234
memory[SAVE + 0x25D4] = 0x8066
memory[SAVE + 0x25D6] = 0x806A

dofile("runtime/KH2JokCombat_Movement.lua")
_OnInit()
_OnFrame()

assert(memory[SAVE + 0x36C0] == 0xF6, "Form inventory was modified")
assert(memory[SAVE + 0x25CE] == 0x8061, "High Jump MAX not equipped")
assert(memory[SAVE + 0x25D0] == 0x0065, "Quick Run must stay unequipped")
assert(memory[SAVE + 0x25D2] == 0x0237, "Dodge Roll must stay unequipped")
assert(memory[SAVE + 0x25D4] == 0x0069, "Aerial Dodge must stay unequipped")
assert(memory[SAVE + 0x25D6] == 0x006D, "Glide must stay unequipped")

local writesAfterFirstFrame = writeCount
_OnFrame()
assert(writeCount == writesAfterFirstFrame, "second frame was not idempotent")

print(string.format(
    "OK KH2JokCombat_Movement smoke test (%d verified writes)",
    writeCount
))
