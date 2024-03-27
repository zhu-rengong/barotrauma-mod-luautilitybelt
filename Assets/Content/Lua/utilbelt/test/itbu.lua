local itbu = require "utilbelt.itbu"

local itbu1 = itbu {
    { identifier = "antibleeding1", stacks = 1 },
    { identifier = "antibloodloss2", amount = 2 },
    { identifier = "antidama1", amount = 3 }
}

local itbu2 = itbu {
    "This is just a debug name",
    -- Spawn Auto-Injector Headset and inhert the Channel from the headset worn by the character
    {
        identifier = "autoinjectorheadset",
        equip = true,
        inheritchannel = true,
        inventory = {
            { identifier = "c4block", tags = "chem,medical" },
        }
    },
    -- Spawn Medic's Fatigues
    {
        identifier = "doctorsuniform1",
        equip = true,
        inventory = { ref = itbu1 }
    },
    -- Spawn a non-interactive sonarbeacon for exposing the position of the owner
    {
        identifier = "sonarbeacon",
        -- Put it in the last slot of Any type in the inventory
        slotindex = 17,
        properties = {
            noninteractable = true,
            [{ "custominterface", "elementstates" }] = "true,",
            [{ "custominterface", "signals" }] = ";Me",
        },
        serverevents = "custominterface",
        inventory = {
            {
                identifier = "batterycell",
                properties = { indestructible = true }
            }
        }
    },
    -- Spawn randomly grenade 3 times
    {
        amount = 3,
        -- 25%(10/40) chance: fraggrenade/stungrenade/incendiumgrenade
        -- 12.5% chance: empgrenade/acidgrenade
        pool = {
            { 10, { identifier = "fraggrenade" } },
            { 10, { identifier = "stungrenade" } },
            { 10, { identifier = "incendiumgrenade" } },
            { 5, { identifier = "empgrenade" } },
            { 5, { identifier = "chemgrenade" } },
        }
    },
    -- Prize draw, 50% chance: a toolbox contained planting manual dirty bomb or c4block
    {
        pool = {
            {
                50,
                {
                    {
                        identifier = "toolbox",
                        inventory = {
                            { identifier = "screwdriver" },
                            { identifier = "wrench" },
                            { identifier = "bluewire" },
                            {
                                identifier = "detonator",
                                inventory = {
                                    pool = {
                                        { 40, { identifier = "c4block", quality = 3 } },
                                        { 20, { identifier = "dirtybomb" } },
                                    }
                                }
                            },
                            { identifier = "button" },
                        }
                    }
                }
            },
            {
                50,
                {}
            }
        }
    },
}

-- Spawn a revolver and fill up ammos
local itbu3 = itbu {
    identifier = "revolver",
    quality = 2,
    inventory = { identifier = "revolverround", fillinventory = true }
}

Hook.Add("chatMessage", "test.utilbelt.itbu", function(msg, client)
    if msg == "test.utilbelt.itbu" then
        if client.Character then
            itbu2:give(client.Character)
            itbu3:give(client.Character)
        end
    end
end)
