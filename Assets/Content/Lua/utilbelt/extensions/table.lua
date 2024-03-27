local inf = 1 / 0
local nan = 0 / 0

local TAB = setmetatable({}, {
    __index = function(self, n)
        self[n] = string.rep('    ', n)
        return self[n]
    end
})

local RESERVED = {
    ['and'] = true,
    ['break'] = true,
    ['do'] = true,
    ['else'] = true,
    ['elseif'] = true,
    ['end'] = true,
    ['false'] = true,
    ['for'] = true,
    ['function'] = true,
    ['goto'] = true,
    ['if'] = true,
    ['in'] = true,
    ['local'] = true,
    ['nil'] = true,
    ['not'] = true,
    ['or'] = true,
    ['repeat'] = true,
    ['return'] = true,
    ['then'] = true,
    ['true'] = true,
    ['until'] = true,
    ['while'] = true,
}

local function isInteger(n)
    if math.type then
        return math.type(n) == 'integer'
    else
        return type(n) == 'number' and n % 1 == 0
    end
end

local function formatNumber(n)
    if n == inf
        or n == -inf
        or n == nan
        or n ~= n then -- IEEE: NAN ~= NAN
        return ('%q'):format(n)
    end
    if isInteger(n) then
        return tostring(n)
    end
    local str = ('%.10f'):format(n)
    str = str:gsub('%.?0*$', '')
    return str
end

---@param tbl table
---@param option? table
---@return string
function table.dump(tbl, option)
    option = option or {}
    if type(tbl) ~= 'table' then
        return tostring(tbl)
    end
    local lines = {}
    local mark = {}
    local stack = {}
    lines[#lines + 1] = '{'
    local function unpack(tbl)
        local deep = #stack
        mark[tbl] = (mark[tbl] or 0) + 1
        local keys = {}
        local keymap = {}
        local integerFormat = '[%d]'
        local alignment = 0
        if #tbl >= 10 then
            local width = #tostring(#tbl)
            integerFormat = ('[%%0%dd]'):format(math.ceil(width))
        end
        for key in pairs(tbl) do
            if type(key) == 'string' then
                if option['longStringKey']
                    or not key:match('^[%a_][%w_]*$')
                    or RESERVED[key]
                then
                    keymap[key] = ('[%q]'):format(key)
                else
                    keymap[key] = ('%s'):format(key)
                end
            elseif isInteger(key) then
                keymap[key] = integerFormat:format(key)
            else
                keymap[key] = ('["<%s>"]'):format(tostring(key))
            end
            keys[#keys + 1] = key
            if option['alignment'] then
                if #keymap[key] > alignment then
                    alignment = #keymap[key]
                end
            end
        end
        local mt = getmetatable(tbl)
        if not mt or not mt.__pairs then
            if option['sorter'] then
                option['sorter'](keys, keymap)
            else
                table.sort(keys, function(a, b)
                    return keymap[a] < keymap[b]
                end)
            end
        end
        for _, key in ipairs(keys) do
            local keyWord = keymap[key]
            if option['noArrayKey']
                and isInteger(key)
                and key <= #tbl
            then
                keyWord = ''
            else
                if #keyWord < alignment then
                    keyWord = keyWord .. (' '):rep(alignment - #keyWord) .. ' = '
                else
                    keyWord = keyWord .. ' = '
                end
            end
            local value = tbl[key]
            local tp = type(value)
            local format = option['format'] and option['format'][key]
            if format then
                value = format(value, unpack, deep + 1, stack)
                tp = type(value)
            end
            if tp == 'table' then
                if mark[value] and mark[value] > 0 then
                    lines[#lines + 1] = ('%s%s%s,'):format(TAB[deep + 1], keyWord, option['loop'] or '"<Loop>"')
                elseif deep >= (option['deep'] or math.huge) then
                    lines[#lines + 1] = ('%s%s%s,'):format(TAB[deep + 1], keyWord, '"<Deep>"')
                else
                    lines[#lines + 1] = ('%s%s{'):format(TAB[deep + 1], keyWord)
                    stack[#stack + 1] = key
                    unpack(value)
                    stack[#stack] = nil
                    lines[#lines + 1] = ('%s},'):format(TAB[deep + 1])
                end
            elseif tp == 'string' then
                lines[#lines + 1] = ('%s%s%q,'):format(TAB[deep + 1], keyWord, value)
            elseif tp == 'number' then
                lines[#lines + 1] = ('%s%s%s,'):format(TAB[deep + 1], keyWord, (option['number'] or formatNumber)(value))
            elseif tp == 'nil' then
            else
                lines[#lines + 1] = ('%s%s%s,'):format(TAB[deep + 1], keyWord, tostring(value))
            end
        end
        mark[tbl] = mark[tbl] - 1
    end
    unpack(tbl)
    lines[#lines + 1] = '}'
    return table.concat(lines, '\r\n')
end
