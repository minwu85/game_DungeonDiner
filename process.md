# DungeonDiner — Process Log

Godot 4.7 (Forward+) 2D top-down action/collector game. Autoloads: `global` (`scn/scences/global.gd`), `signals` (`scn/player/signals.gd`). This document records what the project currently does, what was found while auditing it, and what changed in this pass.

## 1. Current feature set

**Movement & combat** ([player.gd](scn/player/player.gd))
- 8-direction walk, with a `run` action that costs stamina and doubles speed.
- Two attack types: a basic `attack` (hitbox `Collision_Attack`) and a `slice` (hitbox `Collision_Slice`, 2x damage, used via `attack_multiplier`).
- Health/stamina live in a `stats` sub-scene attached to the player (`scn/player/stats.tscn`), so they persist and render the same way across scene changes.
- Death plays a directional death animation, frees the player, and returns to the start menu.

**Enemy AI** ([enemy.gd](scn/enemy/enemy.gd), [enemy_health.gd](scn/enemy/enemy_health.gd))
- Simple state machine: idle → chase (on player detection) → attack/recover → dead.
- Separate `enemy_health` node owns HP, a floating damage-number label, and a hidden-until-hit health bar.
- Player deals damage while `global.player_current_attack`/`player_current_slice` is true and the enemy is in range; enemy deals damage back via its own hitbox/cooldown timer.

**Collectibles** ([gold.gd](scn/collectribles/gold.gd), [gold.tscn](scn/collectribles/gold.tscn))
- Animated coin pickup (5-frame sprite sheet). On pickup: plays the player's collect animation, tweens the coin up and fades it out, then increments `player.gold`.

**World / scenes**
- `world.tscn`: outdoor overworld with a tilemap, one enemy, one gold pickup, a transition trigger to the shop (`cliff_side.tscn`), and a day/night light rig.
- `cliff_side.tscn`: the shop area, with its own tilemap, its own day/night light rig, and a `shop` scene instance.
- Scene transitions are driven by `Area2D` triggers + `global.transition_scene`/`global.current_scene`, and the player's spawn position is restored from `global.player_exit_cliffside_posx/posy` or `global.player_start_posx/posy`.

**Day/night cycle** ([global.gd](scn/scences/global.gd), [world.gd](scn/scences/world.gd), [cliff_side.gd](scn/scences/cliff_side.gd))
- A `Timer` per scene flips between `MORNING`/`EVENING` and tweens a `DirectionalLight2D` ("sun", subtract blend) plus (in the shop) a `PointLight2D` for warm lantern light.
- A "Day N" label fades in/out on each transition into evening.

**UI**
- `stats.tscn` (always active, attached to the player): health bar + stamina/"energy" bar, **and now a gold counter beneath the energy bar** (see §3).
- `pausemenu.tscn`: Resume / Inventory / Quit, opened with `cancel_order`.
- `inventory.tscn`: a separate full-scene screen reached from the pause menu.

**Menus**: `start_menu.tscn` (Play/Settings/Quit — Settings is a stub).

## 2. Architecture notes / how things fit together

- `global` is the single source of truth for cross-scene state: current scene name, whether a transition is pending, spawn coordinates, and the day/night `state_time` + `day_count`. Each scene script (`world.gd`, `cliff_side.gd`) owns its *own* `Light2D` references but calls into `global.apply_light_state()` to actually animate them, so the tweening logic isn't duplicated per scene.
- The player's `stats` node is a `CanvasLayer` that is part of the player scene (not the world scene), which is why health/stamina survive scene changes — worth keeping in mind before adding more persistent UI (put it in `stats.tscn`, not in `world.tscn`/`cliff_side.tscn`'s own `CanvasLayer`).
- Each world scene *also* has its own `CanvasLayer` (for the "Day N" label + pause menu). That layer used to also contain leftover, invisible `HP`/`Gold` debug labels — removed, see §3.

## 3. Issues found and fixed this pass

### 3.1 Day/night timer crash in the overworld (functional bug)
`world.tscn` connects `light/day_night`'s `timeout` signal to `_on_day_night_timeout`, but [world.gd](scn/scences/world.gd) never defined that method — every 30s the timer would fire and Godot would throw an "Invalid call, nonexistent function" error, and the overworld's day/night state would never actually advance past the initial morning. Added `_on_day_night_timeout()` to `world.gd`, mirroring `cliff_side.gd`, so both scenes toggle `global.state_time`, re-apply the light tween, and refresh the day text on nightfall.

### 3.2 Why the shop opened almost pitch black (the screenshot)
This was two compounding bugs in `cliff_side.gd`/`cliff_side.tscn`:
1. The "sun" `DirectionalLight2D` uses **blend mode = Subtract**, so it darkens everything it covers. Its `energy` had no explicit value in the scene file, so it defaulted to **1.0** (full subtract = near-black) the instant `_ready()` set `enabled = true`.
2. `set_light_state()` then tried to *tween* that down to `0.1` — but over **20 seconds**. So on every shop entry the screen flashed to full darkness and only gradually brightened over the next 20 seconds, which is what the second screenshot shows (mid-fade, well before the light had recovered).

