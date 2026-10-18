@tool
class_name Ledge extends Node3D

# A grabbable edge. The player can hang anywhere along it, shimmy along it, and pull
# up onto it if there's floor and room on top.
# Put the origin ON the top edge. Local X runs along the edge (length is centred on the
# origin). The blue arrow (+Z) points OUT, away from the wall, to where the player hangs.
# Don't scale this node: use length instead.
#
# In game the edge is marked with a thin coloured strip so players can tell it's
# climbable. It's see-through (transparent), so it draws after the dark filter and keeps
# its colour in the black and white look, like the vision cones.

@export var length: float = 2.0:
	set(value):
		length = maxf(value, 0.1)
		_update_marker()

@export var show_marker: bool = true:
	set(value):
		show_marker = value
		_update_marker()

@export var marker_color: Color = Color(1.0, 0.65, 0.15, 0.9):
	set(value):
		marker_color = value
		_update_marker()

var _marker: MeshInstance3D

func _ready():
	add_to_group("ledge")
	_update_marker()

# the point on the edge closest to pos (both in world space)
func closest_point(pos: Vector3) -> Vector3:
	var x = clampf(to_local(pos).x, -length / 2.0, length / 2.0)
	return to_global(Vector3(x, 0.0, 0.0))

# the point at this local X along the edge
func point_at(x: float) -> Vector3:
	return to_global(Vector3(x, 0.0, 0.0))

# flat direction pointing out from the wall, towards the hanging player
func out() -> Vector3:
	var direction = global_transform.basis.z
	direction.y = 0.0
	return direction.normalized()

# a thin strip along the edge, sitting just proud of it so it shows on the top and front
func _update_marker():
	if not is_inside_tree():
		return
	if _marker == null:
		_marker = MeshInstance3D.new()
		_marker.mesh = BoxMesh.new()
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_marker.material_override = material
		add_child(_marker)   # no owner set, so it's never saved into the scene
	_marker.visible = show_marker
	_marker.mesh.size = Vector3(length, 0.06, 0.06)
	_marker.position = Vector3(0.0, 0.01, 0.01)
	_marker.material_override.albedo_color = marker_color
