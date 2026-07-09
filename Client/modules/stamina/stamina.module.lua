--- stamina.module.lua: client feature descriptor. `depends = { "hud" }`: the controller
--- registers a HUD gauge and pushes the server's motion segments into it, so the HUD gauge
--- API must exist first. Controller only (no view/service): the gauge lives in the core HUD.
local controller <const> = require 'stamina.controller.lua'; ---@type fun(ctx: ClientAppContext): void

---@type ClientAppModule
return {
    name       = "stamina",
    depends    = { "hud" },
    controller = controller,
    -- Drop the gauge when this addon unregisters (Package "Unload" -> NMRP.unregister) so it
    -- does not linger on the core HUD. The gauge lives in nmrp, not this package, so the
    -- engine's auto-cleanup does not reach it. The loader pcall-guards this call, so on a full
    -- gamemode reload (nmrp already gone) it is a harmless no-op.
    destroy    = function(ctx) ctx.services.hud.unregister_gauge("stamina"); end,
};
