local logtbl = {
    ['i'] = { "Info", color = Color.LightGreen },
    ['d'] = { "Debug", color = Color.Blue },
    ['w'] = { "Warn", color = Color.Orange },
    ['e'] = { "Error", color = Color.Red, showtrace = true }
}

local showtrace = false

---@class log
---@overload fun(text:string, pattern?:'i'|'d'|'w'|'e')

---@param name string
---@return log
local function logger(name)
    return function(text, pattern)
        text = text or type(nil)
        local logtype = logtbl[pattern and pattern:lower() or 'i'] or logtbl['i']
        local msgpref = ("[%s-%s-%s] "):format(SERVER and "SV" or "CL", name, logtype[1])
        if showtrace and logtype.showtrace then
            text = debug.traceback(nil, 2) .. text
        end
        for i = 1, #text, 1024 do
            local block = text:sub(i, math.min((i + 1023), #text))
            local msg = msgpref .. block
            if SERVER then
                for _, client in pairs(Client.ClientList) do
                    if client.HasPermission(ClientPermissions.ServerLog) then
                        local chatMessage = ChatMessage.Create("",
                            msg, ChatMessageType.Console, nil, nil, nil,
                            logtype.color and logtype.color or Color.MediumPurple)
                        Game.SendDirectChatMessage(chatMessage, client)
                    end
                end
                Game.Log(msg, ServerLogMessageType.ServerMessage)
            else
                Logger.Log(msg, logtype.color and logtype.color or Color.Purple)
            end
        end
    end
end

return logger
