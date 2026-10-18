class_name MeleeAttackComponent extends Node

# A punch/kick attack for an enemy. The owner decides WHEN to attack (try_attack());
# this handles the cooldown, picks a random attack, and lands the hit attack_hit_delay
# seconds later, but only if the player is still visible and in reach (they may have
# dodged away during the wind-up). If the owner dies first, this node goes with it, so a
# hit can never land after the enemy is gone.

# an attack has started; anim is the attack animation picked (empty if there are none)
signal attack_started(anim: StringName)
# the hit connected
signal hit_landed(target: Node3D)

@export var body: Node3D               # the attacker (distance is measured from here)
@export var vision: VisionComponent    # we only hit what we can see, never through a wall
@export var stats: EnemyStats          # attack_damage, attack_cooldown, catch_distance
# one of these is picked at random for each attack (they must not loop)
@export var attack_anims: Array[StringName] = [&"Punch_Left", &"Punch_Right", &"Kick_Left", &"Kick_Right"]
@export var attack_hit_delay: float = 0.3   # seconds into the attack when the hit lands
@export var reach_margin: float = 0.5       # extra reach past catch_distance when the hit lands

var cooldown_timer = 0.0
var hit_timer = 0.0   # counts down to the moment an attack connects; 0 = no attack in progress

func _physics_process(delta: float) -> void:
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	if hit_timer <= 0.0:
		return
	hit_timer -= delta
	if hit_timer <= 0.0:
		_land_hit()

# start an attack if we're off cooldown and can see the player; returns true if we did
func try_attack() -> bool:
	if cooldown_timer > 0.0 or not vision.sees_player:
		return false
	# a different punch or kick each time, so attacks don't look repetitive
	var anim = &""
	if not attack_anims.is_empty():
		anim = attack_anims.pick_random()
	cooldown_timer = stats.attack_cooldown
	hit_timer = attack_hit_delay
	attack_started.emit(anim)
	return true

# is this one of our attack animations? (so an animator doesn't cut it off)
func is_attack_animation(anim: StringName) -> bool:
	return anim in attack_anims

func _land_hit():
	# measured flat along the ground, like the owner's reach check
	var player = vision.player
	var to_player = player.global_position - body.global_position
	to_player.y = 0.0
	if vision.sees_player and to_player.length() <= stats.catch_distance + reach_margin:
		player.take_damage(stats.attack_damage)
		hit_landed.emit(player)
