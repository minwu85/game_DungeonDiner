extends Node2D

func _on_play_pressed() -> void:
	global.reset_player_stats()
	get_tree().change_scene_to_file("res://scn/scences/world.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_setting_pressed() -> void:
	pass # Replace with function body.
