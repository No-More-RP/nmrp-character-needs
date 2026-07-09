--- Client entry: register the character-needs feature modules into nmrp, then unregister them
--- when this package unloads so nmrp's loader / HUD keep no stale entry (a hot-reload then
--- re-registers cleanly instead of hitting the loader's duplicate-name error). NMRP.register
--- waits for the client core to be ready (local player resolved, HUD booted) before wiring.
local stamina <const> = require 'modules/stamina/stamina.module.lua'; ---@type ClientAppModule

NMRP.register(stamina);
Package.Subscribe("Unload", function() NMRP.unregister(stamina); end);
