extends Node2D

@onready var time_light = $cliff_side_light/sun #call light change
@onready var point_light = $cliff_side_light/PointLight2D #call light shine in play/shop
@onready var day_night_timer = $cliff_side_light/day_night #call count down
@onready var day_text = $CanvasLayer/Day #call day text
@onready var day_anim = $CanvasLayer/AnimationPlayer #call day text anim

@onready var shop_area = $shop
@onready var shop_player = $player
@onready var shop_prompt = $CanvasLayer/ShopPrompt
@onready var choice_panel = $CanvasLayer/ChoicePanel
@onready var shop_panel = $CanvasLayer/ShopPanel
@onready var shop_feedback_label = $CanvasLayer/ShopPanel/FeedbackLabel
@onready var dialogue_box = $CanvasLayer/DialogueBox
@onready var dialogue_name_label = $CanvasLayer/DialogueBox/NameLabel
@onready var dialogue_text_label = $CanvasLayer/DialogueBox/TextLabel
@onready var dialogue_next_button = $CanvasLayer/DialogueBox/NextButton

const WOODEN_SWORD_NAME := "Wooden Sword"
const WOODEN_SWORD_ICON := "res://art/Weapons/Wood/wood_sword.png"
const WOODEN_SWORD_PRICE := 1

const SHOPKEEPER_NAME := "Shopkeeper"
const SHOPKEEPER_LINES := [
	"Welcome, traveler! Care to see what I've got?",
	"A wooden sword's sturdy enough for a beginner - only 1 gold.",
	"Come back anytime you need supplies.",
]

var player_near_shop := false
var dialogue_index := 0

func _ready():
	# light control - snap instantly to the current state so the scene
	# never opens with a full-energy "sun" subtracting all the light
	time_light.enabled = true
	point_light.enabled = true
	apply_light_state_instant()

	if day_night_timer:
		day_night_timer.wait_time = global.phase_duration_seconds()
		day_night_timer.start()

	set_day_text()
	day_text_fade()

	shop_area.player_entered.connect(_on_shop_range_entered)
	shop_area.player_exited.connect(_on_shop_range_exited)
	_close_all_panels()

func _process(delta):
	global.perform_pending_transition()
	if player_near_shop and not _any_panel_open() and Input.is_action_just_pressed("confirm_order"):
		_open_choice_panel()

func _any_panel_open() -> bool:
	return choice_panel.visible or shop_panel.visible or dialogue_box.visible

func _close_all_panels() -> void:
	choice_panel.visible = false
	shop_panel.visible = false
	dialogue_box.visible = false

func _show_prompt_if_near() -> void:
	shop_prompt.visible = player_near_shop

func _on_cliffside_exitpoint_body_entered(body):
	if body.has_method("player"):
		global.request_scene_transition("res://scn/scences/world.tscn", "world", "cliff_side")

func _on_shop_range_entered() -> void:
	player_near_shop = true
	shop_prompt.visible = true

func _on_shop_range_exited() -> void:
	player_near_shop = false
	shop_prompt.visible = false
	_close_all_panels()

func _open_choice_panel() -> void:
	shop_prompt.visible = false
	choice_panel.visible = true

func _on_choice_talk_pressed() -> void:
	choice_panel.visible = false
	dialogue_index = 0
	_show_dialogue_line()
	dialogue_box.visible = true

func _on_choice_buy_pressed() -> void:
	choice_panel.visible = false
	shop_feedback_label.text = ""
	shop_panel.visible = true

func _on_choice_cancel_pressed() -> void:
	choice_panel.visible = false
	_show_prompt_if_near()

func _show_dialogue_line() -> void:
	dialogue_name_label.text = SHOPKEEPER_NAME + ":"
	dialogue_text_label.text = SHOPKEEPER_LINES[dialogue_index]
	dialogue_next_button.text = "Close" if dialogue_index == SHOPKEEPER_LINES.size() - 1 else "Next"

func _on_dialogue_next_pressed() -> void:
	dialogue_index += 1
	if dialogue_index >= SHOPKEEPER_LINES.size():
		dialogue_box.visible = false
		_show_prompt_if_near()
	else:
		_show_dialogue_line()

func _on_buy_sword_pressed() -> void:
	if shop_player.gold < WOODEN_SWORD_PRICE:
		shop_feedback_label.text = "Not enough gold."
		return
	if not global.add_inventory_item(WOODEN_SWORD_NAME, WOODEN_SWORD_ICON):
		shop_feedback_label.text = "Inventory is full."
		return
	shop_player.gold -= WOODEN_SWORD_PRICE
	shop_feedback_label.text = "Bought a Wooden Sword!"

func _on_shop_close_pressed() -> void:
	shop_panel.visible = false
	shop_feedback_label.text = ""
	_show_prompt_if_near()

func _on_day_night_timeout() -> void:
	global.toggle_day_night()
	global.apply_light_state(time_light, point_light)
	if global.state_time == global.TimeState.EVENING:
		set_day_text()
		day_text_fade()

## Sets the light energy to match the current state immediately (no tween),
## so entering the scene doesn't flash to full darkness while it eases in.
func apply_light_state_instant():
	match global.state_time:
		global.TimeState.MORNING:
			if time_light:
				time_light.energy = 0.1
				time_light.color = global.DAY_LIGHT_COLOR
			if point_light: point_light.energy = 0
		global.TimeState.EVENING:
			if time_light:
				time_light.energy = 1.0
				time_light.color = global.NIGHT_LIGHT_COLOR
			if point_light: point_light.energy = 1.5

func set_day_text():
	if day_text:
		day_text.text = "Day " + str(global.day_count)

func day_text_fade():
	if day_anim:
		day_anim.play("day_fade_in")
		await get_tree().create_timer(3).timeout
		day_anim.play("day_fade_out")
