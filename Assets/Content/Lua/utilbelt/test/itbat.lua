local itbat = require "utilbelt.itbat"
local moses = require "moses"

-- Drop antibleeding1 and remove antibloodloss2, change icon color of items with tag 'medical' to black
local itbat1 = itbat {
    { identifiers = "antibleeding1", drop = true },
    { identifiers = "antibloodloss2", remove = true },
    { tags = "medical", properties = { inventoryiconcolor = "0,0,0" } }
}

local itbat2 = itbat {
    "This is just a debug name",
    -- Drop non-medical items from the inventory of the item in Headset slot
    {
        slottype = InvSlotType.Headset,
        inventory = {
            excludedtags = "syringe",
            drop = true
        }
    },
    -- Apply itbat1 to the inventory of equipped doctorsuniform1
    {
        identifiers = "doctorsuniform1",
        equipped = true,
        inventory = { ref = itbat1 }
    },
    -- Set sonarbeacon in slot(17) interactable and contained item(batterycell) destructible
    {
        identifiers = "sonarbeacon",
        slotindex = 17,
        properties = {
            noninteractable = false,
        },
        inventory = {
            properties = { indestructible = false }
        }
    },
    -- Scale stun grenade bigger
    {
        identifiers = "stungrenade",
        properties = { scale = 5 }
    },
    -- Drop explosives from detonator which is in toolbox
    {
        identifiers = "toolbox",
        inventory = {
            identifiers = "detonator",
            inventory = {
                drop = true
            }
        }
    }
}

-- Remove all rounds from quality-2 revolver
local itbat3 = itbat {
    identifier = "revolver",
    quality = 2,
    inventory = { remove = true }
}

Hook.Add("chatMessage", "test.utilbelt.itbat", function(msg, client)
    if msg == "test.utilbelt.itbat" then
        if client.Character then
            itbat2:run(moses.tabulate(client.Character.Inventory.AllItemsMod))
            itbat3:runforinv(client.Character.Inventory)
        end
    end
end)
