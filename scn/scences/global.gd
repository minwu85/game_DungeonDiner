extends Node


var player_current_attack = false
var player_current_slice = false
var current_scene = "world"
var transition_scene = false

var player_exit_cliffside_posx = 430
var player_exit_cliffside_posy = 180
var player_start_posx = 80
var player_start_posy = 60

var game_first_loadin = true

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



enum TimeState {
	MORNING,
	EVENING
}

var state_time = TimeState.MORNING
var day_count: int = 1

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


func finish_changescenes():
	if transition_scene==true:
		transition_scene=false
		if current_scene=="world":
			current_scene="cliff_side"
		else:
			current_scene="world"


func toggle_day_night():
	state_time = TimeState.EVENING if state_time == TimeState.MORNING else TimeState.MORNING
	if state_time == TimeState.EVENING:
		day_count += 1

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
