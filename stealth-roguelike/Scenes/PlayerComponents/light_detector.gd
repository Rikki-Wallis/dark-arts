class_name LightDetector extends Node3D

# 1.0 while the player stands inside any light (in its range and cone, with
# nothing blocking it), 0.0 in darkness. Guards can only see a lit player.

signal light_level_changed(value)

var light_level = 0.0
# effects like Shadow Cloak set this to 0
var light_multiplier: float = 1.0

func _physics_process(_delta: float) -> void:
	var lit = 0.0
	for light in get_tree().get_nodes_in_group("light"):
		if _is_lit_by(light):
			lit = 1.0
			break
	lit *= light_multiplier

	if not is_equal_approx(lit, light_level):
		light_level = lit
		light_level_changed.emit(light_level)

func _is_lit_by(light: Light3D) -> bool:
	# a hidden light is "off" (Extinguish just hides it)
	if not light.is_visible_in_tree():
		return false

	var to_me = global_position - light.global_position
	# omni lights and spotlights store their range under different names
	var light_range = light.omni_range if light is OmniLight3D else light.spot_range
	if to_me.length() > light_range:
		return false

	# spotlights only light what's inside their cone
	if light is SpotLight3D:
		var forward = -light.global_transform.basis.z
		if rad_to_deg(forward.angle_to(to_me)) > light.spot_angle:
			return false

	# is anything between the light and us? (layer 1 only, so light passes through bars)
	var query = PhysicsRayQueryParameters3D.create(light.global_position, global_position, 1)
	query.exclude = [owner.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
