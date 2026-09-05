-- Central logging policy for KH2 JokCombat.
--
-- Errors and warnings are always visible. Toggle only the functional
-- categories below, then rebuild the mod and press F1 to reload LuaBackend.
local FLAGS = {
    SYSTEM = false,       -- module lifecycle, address discovery and summaries
    COMBAT = false,       -- accepted custom combat branches
    DISPATCH = true,      -- current M-03C/M-03D action/command probe
    PROGRESSION = false,  -- abilities, growth, forms, AP and Keyblades
    GUMMI = false,        -- Gummi Cost Limit status
    PROBE = false,        -- read-only diagnostic snapshots and input probes
    TRACE = false         -- internal state-machine transitions and raw detail
}

local ALWAYS_ENABLED = {
    ERROR = true,
    WARNING = true
}

local DEFAULT_LEVEL = {
    ERROR = 3,
    WARNING = 2
}

local Logger = {
    FLAGS = FLAGS
}

local OnceKeys = {}

local function NormalizeCategory(category)
    if category == nil then
        return "SYSTEM"
    end

    local normalized = string.upper(tostring(category))

    if ALWAYS_ENABLED[normalized] or FLAGS[normalized] ~= nil then
        return normalized
    end

    return nil
end

function Logger.IsEnabled(category)
    local normalized = NormalizeCategory(category)

    if normalized == nil then
        return false
    end

    return ALWAYS_ENABLED[normalized] == true
        or FLAGS[normalized] == true
end

function Logger.SetEnabled(category, enabled)
    local normalized = NormalizeCategory(category)

    if normalized == nil or ALWAYS_ENABLED[normalized] then
        return false
    end

    FLAGS[normalized] = enabled == true
    return true
end

function Logger.Log(moduleName, category, message, level)
    local normalized = NormalizeCategory(category)

    if normalized == nil or not Logger.IsEnabled(normalized) then
        return false
    end

    ConsolePrint(string.format(
        "[%s][%s] %s",
        tostring(moduleName or "KH2JokCombat"),
        normalized,
        tostring(message)
    ), level or DEFAULT_LEVEL[normalized] or 0)

    return true
end

function Logger.Once(moduleName, category, key, message, level)
    local normalized = NormalizeCategory(category)

    if normalized == nil then
        return false
    end

    local onceKey = table.concat({
        tostring(moduleName or "KH2JokCombat"),
        normalized,
        tostring(key)
    }, "\31")

    if OnceKeys[onceKey] then
        return false
    end

    if not Logger.Log(moduleName, normalized, message, level) then
        return false
    end

    OnceKeys[onceKey] = true
    return true
end

return Logger
