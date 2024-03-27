local moses = require "moses"
local log = require "utilbelt.logger" ("Chat")
local l10nmgr = require "utilbelt.l10n"
local utils = require "utilbelt.csharpmodule.Shared.Utils"

---@class chat
local chat = {}

---@class chatmsgbaseparams
---@field msgtypes? Barotrauma.Networking.ChatMessageType|Barotrauma.Networking.ChatMessageType[]
---@field color? Microsoft.Xna.Framework.Color
---@field style? string

---@class chatfsendparams : chatmsgbaseparams, { [1]:string, [2]:Barotrauma.Networking.Client }
---@field boardcast? boolean # Only for client to determine whether the chat message should be send to others, default is true

---@class chatfboardcastparams : chatmsgbaseparams, { [1]:string }
---@field filter? fun(client:Barotrauma.Networking.Client):boolean

---@param params chatfsendparams
function chat.send(params)
    local client = params[2]
    if SERVER then
        if client == nil then return end
    end
    local text = params[1] or type(nil)
    local msgtypes = params.msgtypes and moses.castArray(params.msgtypes) or { ChatMessageType.Default }
    moses.forEachi(msgtypes, function(v)
        local chatmsg = ChatMessage.Create("", text, v, nil, nil, nil, params.color)
        chatmsg.IconStyle = params.style
        if SERVER then
            Game.SendDirectChatMessage(chatmsg, client)
        else
            if Game.IsMultiplayer and (params.boardcast == nil and true or params.boardcast) then
                Game.Client.SendChatMessage(chatmsg)
            else
                Game.ChatBox.AddMessage(chatmsg)
            end
        end
    end)
end

---@param params chatfboardcastparams
function chat.boardcast(params)
    if SERVER then
        local clients = params.filter and moses.filter(Client.ClientList, params.filter) or Client.ClientList
        moses.forEachi(clients, function(client)
            params[2] = client
            chat.send(params)
        end)
    else
        chat.send(params)
    end
end

---@class chatcommandoptions
---@field callback fun(client?:Barotrauma.Networking.Client, args:string[])
---@field help? string
---@field permissions? Barotrauma.Networking.ClientPermissions
---@field sort? integer
---@field hidden? boolean

---@class chatcommand : chatcommandoptions
---@field names string|string[]

---@class chatfaddcommandparams : chatcommandoptions, { [1]:string|string[] }

---@type chatcommand[]
local commands = {}
local invertedclientpermissions = moses.invert(ClientPermissions)

---@param params chatfaddcommandparams
function chat.addcommand(params)
    if moses.any({ "string", "table" }, type(params[1])) then
        if type(params.callback) == "function" then
            local command = {}
            command.names = moses.castArray(params[1])
            command.callback = params.callback
            command.help = params.help
            command.permissions = params.permissions
            command.sort = params.sort or 255
            command.hidden = params.hidden == nil and false or params.hidden
            table.insert(commands, command)
            moses.sortBy(commands, "sort")
            log(("Added a chat-command: %s"):format(table.concat(command.names, ' | ')))
        else
            log(("chat.addcommand() expected params[2] to be 'function' as command callback, but got '%s'"):format(type(params.callback)), 'e')
        end
    else
        log(("chat.addcommand() expected params[1] to be 'string' or 'string[]' as command name, but got '%s'"):format(type(params[1])), 'e')
    end
end

---@param name string
function chat.removecommand(name)
    for i = #commands, 1, -1 do
        local command = commands[i]
        if moses.include(command.names, name) then
            table.remove(commands, i)
            log(("Removed a chat-command: %s"):format(table.concat(command.names, ' | ')))
        end
    end
end

chat.addcommand { SERVER and "!help" or "!clhelp", callback = function(client, args)
    local visiblecommands = moses.filter(commands, function(command)
        return not command.hidden
    end)
    local helps = moses.mapv(visiblecommands, function(command)
        return ("‖color:gui.yellow‖%s‖end‖: %s"):format(
            table.concat(command.names, ' | '),
            command.help or "unknown"
        )
    end)
    chat.send { table.concat(helps, '\n'), client, boardcast = false }
    return true
end, hidden = true }

---@return string[]
local function checkpermissions(permissions)
    return moses.filter(invertedclientpermissions, function(name, value)
        return bit32.band(permissions, value) ~= 0
    end)
end

Hook.Add("chatMessage", "utilbelt.chat",
    ---@param msg string
    ---@param client Barotrauma.Networking.Client
    function(msg, client)
        local split = ToolBox.SplitCommand(msg)
        if split[1] == nil then return end
        local name = table.remove(split, 1)
        local index = moses.findIndex(commands, function(v)
            return moses.include(v.names, name)
        end)
        if index == nil then return end
        local command = commands[index]
        if SERVER then
            if command.permissions == nil or client.HasPermission(command.permissions) then
                log(("client %s requests to execute the command '%s' with the following parameters: %s"):format(
                    utils.ClientLogName(client), name, table.concat(split, ', ')))
                return command.callback(client, split)
            else
                local permnames = moses.mapv(checkpermissions(command.permissions), function(v)
                    return TextManager.Get("clientpermission." .. v).Value
                end)

                chat.send {
                    l10nmgr { "Utilbelt", "ChatCommand", "NoPermission" }:format(table.concat(permnames, ', '), name),
                    client,
                    color = Color.Orange
                }
            end
        else
            log(("You requests to execute the command '%s' with the following parameters: %s"):format(
                name, table.concat(split, ', ')))
            return command.callback(client, split)
        end
    end
)

return chat
