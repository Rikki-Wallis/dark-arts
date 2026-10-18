class_name JailDoor extends AnimatableBody3D

@export var key_id: StringName = &"cell_key"   # the key that opens this door
@export var locked: bool = true
@export var open_angle: float = 100.0          # degrees; negative swings it the other way
@export var open_time: float = 1.2             # seconds to swing open
@export var open_noise: float = 4.0            # creak radius in metres (guards nearby will hear it)
@export var rattle_noise: float = 2.0          # trying the door without the key

var is_open = false

func interact(player):
	if is_open:
		return
	if locked:
		if not player.has_key(key_id):
			# rattling a locked door is a little noisy too
			print("Locked")
			NoiseHelper.make(get_tree(), global_position + Vector3.UP, rattle_noise)
			return
		locked = false
	_open()

func _open():
	is_open = true
	NoiseHelper.make(get_tree(), global_position + Vector3.UP, open_noise)
	# swing around the hinge (this node's origin)
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:y", rotation.y + deg_to_rad(open_angle), open_time)
