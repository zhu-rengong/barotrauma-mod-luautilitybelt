diagnostics = {}

---@param values any[]
---@param ... type
---@return boolean
function diagnostics.checktypes(values, ...)
    local types = { ... }
    if #values ~= #types then return false end
    for i, value in ipairs(values) do
        if type(value) ~= types[i] then
            return false
        end
    end
    return true
end
