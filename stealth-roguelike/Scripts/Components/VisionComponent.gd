class_name VisionComponent extends Node3D

signal player_spotted
signal player_lost

@export var view_distance: float = 15.0
@export var view_angle: float = 90.0 # the vision code

var player = null
var sees_player = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

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
	var query = PhysicsRayQueryParameters3D.create(global_position, target)
	query.exclude = [owner.get_rid()]
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == player
	
	
	
