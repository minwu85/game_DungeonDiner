extends Node2D

signal on_death  # Tells enemy.gd the enemy has died
signal damage_received

@onready var enhealth_bar = $enemy_healthbar
@onready var enhealth_txt = $enemy_healthtxt
@onready var enhealth_txtAn = $enemy_healthtxtAn

var alive = true
@export var max_health: int = 100
var enemy_health: int

func _ready():
	enemy_health = max_health
	enhealth_bar.max_value = max_health
	enhealth_bar.value = enemy_health
	enhealth_bar.visible = false
	enhealth_txt.visible = false

func _process(delta):
	enhealth_bar.rotation = 0
	enhealth_txt.rotation = 0

func receive_damage(amount: int):
	if not alive:
		return

	enemy_health -= amount
	enhealth_txt.text = str(amount)  # Show actual damage received
	enhealth_txtAn.stop()
	enhealth_txtAn.play("endamage_txt")

	update_health_ui()

	if enemy_health <= 0:
		alive = false
		emit_signal("on_death")
	else:
		emit_signal("damage_received")

func update_health_ui():
	enhealth_bar.visible = true
	enhealth_bar.value = enemy_health
	enhealth_txt.visible = true
