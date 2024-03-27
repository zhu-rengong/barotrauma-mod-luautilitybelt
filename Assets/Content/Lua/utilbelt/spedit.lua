local log = require "utilbelt.logger" ("SPEdit")
local utils = require "utilbelt.csharpmodule.Shared.Utils"

---@class spvalue : boolean,integer,number,string
---@class sptbl : {[string|{[1]:string,[2]:string,[3]:integer?}]:spvalue}

---@class spedit
---@overload fun(sptbl:sptbl,_log?:log):spedit|boolean # parse
---@field _sptbl sptbl
local spedit = {}
spedit.__index = spedit

setmetatable(spedit, {
    __call = function(_, sptbl, _log)
        _log = _log or log
        if type(sptbl) ~= "table" then return false end
        local replace = {}
        for indexer, value in pairs(sptbl) do
            if type(indexer) == "table" then
                if type(indexer[1]) == "string" and type(indexer[2]) == "string" then
                    indexer[2] = Identifier(indexer[2])
                else
                    _log(("Got an invalid properties' indexer(table) that its #1(%s) or #2(%s) element type is not string!")
                        :format(tostring(indexer[1]), tostring(indexer[2])), 'w')
                    return false
                end
            else
                sptbl[indexer] = nil
                replace[indexer] = value
            end
        end
        for indexer, value in pairs(replace) do
            sptbl[Identifier(indexer)] = value
        end
        return setmetatable({ _sptbl = sptbl }, spedit)
    end
})

---@param item Barotrauma.Item
---@param _log log
function spedit:apply(item, _log)
    _log = _log or log
    for indexer, value in pairs(self._sptbl) do
        local propertyName
        local entity
        if type(indexer) ~= "table" then
            propertyName = indexer
            entity = item
        else
            propertyName = indexer[2]
            indexer[3] = indexer[3] or 1
            entity = utils.GetComponent(item, indexer[1], indexer[3])
        end

        if entity then
            local serializableProperty = entity.SerializableProperties[propertyName]
            if serializableProperty then
                local lastValue = SERVER and serializableProperty.GetValue(entity) or nil
                if utils.TrySetValue(serializableProperty, entity, value) then
                    if SERVER and utils.IsEditable(serializableProperty) and lastValue ~= serializableProperty.GetValue(entity) then
                        Networking.CreateEntityEvent(item,
                            Item.ChangePropertyEventData(serializableProperty, entity))
                    end
                else
                    if entity == item then
                        _log(("Failed to set SP(%s) to '%s' for item(%s)!"):format(propertyName.Value,
                            tostring(value), item.Prefab.Identifier.Value), 'e')
                    else
                        _log(("Failed to set SP(%s) to '%s' for '%s->%s[%i]'!"):format(propertyName.Value,
                            tostring(value), item.Prefab.Identifier.Value, indexer[1], indexer[3]), 'e')
                    end
                end
            else
                if entity == item then
                    _log(("Could not find any SP with the given name(%s) in item(%s)!"):format(
                        propertyName.Value, item.Prefab.Identifier.Value), 'e')
                else
                    _log(("Could not find any SP with the given name(%s) in '%s->%s[%i]'!"):format(
                        propertyName.Value, item.Prefab.Identifier.Value, indexer[1], indexer[3]), 'e')
                end
            end
        else
            _log(("Could not find any entity matching '%s[%i]' in '%s'!"):format(indexer[1], indexer[3],
                item.Prefab.Identifier.Value), 'e')
        end
    end
end

return spedit
