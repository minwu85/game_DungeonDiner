extends Node

@onready var pause_menu=$"../CanvasLayer/pausemenu"

var game_pause: bool=false


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("cancel_order"):
		game_pause=!game_pause
		
	if game_pause==true:
		get_tree().paused=true
		pause_menu.show()
	else:
		get_tree().paused=false
		pause_menu.hide()

func _on_resume_pressed() -> void:
	game_pause=!game_pause

func _on_save_pressed() -> void:
	global.save_game()

func _on_quit_pressed() -> void:
	get_tree().paused=false
	global.save_game()
	get_tree().change_scene_to_file("res://scn/menu/start_menu.tscn")


func _on_inventory_pressed() -> void:
	get_tree().paused=false
	get_tree().change_scene_to_file("res://scn/ui/inventory/inventory.tscn")
