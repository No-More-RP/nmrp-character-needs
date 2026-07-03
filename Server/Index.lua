--- Server entry: register the character-needs feature modules into nmrp. NMRP.register waits
--- for the core to be ready (schema synced) before wiring, so this is safe at load time.
NMRP.register(require 'modules/stamina/stamina.module.lua');
