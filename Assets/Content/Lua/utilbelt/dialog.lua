if not SERVER then return nil end

---@class dialog
local dialog = {}

---@type fun(option:integer, client:Barotrauma.Networking.Client)[]
local callbacks = {}

---@param msg string
---@param options string[]
---@param id integer
---@param client Barotrauma.Networking.Client
---@param sprite? string
---@param fadeToBlack? boolean
local function SendEventMessage(msg, options, id, client, sprite, fadeToBlack)
    local message = Networking.Start()
    message.WriteByte(Byte(ServerPacketHeader.EVENTACTION))
    message.WriteByte(Byte(0))

    message.WriteUInt16(UInt16(id))
    message.WriteString(sprite)
    message.WriteByte(Byte(0))
    message.WriteBoolean(false)

    message.WriteUInt16(UInt16(0))
    message.WriteString(msg)
    message.WriteBoolean(fadeToBlack or false)
    message.WriteByte(Byte(#options))
    for _, value in ipairs(options) do
        message.WriteString(value)
    end
    message.WriteByte(Byte(#options))
    for i = 0, #options - 1, 1 do
        message.WriteByte(Byte(i))
    end

    Networking.Send(message, client.Connection, DeliveryMethod.Reliable)
end

Hook.Add("netMessageReceived", "utilbelt.dialog",
    ---@param message Barotrauma.Networking.IReadMessage
    ---@param header Barotrauma.Networking.ClientPacketHeader
    ---@param client Barotrauma.Networking.Client
    function(message, header, client)
        if header == ClientPacketHeader.EVENTMANAGER_RESPONSE then
            local id = message.ReadUInt16()
            local option = message.ReadByte()
            if callbacks[id] ~= nil then
                callbacks[id](option, client)
                callbacks[id] = nil
            end
            message.BitPosition = message.BitPosition - 24
        end
    end
)

---@param msg string
---@param options string[]
---@param client Barotrauma.Networking.Client
---@param callback? fun(option:integer, client:Barotrauma.Networking.Client)
---@param sprite? string
---@param fadeToBlack? boolean
function dialog.prompt(msg, options, client, callback, sprite, fadeToBlack)
    local id = #callbacks + 1
    callbacks[id] = callback
    SendEventMessage(msg, options, id, client, sprite, fadeToBlack)
end

return dialog
