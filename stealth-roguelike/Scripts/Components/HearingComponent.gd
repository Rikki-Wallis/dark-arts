class_name HearingComponent extends Node3D

signal noise_heard(position, strength)

@export var sensitivity: float = 1.0
@export var wall_muffle: float = 0.5

# for debug
var last_heard = "-"

func _ready() -> void:
	add_to_group("hearing")

func hear_noise(noise_position: Vector3, loudness: float):
	var radius = loudness * sensitivity
	var distance = global_position.distance_to(noise_position)
	
	if distance > radius:
		return
	
	# muffle through walls
	if _is_blocked(noise_position):
		radius *= wall_muffle
		if distance > radius:
			return
	
	var strength = 1.0 - distance / radius
	last_heard = "%.1fm (%.2f)" % [distance, strength]
	noise_heard.emit(noise_position, strength)

func _is_blocked(noise_position: Vector3) -> bool:
	var query = PhysicsRayQueryParameters3D.create(global_position, noise_position, 1)
	query.exclude = [owner.get_rid()]
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and not result.collider.is_in_group("player")

func get_debug_info() -> Dictionary:
	return {"heard": last_heard}
