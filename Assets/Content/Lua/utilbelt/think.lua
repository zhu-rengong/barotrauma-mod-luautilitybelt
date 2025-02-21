local log = require "utilbelt.logger" ("Think")

---@class thinkargs : { [1]: (fun(): integer?) }
---@field identifier string
---@field interval? integer
---@field ingame? boolean

---@param args thinkargs
---@return boolean
return function(args)
    if type(args) ~= "table" then
        log(("A 'table' parameter must be passed, but got: '%s'!"):format(type(args)), 'e')
        return false
    end
    if type(args.identifier) ~= "string" then
        log(("The index 'identifier' of the table field must be 'string' type, but got '%s'!"):format(type(args.identifier)), 'e')
        return false
    end
    if type(args[1]) ~= "function" then
        log(("The index [1] of the table field must be 'function' type, but got '%s'!"):format(type(args[1])), 'e')
        return false
    end

    local identifier = args.identifier
    local func = args[1]
    local interval = args.interval or 1
    local ticks = 0
    local inGame = args.ingame == nil and true or args.ingame
    if inGame then
        Hook.Add("think", identifier, function()
            if Game.RoundStarted then
                ticks = ticks + 1
                if ticks == interval then
                    ticks = 0
                    interval = func() or interval
                end
            else
                Hook.Remove("think", identifier)
            end
        end)
    else
        Hook.Add("think", identifier, function()
            ticks = ticks + 1
            if ticks == interval then
                ticks = 0
                interval = func() or interval
            end
        end)
    end
    return true
end
