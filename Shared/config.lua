--- config.lua: all character-needs tuning, in one place.
---
--- THIS is the file to edit to balance the survival systems. You do not need to be a
--- developer or read any module code: change the numbers, keep the keys, restart the
--- server. Each sub-table maps to one feature (stamina today; hunger, thirst and alcohol
--- later), and every value has a comment explaining what it does.
---
--- It lives in Shared/ so both the server and the client can read the same numbers, and so
--- any module resolves it with a plain `require 'config.lua'`.

---@class StaminaConfig
---@field max number           full stamina value
---@field drain_per_s number   units lost per second while sprinting
---@field regen_per_s number   units recovered per second at rest
---@field regen_delay_s number delay (s) before regen resumes after a sprint
---@field recover_at number    value at which sprint is re-allowed after exhaustion
---@field tick_ms integer      authority update period (ms)

---@class NeedsConfig
---@field stamina StaminaConfig
return {
    -- Sprint stamina: drains while sprinting, cuts sprint at 0, regenerates at rest.
    stamina = {
        max           = 100,  -- full stamina value
        drain_per_s   = 25,   -- units lost per second while sprinting
        regen_per_s   = 15,   -- units recovered per second at rest
        regen_delay_s = 0.8,  -- delay (seconds) before regen resumes after a sprint
        recover_at    = 20,   -- value at which sprinting is re-allowed after exhaustion
        tick_ms       = 100,  -- authority update period in milliseconds
    },
};
