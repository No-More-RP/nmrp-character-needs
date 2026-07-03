--- stamina.service.lua: (S) server-authoritative stamina, closure-factory style.
---
--- Character:SetCanSprint / SetGaitMode are [Server Side]: the client cannot block
--- sprinting on its own. So all the logic lives here, and the value is replicated to
--- the owning client for the HUD (event "stamina:update").
---
---   - Drains while the Character sprints (GaitMode.Sprinting), regenerates otherwise.
---   - At 0: cuts sprint (SetCanSprint(false)) and forces walking immediately.
---   - Re-allows sprint above a threshold (hysteresis) to avoid re-sprinting for a
---     single frame at 1%.
---
--- EVENT-DRIVEN + ANALYTICAL replication.
---   1. An "active" set holds only the players currently draining or regenerating.
---      A player standing still at full stamina costs zero (no tick, no engine call).
---   2. The server does NOT stream a value every tick. It sends a SEGMENT
---      { value, rate, delay } only when the drain/regen MODE flips (sprint start,
---      sprint stop, exhaustion). The client interpolates the bar from that segment
---      (value + rate * elapsed, held for `delay`, clamped at [0, max]), so ~2 packets
---      per sprint replace ~10/s and the bar stays smooth at 60fps.
---   The tick still advances the authoritative value (for exhaustion / recovery and the
---   debug read), but it replicates nothing between transitions.
---
--- Transient state (no Norm table): cleared on UnPossess and via player.on_releasing.
---
---@class StaminaState
---@field char Character         the possessed Character (cached; handed to us on Possess)
---@field stamina number         current authoritative value in [0, max]
---@field sprinting boolean      currently in the Sprinting gait
---@field exhausted boolean      sprint cut at 0, waiting for the recovery threshold
---@field cooldown number        seconds left before regen resumes after a sprint
---@field seg_draining boolean   draining state carried by the last segment sent (dedup)
---
---@class StaminaService
---@field on_spawn fun(player: Player, character: Character): void                       init on possession
---@field on_gait fun(player: Player, character: Character, new_state: GaitMode): void    react to a gait change
---@field on_release fun(player: Player): void                                           drop a player's state
---@field tick_active fun(): void                                                        advance every active player
---@field get fun(player: Player): number                                               current stamina (max if unknown)
---@field push fun(player: Player): void                                                 (re)push the current segment (reliable)
---@field tick_ms integer                                                                Timer period (ms) for the controller

