local log = require "utilbelt.logger" ("Wait")

---@class waitargs : { [1]: (fun(): integer?) }
---@field delay? integer
---@field ingame? boolean

---@param args waitargs
---@return boolean
return function(args)
    if type(args) ~= "table" then
        log(("须传入'table'参数！但却得到：'%s'。"):format(type(args)), 'e')
        return false
    end
    if type(args[1]) ~= "function" then
        log(("表域的索引[1]须为'function'！但却得到：'%s'。"):format(type(args[1])), 'e')
        return false
    end

    local func = args[1]
    local delay = args.delay or 0
    local inGame = args.ingame == nil and true or args.ingame
    if inGame then
        Timer.Wait(function()
            if Game.RoundStarted then
                func()
            end
        end, delay)
    else
        Timer.Wait(func, delay)
    end
    return true
end
