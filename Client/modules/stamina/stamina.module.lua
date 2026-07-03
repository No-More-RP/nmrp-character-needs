--- stamina.module.lua: client feature descriptor. `depends = { "hud" }`: the controller
--- registers a HUD gauge and pushes the server's motion segments into it, so the HUD gauge
--- API must exist first. Controller only (no view/service): the gauge lives in the core HUD.
local controller <const> = require 'stamina.controller.lua'; ---@type fun(ctx: ClientAppContext): void

---@type ClientAppModule
return {
    name       = "stamina",
    depends    = { "hud" },
    controller = controller,
};
