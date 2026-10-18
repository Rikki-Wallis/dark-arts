class_name GuardAnimator extends Node

# Plays the guard model's animations from how the body is moving: idle, walk or run by
# speed, and an attack animation whenever the MeleeAttackComponent starts one (which is
# allowed to finish before walking/idling takes over again). Pure display: it never
# changes what the guard does.

@export var body: CharacterBody3D
@export var animation_player: AnimationPlayer
@export var stats: EnemyStats                 # walk_speed decides walk vs run
@export var melee: MeleeAttackComponent       # optional
@export var model: Node3D                     # for the optional outline
@export var outline_material: Material        # optional, put over every mesh of the model

@export var idle_anim: StringName = &"Idle"
@export var walk_anim: StringName = &"Walk"
@export var run_anim: StringName = &"Run"
@export var death_anim: StringName = &"Death"
@export var blend_time: float = 0.2

func _ready():
	_apply_outline()
	if melee:
		melee.attack_started.connect(_on_attack_started)

func _physics_process(_delta: float) -> void:
	# let an attack play through before going back to walking or idling
	if melee and melee.is_attack_animation(animation_player.current_animation):
		return

	var speed = Vector2(body.velocity.x, body.velocity.z).length()
	var anim_name = idle_anim
	if speed > stats.walk_speed + 0.5:
		anim_name = run_anim
	elif speed > 0.1:
		anim_name = walk_anim

	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name, blend_time)

func _on_attack_started(anim: StringName):
	if anim != &"":
		animation_player.play(anim, 0.1)

func _apply_outline():
	if outline_material == null or model == null:
		return
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = outline_material
