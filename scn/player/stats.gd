extends CanvasLayer

signal leveled_up(new_level: int)

@onready var health_bar = $HealthBar
@onready var stamina_bar = $stamina
@onready var gold_label = $GoldDisplay/GoldLabel
@onready var level_label = $LevelDisplay/LevelLabel
@onready var xp_bar = $LevelDisplay/XPBar
@onready var time_bar = $TimeBar

@export var max_player_health := 100
var _player_health := max_player_health

@export var max_stamina := 100.0
var stamina = 100.0
var stamina_cost
@export var attack_cost := 10
@export var slice_cost := 20
@export var run_cost := 5

var player_health:
	get: return _player_health
	set(value):
		_player_health = clamp(value, 0, max_player_health)
		if health_bar:
			health_bar.value = _player_health
		global.player_health = _player_health

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
	# Pull persisted values back in - this node (like the rest of the
	# player scene) is fully recreated on every scene change, so gold/
	# health/stamina/xp/level would otherwise reset every time the player
	# walked into the shop/forest/cliff and came back.
	max_player_health = global.max_player_health
	_player_health = global.player_health
	max_stamina = global.max_stamina
	stamina = global.stamina
	xp = global.xp
	level = global.level

	if health_bar:
		health_bar.max_value = max_player_health
		health_bar.value = _player_health
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = stamina
	set_gold(global.gold)
	_update_level_ui()
	_update_time_bar()

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
	global.stamina = stamina
	global.phase_elapsed += delta
	_update_time_bar()

func stamina_consumption():
	stamina-=stamina_cost

func add_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= XP_FOR_LEVEL[level + 1]:
		_level_up()
	global.xp = xp
	_update_level_ui()

func _level_up() -> void:
	level += 1
	match level:
		2:
			max_player_health += 20
			global.max_player_health = max_player_health
			if health_bar:
				health_bar.max_value = max_player_health
			player_health = max_player_health # full heal on level up
		4:
			max_stamina += 20
			global.max_stamina = max_stamina
			if stamina_bar:
				stamina_bar.max_value = max_stamina
	global.level = level
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

func _update_time_bar() -> void:
	if not time_bar:
		return
	time_bar.max_value = global.phase_duration_seconds()
	time_bar.value = global.phase_elapsed
	# Warm/yellow while it's day, cool/blue at night - readable at a glance
	# without needing to fit "Day N - Night" text into a 52px-wide box.
	if global.state_time == global.TimeState.MORNING:
		time_bar.modulate = Color(1, 0.85, 0.3)
	else:
		time_bar.modulate = Color(0.4, 0.55, 0.9)
