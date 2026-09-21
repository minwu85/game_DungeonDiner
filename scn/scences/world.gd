extends Node2D

@onready var time_light = $light/sun #call light change
@onready var day_night_timer = $light/day_night #call count down
@onready var day_text=$CanvasLayer/Day #call day text
@onready var day_anim=$CanvasLayer/AnimDay #call day text anim
@onready var player=$player/player #call player

func _ready():

	##player position
	if global.game_first_loadin == true:#player first position set
		$player/player.position.x = global.player_start_posx
		$player/player.position.y = global.player_start_posy
	else:#returning from another area - spawn near that area's door
		match global.returning_from:
			"forest":
				$player/player.position.x = global.player_exit_forest_posx
				$player/player.position.y = global.player_exit_forest_posy
			"cliff":
				$player/player.position.x = global.player_exit_cliff_posx
				$player/player.position.y = global.player_exit_cliff_posy
			_: # "cliff_side" (shop) or unset
				$player/player.position.x = global.player_exit_cliffside_posx
				$player/player.position.y = global.player_exit_cliffside_posy

	##light change control
	if day_night_timer:
		day_night_timer.wait_time = global.phase_duration_seconds()
		day_night_timer.start()
	global.apply_light_state(time_light)
	set_day_ui()

func _on_day_night_timeout() -> void:
	global.toggle_day_night()
	global.apply_light_state(time_light)
	if global.state_time == global.TimeState.EVENING:
		set_day_ui()

func _process(delta):
	global.perform_pending_transition()

func _on_cliffside_transition_point_body_entered(body):
	if body.has_method("player"):
		global.request_scene_transition("res://scn/scences/cliff_side.tscn", "cliff_side")

func _on_forest_transition_point_body_entered(body):
	if body.has_method("player"):
		global.request_scene_transition("res://scn/scences/forest.tscn", "forest")

func _on_cliff_transition_point_body_entered(body):
	if body.has_method("player"):
		global.request_scene_transition("res://scn/scences/cliff.tscn", "cliff")

func set_day_ui():
	day_text.text = "Day " + str(global.day_count)
	day_anim.play("day_fade_in")
	await get_tree().create_timer(3).timeout
	day_anim.play("day_fade_out")
