class_name NoiseHelper

static var show_debug: bool = true

# make a noise at a position. kind says what it was, for listeners that care
# (e.g. &"shout" = a guard calling for help); everything else is a plain &"noise"
static func make(tree: SceneTree, position: Vector3, loudness: float, kind: StringName = &"noise") -> void:
	tree.call_group("hearing", "hear_noise", position, loudness, kind)
	if show_debug:
		var colour = Color(1.0, 0.3, 0.2, 0.8) if kind == &"shout" else Color(0.3, 0.6, 1.0, 0.8)
		_draw_debug_ring(tree, position, loudness, colour)

static func _draw_debug_ring(tree: SceneTree, position: Vector3, radius: float, colour: Color) -> void:
	var mesh = TorusMesh.new()
	mesh.outer_radius = radius
	mesh.inner_radius = max(radius - 0.1, 0.01)

	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	mesh.material = material

	var ring = MeshInstance3D.new()
	ring.mesh = mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(ring)
	# Slightly above the floor so it doesn't flicker into the ground
	ring.global_position = _find_floor(tree, position) + Vector3(0, 0.05, 0)

	# Ripple out to full size, fade, then delete itself
	ring.scale = Vector3.ONE * 0.1
	var tween = ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)

# Ray straight down from the noise to find the floor beneath it
static func _find_floor(tree: SceneTree, position: Vector3) -> Vector3:
	var space = tree.current_scene.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(position, position + Vector3.DOWN * 5.0)
	var result = space.intersect_ray(query)
	if result.is_empty():
		return position
	return result.position
