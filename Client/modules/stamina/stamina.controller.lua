--- stamina.controller.lua: (C) client stamina. Registers the "stamina" HUD gauge and drives
--- it from the server's authoritative motion segments ("stamina:update"), which the core's
--- generic gauge interpolates locally (value + rate * elapsed). No per-tick network: the
--- server sends a segment only at a transition. depends = { "hud" }, so the gauge API exists.
---
--- ```lua
--- require 'modules/stamina/stamina.controller.lua' (ctx);
--- ```
---@param ctx ClientAppContext
---@return void
return function(ctx)
    local hud <const> = ctx.services.hud; ---@type HudService

    hud.register_gauge({ id = "stamina", label = "Stamina", icon = "⚡", color = "#4ea1ff", order = 30, height = "thin" });

    -- Server -> client: a motion segment (value, rate, delay) at each transition (sprint
    -- start/stop, exhaustion). Reliability is consumed by the engine, not forwarded.
    Events.SubscribeRemote("stamina:update", function(value, rate, delay)
        hud.set_gauge_segment("stamina", value, rate, delay);
    end);

    -- Drop the gauge if THIS package unloads on its own, so it does not linger on the HUD.
    -- Guarded: on a full gamemode reload nmrp unloads first, so reaching into its (now dead)
    -- HUD would error; pcall makes that a harmless no-op (nmrp took its registry with it).
    Package.Subscribe("Unload", function() pcall(hud.unregister_gauge, "stamina"); end);
end
