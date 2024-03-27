local log = require "utilbelt.logger" ("ItemBuilder")
local utils = require "utilbelt.csharpmodule.Shared.Utils"
local spedit = require "utilbelt.spedit"
local moses = require "moses"

---@class itembuilderblock
---@field _prefab Barotrauma.ItemPrefab
---@field _pool_weights? number[]
---@field _pool_objects? itembuilderblock[]
---@field _amount? number
---@field _stacks? number
---@field _getamount? fun(self:itembuilderblock, context:itembuilderspawnctx):number
---@field _getrepetitions? fun(self:itembuilderblock, context:itembuilderspawnctx):integer
---@field _spedit? spedit
---@field ref itembuilder
---@field identifier string
---@field tags? string
---@field quality? integer
---@field slotindex? integer
---@field equip? boolean
---@field install? boolean
---@field inheritchannel? boolean
---@field amount? number|{[1]:number,[2]:number}
---@field amountround? boolean # default is `falsy`
---@field stacks? number|{[1]:number,[2]:number}
---@field fillinventory? boolean
---@field properties? sptbl
---@field serverevents? string|{[1]:string,[2]:integer?}|string[]|{[1]:string,[2]:integer?}[]
---@field onspawned? fun(item:Barotrauma.Item)
---@field inventory? itembuilderblock|itembuilderblock[]
---@field pool? {[1]:number,[2]:itembuilderblock|itembuilderblock[]}[]

---@class itembuilderspawnctx
---@field inventory? Barotrauma.Inventory|Barotrauma.ItemInventory|Barotrauma.CharacterInventory
---@field atinventory boolean
---@field atiteminventory boolean
---@field worldpos? Microsoft.Xna.Framework.Vector2
---@field _character? Barotrauma.Character

---@param itembuilds itembuilderblock[]
---@param context itembuilderspawnctx
---@param iterateoverpool boolean?
---@param debugname? string
local function spawn(itembuilds, context, iterateoverpool, debugname)
    local log = function(text, pattern)
        if debugname then
            log(("[DebugName:%s] %s"):format(debugname, text), pattern)
        else
            log(text, pattern)
        end
    end
    ---@param item Barotrauma.Item
    ---@param itemblock itembuilderblock
    ---@param context itembuilderspawnctx
    local function onspawned(item, itemblock, context)
        if itemblock.tags then
            item.Tags = itemblock.tags
        end

        if context.atinventory then
            if context.atiteminventory then
                if item.ParentInventory ~= context.inventory then
                    local containable = false
                    if itemblock.tags and context.inventory.TryPutItem(item, nil) then
                        containable = true
                    end
                    if not containable then
                        log(("Cannot put %s in %s"):format(tostring(item), tostring(context.inventory.Owner)), 'e')
                    end
                end
            else
                if context._character == nil then
                    context._character = context.inventory.Owner
                end

                if itemblock.slotindex then
                    if not context.inventory.CanBePutInSlot(item, itemblock.slotindex, false)
                        or not context.inventory.TryPutItem(item, itemblock.slotindex, true, true, context._character, true, false) then
                        log(("Cannot put %s in %s(slot:%i)"):format(tostring(item), tostring(context.inventory.Owner), itemblock.slotindex), 'e')
                    end
                end

                if itemblock.equip then
                    utils.Equip(context._character, item)
                end
            end

            if itemblock.inheritchannel and context._character then
                local headset = context._character.Inventory.GetItemInLimbSlot(InvSlotType.Headset)
                if headset then
                    local wifi = utils.GetComponent(headset, "WifiComponent")
                    if wifi then
                        spedit {
                            [{ "WifiComponent", "Channel" }] = wifi.Channel,
                            [{ "WifiComponent", "TeamID" }] = wifi.TeamID,
                            [{ "WifiComponent", "AllowCrossTeamCommunication" }] = wifi.AllowCrossTeamCommunication,
                        }:apply(item, log)
                    end
                end
            end
        end

        if itemblock._spedit then
            itemblock._spedit:apply(item, log)
        end

        if itemblock.inventory then
            local itemContainer = utils.GetComponent(item, "ItemContainer")
            if itemContainer then
                spawn(itemblock.inventory, {
                    atinventory = true,
                    atiteminventory = true,
                    inventory = itemContainer.Inventory,
                    _character = context._character
                }, iterateoverpool, debugname)
            else
                log(("Cannot spawn items in item(%s)'s inventory since it has no inventory!"):format(item.Prefab
                    .Identifier.Value), 'e')
            end
        end

        if SERVER and itemblock.serverevents then
            for _, serverevent in ipairs(itemblock.serverevents) do
                local index = 0
                for _, component in ipairs(item.Components) do
                    if component.Name:lower() == serverevent[1]:lower() then
                        index = index + 1
                        if serverevent[2] == nil or serverevent[2] == index then
                            item.CreateServerEvent(component, component)
                        end
                    end
                end
            end
        end

        if itemblock.onspawned then
            itemblock.onspawned(item)
        end
    end

    for _, itemblock in ipairs(itembuilds) do
        if type(itemblock) == "string" then
            debugname = #itemblock > 0 and itemblock or nil
        else
            if itemblock.ref then
                local num = itemblock:_getrepetitions(context)
                for _ = 1, num, 1 do
                    spawn(itemblock.ref._itembuilds, context, iterateoverpool, nil)
                end
            elseif itemblock.pool then
                local num = itemblock:_getrepetitions(context)
                for _ = 1, num, 1 do
                    if not iterateoverpool then
                        local object = utils.SelectDynValueWeightedRandom(itemblock._pool_objects, itemblock._pool_weights)
                        spawn(object, context, iterateoverpool, debugname)
                    else
                        for _, object in ipairs(itemblock._pool_objects) do
                            spawn(object, context, iterateoverpool, debugname)
                        end
                    end
                end
            else
                local amount = itemblock:_getamount(context)
                local num = math.ceil(amount)
                for i = 1, num, 1 do
                    local condition = nil
                    if i == num and amount < num then
                        condition = table.pack(math.modf(amount))[2] * itemblock._prefab.Health
                    end
                    if context.worldpos then
                        local shouldspawn = true
                        if itemblock.install then
                            for _, sub in pairs(Submarine.MainSubs) do
                                local borders, worldpos = sub.Borders, sub.WorldPosition
                                local worldrect = Rectangle(worldpos.X - borders.Width / 2, worldpos.Y + borders.Height / 2,
                                    borders.Width, borders.Height)
                                if sub.RectContains(worldrect, context.worldpos, true) then
                                    shouldspawn = false
                                    Entity.Spawner.AddItemToSpawnQueue(itemblock._prefab, context.worldpos - sub.Position,
                                        sub, condition, itemblock.quality, function(item)
                                            onspawned(item, itemblock, context)
                                        end)
                                    break
                                end
                            end
                        end
                        if shouldspawn then
                            Entity.Spawner.AddItemToSpawnQueue(itemblock._prefab, context.worldpos, condition,
                                itemblock.quality, function(item)
                                    onspawned(item, itemblock, context)
                                end)
                        end
                    elseif context.inventory then
                        Entity.Spawner.AddItemToSpawnQueue(itemblock._prefab, context.inventory, condition,
                            itemblock.quality, function(item)
                                onspawned(item, itemblock, context)
                            end)
                    end
                end
            end
        end
    end
