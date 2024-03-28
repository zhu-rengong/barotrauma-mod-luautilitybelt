LuaUtilityBelt = {}
Lub = LuaUtilityBelt
Lub.Path = ...
Lub.Test = false

Lub.IsMultiplayerClient = CLIENT and Game.IsMultiplayer

require "utilbelt.extensions.table"
require "utilbelt.tools.diagnostics"

Lub.Class = require "utilbelt.tools.class"
Class = Lub.Class.declare
New = Lub.Class.new
Extends = Lub.Class.extends

Lub.Logger = require "utilbelt.logger"
Lub.Think = require "utilbelt.think"
Lub.Wait = require "utilbelt.wait"
Lub.Localization = require "utilbelt.l10n"
Lub.Chat = require "utilbelt.chat"
Lub.Dialog = require "utilbelt.dialog"
Lub.SPEdit = require "utilbelt.spedit"
Lub.ItemBuilder = require "utilbelt.itbu"
Lub.ItemBatch = require "utilbelt.itbat"

require "utilbelt.csharpmodule.Shared.Utils"



if Lub.IsMultiplayerClient then return end

if Lub.Test then
    dofile(Lub.Path .. "/Lua/utilbelt/test/itbu.lua")
    dofile(Lub.Path .. "/Lua/utilbelt/test/itbat.lua")
end
