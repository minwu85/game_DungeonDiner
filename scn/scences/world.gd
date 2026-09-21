extends Node2D

@onready var time_light = $light/sun #call light change
#@onready var point_light = #call light shine in play/shop
@onready var day_night_timer = $light/day_night #call count down 
@onready var day_text=$CanvasLayer/Day #call day text
@onready var day_anim=$CanvasLayer/AnimDay #call day text anim
#@onready var health_bar=$CanvasLayer/HealthBar #call healthbar display 
@onready var player=$player/player #call player

func _ready():

	##player position
	if global.game_first_loadin == true:#player first position set
		$player/player.position.x = global.player_start_posx
		$player/player.position.y = global.player_start_posy
	else:#player position set change after first scence change
		$player/player.position.x = global.player_exit_cliffside_posx
		$player/player.position.y = global.player_exit_cliffside_posy

	##light change control
	if day_night_timer:
		day_night_timer.start()
	global.apply_light_state(time_light)
	set_day_ui()

func _on_day_night_timeout() -> void:
	global.toggle_day_night()
	global.apply_light_state(time_light)
	if global.state_time == global.TimeState.EVENING:
		set_day_ui()

func _process(delta):
	change_scene()#call change scence

func _on_cliffside_transition_point_body_entered(body):
	if body.has_method("player"):
		global.transition_scene = true

func change_scene():#function for scence change 
	if global.transition_scene == true:
		if global.current_scene == "world":
			get_tree().change_scene_to_file("res://scn/scences/cliff_side.tscn")#cliff_side
			global.game_first_loadin = false
			global.finish_changescenes()

func set_day_ui():
	day_text.text = "Day " + str(global.day_count)
	day_anim.play("day_fade_in")
	await get_tree().create_timer(3).timeout
	day_anim.play("day_fade_out")



	
