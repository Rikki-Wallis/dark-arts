class_name ClippedCone extends MeshInstance3D

enum Mode { BEAM, FLAT }

@export var mode: Mode = Mode.BEAM
@export var cone_range: float = 8.0
@export var cone_angle: float = 30.0        # half-angle in degrees (centre to edge)
@export var cone_color: Color = Color(1, 1, 0, 0.1)
@export var segments: int = 48              # smoothness of the cone's edge
@export var end_fade: float = 0.2           # BEAM: brightness at the far end, compared to the tip
@export var fade_distance: float = 0.5      # BEAM: how softly it fades into surfaces it touches
@export var update_interval: float = 0.05   # FLAT: seconds between rebuilds (it follows moving guards)
@export var collision_mask: int = 1         # FLAT: what blocks it (layer 1 = walls, not jail bars)

const SURFACE_GAP = 0.05   # FLAT: stop rays this far short of walls, so it never flickers into them
const FLOOR_LIFT = 0.03    # FLAT: float this far above the floor

var material: StandardMaterial3D
var timer = 0.0

func _ready():
	var parent = get_parent()
	if parent is SpotLight3D:
		cone_range = parent.spot_range
		cone_angle = parent.spot_angle
		cone_color = Color(parent.light_color, cone_color.a)
	elif parent is VisionComponent:
		cone_range = parent.view_distance
		cone_angle = parent.view_angle / 2.0

	material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# the colour (and fade) comes from each vertex, so the beam can fade along its length
	material.vertex_color_use_as_albedo = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if mode == Mode.BEAM:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD   # glows, adding light on top
		material.cull_mode = BaseMaterial3D.CULL_BACK         # only the side facing you: one clean layer
		material.proximity_fade_enabled = true                # soft where it meets the floor and walls
		material.proximity_fade_distance = fade_distance
		mesh = _build_beam()
	else:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material

func _physics_process(delta):
	# only the flat cone changes: it follows guards around and is cut by walls
	if mode != Mode.FLAT or not is_visible_in_tree():
		return
	timer -= delta
	if timer > 0.0:
		return
	timer = update_interval
	mesh = _build_flat(get_world_3d().direct_space_state)

func set_cone_color(new_color: Color):
	cone_color = new_color
	if mode == Mode.BEAM:
		mesh = _build_beam()
	# a flat cone picks up the new colour on its next rebuild

# --- BEAM: a smooth cone, brightest at the tip ---

func _build_beam() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius = cone_range * tan(deg_to_rad(cone_angle))
	var end_color = Color(cone_color, cone_color.a * end_fade)
	for s in segments:
		var a1 = TAU * s / segments
		var a2 = TAU * (s + 1) / segments
		var p1 = Vector3(cos(a1) * radius, sin(a1) * radius, -cone_range)
		var p2 = Vector3(cos(a2) * radius, sin(a2) * radius, -cone_range)
		# this vertex order faces outwards (Godot treats clockwise as the front)
		st.set_color(cone_color)
		st.add_vertex(Vector3.ZERO)
		st.set_color(end_color)
		st.add_vertex(p2)
		st.set_color(end_color)
		st.add_vertex(p1)
	return st.commit()

# --- FLAT: the footprint on the floor, cut off by walls ---

func _build_flat(space: PhysicsDirectSpaceState3D) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var origin = global_position
	var forward = -global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		return st.commit()  # pointing straight up or down: nothing sensible to draw
	forward = forward.normalized()

	# find the floor under the tip, and draw just above it
	var down = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 5.0, collision_mask))
	var floor_y = down.position.y if down else origin.y - 1.0
	var draw_y = floor_y + FLOOR_LIFT
	var apex = to_local(Vector3(origin.x, draw_y, origin.z))

	# rays fan out flat; triangles fan out from the tip, so they never cut through a wall
	var previous = null
	for i in segments + 1:
		var angle = deg_to_rad(-cone_angle + 2.0 * cone_angle * i / segments)
		var dir = forward.rotated(Vector3.UP, angle)
		var reach = origin + dir * _ray_distance(space, origin, dir)
		var point = to_local(Vector3(reach.x, draw_y, reach.z))
		if previous != null:
			st.set_color(cone_color)
			st.add_vertex(apex)
			st.add_vertex(previous)
			st.add_vertex(point)
		previous = point
	return st.commit()

# how far a ray gets before hitting something, stopping just short of it
func _ray_distance(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3) -> float:
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * cone_range, collision_mask)
	var hit = space.intersect_ray(query)
	if hit.is_empty():
		return cone_range
	return max(from.distance_to(hit.position) - SURFACE_GAP, 0.0)
