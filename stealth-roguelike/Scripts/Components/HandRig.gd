class_name HandRig extends Node3D

# Put this on the root of a rigged first-person hand scene. It switches the
# hand between poses, and gives held things (weapons, spell effects) a mount
# point on the hand's BoneAttachment3D.

@export var idle_animation: StringName = &"RightHandIdle"
# pose used to line the mount up with the camera (see _create_mount)
@export var mount_animation: StringName = &"RightHandGrip"
@export var blend_time: float = 0.15

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var skeleton: Skeleton3D = find_children("*", "Skeleton3D", true, false)[0]
@onready var slot: BoneAttachment3D = find_children("*", "BoneAttachment3D", true, false)[0]

# things held in this hand are added as children of this. While in the mount
# pose, its axes match the hand's parent (the camera): -Z forward, +Y up
var mount: Node3D

func _ready():
	_create_mount()
	play_idle()

func play_pose(anim_name: StringName):
	if not anim.has_animation(anim_name):
		push_warning("HandRig: no animation called '%s'. Available: %s" % [anim_name, anim.get_animation_list()])
		return
	anim.play(anim_name, blend_time)

func play_idle():
	play_pose(idle_animation)

func _create_mount():
	# snap into the mount pose right now and measure how the slot's bone is
	# rotated relative to this hand scene
	if anim.has_animation(mount_animation):
		anim.play(mount_animation)
		anim.seek(0.0, true)
	else:
		push_warning("HandRig: mount animation '%s' not found, using the rest pose" % mount_animation)
	var bone_idx = skeleton.find_bone(slot.bone_name)
	var bone_global = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)

	# line the mount up with whatever this hand is attached to (normally the
	# camera), so held things point where the camera looks even if the hand
	# itself is rotated or tilted for framing
	var reference: Node3D = get_parent() if get_parent() is Node3D else self
	var bone_in_reference = reference.global_transform.affine_inverse() * bone_global

	# the mount undoes the bone's rotation, so it faces the same way as the reference
	mount = Node3D.new()
	mount.name = "Mount"
	mount.basis = bone_in_reference.basis.orthonormalized().inverse()
	slot.add_child(mount)
