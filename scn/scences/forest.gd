extends Node2D

func _ready():
	if global.game_first_loadin:
		$player/player.position.x = global.player_start_posx
		$player/player.position.y = global.player_start_posy
	else:
		$player/player.position.x = 350
		$player/player.position.y = 150

func _process(delta):
	global.perform_pending_transition()

func _on_world_transition_point_body_entered(body):
	if body.has_method("player"):
		global.request_scene_transition("res://scn/scences/world.tscn", "world", "forest")
