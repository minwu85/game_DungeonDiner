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



enum TimeState {
	MORNING,
	EVENING
}

var state_time = TimeState.MORNING
var day_count: int = 1


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

func apply_light_state(time_light: Light2D, point_light: Light2D = null):
	var tween = get_tree().create_tween()
	var tween1 = get_tree().create_tween()
	match state_time:
		TimeState.MORNING:
			if time_light: tween.tween_property(time_light, "energy", 0.1, 1.5)
			if point_light: tween1.tween_property(point_light, "energy", 0, 1.5)
		TimeState.EVENING:
			if time_light: tween.tween_property(time_light, "energy", 1.0, 1.5)
			if point_light: tween1.tween_property(point_light, "energy", 1.5, 1.5)
