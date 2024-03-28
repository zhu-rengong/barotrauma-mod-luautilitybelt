local defaultlog = require "utilbelt.logger" ("SPEdit")
local utils = require "utilbelt.csharpmodule.Shared.Utils"

---@class spvalue : boolean, integer, number, string
---@class sptbl : { [string]: spvalue }, { [{ [1]: string, [2]: string, [3]: integer? }]: spvalue }, { [string]: { [string]: spvalue, [1]: integer? } }

local function isValidValue(v)
    return type(v) == "boolean"
        or type(v) == "number"
        or type(v) == "string"
end

---@class spedit
---@field private _sptbl table
---@overload fun(sptbl: sptbl, log?: log):self
local m = Class 'spedit'

---@param sptbl sptbl
---@param log? log
function m:__init(sptbl, log)
    log = log or defaultlog
    self._sptbl = {}
    for k, v in pairs(sptbl) do
        local function logInvalidField(expected)
            log(("此处的表域是无效的，预期的类型是：\n%s，但却得到：\n%s")
                :format(expected, table.dump({ [k] = v }, { noArrayKey = true })), 'e')
        end
        if type(k) == "table" then
            if type(k[1]) == "string"
                and type(k[2]) == "string"
                and (k[3] == nil or moses.isInteger(k[3]))
                and isValidValue(v)
            then
                self._sptbl[{ k[1], Identifier(k[2]), k[3] }] = v
            else
                logInvalidField "{ [{ [1]: string, [2]: string, [3]: integer? }]: boolean|number|string }"
            end
        elseif type(k) == "string" then
            if type(v) == "table" then
                local isInvalidField = false
                for k2, v2 in pairs(v) do
                    if type(k2) == "string"
                        and (v[1] == nil or moses.isInteger(v[1]))
                        and isValidValue(v2)
                    then
                        self._sptbl[{ k, Identifier(k2), v[1] }] = v2
                    else
                        isInvalidField = true
                    end
                end
                if isInvalidField then
                    logInvalidField "{ [string]: { [string]: boolean|number|string, [1]: integer? } }"
                end
            else
                if isValidValue(v) then
                    self._sptbl[Identifier(k)] = v
                else
                    logInvalidField "{ [string]: boolean|number|string }"
                end
            end
        else
            logInvalidField "unknown"
        end
    end
end

---@param item userdata
---@param log? log
function m:apply(item, log)
    log = log or defaultlog
    for indexer, newValue in pairs(self._sptbl) do
        local propertyName
        local target
        if type(indexer) ~= "table" then
            propertyName = indexer
            target = item
        else
            propertyName = indexer[2]
            indexer[3] = indexer[3] or 1
            target = utils.GetComponent(item, indexer[1], indexer[3])
        end

        if target then
            local serializableProperty = target.SerializableProperties[propertyName]
            if serializableProperty then
                local oldValue = serializableProperty.GetValue(target)
                if utils.TrySetValue(serializableProperty, target, newValue) then
                    if oldValue ~= serializableProperty.GetValue(target) then
                        if SERVER then
                            if utils.IsEditable(serializableProperty) then
                                Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(serializableProperty, target))
                            end
                        end
                    end
                else
                    if target == item then
                        log(("设置失败！原因是物品'%s'的序列化属性'%s'无法设为'%s'。")
                            :format(item.Prefab.Identifier.Value, propertyName.Value, tostring(newValue)), 'e')
                    else
                        log(("设置失败！原因是物品'%s'组件'%s[%i]'的序列化属性'%s'无法设为'%s'。")
                            :format(item.Prefab.Identifier.Value, indexer[1], indexer[3], propertyName.Value, tostring(newValue)), 'e')
                    end
                end
            else
                if target == item then
                    log(("没有找到物品'%s'的序列化属性'%s'！")
                        :format(item.Prefab.Identifier.Value, propertyName.Value), 'e')
                else
                    log(("没有找到物品'%s'组件'%s[%i]'的序列化属性'%s'！")
                        :format(item.Prefab.Identifier.Value, indexer[1], indexer[3], propertyName.Value), 'e')
                end
            end
        else
            log(("没有找到物品'%s'的组件'%s[%i]'！")
                :format(item.Prefab.Identifier.Value, indexer[1], indexer[3]), 'e')
        end
    end
end

return m
