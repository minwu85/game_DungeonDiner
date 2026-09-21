extends CharacterBody2D
@onready var animEn = $AnimatedSprite2D
@onready var damage_cooldown = $take_damage_cooldown
@onready var enemy_health = $enemy_health

enum PlayerState {
	IDLE,
	CHASE,
	ATTACK,
	DAMAGE,
	RECOVER,
	DEAD
}
var state: PlayerState = PlayerState.IDLE:
	set(value):
		state = value
		match state:
			PlayerState.IDLE:
				pass
				#idle_state()
			PlayerState.CHASE:
				pass
				#chase_state()
			PlayerState.ATTACK:
				pass
				#attack_state()
			PlayerState.RECOVER:
				recover_state()
			PlayerState.DEAD:
				death_state()

var speed = 40 # Enemy movement speed
var player_chase = false # Whether the enemy should chase the player
var player = null # Reference to the player node

@export var xp_reward: int = 20

# Enemy health and status flags

var player_inattack_zone = false
var can_take_damage = true
var alive = true

func _ready():
	$enemy_health.connect("on_death", Callable(self, "death_state"))



func _physics_process(delta):
	if alive:
		if can_take_damage and (global.player_current_attack or global.player_current_slice) and is_player_in_attack_range():
			enemy_health.receive_damage(10)
			can_take_damage = false
			damage_cooldown.start()

		if player_chase and player != null:
			position += (player.position - position).normalized() * speed * delta
			move_and_collide(Vector2.ZERO)
			animEn.play("ske_run")
			animEn.flip_h = (player.position.x - position.x) < 0
		
		else:
			animEn.play("ske_idle")
		
		move_and_slide()

func is_player_in_attack_range() -> bool:
	return player != null and position.distance_to(player.position) < 40  # tweak as needed

# Player enters detection area
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player = body
		player_chase = true

# Player exits detection area
func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		player_chase = false

# Empty placeholder function
func enemy():
	pass

# Player enters enemy's attack zone
func _on_enemy_hitbox_body_entered(body):
	if body.has_method("player"):
		player_inattack_zone = true

# Player exits enemy's attack zone
func _on_enemy_hitbox_body_exited(body):
	if body.has_method("player"):
		player_inattack_zone = false

func death_state():
	alive = false
	var xp_target = player if player else get_tree().get_first_node_in_group("player")
	if xp_target and xp_target.has_method("gain_xp"):
		xp_target.gain_xp(xp_reward)
	animEn.play("ske_death")
	await animEn.animation_finished
	queue_free()


func _on_take_damage_cooldown_timeout():
	can_take_damage = true

func recover_state():
	animEn.play("ske_recover")
	await animEn.animation_finished
	if alive:
		state = PlayerState.CHASE
