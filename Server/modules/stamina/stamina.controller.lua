--- stamina.controller.lua: (C) wires stamina to the world: initializes on possession,
--- subscribes each Character's gait changes, runs the (active-set-only) authority loop, and
--- exposes a debug command. Reads ctx.services.stamina; never touches the internal state
--- directly. The client needs no handshake: on_spawn pushes the initial segment reliably.
---
--- ```lua
--- require 'stamina.controller.lua' (ctx);
--- ```
--- `command` is the nmrp command lib, reached through the exported NMRP global (an addon
--- package does not see nmrp's bare globals, only what NMRP exposes).
local command <const> = NMRP.command; ---@type CommandLib

---@param ctx AppContext
---@return void
return function(ctx)
    local stamina <const> = ctx.services.stamina; ---@type StaminaService

    -- Possession: hand the Character to the service and subscribe its gait changes.
    -- GaitModeChange is [Both Sides]; Characters are spawned server side, so the server has
    -- authority and fires it locally (no client round-trip). The stale Character's
    -- subscription dies with the Character on UnPossess, and on_gait guards on the tracked
    -- char, so no explicit Unsubscribe is needed.
    Player.Subscribe("Possess", function(player, character)
        if (not character:IsA(Character)) then return; end
        stamina.on_spawn(player, character);
        character:Subscribe("GaitModeChange", function(char, _old_state, new_state)
            stamina.on_gait(player, char, new_state);
        end);
    end);

    -- Losing the Character (respawn / vehicle / disconnect): drop the state.
    Player.Subscribe("UnPossess", stamina.on_release);

    -- Authority loop: advances ONLY the draining/regenerating players. A server full of idle
    -- players does no per-player work here.
    Timer.SetInterval(function() stamina.tick_active(); end, stamina.tick_ms);
end
