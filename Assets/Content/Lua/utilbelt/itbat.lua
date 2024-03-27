local log = require "utilbelt.logger" ("ItemBatch")
local utils = require "utilbelt.csharpmodule.Shared.Utils"
local spedit = require "utilbelt.spedit"
local moses = require "moses"

---@class itembatchblock
---@field _checkparent boolean
---@field ref? itembatch
---@field identifiers? string|string[]
---@field tags? string|string[]
---@field excludedidentifiers? string|string[]
---@field excludedtags? string|string[]
---@field slotindex? integer|integer[]
---@field slottype? Barotrauma.InvSlotType|Barotrauma.InvSlotType[]
---@field quality? integer|integer[]
---@field equipped? boolean
---@field equip? boolean
---@field drop? boolean
---@field remove? boolean
---@field properties? sptbl
---@field _spedit? spedit
---@field predicate? fun(item:Barotrauma.Item):boolean
---@field onmatched? fun(item:Barotrauma.Item)
---@field inventory? itembatchblock|itembatchblock[]

---@class itembatchctx
---@field _character? Barotrauma.Character

---@class itembatch
---@overload fun(itembatchunit:itembatchblock|itembatchblock[]):itembatch
---@field _invalid boolean
---@field _itembatchunit itembatchblock[]
local itembatch = {}

---@param itembatchunit itembatchblock[]
---@param items Barotrauma.Item[]
---@param context itembatchctx
---@param debugname? string
local function run(itembatchunit, items, context, debugname)
    local log = function(text, pattern)
        if debugname then
            log(("[DebugName:%s] %s"):format(debugname, text), pattern)
        else
            log(text, pattern)
        end
    end

    moses.forEachi(items, function(item)
        moses.forEachi(itembatchunit, function(itemblock)
            if type(itemblock) == "string" then
                debugname = #itemblock > 0 and itemblock or nil
                return
            end

            if itemblock.ref then
                itemblock.ref:run({ item })
                return
            end

            local inventory = item.ParentInventory
            local owner = nil
            local isAtCharacterInventory = false
            if inventory then
                owner = inventory.Owner
                if LuaUserData.TypeOf(inventory) == "Barotrauma.CharacterInventory" then
                    isAtCharacterInventory = true
                    context._character = owner
                end
            elseif itemblock._checkparent then
                return
            end

            local identifier = item.Prefab.Identifier.Value
            if itemblock.excludedidentifiers and moses.include(itemblock.excludedidentifiers, identifier) then return end
            if itemblock.excludedtags and moses.include(itemblock.excludedtags, function(tag) return item.HasTag(tag) end) then return end
            if itemblock.identifiers and not moses.include(itemblock.identifiers, identifier) then return end
            if itemblock.tags and not moses.include(itemblock.tags, function(tag) return item.HasTag(tag) end) then return end
            if itemblock.quality and not moses.include(itemblock.quality, item.Quality) then return end

            if itemblock.slotindex and not moses.include(itemblock.slotindex, function(slotindex)
                    return inventory.IsInSlot(item, slotindex)
                end) then
                return
            end

            if itemblock.slottype and not (isAtCharacterInventory and moses.include(itemblock.slottype, function(slottype)
                    return inventory.IsInLimbSlot(item, slottype)
                end)) then
                return
            end

            if itemblock.equipped ~= nil then
                if isAtCharacterInventory then
                    if moses.isunique({ itemblock.equipped, owner.HasEquippedItem(item) }) then return end
                elseif itemblock.equipped then
                    return
                end
            end

            if itemblock.predicate and not itemblock.predicate(item) then return end
            if itemblock.onmatched then itemblock.onmatched(item) end

            if itemblock.drop then item.Drop() end
            if itemblock.remove then Entity.Spawner.AddItemToRemoveQueue(item) end
            if itemblock.equip and context._character then
                utils.Equip(context._character, item)
            end

            if itemblock._spedit then
                itemblock._spedit:apply(item, log)
            end

            if itemblock.inventory then
                local itemContainer = utils.GetComponent(item, "ItemContainer")
                if itemContainer then
                    run(itemblock.inventory, moses.tabulate(itemContainer.Inventory.AllItemsMod), {
                        _character = context._character
                    }, debugname)
                else
                    log(("Cannot batch items in item(%s)'s inventory since it has no inventory!"):format(identifier), 'e')
                end
            end
        end)
    end)
end

---@param items Barotrauma.Item[]
---@param debugname? string
function itembatch:run(items, debugname)
    run(self._itembatchunit, items, {}, debugname)
end

---@param inventory Barotrauma.Inventory
---@param debugname? string
function itembatch:runforinv(inventory, debugname)
    run(self._itembatchunit, moses.tabulate(inventory.AllItemsMod), {}, debugname)
end

itembatch.__index = itembatch
setmetatable(itembatch, {
    ---@param itembatchunit itembatchblock|itembatchblock[]
    __call = function(_, itembatchunit)
        ---@param itbatunit itembatchblock|itembatchblock[]
        ---@param debugname? string
        local function construct(itbatunit, debugname)
            local log = function(text, pattern)
                if debugname then
                    log(("[DebugName:%s] %s"):format(debugname, text), pattern)
                else
                    log(text, pattern)
                end
            end
            local k1type = type(next(itbatunit))
            itbatunit = (k1type == "number" or k1type == "nil") and itbatunit or { itbatunit }
            local _itbatunit = moses.filter(itbatunit, function(itemblock)
                if type(itemblock) == "string" then
                    debugname = #itemblock > 0 and itemblock or nil
                    return true
                end
                if itemblock.ref then
                    if itemblock.ref._invalid then
                        log(("itemblock is referenced to an invalid itembatch!"), 'e')
                        return false
                    end
                    return true
                else
                    if itemblock.properties then
                        itemblock._spedit = spedit(itemblock.properties, log)
                    end

                    itemblock.identifiers = itemblock.identifiers and moses.castArray(itemblock.identifiers) or nil
                    itemblock.tags = itemblock.tags and moses.castArray(itemblock.tags) or nil
                    itemblock.excludedidentifiers = itemblock.excludedidentifiers and moses.castArray(itemblock.excludedidentifiers) or nil
                    itemblock.excludedtags = itemblock.excludedtags and moses.castArray(itemblock.excludedtags) or nil
                    itemblock.slotindex = itemblock.slotindex and moses.castArray(itemblock.slotindex) or nil
                    itemblock.slottype = itemblock.slottype and moses.castArray(itemblock.slottype) or nil
                    itemblock.quality = itemblock.quality and moses.castArray(itemblock.quality) or nil

                    itemblock._checkparent = itemblock.slotindex or itemblock.slottype or itemblock.equipped ~= nil

                    if itemblock.inventory then
                        itemblock.inventory = type(next(itemblock.inventory)) == "number"
                            and itemblock.inventory or { itemblock.inventory }
                        itemblock.inventory = construct(itemblock.inventory, debugname)
                    end
                    return true
                end
            end)
            return _itbatunit
        end

        ---@type itembuilder
        local inst = setmetatable({ _itembatchunit = construct(itembatchunit) }, itembatch)

        if #inst._itembatchunit == 0 then
            inst._invalid = true
            log("itembatchunit is invalid!", 'e')
        end

        return inst
    end,
})

return itembatch
