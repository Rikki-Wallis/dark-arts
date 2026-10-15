extends MeshInstance3D

# Draws the beam of its parent SpotLight3D, sized from that light's own range
# and angle, so what you see always matches what LightDetector counts as lit.

@export var opacity: float = 0.06

func _ready():
	var light = get_parent() as SpotLight3D
	if light == null:
		push_warning("LightCone must be a child of a SpotLight3D")
		return

	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = light.spot_range * tan(deg_to_rad(light.spot_angle))
	cone.height = light.spot_range

	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD   # glows, adding light on top
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(light.light_color, opacity)
	cone.material = material

	mesh = cone
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a cylinder stands along +Y with its point at the top; a spotlight shines
	# along -Z. Tip it so the point sits at the light and the wide end faces -Z.
	rotation.x = deg_to_rad(90)
	position.z = -light.spot_range / 2.0
