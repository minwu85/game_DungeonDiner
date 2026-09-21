extends ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0, 0, 0, 1)
	var tween = create_tween()
	tween.tween_property(self, "color:a", 0.0, 1.0)
	tween.tween_callback(func(): visible = false)
