extends Panel

## World-space rectangle this minimap covers, in the current scene's
## coordinates. Override per-instance - each scene has a different map.
@export var map_world_origin := Vector2(-30, -20)
@export var map_world_size := Vector2(545, 290)

@onready var player_dot: ColorRect = $PlayerDot

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		player_dot.visible = false
		return
	player_dot.visible = true
	var relative: Vector2 = (player.global_position - map_world_origin) / map_world_size
	relative.x = clamp(relative.x, 0.0, 1.0)
	relative.y = clamp(relative.y, 0.0, 1.0)
	player_dot.position = relative * size - player_dot.size / 2.0
