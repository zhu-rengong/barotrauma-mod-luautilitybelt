using System;
using System.Linq;
using System.Collections.Generic;
using Barotrauma;
using Barotrauma.Networking;
using Barotrauma.Items.Components;
using MoonSharp.Interpreter;

namespace LuaUtilityBelt
{
    static class Utils
    {
        public static ItemComponent? GetComponent(Item item, string name, int lidx = 1)
        {
            int i = 0;
            foreach (var itemComponent in item.Components)
            {
                if (string.Equals(itemComponent.Name, name, StringComparison.OrdinalIgnoreCase))
                {
                    if (++i == lidx)
                    {
                        return itemComponent;
                    }
                }
            }
            return null;
        }

        public static bool TrySetValue(SerializableProperty serializableProperty, object parentObject, string value)
        {
            return serializableProperty.TrySetValue(parentObject, value);
        }

        public static bool IsEditable(SerializableProperty serializableProperty)
        {
            return serializableProperty.Attributes.OfType<Editable>().Any();
        }

        public static DynValue SelectDynValueWeightedRandom(IList<DynValue> objects, IList<float> weights)
        {
            return ToolBox.SelectWeightedRandom(objects, weights, Rand.GetRNG(Rand.RandSync.Unsynced));
        }
            
        public static void Equip(Character character, Item item)
        {
            var inventory = character.Inventory;
            if (inventory == null) { return; }
            List<InvSlotType> allowedSlots =
                item.GetComponents<Pickable>().Count() > 1 ?
                new List<InvSlotType>(item.GetComponent<Wearable>()?.AllowedSlots ?? item.GetComponent<Pickable>().AllowedSlots) :
                new List<InvSlotType>(item.AllowedSlots);
            allowedSlots.Remove(InvSlotType.Any);
            inventory.TryPutItem(item, null, allowedSlots);
        }

        public static string ClientLogName(Client client, string? name = null)
        {
            return NetworkMember.ClientLogName(client, name);
        }
    }
}
