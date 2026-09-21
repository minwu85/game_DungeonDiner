extends Node2D

@onready var time_light = $cliff_side_light/sun #call light change
@onready var point_light = $cliff_side_light/PointLight2D #call light shine in play/shop
@onready var day_night_timer = $cliff_side_light/day_night #call count down 
@onready var day_text = $CanvasLayer/Day #call day text
@onready var day_anim = $CanvasLayer/AnimationPlayer #call day text anim

func _ready():
	# light control - snap instantly to the current state so the scene
	# never opens with a full-energy "sun" subtracting all the light
	time_light.enabled = true
	point_light.enabled = true
	apply_light_state_instant()

	if day_night_timer:
		day_night_timer.wait_time = global.phase_duration_seconds()
		day_night_timer.start()

	set_day_text()
	day_text_fade()

func _process(delta):
	change_scene()

func _on_cliffside_exitpoint_body_entered(body):
	if body.has_method("player"):
		global.transition_scene = true

func change_scene():
	if global.transition_scene == true:
		if global.current_scene == "cliff_side":
			get_tree().change_scene_to_file("res://scn/scences/world.tscn")
			global.finish_changescenes()
		print("Trying to change from", global.current_scene)

func _on_day_night_timeout() -> void:
	global.toggle_day_night()
	global.apply_light_state(time_light, point_light)
	if global.state_time == global.TimeState.EVENING:
		set_day_text()
		day_text_fade()

## Sets the light energy to match the current state immediately (no tween),
## so entering the scene doesn't flash to full darkness while it eases in.
func apply_light_state_instant():
	match global.state_time:
		global.TimeState.MORNING:
			if time_light:
				time_light.energy = 0.1
				time_light.color = global.DAY_LIGHT_COLOR
			if point_light: point_light.energy = 0
		global.TimeState.EVENING:
			if time_light:
				time_light.energy = 1.0
				time_light.color = global.NIGHT_LIGHT_COLOR
			if point_light: point_light.energy = 1.5

func set_day_text():
	if day_text:
		day_text.text = "Day " + str(global.day_count)

func day_text_fade():
	if day_anim:
		day_anim.play("day_fade_in")
		await get_tree().create_timer(3).timeout
		day_anim.play("day_fade_out")
