class_name ExtinguishSpell extends Spell

# Snuffs out the light closest to the crosshair.

@export var max_range: float = 15.0
@export var max_angle: float = 8.0       # how close to the crosshair the light must be, in degrees
@export var hiss_loudness: float = 2.0   # a dying flame makes a little noise

func cast(controller: SpellController) -> bool:
	var light = _find_target(controller)
	if light == null:
		return false

	# a hidden light gives no light, and LightDetector already skips hidden lights
	light.visible = false
	NoiseHelper.make(controller.get_tree(), light.global_position, hiss_loudness)
	return true

# the visible light closest to the crosshair, in range, that we can actually see
func _find_target(controller: SpellController) -> Light3D:
	var origin = controller.aim_origin()
	var forward = controller.aim_direction()
	var best: Light3D = null
	var best_angle = max_angle

	for light in controller.get_tree().get_nodes_in_group("light"):
		if not light.is_visible_in_tree():
			continue
		var to_light = light.global_position - origin
		if to_light.length() > max_range:
			continue
		var angle = rad_to_deg(forward.angle_to(to_light))
		if angle > best_angle:
			continue
		if _is_blocked(controller, origin, light.global_position):
			continue
		best = light
		best_angle = angle

	return best

func _is_blocked(controller: SpellController, from: Vector3, to: Vector3) -> bool:
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [controller.owner.get_rid()]
	var result = controller.aim_camera.get_world_3d().direct_space_state.intersect_ray(query)
	# hitting something just short of the light (e.g. the wall it's mounted on) still counts as visible
	return not result.is_empty() and from.distance_to(result.position) < from.distance_to(to) - 0.5
