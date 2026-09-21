extends Node2D

const SlotClass = preload("res://scn/ui/inventory/slot.gd")

@onready var inventory_slots = $GridContainer
var holding_item: Node2D = null

func _ready():
	var slots = inventory_slots.get_children()
	for i in range(min(slots.size(), global.inventory_items.size())):
		var data = global.inventory_items[i]
		slots[i].spawn_item(data["name"], load(data["icon"]))
	for inv_slot in slots:
		inv_slot.gui_input.connect(slot_gui_input.bind(inv_slot))

func _on_back_pressed() -> void:
	get_tree().paused = false
	match global.current_scene:
		"cliff_side":
			get_tree().change_scene_to_file("res://scn/scences/cliff_side.tscn")
		"forest":
			get_tree().change_scene_to_file("res://scn/scences/forest.tscn")
		"cliff":
			get_tree().change_scene_to_file("res://scn/scences/cliff.tscn")
		_:
			get_tree().change_scene_to_file("res://scn/scences/world.tscn")

func slot_gui_input(event: InputEvent, slot: SlotClass):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if holding_item != null:
			# We're holding an item, try to place it into a slot
			if slot.item == null:
				# Drop into empty slot
				if holding_item.get_parent():
					holding_item.get_parent().remove_child(holding_item)
				slot.put_into_slot(holding_item)
				holding_item = null
			else:
				# Swap items
				var temp = slot.pick_from_slot()
				if holding_item.get_parent():
					holding_item.get_parent().remove_child(holding_item)
				slot.put_into_slot(holding_item)
				add_child(temp)  # Hold the old item now
				holding_item = temp
		elif slot.item:
			# Pick up item from slot
			holding_item = slot.pick_from_slot()
			add_child(holding_item)  # Make it follow the mouse
			holding_item.global_position = get_global_mouse_position()

func _input(event):
	if holding_item:
		holding_item.global_position = get_global_mouse_position()
