local log = require "utilbelt.logger" ("ItemBuilder")
local utils = require "utilbelt.csharpmodule.Shared.Utils"
local spedit = require "utilbelt.spedit"
local moses = require "moses"

---@class itembuildsarg : itembuilderblockarg, { [integer]: itembuilderblockarg }
---@class itembuilds : { [integer]: itembuilderblock }

---@class itembuilderblockarg
---@field ref itembuilder
---@field identifier string
---@field tags? string
---@field quality? integer
---@field slotindex? integer
---@field equip? boolean
---@field install? boolean
---@field inheritchannel? boolean
---@field amount? number|{ [1]: number, [2]: number}
---@field amountround? boolean
---@field stacks? number|{ [1]: number, [2]: number}
---@field fillinventory? boolean
---@field properties? sptbl
---@field serverevents? string|string[]|{ [1]: string, [2]: integer? }|{ [1]: string, [2]: integer? }[]
---@field onspawned? fun(item:userdata)
---@field inventory? itembuildsarg
---@field pool? { [1]: number, [2]: itembuildsarg }[]

---@class itembuilderblock
---@field logWithMark log
---@field amountDefined boolean
---@field amount? number
---@field amountRange? { [1]: number, [2]: number }
---@field amountRound? boolean
---@field stacksDefined boolean
---@field stacks? number
---@field stacksRange? { [1]: number, [2]: number }
---@field calcAmount fun(self:itembuilderblock, context:itembuilderspawnctx, round?: boolean):number
---@field isRef boolean
---@field ref itembuilder
---@field isPrefab boolean
---@field identifier userdata
---@field itemPrefab userdata
---@field tags? string
---@field quality? integer
---@field slotIndex? integer
---@field equip? boolean
---@field install? boolean
---@field inheritChannel? boolean
---@field fillInventory? boolean
---@field spedit? spedit
---@field serverEvents? { [1]: string, [2]: integer }[]
---@field onSpawned? fun(item:userdata)
---@field inventory? itembuilder
---@field isPool boolean
---@field poolWeights? number[]
---@field poolBuilders? itembuilder[]

---@class itembuilderspawnctx
---@field inventory? userdata
---@field atInventory boolean
---@field atItemInventory boolean
---@field worldPosition? userdata
---@field character? userdata
---@field iterateOverPool? boolean

local spawn

---@param item userdata
---@param itemBlock itembuilderblock
---@param context itembuilderspawnctx
local function onSpawned(item, itemBlock, context)
    local logWithMark = itemBlock.logWithMark

    if itemBlock.tags then
        item.Tags = itemBlock.tags
    end

    if context.atInventory then
        if item.ParentInventory ~= context.inventory then
            local alreadyContained = false
            if context.atItemInventory then
                if itemBlock.tags and context.inventory:TryPutItem(item, nil) then
                    alreadyContained = true
                end
            end
            if not alreadyContained then
                logWithMark(("无法将物品'%s'存放至'%s'！"):format(tostring(item), tostring(context.inventory.Owner)), 'w')
            end
        end

        if not context.atItemInventory then
            if context.character == nil then
                context.character = context.inventory.Owner
            end

            if itemBlock.slotIndex then
                if not context.inventory:CanBePutInSlot(item, itemBlock.slotIndex, false)
                    or not context.inventory:TryPutItem(item, itemBlock.slotIndex, true, true, context.character, true, false) then
                    logWithMark(("无法将物品'%s'存放至'%s'的第%i槽位！"):format(tostring(item), tostring(context.inventory.Owner), itemBlock.slotIndex), 'w')
                end
            end
        end
    end

    if context.character then
        if itemBlock.inheritChannel then
            local headset = context.character.Inventory.GetItemInLimbSlot(InvSlotType.Headset)
            if headset then
                local wifi = Game.GetWifiComponent(headset)
                if wifi then
                    spedit {
                        WifiComponent = {
                            channel = wifi.Channel,
                            teamid = wifi.TeamID,
                            allowcrossteamcommunication = wifi.AllowCrossTeamCommunication,
                        }
                    }:apply(item, logWithMark)
                end
            end
        end

        if itemBlock.equip then
            utils.Equip(context.character, item)
        end
    end

    if itemBlock.spedit then
        itemBlock.spedit:apply(item, logWithMark)
    end

    if itemBlock.inventory then
        local itemContainer = utils.GetComponent(item, "ItemContainer")
        if itemContainer then
            spawn(itemBlock.inventory.itemBuilds, {
                atInventory = true,
                atItemInventory = true,
                inventory = itemContainer.Inventory,
                character = context.character,
                iterateOverPool = context.iterateOverPool
            })
        else
            logWithMark(("无法生成子物品！原因是没有找到物品'%s'的容器。"):format(tostring(item)), 'e')
        end
    end

    if SERVER then
        if itemBlock.serverEvents then
            for _, event in ipairs(itemBlock.serverEvents) do
                local index = 0
                for _, component in ipairs(item.Components) do
                    if component.Name:lower() == event[1]:lower() then
                        index = index + 1
                        if event[2] == nil or event[2] == index then
                            item.CreateServerEvent(component, component)
                        end
                    end
                end
            end
        end
    end

    if itemBlock.onSpawned then
        itemBlock.onSpawned(item)
    end