end

---@class itembuilder
---@overload fun(itembuilds:itembuilderblock|itembuilderblock[]):itembuilder
---@field _invalid boolean
---@field _itembuilds itembuilderblock[]
local itembuilder = {}

---@param worldpos Microsoft.Xna.Framework.Vector2
---@param iterateoverpool boolean?
function itembuilder:spawnat(worldpos, iterateoverpool)
    spawn(self._itembuilds, {
        atinventory = false,
        atiteminventory = false,
        worldpos = worldpos
    }, iterateoverpool, nil)
end

---@param container Barotrauma.Item
---@param iterateoverpool boolean?
function itembuilder:spawnin(container, iterateoverpool)
    if container.OwnInventory then
        spawn(self._itembuilds, {
            atinventory = true,
            atiteminventory = true,
            inventory = container.OwnInventory
        }, iterateoverpool, nil)
    else
        self:spawnat(container.WorldPosition, iterateoverpool)
    end
end

---@param character Barotrauma.Character
---@param iterateoverpool boolean?
function itembuilder:give(character, iterateoverpool)
    if character.Inventory then
        spawn(self._itembuilds, {
            atinventory = true,
            atiteminventory = false,
            inventory = character.Inventory
        }, iterateoverpool, nil)
    else
        self:spawnat(character.WorldPosition, iterateoverpool)
    end
end

