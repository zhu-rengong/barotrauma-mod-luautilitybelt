local log = require "utilbelt.logger" ("ItemBatch")
local utils = require "utilbelt.csharpmodule.Shared.Utils"
local spedit = require "utilbelt.spedit"
local moses = require "moses"

---@class itembatchunitarg : itembatchblockarg, { [integer]: itembatchblockarg }
---@class itembatchunit : { [integer]: itembatchblock }

---@class itembatchblockarg
---@field ref? itembatch
---@field identifiers? string|string[]
---@field tags? string|string[]
---@field excludedidentifiers? string|string[]
---@field excludedtags? string|string[]
---@field slotindex? integer|integer[]
---@field slottype? userdata[]
---@field quality? integer|integer[]
---@field equipped? boolean
---@field equip? boolean
---@field drop? boolean
---@field remove? boolean
---@field properties? sptbl
---@field spedit? spedit
---@field predicate? fun(item:userdata):boolean
---@field onmatched? fun(item:userdata)
---@field inventory? itembatchunitarg

---@class itembatchblock
---@field logWithMark log
---@field checkParent boolean
---@field isRef boolean
---@field ref? itembatch
---@field identifiers? string[]
---@field tags? string[]
---@field excludedIdentifiers? string[]
---@field excludedTags? string[]
---@field slotIndexList? integer[]
---@field slotTypeList? userdata[]
---@field qualityList? integer[]
---@field equipped? boolean
---@field equip? boolean
---@field drop? boolean
---@field remove? boolean
---@field spedit? spedit
---@field predicate? fun(item:userdata):boolean
---@field onMatched? fun(item:userdata)
---@field inventory? itembatch

---@class itembatchctx
---@field character? userdata

---@class itembatch
---@field itemBatchUnit itembatchunit
---@overload fun(itemBatchUnitArg: itembatchunitarg, debugName?: string, parentMark?: string):itembatch
local m = Class 'itembatch'
m._ISITEMBATCH = true

---@param itemBatchUnitArg itembatchunitarg
---@param debugName? string
---@param parentMark? string
function m:__init(itemBatchUnitArg, debugName, parentMark)
    local itemBatchUnit = {}
    self.itemBatchUnit = itemBatchUnit

    local initialIndexType = type(next(itemBatchUnitArg))
    itemBatchUnitArg = (initialIndexType == "number" or initialIndexType == "nil") and itemBatchUnitArg or { itemBatchUnitArg }

    moses.forEachi(itemBatchUnitArg, function(itemBlockArg, index)
        if type(itemBlockArg) == "string" then
            debugName = #itemBlockArg > 0 and itemBlockArg or nil
            return
        end

        local mark = parentMark and ("%s-%i"):format(parentMark, index) or tostring(index)
        local internalDebugName = debugName
        local function logWithMark(text, pattern)
            if internalDebugName then
                log(("[层级索引:%s] [调试名称:%s] %s"):format(mark, internalDebugName, text), pattern)
            else
                log(("[层级索引:%s] %s"):format(mark, text), pattern)
            end
        end

        ---@type itembatchblock
        local itemBlock = { isRef = false }

        local function initItemBlockToBatchUnit()
            itemBlock.logWithMark = logWithMark
            table.insert(itemBatchUnit, itemBlock)
        end

        if itemBlockArg.ref then
            if not itemBlockArg.ref._ISITEMBATCH then
                logWithMark("只许引用ItemBatch！", 'e')
                return
            end
            itemBlock.isRef = true
            itemBlock.ref = itemBlockArg.ref
            initItemBlockToBatchUnit(); return
        else
            if itemBlockArg.properties then
                itemBlock.spedit = spedit(itemBlockArg.properties, logWithMark)
            end

            itemBlock.identifiers = itemBlockArg.identifiers and moses.castArray(itemBlockArg.identifiers) or nil
            itemBlock.tags = itemBlockArg.tags and moses.castArray(itemBlockArg.tags) or nil
            itemBlock.excludedIdentifiers = itemBlockArg.excludedidentifiers and moses.castArray(itemBlockArg.excludedidentifiers) or nil
            itemBlock.excludedTags = itemBlockArg.excludedtags and moses.castArray(itemBlockArg.excludedtags) or nil
            itemBlock.slotIndexList = itemBlockArg.slotindex and moses.castArray(itemBlockArg.slotindex) or nil
            itemBlock.slotTypeList = itemBlockArg.slottype and moses.castArray(itemBlockArg.slottype) or nil
            itemBlock.qualityList = itemBlockArg.quality and moses.castArray(itemBlockArg.quality) or nil
            itemBlock.equipped = itemBlockArg.equipped
            itemBlock.equip = itemBlockArg.equip
            itemBlock.drop = itemBlockArg.drop
            itemBlock.remove = itemBlockArg.remove
            itemBlock.predicate = itemBlockArg.predicate
            itemBlock.onMatched = itemBlockArg.onmatched
            itemBlock.checkParent = itemBlock.slotIndexList or itemBlock.slotTypeList or itemBlock.equipped ~= nil

            if itemBlockArg.inventory then
                itemBlock.inventory = New "itembatch" (itemBlockArg.inventory, internalDebugName, mark)
            end

            initItemBlockToBatchUnit(); return
        end
    end)
