local log = require "utilbelt.logger" ("L10N")

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.GameSettings"], "currentConfig")
local locallanguage = GameSettings.currentConfig.Language.Value.Value
log(("'%s' was detected as the local language"):format(locallanguage))

---@class l10nstr
---@field value string
---@field altvalue string # return the last key if `self` is nil
---@field format fun(self:l10nstr, ...:any):string

---@class l10nmgr
---@overload fun(keys:string|string[]):l10nstr
local l10nmgr = {}
l10nmgr.__index = l10nmgr

---@type table[]
local languages = {}
---@type { [string]:table }
local caches = {}

---@param lang table
l10nmgr.addlang = function(lang)
    table.insert(languages, lang)
end

---@param lang table
l10nmgr.removelang = function(lang)
    for i = #languages, 1, -1 do
        if languages[i] == lang then
            table.remove(languages, i)
        end
    end
end

l10nmgr.sortlangs = function()
    table.sort(languages, function(l1, l2)
        if l1[1] == locallanguage and l2[1] ~= locallanguage then
            return true
        elseif l1[1] ~= locallanguage and l2[1] == locallanguage then
            return false
        else
            return nil
        end
    end)
end

---@param dir string
function l10nmgr.loadlangs(dir)
    if File.DirectoryExists(dir) then
        local files = File.DirSearch(dir)
        for _, file in pairs(files) do
            local lang = caches[file]
            if lang == nil then
                if file:endsWith(".lua") then
                    lang = dofile(file)
                    if lang[1] ~= locallanguage and lang[1] ~= [[English]] then
                        lang = nil
                    end
                end
            end
            if lang ~= nil then
                l10nmgr.addlang(lang)
                log(("Loaded a lang in '%s'"):format(file))
                caches[file] = lang
            end
        end
        l10nmgr.sortlangs()
    else
        log(("Failed to load languages in '%s' since it is not existed!"):format(dir), 'e')
    end
end

---@param dir string
function l10nmgr.unloadlangs(dir)
    local files = File.DirSearch(dir)
    for _, file in pairs(files) do
        local lang = caches[file]
        if lang ~= nil then
            l10nmgr.removelang(lang)
            log(("Unloaded a lang in '%s'"):format(file))
        end
    end
end

setmetatable(l10nmgr, {
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

l10nmgr.loadlangs(LuaUtilityBelt.Path .. "/Lua/utilbelt/texts")

return l10nmgr
