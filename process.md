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

## 6. Session 2 — configurable day length, sunset colors, Home/Help HUD

### 6.1 "5 minutes is a day"
`global.gd` now exposes `day_length_minutes` (default `5.0`) and `phase_duration_seconds()` (half of that, in seconds — one call is one phase, either the day half or the night half). Both `world.gd` and `cliff_side.gd` set their `day_night` Timer's `wait_time` from this at `_ready()`, instead of the scene file's hardcoded value, so both scenes always agree and are tunable from one place. With the default, a full day→night→day cycle takes 5 real minutes, and `global.day_count` (and the "Day N" label) advances by one every time night falls (every 2.5 minutes).

### 6.2 Sunset/sunrise color, not just brightness
Previously the day/night transition only tweened `DirectionalLight2D.energy` (brightness). `global.apply_light_state()` now also tweens the light's `color` through a sunset/sunrise hue partway through each transition, over the full phase duration (so it's a slow, continuous shift rather than a snap). Because the "sun" light uses **Subtract** blend mode, the colors are chosen for what they *remove*, not what they add: `SUNSET_LIGHT_COLOR` (cool/cyan) leaves a warm orange glow behind when subtracted, and `NIGHT_LIGHT_COLOR` (warm/gold) leaves a cool blue tint behind — see the comment above the constants in `global.gd`. This is a reasonable, standard trick for subtractive 2D lighting but wasn't visually verified in the editor (no Godot CLI available in this environment) — if the hues look off, the three `*_LIGHT_COLOR` constants at the top of `global.gd` are the only place to tune.

