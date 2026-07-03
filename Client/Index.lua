--- Client entry: register the character-needs feature modules into nmrp. NMRP.register waits
--- for the client core to be ready (local player resolved, HUD booted) before wiring.
NMRP.register(require 'modules/stamina/stamina.module.lua');