end

---@param itemBuilds itembuilds
---@param context itembuilderspawnctx
spawn = function(itemBuilds, context)
    for _, itemBlock in ipairs(itemBuilds) do
        if itemBlock.isRef then
            local num = itemBlock:calcAmount(context, true)
            while num > 0 do
                num = num - 1
                spawn(itemBlock.ref.itemBuilds, context)
            end
        elseif itemBlock.isPool then
            local num = itemBlock:calcAmount(context, true)
            while num > 0 do
                num = num - 1
                if not context.iterateOverPool then
                    ---@type itembuilder
                    local object = utils.SelectDynValueWeightedRandom(itemBlock.poolBuilders, itemBlock.poolWeights)
                    spawn(object.itemBuilds, context)
                else
                    for _, object in ipairs(itemBlock.poolBuilders) do
                        spawn(object.itemBuilds, context)
                    end
                end
            end
        elseif itemBlock.isPrefab then
            local amount = itemBlock:calcAmount(context)
            local num = math.ceil(amount)
            for i = 1, num, 1 do
                local condition = nil
                if i == num and amount < num then
                    condition = table.pack(math.modf(amount))[2] * itemBlock.itemPrefab.Health
                end
                if context.worldPosition then
                    local notSpawnYet = true
                    if itemBlock.install then
                        for _, sub in pairs(Submarine.MainSubs) do
                            local borders, worldPosition = sub.Borders, sub.WorldPosition
                            local worldrect = Rectangle(worldPosition.X - borders.Width / 2, worldPosition.Y + borders.Height / 2,
                                borders.Width, borders.Height)
                            if sub.RectContains(worldrect, context.worldPosition, true) then
                                Entity.Spawner.AddItemToSpawnQueue(itemBlock.itemPrefab, context.worldPosition - sub.Position,
                                    sub, condition, itemBlock.quality, function(item)
                                        onSpawned(item, itemBlock, context)
                                    end)
                                break
                                notSpawnYet = false
                            end
                        end
                    end
                    if notSpawnYet then
                        Entity.Spawner.AddItemToSpawnQueue(itemBlock.itemPrefab, context.worldPosition, condition,
                            itemBlock.quality, function(item)
                                onSpawned(item, itemBlock, context)
                            end)
                    end
                elseif context.inventory then
                    Entity.Spawner.AddItemToSpawnQueue(itemBlock.itemPrefab, context.inventory, condition,
                        itemBlock.quality, function(item)
                            onSpawned(item, itemBlock, context)
                        end)
                end
            end
        end
    end
end

---@class itembuilder
---@field itemBuilds itembuilds
---@overload fun(itemBuildsArg: itembuildsarg, debugName?: string, parentMark?: string):self
local m = Class 'itembuilder'
m._ISITEMBUILDER = true

