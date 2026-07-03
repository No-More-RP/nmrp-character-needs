--- stamina.module.lua: feature descriptor. `depends = { "player" }`: we hook into the
--- player lifecycle (on_releasing for transient cleanup). No Norm model: stamina is
--- runtime state, not persisted.
--- require paths relative to THIS folder; returns typed by hand.
local service <const>    = require 'stamina.service.lua';    ---@type fun(ctx: AppContext): StaminaService
local controller <const> = require 'stamina.controller.lua'; ---@type fun(ctx: AppContext): void

---@type AppModule
return {
    name       = "stamina",
    depends    = { "player" },
    service    = service,
    controller = controller,
};
