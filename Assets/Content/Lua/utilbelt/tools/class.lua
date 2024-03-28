---@class Class
local M = {}

---@private
M._errorHandler = error

---@param errorHandler fun(msg: string)
function M.setErrorHandler(errorHandler)
    M._errorHandler = errorHandler
end

---@generic T
---@param obj T
---@return T
local function clone(obj)
    ---@type { table: table }
    local copyCaches = {}

    local function deepCopy(o)
        if type(o) ~= 'table' then return o end
        local copy = copyCaches[o]
        if copy then return copy end
        local _o = {}
        copyCaches[o] = _o
        for k, v in pairs(o) do
            if type(v) == 'table' then
                _o[k] = deepCopy(v)
            else
                _o[k] = v
            end
        end
        return _o
    end

    return deepCopy(obj)
end

---@class Class.Base
---@field public __init fun(obj: any, ...)

---@class Class.Config
---@field private name string
---@field package extendsMap { [string]: Class.Base }
local Config = {}

---@private
---@type { [string]: Class.Config }
M._classConfig = {}

---@private
---@type { [string]: Class.Base }
M._classes = {}

---@param name string
---@return Class.Config
function M.getConfig(name)
    local config = M._classConfig[name]
    if config == nil then
        config = setmetatable({
            name = name,
            extendsMap = {}
        }, { __index = Config })
        M._classConfig[name] = config
    end
    return config
end

---@param class Class.Base
local function instantiate(class)
    return setmetatable({}, class)
end

---@generic T: string
---@param name `T`
---@return T, Class.Config
function M.declare(name)
    local config = M.getConfig(name)
    if M._classes[name] then
        return M._classes[name], config
    end

    local mt = {}
    local class = setmetatable({}, mt)

    function mt:__index(k)
        for _, extends in pairs(config.extendsMap) do
            local v = extends[k]
            if v ~= nil then
                return v
            end
        end
    end

    function mt:__call(...)
        return instantiate(class)(...)
    end

    function class:__index(k)
        local v = class[k]
        if v ~= nil then
            v = clone(v)
            self[k] = v
        end
        return v
    end

    function class:__call(...)
        if class.__init then
            class.__init(self, ...)
        end
        return self
    end

    M._classes[name] = class

    return class, config
end

---@generic T: string
---@param extendsName `T`
function Config:extends(extendsName)
    local extends = M._classes[extendsName]
    if extends == nil then
        M._errorHandler(('class %q not found'):format(extendsName))
    end
    self.extendsMap[extendsName] = extends
end

---@generic T: string
---@param name `T`
---@param ... string
function M.extends(name, ...)
    local config = M.getConfig(name)
    for _, extendsName in ipairs({ ... }) do
        config:extends(extendsName)
    end
end

---@generic T: string
---@param name `T`
---@return T
function M.new(name)
    local class = M._classes[name]
    if class == nil then
        M._errorHandler(('class %q not found'):format(name))
    end

    return instantiate(class)
end

return M
