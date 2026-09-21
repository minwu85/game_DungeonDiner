extends Node2D

var item_name := "Wooden Sword"

# Called by inventory/pickup code to turn this generic item node into a
# specific item. Leaves the scene's default icon/name if never called.
func setup(name: String, icon: Texture2D) -> void:
	item_name = name
	$TextureReact.texture = icon
