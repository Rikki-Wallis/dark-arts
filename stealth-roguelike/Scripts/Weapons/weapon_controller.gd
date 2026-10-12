class_name WeaponController extends Node

signal weapon_changed(weapon)
signal ammo_changed(current, max_ammo)
signal fired

@export var current_weapon: Weapon
@export var hand: WeaponHand
@export var aim_camera: Camera3D

var current_weapon_model: Node3D
var ammo = 0
var cooldown_timer = 0.0

func _ready() -> void:
	equip(current_weapon)

func _physics_process(delta):
	if cooldown_timer > 0:
		cooldown_timer -= delta

# swap to a new weapon, or pass null to empty the hand
func equip(weapon: Weapon):
	current_weapon = weapon
	ammo = weapon.max_ammo if weapon else 0
	_spawn_weapon_model()
	hand.hold(weapon)
	weapon_changed.emit(weapon)
	ammo_changed.emit(ammo, weapon.max_ammo if weapon else 0)

func fire():
	if current_weapon == null or cooldown_timer > 0:
		return
	if ammo <= 0:
		print("Click - out of ammo")
		return

	ammo -= 1
	cooldown_timer = current_weapon.fire_cooldown
	ammo_changed.emit(ammo, current_weapon.max_ammo)
	fired.emit()

	NoiseHelper.make(get_tree(), aim_camera.global_position, current_weapon.noise_loudness)

	# hitscan
	var from = aim_camera.global_position
	var to = from - aim_camera.global_transform.basis.z * current_weapon.max_range
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [owner.get_rid()]
	var result = aim_camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	if result.collider.has_method("take_damage"):
		result.collider.take_damage(current_weapon.damage)

func _spawn_weapon_model():
	if current_weapon_model:
		current_weapon_model.queue_free()
		current_weapon_model = null

	if current_weapon and current_weapon.weapon_model:
		current_weapon_model = current_weapon.weapon_model.instantiate()
		hand.weapon_mount.add_child(current_weapon_model)
		# offset from the hand's weapon mount, so the weapon's grip sits in the palm
		current_weapon_model.position = current_weapon.weapon_position
