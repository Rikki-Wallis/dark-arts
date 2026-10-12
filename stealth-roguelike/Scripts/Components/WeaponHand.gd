class_name WeaponHand extends Node3D

# Put this on the root of a rigged first-person hand scene.
# It plays the hand pose for whatever is being held, and gives weapons a
# mount point on the hand's weapon bone (via the WeaponSlot BoneAttachment3D).

@export var idle_animation: StringName = &"RightHandIdleAction"
# pose used to line weapons up with the camera (see _create_weapon_mount)
@export var grip_animation: StringName = &"RightHandGripAction"
@export var blend_time: float = 0.15

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var skeleton: Skeleton3D = find_children("*", "Skeleton3D", true, false)[0]
@onready var weapon_slot: BoneAttachment3D = find_children("*", "BoneAttachment3D", true, false)[0]

# weapons are added as children of this. While gripping, its axes match this
# hand scene's axes (-Z forward, +Y up), so weapon scenes built the normal
# Godot way (barrel along -Z) point where the camera looks
var weapon_mount: Node3D

func _ready():
	_create_weapon_mount()
	_play_pose(idle_animation, 0.0)

# show the pose for a weapon, or the idle pose when the hand is empty
func hold(weapon: Weapon):
	if weapon:
		_play_pose(weapon.hold_animation, blend_time)
	else:
		_play_pose(idle_animation, blend_time)

func _play_pose(anim_name: StringName, blend: float):
	if not anim.has_animation(anim_name):
		push_warning("WeaponHand: no animation called '%s'. Available: %s" % [anim_name, anim.get_animation_list()])
		return
	anim.play(anim_name, blend)

func _create_weapon_mount():
	# snap the hand into its grip pose right now and measure how the weapon
	# bone is rotated relative to this hand scene
	_play_pose(grip_animation, 0.0)
	anim.seek(0.0, true)
	var bone_idx = skeleton.find_bone(weapon_slot.bone_name)
	var bone_in_hand = global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)

	# the mount undoes that rotation, so it faces the same way as the hand scene
	weapon_mount = Node3D.new()
	weapon_mount.name = "WeaponMount"
	weapon_mount.basis = bone_in_hand.basis.orthonormalized().inverse()
	weapon_slot.add_child(weapon_mount)