### 6.3 Home / Help buttons (top-right)
Added `scn/ui/hud/corner_menu.tscn` (+ `corner_menu.gd`): a small always-on-screen `Control` with a **Home** button (returns to the start menu, same as the pause menu's Quit) and a **Help** button (toggles an instructions panel listing controls: WASD/arrows to move, Shift to run, Space to attack, J to slice, X to pause). It's instanced once into each scene's existing `CanvasLayer` (`world.tscn` and `cliff_side.tscn`), the same way `pausemenu` already was, so it didn't need duplicating into two separate implementations.

### 6.4 Not implemented
The large "Simple RPG Ideas" brainstorm (XP/levels, equipment, quests, cooking, NPCs, save system, new areas, etc.) is a substantial expansion, not a bug fix or small feature — it wasn't implemented in this pass. It's a good roadmap; if you want to start on a piece of it, the recommended first slice from that doc (XP/levels → potions → basic shop buying) is a reasonable place to begin, and it builds directly on the gold/inventory/shop plumbing that already exists.

## 7. Session 3 — overworld night, inventory cleanup, character portrait, XP/levels

### 7.1 Overworld now actually gets dark at night
`world.tscn`'s `light` node had `visible = false` hardcoded, so the day/night tween from Session 1 was running the whole time but never visible outdoors — only the shop interior ever darkened. Removed that flag. The overworld now darkens/lightens on the same cycle as the shop; the player's own `PointLight2D` (`player_light`) still lights their immediate surroundings the way it did in the original "dark" screenshot.

### 7.2 Inventory: removed the random junk-item generator
`slot.gd`'s `_ready()` had a `if randi() % 2 == 0: item = ItemClass.instantiate(); add_child(item)` — every time the inventory screen opened, each of the 16 slots had a *coin-flip* chance of spawning a placeholder item. `item.gd` then *also* randomly picked between `wood_sword.png`/`wood_axe.png` on its own `_ready()`. On top of that, `item.tscn`'s icon (`TextureReact`) had a baked-in `rotation = 0.261799` (15°) and a skewed `10x41` box, so populated slots showed random, tilted, differently-shaped icons every time you opened the screen — that's the screenshot.

Fixed:
- `slot.gd` no longer spawns anything randomly; slots start empty and stay that way until something real is put into them (`put_into_slot`, or the new `spawn_item(name, icon)` helper for a future pickup/shop system to call).
- `item.gd` no longer randomly swaps its own texture; it now has a `setup(name, icon)` method so a real item can be created with a specific icon/name.
- `item.tscn`'s icon box is now a clean, unrotated `24x24` square with `stretch_mode = KEEP_ASPECT_CENTERED`.
- Net effect: the inventory now opens **empty** (there's no real pickup-to-inventory system wired up yet — only gold, which is a separate counter, not an item), which is the honest/correct state rather than showing fake random junk. Wiring real items into it is future work (see the "Item pickup" idea from Session 1's roadmap).

### 7.3 Character portrait
Added a static portrait of the player (`Idle_Down-Sheet.png` frame 0, the same art already used for the player's idle animation) to the empty left two-thirds of the inventory panel (`inventory.tscn`, new `CharacterPortrait` node). It's a plain snapshot, not a live sprite — reusing the player's full animated `SpriteFrames` resource would mean duplicating a very large embedded resource across scene files, which wasn't worth the risk for a portrait.

### 7.4 Player progression (XP & levels)
Implemented the 5-level table from the brainstorm doc, split across `stats.gd` (owns `xp`/`level`/the XP table, emits `leveled_up(new_level)`) and `player.gd` (listens for `leveled_up` to apply the two rewards that aren't pure stats):

| Level | XP required | Reward |
|---|---|---|
| 1 | 0 | starting attributes |
| 2 | 100 | +20 max HP (also fully heals) |
| 3 | 250 | +5 attack damage (`attack_basic`) |
| 4 | 450 | +20 max stamina |
| 5 | 700 | slice attack multiplier goes from 2x to 3x |

- Enemies award XP on death (`enemy.gd` now has `@export var xp_reward: int = 20`); the player exposes `gain_xp(amount)` which forwards to `stats.add_xp()`.
- A small "Lv N" label + XP bar was added to `stats.tscn` next to the gold counter.
- **Bugs fixed along the way, found while wiring this up:**
  - `enemy.gd`'s `_ready()` connected a signal called `"player_attack"` on the player that never existed (player.gd has no such signal) — this errored on every enemy spawn and did nothing. Removed; actual attack damage was already being dealt correctly elsewhere, via the `global.player_current_attack`/`player_current_slice` flags checked in `enemy.gd`'s `_physics_process`.
  - `player.gd`'s `_on_player_hitbox_body_entered` emitted a signal called `"attack"` that was never declared — errored on every hitbox overlap, and nothing listened to it anyway. Removed.
  - `enemy.gd`'s `_physics_process` had `if not alive: death_state()`, but `death_state()` is the *only* place that sets `alive = false` and it `await`s an animation before `queue_free()`-ing — so once an enemy died, this line would re-invoke `death_state()` (and, now, re-award XP) on every physics frame until the animation finished. Removed the redundant call; `death_state()` is already triggered exactly once via `enemy_health`'s `on_death` signal.
  - Slice damage wasn't actually using the slice multiplier: `slice_state()` set `attack_multiplier` but the shared `attack_current` it read from was being unconditionally reset back to base by `attack()`, which runs every physics frame — including the frames spent `await`ing the slice animation. Slice damage is now computed into a local variable at the moment the slice starts, so it isn't clobbered, and so the level-5 reward (2x → 3x) actually does something.

## 8. Session 4 — combined HUD, minimap, fade-in, inventory back button, shop buying

The mockups in this session (a combined stat panel, an empty-slot inventory with a portrait, and a "Character:" prompt near the shop) were wireframes for direction, not screenshots of a running state — treated as a spec to build toward, not a bug report.

### 8.1 Combined HUD panel
`stats.tscn` previously had the health bar, stamina bar, gold counter and XP bar floating independently in the top-left corner. Added a `Background` `Panel` behind all of them and a `CharacterPortrait` (same idle-sprite-frame technique as the inventory portrait) on the left, with the four stat elements shifted right to sit beside it — one grouped panel instead of four loose widgets, matching the mockup's composition. It reuses the project's default UI theme for the background rather than a custom nine-patch border texture, since guessing patch margins on an unfamiliar texture blind (no way to preview here) risked looking worse than the plain version.

### 8.2 Minimap
Added `scn/ui/hud/minimap.tscn` (+ `minimap.gd`): a `SubViewportContainer`/`SubViewport`/`Camera2D` that shares the main game's `World2D` (`sub_viewport.world_2d = get_tree().root.world_2d`), so its camera renders the *actual* live tilemap/player/enemies rather than a duplicate or a static image — the player shows up on it automatically, with no separate "player dot" needed. Positioned top-right in both `world.tscn` and `cliff_side.tscn`'s `CanvasLayer`, left of the Home/Help buttons. `map_center` and `map_zoom` are `@export`ed on the script (defaults `(235, 120)` and `4.5`, estimated from both maps' collision-polygon bounds, which are both roughly 520-540px wide) — this is the one piece in this session most likely to need a quick in-editor nudge, since camera framing can't be checked without running Godot.

### 8.3 Dark-to-light entry fade
Added `scn/ui/hud/scene_fade.tscn` (+ `scene_fade.gd`): a fullscreen black `ColorRect` that tweens its alpha to 0 over 1 second on `_ready()`, then hides itself. Instanced as the *last* child of `CanvasLayer` in both `world.tscn` and `cliff_side.tscn` (so it draws on top of everything else during the fade). Every scene entry now fades in from black, not just the overworld specifically — added to both scenes for consistency rather than singling one out, since the underlying mechanism is identical either way.

### 8.4 Inventory back button
`inventory.tscn` had no way to leave — opening it (from the pause menu) calls `change_scene_to_file`, which fully replaces whatever scene was running, and nothing sent the player back. Added a `BackButton` + `inventory.gd:_on_back_pressed()`, which returns to `cliff_side.tscn` or `world.tscn` based on `global.current_scene`. This was a real dead-end bug, not just a missing nicety.

### 8.5 Shop dialogue + buying a Wooden Sword
- `shop.tscn`'s `Area2D` had a collision shape but no script — added `shop.gd`, emitting `player_entered`/`player_exited` when the player walks in/out of it (same `body.has_method("player")` pattern used elsewhere in the project).
- `cliff_side.gd` listens for those and shows a "Press Z to shop" prompt (`Z` = the existing `confirm_order` action) when in range; pressing it opens a `ShopPanel` ("Character: Shopkeeper" + a Wooden Sword row: icon, name, "1 Gold", **Buy**) with a **Close** button.
- Buying checks `player.gold`, and on success deducts 1 gold and calls a new `global.add_inventory_item(name, icon_path)`.
- **Why a new `global.inventory_items` array**: the inventory screen's 16 `slot` nodes are local to `inventory.tscn`, which — per §8.4 — gets fully torn down and replaced on every scene change; there was nothing for a purchased item to persist *into*. `global` (an autoload) is the one thing that survives scene changes, so it now holds the source-of-truth item list (`{"name", "icon"}` dicts, capped at 16), and `inventory.gd`'s `_ready()` populates its slots from it via the `slot.spawn_item()` helper added in Session 3. Rearranging items within the inventory UI (drag between slots) still doesn't write back to `global.inventory_items` — only acquiring items does — which is an acceptable gap for a first version but worth knowing if slot order ever needs to persist.

### 8.6 Overworld night (recap from user's request, same fix already in §7.1)
Confirmed still in place — not re-done, just flagged in case it needed re-verifying alongside this session's other lighting-adjacent HUD work: it didn't need changes.
