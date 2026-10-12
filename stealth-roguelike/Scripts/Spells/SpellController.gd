class_name SpellController extends Node

signal spell_cast(spell)
signal cooldown_changed(remaining, total)

@export var current_spell: Spell
@export var hand: HandRig
@export var aim_camera: Camera3D

var cooldown_timer = 0.0
var pose_timer = 0.0

func _ready():
	assert(hand != null and aim_camera != null, "SpellController: assign Hand and Aim Camera in the Inspector")

func _physics_process(delta):
	if cooldown_timer > 0:
		cooldown_timer = max(cooldown_timer - delta, 0.0)
		cooldown_changed.emit(cooldown_timer, current_spell.cooldown)

	# drop the hand back to idle after the cast pose
	if pose_timer > 0:
		pose_timer -= delta
		if pose_timer <= 0:
			hand.play_idle()

func cast():
	if current_spell == null or cooldown_timer > 0:
		return
	# the spell decides whether there was anything to cast at
	if not current_spell.cast(self):
		return

	cooldown_timer = current_spell.cooldown
	hand.play_pose(current_spell.cast_animation)
	pose_timer = current_spell.cast_pose_time
	spell_cast.emit(current_spell)

# where the player is aiming: from the camera, straight through the crosshair
func aim_origin() -> Vector3:
	return aim_camera.global_position

func aim_direction() -> Vector3:
	return -aim_camera.global_transform.basis.z
