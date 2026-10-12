class_name SpellController extends Node

signal spell_cast(spell)
signal spell_selected(spell)
signal cooldown_changed(spell, remaining, total)

@export var spells: Array[Spell] = []
@export var hand: HandRig
@export var aim_camera: Camera3D

var current_index = 0
var cooldowns = {}   # spell -> seconds of cooldown left
var pose_timer = 0.0

func _ready():
	assert(hand != null and aim_camera != null, "SpellController: assign Hand and Aim Camera in the Inspector")

func _physics_process(delta):
	# count every spell's cooldown down; keys() is a copy, so erasing inside the loop is safe
	for spell in cooldowns.keys():
		cooldowns[spell] = max(cooldowns[spell] - delta, 0.0)
		cooldown_changed.emit(spell, cooldowns[spell], spell.cooldown)
		if cooldowns[spell] == 0.0:
			cooldowns.erase(spell)

	# drop the hand back to idle after the cast pose
	if pose_timer > 0:
		pose_timer -= delta
		if pose_timer <= 0:
			hand.play_idle()

func current_spell() -> Spell:
	if spells.is_empty():
		return null
	return spells[current_index]

func select_spell(index: int):
	if index < 0 or index >= spells.size():
		return
	current_index = index
	spell_selected.emit(current_spell())

func cast():
	var spell = current_spell()
	if spell == null or cooldowns.has(spell):
		return
	# the spell decides whether there was anything to cast at
	if not spell.cast(self):
		return

	cooldowns[spell] = spell.cooldown
	hand.play_pose(spell.cast_animation)
	pose_timer = spell.cast_pose_time
	spell_cast.emit(spell)

# where the player is aiming: from the camera, straight through the crosshair
func aim_origin() -> Vector3:
	return aim_camera.global_position

func aim_direction() -> Vector3:
	return -aim_camera.global_transform.basis.z

# what the crosshair is pointing at, up to max_range away (empty if nothing)
func aim_raycast(max_range: float) -> Dictionary:
	var from = aim_origin()
	var query = PhysicsRayQueryParameters3D.create(from, from + aim_direction() * max_range)
	query.exclude = [owner.get_rid()]
	return aim_camera.get_world_3d().direct_space_state.intersect_ray(query)
