extends Node


var player_current_attack = false
var player_current_slice = false
var current_scene = "world"
var game_first_loadin = true

# --- Scene transitions -------------------------------------------------
# Generalized so any scene can hand off to any other scene (used to be a
# single world<->cliff_side toggle, which stopped working once forest/cliff
# were added). A transition trigger calls request_scene_transition(), and
# the current scene's _process() calls perform_pending_transition() once
# per frame to actually load it.
var transition_scene = false
var next_scene_path := ""
var next_scene_name := ""
var returning_from := "" # which scene we're coming back FROM, for spawn placement

func request_scene_transition(scene_path: String, scene_name: String, return_marker: String = "") -> void:
	transition_scene = true
	next_scene_path = scene_path
	next_scene_name = scene_name
	if return_marker != "":
		returning_from = return_marker

func perform_pending_transition() -> void:
	if transition_scene:
		transition_scene = false
		current_scene = next_scene_name
		game_first_loadin = false
		save_game()
		get_tree().change_scene_to_file(next_scene_path)

# Where the player reappears in world.tscn depending on which area they
# just left (each is just inside that area's transition point back to world).
var player_start_posx = 80
var player_start_posy = 60
var player_exit_cliffside_posx = 430
var player_exit_cliffside_posy = 180
var player_exit_forest_posx = 5
var player_exit_forest_posy = 120
var player_exit_cliff_posx = 240
var player_exit_cliff_posy = 10

## Minimal persistent inventory (survives scene changes, unlike the
## inventory screen's own slot nodes). Each entry is {"name": String, "icon": res:// path}.
var inventory_items: Array = []
const INVENTORY_CAPACITY := 16

## Adds an item if there's room. Returns false (and adds nothing) if the
## inventory is full.
func add_inventory_item(item_name: String, icon_path: String) -> bool:
	if inventory_items.size() >= INVENTORY_CAPACITY:
		return false
	inventory_items.append({"name": item_name, "icon": icon_path})
	return true

# --- Player stats persisted across scene changes ------------------------
# The player (and its "stats" child) get fully destroyed and recreated on
# every scene change, so anything that should survive a trip to the shop/
# forest/cliff and back has to live here instead, and get pulled back into
# the fresh player/stats nodes on _ready().
var gold: int = 0
var player_health: int = 100
var max_player_health: int = 100
var stamina: float = 100.0
var max_stamina: float = 100.0
var xp: int = 0
var level: int = 1

const DEFAULT_MAX_HEALTH := 100
const DEFAULT_MAX_STAMINA := 100.0

## Called when starting a fresh game (not a scene transition within a
## playthrough) so a new run doesn't inherit the previous run's gold/death.
func reset_player_stats() -> void:
	gold = 0
	max_player_health = DEFAULT_MAX_HEALTH
	player_health = DEFAULT_MAX_HEALTH
	max_stamina = DEFAULT_MAX_STAMINA
	stamina = DEFAULT_MAX_STAMINA
	xp = 0
	level = 1
	inventory_items.clear()
	game_first_loadin = true
	state_time = TimeState.MORNING
	day_count = 1
	phase_elapsed = 0.0

# --- Save file ------------------------------------------------------------
# A simple JSON dump of everything above. Autosaved on every scene
# transition and on quitting to the menu; loaded (instead of a fresh
# reset_player_stats()) when the start menu's Play button finds one.
const SAVE_PATH := "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var data := {
		"gold": gold,
		"max_player_health": max_player_health,
		"player_health": player_health,
		"max_stamina": max_stamina,
		"stamina": stamina,
		"xp": xp,
		"level": level,
		"inventory_items": inventory_items,
		"day_count": day_count,
		"state_time": state_time,
		"phase_elapsed": phase_elapsed,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

## Returns true if a save was found and loaded.
func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	gold = parsed.get("gold", 0)
	max_player_health = parsed.get("max_player_health", DEFAULT_MAX_HEALTH)
	player_health = parsed.get("player_health", DEFAULT_MAX_HEALTH)
	max_stamina = parsed.get("max_stamina", DEFAULT_MAX_STAMINA)
	stamina = parsed.get("stamina", DEFAULT_MAX_STAMINA)
	xp = parsed.get("xp", 0)
	level = parsed.get("level", 1)
	inventory_items = parsed.get("inventory_items", [])
	day_count = parsed.get("day_count", 1)
	state_time = parsed.get("state_time", TimeState.MORNING)
	phase_elapsed = parsed.get("phase_elapsed", 0.0)
	game_first_loadin = true
	return true


enum TimeState {
	MORNING,
	EVENING
}

var state_time = TimeState.MORNING
var day_count: int = 1

## Seconds elapsed in the current day/night phase - drives the HUD time
## bar. Reset whenever the phase flips.
var phase_elapsed: float = 0.0

## Real-world length of one full day+night cycle. "5 minutes is a day" ->
## the timer that flips MORNING/EVENING fires every half of this.
var day_length_minutes: float = 5.0

## Length of a single phase (day OR night), in seconds - use this as the
## day_night Timer's wait_time so a full cycle takes day_length_minutes.
func phase_duration_seconds() -> float:
	return (day_length_minutes * 60.0) / 2.0

# Colors are for a Light2D in SUBTRACT blend mode, so they're what gets
# *removed* from the scene, not what gets added. Subtracting a cool/cyan
# tint leaves a warm sunset glow behind; subtracting a warm/gold tint
# leaves a cool blue night behind.
const DAY_LIGHT_COLOR := Color(1, 1, 1)
const SUNSET_LIGHT_COLOR := Color(0.25, 0.55, 0.65)
const NIGHT_LIGHT_COLOR := Color(0.85, 0.7, 0.3)

func toggle_day_night():
	state_time = TimeState.EVENING if state_time == TimeState.MORNING else TimeState.MORNING
	if state_time == TimeState.EVENING:
		day_count += 1
	phase_elapsed = 0.0

## Tweens a scene's light(s) from their current state to the current
## state_time over one full phase (so the "sunset"/"sunrise" color shift
## plays out gradually across the whole day or night, not instantly).
func apply_light_state(time_light: Light2D, point_light: Light2D = null):
	var duration = phase_duration_seconds()
	var half = duration / 2.0
	var energy_tween = get_tree().create_tween()
	var point_tween = get_tree().create_tween()
	var color_tween = get_tree().create_tween()
	match state_time:
		TimeState.MORNING: # night -> sunrise -> day
			if time_light:
				energy_tween.tween_property(time_light, "energy", 0.1, duration)
				color_tween.tween_property(time_light, "color", SUNSET_LIGHT_COLOR, half)
				color_tween.tween_property(time_light, "color", DAY_LIGHT_COLOR, half)
			if point_light:
				point_tween.tween_property(point_light, "energy", 0, duration)
		TimeState.EVENING: # day -> sunset -> night
			if time_light:
				energy_tween.tween_property(time_light, "energy", 1.0, duration)
				color_tween.tween_property(time_light, "color", SUNSET_LIGHT_COLOR, half)
				color_tween.tween_property(time_light, "color", NIGHT_LIGHT_COLOR, half)
			if point_light:
				point_tween.tween_property(point_light, "energy", 1.5, duration)
