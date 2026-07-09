--- Server entry: register the character-needs feature modules into nmrp, then unregister them
--- on unload so the core loader keeps no stale 'stamina' descriptor (a hot-reload then
--- re-registers cleanly instead of hitting the loader's duplicate-name error). NMRP.register
--- waits for the core to be ready (schema synced) before wiring, so this is safe at load time.
local stamina <const> = require 'modules/stamina/stamina.module.lua'; ---@type AppModule

NMRP.register(stamina);
Package.Subscribe("Unload", function() NMRP.unregister(stamina); end);
