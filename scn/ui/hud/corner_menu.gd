extends Control

@onready var instructions_panel = $InstructionsPanel

func _ready() -> void:
	instructions_panel.visible = false

func _on_home_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scn/menu/start_menu.tscn")

func _on_instruction_pressed() -> void:
	instructions_panel.visible = not instructions_panel.visible

func _on_close_pressed() -> void:
	instructions_panel.visible = false
