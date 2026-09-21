extends SubViewportContainer

## World-space point the minimap camera is centered on. Both the overworld
## and the shop map are roughly this size, so one default works for both -
## override per-instance if a scene's map is laid out very differently.
@export var map_center := Vector2(235, 120)

## How zoomed-out the minimap is. Camera2D.zoom > 1 shows MORE of the world.
## Roughly: map_pixel_width / minimap_pixel_width.
@export var map_zoom := 4.5

@onready var sub_viewport: SubViewport = $SubViewport
@onready var camera: Camera2D = $SubViewport/Camera2D

func _ready() -> void:
	# Share the main game's 2D world so the minimap's camera renders the
	# real tilemap/player/enemies instead of an empty viewport.
	sub_viewport.world_2d = get_tree().root.world_2d
	camera.position = map_center
	camera.zoom = Vector2(map_zoom, map_zoom)
	camera.make_current()
