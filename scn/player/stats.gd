extends CanvasLayer

signal leveled_up(new_level: int)

@onready var health_bar = $HealthBar
@onready var stamina_bar = $stamina
@onready var gold_label = $GoldDisplay/GoldLabel
@onready var level_label = $LevelDisplay/LevelLabel
@onready var xp_bar = $LevelDisplay/XPBar

var max_player_health := 100
var _player_health := max_player_health

var stamina=50
var max_stamina := 100
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

# --- Player progression (levels 1-5, see design table in process.md) ---
var xp: int = 0
var level: int = 1

const MAX_LEVEL := 5
const XP_FOR_LEVEL := {
	2: 100,
	3: 250,
	4: 450,
	5: 700,
}

func _ready() -> void:
	if health_bar:
		health_bar.max_value = max_player_health
		health_bar.value = _player_health
	if stamina_bar:
		stamina_bar.max_value = max_stamina
	set_gold(0)
	_update_level_ui()

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
	if stamina<max_stamina:
		stamina+=10*delta

func stamina_consumption():
	stamina-=stamina_cost

func add_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= XP_FOR_LEVEL[level + 1]:
		_level_up()
	_update_level_ui()

func _level_up() -> void:
	level += 1
	match level:
		2:
			max_player_health += 20
			if health_bar:
				health_bar.max_value = max_player_health
			player_health = max_player_health # full heal on level up
		4:
			max_stamina += 20
			if stamina_bar:
				stamina_bar.max_value = max_stamina
	# Level 3 (+5 attack) and level 5 (stronger slice) are applied by
	# player.gd, which listens for this signal.
	leveled_up.emit(level)

func _update_level_ui() -> void:
	if level_label:
		level_label.text = "Lv " + str(level)
	if xp_bar:
		if level >= MAX_LEVEL:
			xp_bar.max_value = 1
			xp_bar.value = 1
		else:
			xp_bar.max_value = XP_FOR_LEVEL[level + 1]
			xp_bar.value = xp