end

---@param itemBatchUnit itembatchunit
---@param items userdata[]
---@param context itembatchctx
local function run(itemBatchUnit, items, context)
    moses.forEachi(itemBatchUnit, function(itemBlock)
        local logWithMark = itemBlock.logWithMark
        moses.forEachi(items, function(item)
            if itemBlock.isRef then
                run(itemBlock.ref.itemBatchUnit, { item }, {
                    character = context.character
                })
                return
            end

            local inventory = item.ParentInventory
            local owner
            local isAtCharacterInventory = false
            if inventory then
                owner = inventory.Owner
                if LuaUserData.TypeOf(inventory) == "Barotrauma.CharacterInventory" then
                    isAtCharacterInventory = true
                    context.character = owner
                end
            elseif itemBlock.checkParent then
                return
            end

            local identifier = item.Prefab.Identifier.Value
            if itemBlock.excludedIdentifiers and moses.include(itemBlock.excludedIdentifiers, identifier) then return end
            if itemBlock.excludedTags and moses.include(itemBlock.excludedTags, function(tag) return item.HasTag(tag) end) then return end
            if itemBlock.identifiers and not moses.include(itemBlock.identifiers, identifier) then return end
            if itemBlock.tags and not moses.include(itemBlock.tags, function(tag) return item.HasTag(tag) end) then return end
            if itemBlock.qualityList and not moses.include(itemBlock.qualityList, item.Quality) then return end

            if itemBlock.slotIndexList and not moses.include(itemBlock.slotIndexList, function(slotIndex)
                    return inventory.IsInSlot(item, slotIndex)
                end) then
                return
            end

            if itemBlock.slotTypeList and not (isAtCharacterInventory and moses.include(itemBlock.slotTypeList, function(slotType)
                    return inventory.IsInLimbSlot(item, slotType)
                end)) then
                return
            end

            if itemBlock.equipped ~= nil then
                if isAtCharacterInventory then
                    if moses.isuniq { itemBlock.equipped, owner:HasEquippedItem(item) } then return end
                elseif itemBlock.equipped then
                    return
                end
            end

            if itemBlock.predicate and not itemBlock.predicate(item) then return end
            if itemBlock.onMatched then itemBlock.onMatched(item) end

            if itemBlock.drop then item.Drop() end
            if itemBlock.remove then Entity.Spawner.AddItemToRemoveQueue(item) end
            if itemBlock.equip and context.character then
                utils.Equip(context.character, item)
            end

            if itemBlock.spedit then
                itemBlock.spedit:apply(item, logWithMark)
            end

            if itemBlock.inventory then
                local itemContainer = utils.GetComponent(item, "ItemContainer")
                if itemContainer then
                    run(itemBlock.inventory.itemBatchUnit, moses.tabulate(itemContainer.Inventory.AllItemsMod), {
                        character = context.character
                    })
                else
                    logWithMark(("无法批处理子物品！原因是没有找到物品'%s'的容器。"):format(tostring(item)), 'e')
                end
            end
        end)
    end)
end

---@param items userdata[]
function m:run(items)
    run(self.itemBatchUnit, items, {})
end

---@param inventory userdata
function m:runforinv(inventory)
    run(self.itemBatchUnit, moses.tabulate(inventory.AllItemsMod), {})
end

return m
