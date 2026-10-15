class_name VisionComponent extends Node3D

signal player_spotted
signal player_lost

@export var view_distance: float = 15.0
@export var view_angle: float = 90.0 # the vision code
@export var show_cone: bool = false

var player = null
var sees_player = false
var cone: MeshInstance3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	_build_cone()
	cone.visible = show_cone

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var sees = can_see_player()
	if sees != sees_player:
		sees_player = sees
		if sees:
			player_spotted.emit()
		else:
			player_lost.emit()

func can_see_player() -> bool:
	if player == null:
		return false
	
	var target = player.head.global_position
	var to_player = target - global_position
	
	# First check if the player is within the range of the vision
	if to_player.length() > view_distance:
		return false
	
	# Second check if the player is in the view cone
	var forward = -global_transform.basis.z
	if rad_to_deg(forward.angle_to(to_player)) > view_angle / 2.0:
		return false
	
	# Final, line of site check
	var query = PhysicsRayQueryParameters3D.create(global_position, target, 1)
	query.exclude = [owner.get_rid()]
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == player
	

func set_cone_visibility(value: bool):
	cone.visible = value

func set_cone_colour(colour: Color):
	cone.mesh.material.albedo_color = colour

func _build_cone():
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = view_distance * tan(deg_to_rad(view_angle / 2.0))
	mesh.height = view_distance

	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # visible from inside too
	material.albedo_color = Color(1, 1, 0, 0.15)
	mesh.material = material

	cone = MeshInstance3D.new()
	cone.mesh = mesh
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.rotation.x = deg_to_rad(90)
	cone.position.z = -view_distance / 2.0
	add_child(cone)
	
	
