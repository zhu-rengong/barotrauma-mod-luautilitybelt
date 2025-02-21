local log = require "utilbelt.logger" ("L10N")

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.GameSettings"], "currentConfig")
local localLanguage = GameSettings.currentConfig.Language.Value.Value
log(("Local language: '%s'"):format(localLanguage))

---@class l10nstr
---@field value string
---@field altvalue string # return the last key if `self` is nil
---@field format fun(self:l10nstr, ...:any):string

---@class l10n
---@overload fun(keys: string|string[]):l10nstr
local l10n = {}
l10n.__index = l10n

---@type table[]
local languages = {}
---@type { [string]: table }
local caches = {}

---@param lang table
l10n.addlang = function(lang)
    table.insert(languages, lang)
end

---@param lang table
l10n.removelang = function(lang)
    for i = #languages, 1, -1 do
        if languages[i] == lang then
            table.remove(languages, i)
        end
    end
end

l10n.sortlangs = function()
    table.sort(languages, function(l1, l2)
        if l1[1] == localLanguage and l2[1] ~= localLanguage then
            return true
        elseif l1[1] ~= localLanguage and l2[1] == localLanguage then
            return false
        else
            return nil
        end
    end)
end

---@param dir string
function l10n.loadlangs(dir)
    if File.DirectoryExists(dir) then
        local files = File.DirSearch(dir)
        for _, file in pairs(files) do
            local lang = caches[file]
            if lang == nil then
                if file:endsWith(".lua") then
                    lang = dofile(file)
                    if lang[1] ~= localLanguage and lang[1] ~= [[English]] then
                        lang = nil
                    end
                end
            end
            if lang ~= nil then
                l10n.addlang(lang)
                log(("The language file located at \"%s\" has been loaded."):format(file))
                caches[file] = lang
            end
        end
        l10n.sortlangs()
    else
        log(("Failed to locate language files, the given directory \"%s\" does not exist!"):format(dir), 'e')
    end
end

---@param dir string
function l10n.unloadlangs(dir)
    local files = File.DirSearch(dir)
    for _, file in pairs(files) do
        local lang = caches[file]
        if lang ~= nil then
            l10n.removelang(lang)
            log(("The language file located at \"%s\" has been unloaded."):format(file))
        end
    end
end

setmetatable(l10n, {
    __call = function(_, ...)
        local keys = ...
        if type(keys) == "string" then keys = { keys } end
        local size = #keys
        for _, lang in ipairs(languages) do
            local result = nil
            for i = 1, size, 1 do
                local key = keys[i]
                result = result and result[key] or lang[key]
                if result then
                    if i == size then
                        if type(result) == "string" then
                            return {
                                isnull = false,
                                value = result,
                                altvalue = result,
                                format = function(lstr, ...)
                                    local str = lstr.value
                                    for ph, repl in ipairs(table.pack(...)) do
                                        str = str:gsub('{' .. ph .. '}', repl)
                                    end
                                    return str
                                end
                            }
                        else
                            break
                        end
                    elseif type(result) ~= "table" then
                        break
                    end
                else
                    break
                end
            end
        end
        return {
            value = table.concat(keys, '.'),
            altvalue = size > 0 and keys[size] or '';
            format = function(lstr)
                return lstr.value
            end
        }
    end
})

l10n.loadlangs(LuaUtilityBelt.Path .. "/Lua/utilbelt/texts")

return l10n
