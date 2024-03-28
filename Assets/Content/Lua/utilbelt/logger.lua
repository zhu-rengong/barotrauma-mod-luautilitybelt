local logTypes = {
    ['i'] = { name = "Info", color = Color.LightGreen },
    ['d'] = { name = "Debug", color = Color.Blue },
    ['w'] = { name = "Warn", color = Color.Orange },
    ['e'] = { name = "Error", color = Color.Red, showtrace = true }
}

local showtrace = false

---@class log
---@overload fun(text:string, pattern?:'i'|'d'|'w'|'e')

---@param name string
---@return log
local function logger(name)
    return function(text, pattern)
        text = text or type(nil)
        local logType = logTypes[pattern and pattern or 'i'] or logTypes['i']
        local msgPrefix = ("[%s-%s-%s] "):format(SERVER and "SV" or "CL", name, logType.name)
        if showtrace and logType.showtrace then
            text = debug.traceback(nil, 2) .. text
        end
        for i = 1, #text, 1024 do
            local block = text:sub(i, math.min((i + 1023), #text))
            local msg = msgPrefix .. block
            if SERVER then
                for _, client in pairs(Client.ClientList) do
                    if client.HasPermission(ClientPermissions.ServerLog) then
                        local chatMessage = ChatMessage.Create("",
                            msg, ChatMessageType.Console, nil, nil, nil,
                            logType.color and logType.color or Color.MediumPurple)
                        Game.SendDirectChatMessage(chatMessage, client)
                    end
                end
                Game.Log(msg, ServerLogMessageType.ServerMessage)
            else
                Logger.Log(msg, logType.color and logType.color or Color.Purple)
            end
        end
    end
end

return logger
