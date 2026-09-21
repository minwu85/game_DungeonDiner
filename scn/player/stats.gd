extends CanvasLayer

@onready var health_bar = $HealthBar
@onready var stamina_bar = $stamina
@onready var gold_label = $GoldDisplay/GoldLabel

var max_player_health := 100
var _player_health := max_player_health

var stamina=50
var stamina_cost
var attack_cost=10
var slice_cost=20
var run_cost=5

var player_health:
	get: return _player_health
	set(value):
		_player_health = clamp(value, 0, max_player_health)
		if health_bar:
			health_bar.value = _player_health

func _ready() -> void:
	if health_bar:
		health_bar.max_value = max_player_health
		health_bar.value = _player_health
	set_gold(0)

# Updates the gold counter displayed below the energy/stamina bar
func set_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = str(amount)

# Optional function to apply damage
func apply_damage(amount: int) -> void:
	player_health -= amount

# Optional function to heal
func heal(amount: int) -> void:
	player_health += amount

func _process(delta: float) -> void:
	stamina_bar.value=stamina
	if stamina<100:
		stamina+=10*delta
		
func stamina_consumption():
	stamina-=stamina_cost
