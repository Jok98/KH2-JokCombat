LUAGUI_NAME = "KH2 JokCombat - Roxas Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Probe minimale per verificare LuaBackend"

function _OnInit()
    ConsolePrint("Roxas Probe ricaricata con F1.", 1)
    ConsolePrint("SCRIPT_PATH = " .. tostring(SCRIPT_PATH), 0)
end

function _OnFrame()
    -- Per ora non eseguiamo nulla durante i frame.
end