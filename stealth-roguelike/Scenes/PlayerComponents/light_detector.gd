class_name LightDetector extends Node3D

signal light_level_changed(value)

@export var ambient: float = 0.1

var light_level = 0.0
# scales the final light level; effects like Shadow Cloak set this to 0
var light_multiplier: float = 1.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var total = ambient
	for light in get_tree().get_nodes_in_group("light"):
		total += _light_contribution(light)
	total = clamp(total * light_multiplier, 0.0, 1.0)
	
	if not is_equal_approx(total, light_level):
		light_level = total
		light_level_changed.emit(light_level)

func _light_contribution(light: OmniLight3D):
	# hidden light
	if not light.is_visible_in_tree():
		return 0.0
	
	# is player in range of light
	var distance = global_position.distance_to(light.global_position)
	if distance > light.omni_range:
		return 0.0
	
	# is there stuff between light and player
	var query = PhysicsRayQueryParameters3D.create(light.global_position, global_position)
	query.exclude = [owner.get_rid()]
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		return 0.0
	
	# adjust by distance to light
	var falloff = 1.0 - distance / light.omni_range
	return falloff * falloff * light.light_energy
