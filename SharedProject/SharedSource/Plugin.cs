using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Runtime.CompilerServices;
using System.Text;
using Barotrauma;
using Microsoft.Xna.Framework;

[assembly: IgnoresAccessChecksTo("Barotrauma")]

namespace LuaUtilityBelt
{
    public partial class Plugin : IAssemblyPlugin
    {
        public void Initialize()
        {

        }

        public void OnLoadCompleted()
        {

        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {

        }
    }
}