--- Build the stamina service.
---
--- ```lua
--- local service <const> = require 'stamina.service.lua' (ctx);
--- ```
---@param ctx AppContext
---@return StaminaService
return function(ctx)
    local players <const> = ctx.services.player; ---@type PlayerService

    local CONFIG <const> = {
        max           = 100,
        drain_per_s   = 25,   -- loss while sprinting
        regen_per_s   = 15,   -- recovery at rest
        regen_delay_s = 0.8,  -- delay before regen after a sprint
        recover_at    = 20,   -- sprint re-allow threshold after exhaustion
        tick_ms       = 100,
    };
    local DT <const> = CONFIG.tick_ms / 1000;

    -- Every tracked player's state (present between Possess and release).
    local states <const> = {}; ---@type table<Player, StaminaState>
    -- The subset currently draining or regenerating: the only players tick_active touches.
    local active <const> = {}; ---@type table<Player, StaminaState>

    local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)); end

    -- Send the current motion SEGMENT to the owning client: the value now, the signed
    -- rate (units/s), and the delay (s) before that rate applies (regen cooldown). The
    -- client interpolates from it, so this is called only on a mode transition or the
    -- handshake reply, never per tick. Records the mode it just described.
    ---@param player Player
    ---@param st StaminaState
    ---@param reliable boolean
    local function send_segment(player, st, reliable)
        local draining <const> = st.sprinting and not st.exhausted;
        local rate, delay; ---@type number, number
        if (draining) then
            rate, delay = -CONFIG.drain_per_s, 0;
        elseif (st.stamina >= CONFIG.max) then
            rate, delay = 0, 0;
        else
            rate, delay = CONFIG.regen_per_s, st.cooldown;
        end
        Events.CallRemote(
            "stamina:update",
            player,
            reliable and Reliability.Reliable or Reliability.Unreliable,
            st.stamina, rate, delay
        );
        st.seg_draining = draining;
    end

    -- One authority step for one ACTIVE player: drain or regen, handle exhaustion and
    -- recovery, and replicate a fresh segment only if the drain/regen mode flipped.
    ---@param player Player
    ---@param st StaminaState
    local function advance(player, st)
        local draining <const> = st.sprinting and not st.exhausted;
        if (draining) then
            st.stamina = clamp(st.stamina - CONFIG.drain_per_s * DT, 0, CONFIG.max);
            st.cooldown = CONFIG.regen_delay_s;
        elseif (st.cooldown > 0) then
            st.cooldown = st.cooldown - DT;
        else
            st.stamina = clamp(st.stamina + CONFIG.regen_per_s * DT, 0, CONFIG.max);
        end

        -- Exhaustion: cut sprint and force walking (fires a GaitModeChange, which clears
        -- st.sprinting through on_gait, keeping the two in sync).
        if (st.stamina <= 0 and not st.exhausted) then
            st.exhausted = true;
            st.char:SetCanSprint(false);
            st.char:SetGaitMode(GaitMode.Walking);
        -- Recovery: re-allow sprint once the threshold is crossed (no visual change, so
        -- no new segment: the client is already regenerating past it).
        elseif (st.exhausted and st.stamina >= CONFIG.recover_at) then
            st.exhausted = false;
            st.char:SetCanSprint(true);
        end

        -- Replicate only on a mode flip (start sprint / stop sprint / exhaustion). Full
        -- needs no send: the client clamps the regen segment at max.
        if ((st.sprinting and not st.exhausted) ~= st.seg_draining) then
            send_segment(player, st, true);
        end
    end

    local service <const> = {}; ---@type StaminaService
    service.tick_ms = CONFIG.tick_ms;

    --- Initialize a player on possession: cache the Character, reset to full, allow
    --- sprint, and push the reliable initial segment. Full and not sprinting is a steady
    --- state, so the player is NOT added to the active set here.
    ---
    --- ```lua
    --- stamina.on_spawn(player, character); -- from Player "Possess"
    --- ```
    ---@param player Player
    ---@param character Character
    function service.on_spawn(player, character)
        local st <const> = {
            char         = character,
            stamina      = CONFIG.max,
            sprinting    = false,
            exhausted    = false,
            cooldown     = 0,
            seg_draining = false,
        }; ---@type StaminaState
        states[player] = st;
        character:SetCanSprint(true);
        send_segment(player, st, true);
    end

    --- React to a Character gait change. Entering Sprinting starts draining and adds
    --- the player to the active set; leaving it lets regen run (the player stays active
    --- until full). The segment itself is sent by the next tick, which holds the fresh
    --- value. Ignores stale events from a Character we no longer track.
    ---
    --- ```lua
    --- stamina.on_gait(player, char, new_state); -- from Character "GaitModeChange"
    --- ```
    ---@param player Player
    ---@param character Character
    ---@param new_state GaitMode
    function service.on_gait(player, character, new_state)
        local st <const> = states[player];
        if (not st or st.char ~= character) then return; end
        st.sprinting = new_state == GaitMode.Sprinting;
        if (st.sprinting) then active[player] = st; end
    end

    --- Advance every draining/regenerating player by one step, then drop from the active
    --- set anyone back to a steady state (full and not sprinting). Driven by the
    --- controller's Timer. Players at rest cost nothing here.
    ---
    --- ```lua
    --- stamina.tick_active(); -- from Timer.SetInterval(..., stamina.tick_ms)
    --- ```
    function service.tick_active()
        for player, st in pairs(active) do
            if (not (st.char and st.char:IsValid())) then
                active[player] = nil;
            else
                advance(player, st);
                if (not st.sprinting and not st.exhausted and st.stamina >= CONFIG.max) then
                    active[player] = nil;
                end
            end
        end
    end

    --- Current stamina (max if the player is not tracked yet).
    ---
    --- ```lua
    --- local value <const> = stamina.get(player); -- 100
    --- ```
    ---@param player Player
    ---@return number
    function service.get(player)
        local st <const> = states[player];
        return st and st.stamina or CONFIG.max;
    end

    --- (Re)push the current segment to the client (e.g. after a manual reset).
    ---
    --- ```lua
    --- stamina.push(player);
    --- ```
    ---@param player Player
    function service.push(player)
        local st <const> = states[player];
        if (st) then send_segment(player, st, true); end
    end

    --- Drop a player's state and remove them from the active set (respawn / UnPossess /
    --- disconnect).
    ---
    --- ```lua
    --- stamina.on_release(player);
    --- ```
    ---@param player Player
    function service.on_release(player)
        states[player] = nil;
        active[player] = nil;
    end

    -- Disconnect cleanup (UnPossess covers respawn / vehicle exit).
    players.on_releasing(function(player) service.on_release(player); end);

    return service;
end