itembuilder.__index = itembuilder
setmetatable(itembuilder, {
    ---@param itembuilds itembuilderblock|itembuilderblock[]
    __call = function(_, itembuilds)
        ---@param itblds itembuilderblock|itembuilderblock[]
        ---@param debugname? string
        local function construct(itblds, debugname)
            local log = function(text, pattern)
                if debugname then
                    log(("[DebugName:%s] %s"):format(debugname, text), pattern)
                else
                    log(text, pattern)
                end
            end
            local k1type = type(next(itblds))
            itblds = (k1type == "number" or k1type == "nil") and itblds or { itblds }
            local _itblds = moses.filter(itblds, function(itemblock)
                if type(itemblock) == "string" then
                    debugname = #itemblock > 0 and itemblock or nil
                    return true
                end
                if itemblock.amount then
                    if type(itemblock.amount) == "number" and itemblock.amount > 0 then
                        itemblock._amount = itemblock.amount
                    elseif type(itemblock.amount) ~= "table"
                        or type(itemblock.amount[1]) ~= "number"
                        or type(itemblock.amount[2]) ~= "number"
                    then
                        itemblock._amount = 1
                    else
                        itemblock._amount = nil
                    end
                else
                    itemblock.amount, itemblock._amount = 1, 1
                end
                if itemblock.ref then
                    if itemblock.ref._invalid then
                        log(("itemblock is referenced to an invalid itembuilder!"), 'e')
                        return false
                    end
                    function itemblock:_getrepetitions()
                        local amount = self._amount or
                            self.amount[1] + math.random() * (self.amount[2] - self.amount[1])
                        return math.floor(amount)
                    end
                    return true
                elseif itemblock.pool then
                    local num = #itemblock.pool
                    if num > 0 then
                        itemblock._pool_weights = {}
                        itemblock._pool_objects = {}
                        for i = 1, num, 1 do
                            local tuple = itemblock.pool[i]
                            if type(tuple[1]) == "number" and tuple[1] > 0 and type(tuple[2]) == "table" then
                                itemblock._pool_weights[i] = tuple[1]
                                itemblock._pool_objects[i] = tuple[2]
                            else
                                log(("itemblock's pool exists invalid datas!"), 'e')
                                return false
                            end
                        end
                        for i, object in ipairs(itemblock._pool_objects) do
                            local k1type = type(next(object))
                            itemblock._pool_objects[i] = construct((k1type == "number" or k1type == "nil") and object or { object }, debugname)
                        end
                        function itemblock:_getrepetitions()
                            local amount = self._amount or
                                self.amount[1] + math.random() * (self.amount[2] - self.amount[1])
                            return math.floor(amount)
                        end
                        return true
                    end
                    log(("itemblock's pool is empty!"), 'e')
                    return false
                elseif itemblock.identifier and ItemPrefab.Prefabs.ContainsKey(itemblock.identifier) then
                    itemblock.identifier = Identifier(itemblock.identifier)
                    itemblock._prefab = ItemPrefab.Prefabs[itemblock.identifier]
                    if itemblock.stacks then
                        if type(itemblock.stacks) == "number" and itemblock.stacks > 0 then
                            itemblock._stacks = itemblock.stacks
                        elseif type(itemblock.stacks) ~= "table"
                            or type(itemblock.stacks[1]) ~= "number"
                            or type(itemblock.stacks[2]) ~= "number"
                        then
                            itemblock.stacks = nil
                        end
                    end
                    function itemblock:_getamount(context)
                        if self.fillinventory and context.atinventory then
                            return context.inventory.HowManyCanBePut(self._prefab)
                        elseif self.stacks then
                            local stacks = self._stacks or
                                self.stacks[1] + math.random() * (self.stacks[2] - self.stacks[1])
                            local amount = (context.atinventory
                                and self._prefab.GetMaxStackSize(context.inventory)
                                or self._prefab.MaxStackSize) * stacks
                            if self.amountround then amount = math.round(amount, 0) end
                            return amount
                        elseif self.amount then
                            local amount = self._amount or
                                self.amount[1] + math.random() * (self.amount[2] - self.amount[1])
                            if self.amountround then amount = math.round(amount, 0) end
                            return amount
                        else
                            -- code never covering here since `self.amount` is defined
                            log(("Cannot spawn item(%s) since the amount calculated by itub is not more then 0!")
                                :format(itemblock.identifier.Value), 'w')
                            return 0
                        end
                    end

                    if itemblock.properties then
                        itemblock._spedit = spedit(itemblock.properties, log)
                    end

                    if SERVER and itemblock.serverevents then
                        if type(itemblock.serverevents) == "string" then
                            itemblock.serverevents = { { itemblock.serverevents } }
                        elseif type(itemblock.serverevents) == "table" then
                            if #itemblock.serverevents > 0 then
                                local k1, v1 = next(itemblock.serverevents)
                                local _, v2 = next(itemblock.serverevents, k1)
                                if type(v1) == "string" then
                                    if v2 == nil or type(v2) == "string" then
                                        local _t = {}
                                        for _, eventstr in ipairs(itemblock.serverevents) do
                                            table.insert(_t, { eventstr })
                                        end
                                        itemblock.serverevents = _t
                                    elseif type(v2) == "number" then
                                        itemblock.serverevents = { { itemblock.serverevents[1], itemblock.serverevents[2] } }
                                    else
                                        log("itemblock's ServerEvents's secondary data is invalid!", "e")
                                        itemblock.serverevents = nil
                                    end
                                end
                            else
                                log("Table(itemblock's ServerEvents)'s length is not more then 0!", 'w')
                                itemblock.serverevents = nil
                            end
                        else
                            log(("Field(itemblock's ServerEvents) has invalid type, expected 'string' or 'table', but got %s")
                                :format(tostring(itemblock.serverevents)), 'e')
                            itemblock.serverevents = nil
                        end
                    end
                    if itemblock.inventory then
                        itemblock.inventory = type(next(itemblock.inventory)) == "number"
                            and itemblock.inventory or { itemblock.inventory }
                        itemblock.inventory = construct(itemblock.inventory, debugname)
                    end
                    return true
                else
                    log(("Could not found any prefab with given identifier(%s)")
                        :format(itemblock.identifier or type(nil)), 'e')
                    return false
                end
            end)
            return _itblds
        end

        ---@type itembuilder
        local inst = setmetatable({ _itembuilds = construct(itembuilds) }, itembuilder)

        if #inst._itembuilds == 0 then
            inst._invalid = true
            log("itembuilds is invalid!", 'e')
        end

        return inst
    end,
})

return itembuilder