---@param itemBuildsArg itembuildsarg
---@param debugName? string
---@param parentMark? string
function m:__init(itemBuildsArg, debugName, parentMark)
    local itemBuilds = {}
    self.itemBuilds = itemBuilds

    local initialIndexType = type(next(itemBuildsArg))
    itemBuildsArg = (initialIndexType == "number" or initialIndexType == "nil") and itemBuildsArg or { itemBuildsArg }

    moses.forEachi(itemBuildsArg, function(itemBlockArg, index)
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

        ---@type itembuilderblock
        local itemBlock = { isRef = false, isPool = false, isPrefab = false }

        local function initItemBlockToBuilds()
            itemBlock.logWithMark = logWithMark

            itemBlock.amountRound = itemBlockArg.amountround
            itemBlock.tags = itemBlockArg.tags
            itemBlock.quality = itemBlockArg.quality
            itemBlock.slotIndex = itemBlockArg.slotindex
            itemBlock.equip = itemBlockArg.equip
            itemBlock.install = itemBlockArg.install
            itemBlock.inheritChannel = itemBlockArg.inheritchannel
            itemBlock.fillInventory = itemBlockArg.fillinventory
            itemBlock.onSpawned = itemBlockArg.onspawned

            itemBlock.amountDefined = false
            if type(itemBlockArg.amount) == "number" then
                if itemBlockArg.amount >= 0 then
                    itemBlock.amount = itemBlockArg.amount
                    itemBlock.amountDefined = true
                end
            elseif type(itemBlockArg.amount) == "table" then
                local amountMin, amountMax = itemBlockArg.amount[1], itemBlockArg.amount[2]
                if type(amountMin) == "number"
                    and type(amountMax) == "number"
                    and amountMin >= 0
                    and amountMax >= 0
                then
                    if amountMin > amountMax then
                        amountMin, amountMax = amountMax, amountMin
                    end
                    itemBlock.amountRange = { amountMin, amountMax }
                    itemBlock.amountDefined = true
                end
            end

            itemBlock.stacksDefined = false
            if type(itemBlockArg.stacks) == "number" then
                if itemBlockArg.stacks >= 0 then
                    itemBlock.stacks = itemBlockArg.stacks
                    itemBlock.stacksDefined = true
                end
            elseif type(itemBlockArg.stacks) == "table" then
                local stacksMin, stacksMax = itemBlockArg.stacks[1], itemBlockArg.stacks[2]
                if type(stacksMin) == "number"
                    and type(stacksMax) == "number"
                    and stacksMin >= 0
                    and stacksMax >= 0
                then
                    if stacksMin > stacksMax then
                        stacksMin, stacksMax = stacksMax, stacksMin
                    end
                    itemBlock.stacksRange = { stacksMin, stacksMax }
                    itemBlock.stacksDefined = true
                end
            end

            function itemBlock:calcAmount(context, round)
                if round == nil then round = self.amountRound end
                local amount = 1
                if self.amountDefined then
                    if self.amount then
                        amount = self.amount
                    elseif self.amountRange then
                        amount = self.amount[1] + math.random() * (self.amount[2] - self.amount[1])
                    end
                elseif self.isPrefab then
                    if self.stacksDefined then
                        local maxStackSize = context.atInventory
                            and itemBlock.itemPrefab:GetMaxStackSize(context.inventory)
                            or itemBlock.itemPrefab.MaxStackSize
                        if self.stacks then
                            amount = self.stacks * maxStackSize
                        elseif self.stacksRange then
                            amount = (self.amount[1] + math.random() * (self.amount[2] - self.amount[1])) * maxStackSize
                        end
                    elseif self.fillInventory then
                        if context.atInventory then
                            amount = context.inventory:HowManyCanBePut(self.itemPrefab)
                        end
                    end
                end
                if amount == 0 then
                    logWithMark("量的计算结果为零！", 'w')
                end
                return round and math.round(amount, 0) or amount
            end

            table.insert(itemBuilds, itemBlock)
        end

        if itemBlockArg.ref then
            if not itemBlockArg.ref._ISITEMBUILDER then
                logWithMark("只许引用ItemBuilder！", 'e')
                return
            end
            itemBlock.isRef = true
            itemBlock.ref = itemBlockArg.ref
            initItemBlockToBuilds(); return
        elseif itemBlockArg.pool then
            local num = #itemBlockArg.pool
            if num == 0 then
                logWithMark("物品池为空！", 'e')
                return
            end
            local weights = {}
            local poolArgs = {}
            for i = 1, num, 1 do
                local tuple = itemBlockArg.pool[i]
                if type(tuple[1]) == "number"
                    and type(tuple[2]) == "table"
                    and tuple[1] > 0
                then
                    weights[i] = tuple[1]
                    poolArgs[i] = tuple[2]
                else
                    logWithMark("物品池中存在无效项！", 'e')
                    return
                end
            end
            itemBlock.isPool = true
            itemBlock.poolWeights = weights
            itemBlock.poolBuilders = {}
            for i, args in ipairs(poolArgs) do
                itemBlock.poolBuilders[i] = New "itembuilder" (args, internalDebugName, mark)
            end
            initItemBlockToBuilds(); return
        elseif itemBlockArg.identifier then
            if not ItemPrefab.Prefabs.ContainsKey(itemBlockArg.identifier) then
                logWithMark(("无法找到id为'%s'的物品预制件！"):format(itemBlockArg.identifier), 'e')
                return
            end
            itemBlock.isPrefab = true
            itemBlock.identifier = Identifier(itemBlockArg.identifier)
            itemBlock.itemPrefab = ItemPrefab.Prefabs[itemBlock.identifier]

            if itemBlockArg.properties then
                itemBlock.spedit = spedit(itemBlockArg.properties, logWithMark)
            end

            if SERVER then
                if itemBlockArg.serverevents then
                    if type(itemBlockArg.serverevents) == "string" then
                        itemBlock.serverEvents = { { itemBlockArg.serverevents, 1 } }
                    elseif type(itemBlockArg.serverevents) == "table" then
                        local function logInvalidField(expected)
                            logWithMark(("此处serverevents的表域是无效的，预期的类型是：\n%s，但却得到：\n%s")
                                :format(expected, table.dump(itemBlockArg.serverevents, { noArrayKey = true })), 'e')
                        end
                        local k1, v1 = next(itemBlockArg.serverevents)
                        if k1 then
                            if type(v1) == "string" then
                                local _, v2 = next(itemBlockArg.serverevents, k1)
                                if v2 == nil or type(v2) == "string" then
                                    local isInvalidField = false
                                    itemBlock.serverEvents = {}
                                    for _, event in ipairs(itemBlockArg.serverevents) do
                                        if type(event) == "string" then
                                            table.insert(itemBlock.serverEvents, { event, 1 })
                                        else
                                            isInvalidField = true
                                        end
                                    end
                                    if isInvalidField then
                                        logInvalidField "string[]"
                                    end
                                elseif type(v2) == "number" then
                                    if math.floor(v2) == v2 then
                                        itemBlock.serverEvents = { { v1, v2 } }
                                    else
                                        logInvalidField "{ [1]: string, [2]: integer }"
                                    end
                                else
                                    logInvalidField "unknown"
                                end
                            elseif type(v1) == "table" then
                                local isInvalidField = false
                                itemBlock.serverEvents = {}
                                for _, event in ipairs(itemBlockArg.serverevents) do
                                    if type(event) == "table"
                                        and type(event[1]) == "string"
                                        and (event[2] == nil or moses.isInteger(event[2]))
                                    then
                                        table.insert(itemBlock.serverEvents, { event[1], event[2] })
                                    else
                                        isInvalidField = true
                                    end
                                end
                                if isInvalidField then
                                    logInvalidField "{ [1]: string, [2]: integer? }[]"
                                end
                            else
                                logInvalidField "unknown"
                            end
                        else
                            logWithMark("serverevents为空！", 'w')
                        end
                    else
                        logWithMark("serverevents不是有效的类型！", 'e')
                    end
                end
            end

            if itemBlockArg.inventory then
                itemBlock.inventory = New "itembuilder" (itemBlockArg.inventory, internalDebugName, mark)
            end

            initItemBlockToBuilds(); return
        else
            logWithMark("必须定义字段ref、pool、identifier之中的一个！", 'e')
        end
    end)
end

---@param worldPosition userdata
---@param iterateOverPool? boolean
function m:spawnat(worldPosition, iterateOverPool)
    spawn(self.itemBuilds, {
        atInventory = false,
        atItemInventory = false,
        worldPosition = worldPosition,
        iterateOverPool = iterateOverPool
    })
end

---@param container userdata
---@param iterateOverPool? boolean
function m:spawnin(container, iterateOverPool)
    if container.OwnInventory then
        spawn(self.itemBuilds, {
            atInventory = true,
            atItemInventory = true,
            inventory = container.OwnInventory,
            iterateOverPool = iterateOverPool
        })
    else
        self:spawnat(container.WorldPosition, iterateOverPool)
    end
end

---@param character userdata
---@param iterateOverPool? boolean
function m:give(character, iterateOverPool)
    if character.Inventory then
        spawn(self.itemBuilds, {
            atInventory = true,
            atItemInventory = false,
            inventory = character.Inventory,
            iterateOverPool = iterateOverPool
        })
    else
        self:spawnat(character.WorldPosition, iterateOverPool)
    end
end

return m