Fix:
- Gave the `sun` node an explicit `energy = 0.1` baseline in both `cliff_side.tscn` and `world.tscn` (matching the default `MORNING` state), so there's no full-energy frame before any script runs.
- Replaced the ad-hoc tween-on-`_ready()` with an instant snap-to-current-state (`apply_light_state_instant()`) on scene load; tweens are now only used for actual morning↔evening *transitions*, reusing `global.apply_light_state()` (previously only `world.gd` used it — `cliff_side.gd` had its own copy-pasted, slower version).
- This also fixed the transition duration inconsistency (world used 1.5s, the shop used 20s) — both scenes now animate at the same 1.5s pace.

### 3.3 Duplicate/dead UI (contributed to visual confusion)
`cliff_side.tscn` had a **second, static** `HealthBar` (`value = 50`, never updated by any script) sitting at the exact same offsets as the player's real, live health bar from `stats.tscn`. Depending on draw order this could show a stale half-full bar under/over the real one. Removed the dead duplicate.

Both `world.tscn` and `cliff_side.tscn` also carried invisible, unused `HP`/`Gold` debug `Label`s with inline scripts hardcoded to `get_node("/root/world/player/player")` — a path that's simply wrong in `cliff_side` (its root node is `cliff_side`, not `world`), so they were dead code even when visible was flipped on. Removed both labels and their inline scripts from both scenes.

`global.gd` also carried a `day_ui()` helper wired to `get_node_or_null("/root/Main/CanvasLayer/Day")` — `Main` doesn't exist anywhere in this project, so it always silently no-op'd (printed a warning). Removed; each scene already has its own working day-text logic.

### 3.4 Coin system added below the energy bar
`player.gold` was tracked (incremented by `gold.gd` on pickup) but never displayed anywhere live — the only place that read it was a dead debug label (§3.3). Added a small coin-icon + count `HBoxContainer` (`GoldDisplay`) to `stats.tscn`, directly beneath the stamina/"energy" bar, reusing the existing coin sprite (`art/art2/MonedaD.png`, first frame). `player.gd`'s `gold` is now a property with a setter that pushes the new value into `stats.set_gold()`, so the counter updates automatically the instant a coin is collected — no changes needed in `gold.gd`.

## 4. Known issues not fixed here (need editor/art work, not just code)

- **Shop entrance tile seam**: the dirt path tile in front of the shop in `cliff_side.tscn` ends abruptly against the grass with a hard, small, diamond-shaped edge instead of blending in. The tilemap data is stored as an opaque `PackedByteArray` in the `.tscn`; hand-editing that blind (without the Godot tile-painting UI) is a good way to silently corrupt the map, so this needs a pass in the editor's TileMap panel (repaint the path/grass terrain transition, or extend the path tiles) rather than a scripted fix.
- **Pause menu → Inventory replaces the whole scene** (`manager.gd`'s `_on_inventory_pressed` calls `change_scene_to_file`), so opening the inventory unloads the current world/shop scene entirely instead of overlaying it. Works, but means "Resume" from inventory has to re-enter through the pause flow rather than just closing an overlay — worth revisiting if inventory is meant to be a lightweight popup.
- **Day count increments at nightfall, not at morning** (`global.toggle_day_night()`): "Day 2" appears the moment evening starts, before a new morning has actually begun. Semantically may want to flip so `day_count` increments on the morning transition instead.
- **Settings button on the start menu is a stub** (`start_menu.gd:_on_setting_pressed`).
- Overworld (`world.tscn`) keeps its light rig invisible (`light.visible = false`) permanently, so the day/night cycle only ever visibly affects the shop interior — the overworld itself never actually darkens. May be intentional (open field vs. indoor shop), but worth confirming as a design decision.

## 5. Ideas / suggestions (not implemented)

- Persist `gold`/inventory across a save file (currently resets on every run since nothing is saved).
- Give the coin counter a small "+1" pop/tween when gold increases, matching the coin pickup's own tween polish.
- Move the magic numbers in `player.gd`/`enemy.gd` (attack ranges, damage, costs) into `@export` vars so they're tunable from the inspector instead of buried in code.
- The `PlayerState`/`enemy.PlayerState` enums are declared but largely unused (most state is tracked with loose booleans instead) — either wire the state machine through them or drop the enums to reduce confusion.
- Add a shadow/occlusion pass (`LightOccluder2D` already exists on the player) to the shop's walls so the point light actually casts shop-shaped shadows, since `shadow_enabled = true` is already set on the shop's sun light.
- Consider unifying `world.gd` and `cliff_side.gd` further — after this pass they already share `global.apply_light_state`/`toggle_day_night`; the remaining per-scene code (spawn positioning, transition triggers) is genuinely scene-specific and probably not worth merging further.
