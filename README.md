# NMRP Character Needs

A **character-needs addon for [NMRP](https://github.com/No-More-RP/nmrp)**.
It plugs into the NMRP core through its addon SDK and adds survival gauges
to the HUD without touching the core.

Ships today with **stamina** (server-authoritative sprint stamina, replicated to a HUD gauge).
Hunger, thirst and alcohol are on the roadmap, each a new module registered the same way.

## Installation

This is a **script** package (not a game-mode). It runs on top of the `nmrp` game-mode.

1. Place the `nmrp-character-needs` folder in your server's `Packages/` directory.
2. Make sure its dependencies are present in `Packages/` too (declared in
   [`Package.toml`](Package.toml)):

   ```toml
   [script]
       packages_requirements = [
           "nmrp-promise",
           "nmrp-norm",
           "nmrp-rpc",
           "nmrp-locale",
           "nmrp",
       ]
   ```

3. **Register the package in your server's `Config.toml`**. It is not a game-mode, so it goes
   in the `packages` list of the `[game]` section (next to `game_mode = "nmrp"`), NOT in
   `game_mode`:

   ```toml
   [game]
       game_mode = "nmrp"
       packages = [
           "nmrp-character-needs",
       ]
   ```

4. Start (or restart) the server. The addon loads after the NMRP core and registers itself.

## How it works

The addon uses the **NMRP addon SDK** exposed through the `NMRP` global (published by the core
via `Package.Export`). Each realm's `Index.lua` registers its modules once the core is ready:

```lua
-- Server/Index.lua and Client/Index.lua
NMRP.register(require 'modules/stamina/stamina.module.lua');
```

`NMRP.register` waits for the core to finish booting (schema synced on the server, local player
resolved on the client), then wires the module into the core loader. An addon module is the
same descriptor the core uses (`{ name, depends?, models?, service?, controller? }`), so it can
`depends` on core modules (`"player"`, `"hud"`, ...) and reach them through `ctx.services`.

| Module | Realm | Role |
|---|---|---|
| `stamina` | Server | Authoritative sprint stamina: drains while sprinting, cuts sprint at 0, regenerates at rest. Replicates a motion segment `{ value, rate, delay }` to the owning client only on a transition. |
| `stamina` | Client | Registers a `stamina` gauge on the core HUD (`ctx.services.hud.register_gauge`) and feeds it the segments, which the HUD interpolates locally. |

The stamina gauge is a runtime **HUD gauge**: the core HUD keeps only health permanent and lets
features add/remove bars on the fly, so this addon owns its bar and removes it on unload.

## Configuration

All tuning lives in one file, [`Shared/config.lua`](Shared/config.lua). To balance the
survival systems you edit that file and restart the server, no need to be a developer or to
touch any module code: change the numbers, keep the keys. Each feature has its own sub-table
and every value is commented.

```lua
return {
    stamina = {
        max           = 100,  -- full stamina value
        drain_per_s   = 25,   -- units lost per second while sprinting
        regen_per_s   = 15,   -- units recovered per second at rest
        regen_delay_s = 0.8,  -- delay (s) before regen resumes after a sprint
        recover_at    = 20,   -- value at which sprinting is re-allowed after exhaustion
        tick_ms       = 100,  -- authority update period (ms)
    },
};
```

> Why a file and not the New Game menu? nanos' `[custom_settings]` (the menu form) is only
> read for the **game-mode** package; a **script** package like this one cannot expose them.
> A shared config file is the portable way to keep the knobs in one obvious place.

Each module reads its own section at boot (`require 'config.lua'.stamina`), so a new feature
just adds a sub-table here.

## Add a module

Same shape as the NMRP core (see its README):

1. Create `Server/modules/<name>/` and/or `Client/modules/<name>/` with `<name>.module.lua`
   (+ `model` / `service` / `controller` as needed).
2. Write requires **relative to the folder** and type them by hand (paths end with `.lua`).
3. Declare `depends` on the core modules you need (`"player"`, `"hud"`, ...).
4. Add `NMRP.register(require 'modules/<name>/<name>.module.lua');` to the realm's `Index.lua`.

## Conventions

Follows the NMRP conventions: English-only comments, `;`-terminated statements, `<const>` on
every non-reassigned local, parenthesized conditions, full LuaCATS annotations, and an example
on every public function.

## License

MIT © 2026 JustGod.
