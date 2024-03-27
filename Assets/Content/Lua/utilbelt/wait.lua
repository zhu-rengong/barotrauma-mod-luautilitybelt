---@class waitargs : { [1]:function }
---@field delay? integer
---@field ingame? boolean

---@overload fun(args:waitargs):boolean
local wait = {}

wait.__index = wait
setmetatable(wait, {
    __call = function(_, args)
        assert(type(args) == "table", ("Missing arguments on wait(). Expected #1 to be table, but got %s"):format(type(args)))
        assert(type(args[1]) == "function", ("Missing arguments on wait(). Expected args[1] to be function, but got %s"):format(type(args.func)))
        local func = args[1]
        local delay = args.delay or 0
        local ingame = args.ingame == nil and true or args.ingame
        if ingame then
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
})

return wait
