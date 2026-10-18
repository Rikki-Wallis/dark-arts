extends CharacterBody3D

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var collision_shape = $CollisionShape3D
@onready var ceiling_check = $CeilingCheck
@onready var interact_ray = $Head/Camera3D/InteractRay
@onready var health = $Components/HealthComponent
@onready var light_detector = $LightDetector2
@onready var weapon_controller = $Components/WeaponController
@onready var spell_controller = $Components/SpellController
@onready var climb: ClimbComponent = $Components/ClimbComponent
@onready var footsteps: FootstepComponent = $Components/FootstepComponent

# vars
var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003

# head bob
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

# fov
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5
# crouch (ClimbComponent reads STAND_HEIGHT / CROUCH_HEIGHT and calls set_crouch())
const CROUCH_SPEED = 2.5
const STAND_HEIGHT = 2.0
const CROUCH_HEIGHT = 1.2
const STAND_HEAD_Y = 1.7
const CROUCH_HEAD_Y = 0.8
var is_crouching = false

# Items
var keys: Array[StringName] = []

# true while a cutscene plays: you can look around but not move or act
var controls_locked = false

# Runs at beggining of scene, get rid of cursor
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Make sure interact ray doesnt collide with player model
	interact_ray.add_exception(self)
	# Init health
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(60))

	if event.is_action_pressed("Toggle Debug"):
		get_tree().call_group("debug_label", "toggle")

	if event.is_action_pressed("Holster"):
		if weapon_controller.current_weapon:
			weapon_controller.equip(null)
		else:
			weapon_controller.equip(preload("res://Resources/Weapons/pistol.tres"))

	# select a spell with 1, 2, 3
	for i in 3:
		if event.is_action_pressed("Spell%d" % (i + 1)):
			spell_controller.select_spell(i)

func _physics_process(delta: float) -> void:
	# mantling or hanging: the ClimbComponent moves us (no gravity, no walking)
	if climb.busy():
		if climb.is_hanging() and not controls_locked:
			climb.hang_update(delta,
				Input.get_axis("Left", "Right"),
				Input.is_action_just_pressed("Jump") or Input.is_action_pressed("Forward"),
				Input.is_action_just_pressed("Crouch") or Input.is_action_just_pressed("Backward"))
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle crouch
	if Input.is_action_pressed("Crouch"):
		set_crouch(true)
	elif is_crouching and not ceiling_check.is_colliding():
		set_crouch(false)
	# lower head down
	var target_head_y = CROUCH_HEAD_Y if is_crouching else STAND_HEAD_Y
	head.position.y = lerp(head.position.y, target_head_y, delta * 10.0)

	# Handle interact
	if not controls_locked and Input.is_action_just_pressed("Interact") and interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		if target.has_method("interact"):
			target.interact(self)

	# Handle weapon
	if not controls_locked and Input.is_action_just_pressed("UseWeapon"):
		weapon_controller.fire()

	# Handle spells
	if not controls_locked and Input.is_action_just_pressed("CastSpell"):
		spell_controller.cast()

	# Handle climbing: Jump in front of something low to climb onto it, or at a Ledge to
	# hang from it; in the air, keep pushing forward into one to grab it
	if not controls_locked:
		var jumped = Input.is_action_just_pressed("Jump")
		var pushing_in_air = not is_on_floor() and Input.is_action_pressed("Forward") and climb.can_grab()
		if (jumped or pushing_in_air) and climb.try_start(_flat_forward()):
			return

	# Handle jump
	if not controls_locked and Input.is_action_just_pressed("Jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	# Handle sprint
	if Input.is_action_pressed("Sprint") and is_on_floor() and not is_crouching:
		speed = SPRINT_SPEED
	elif not is_crouching:
		speed = WALK_SPEED
	else:
		speed = CROUCH_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Vector2.ZERO
	if not controls_locked:
		input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Only allow for user to effect x direction when on floor
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 8.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 8.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	# head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	# fov
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	# how fast we're falling, read BEFORE move_and_slide, which zeroes it on landing
	var fall_speed = -velocity.y
	move_and_slide()

	footsteps.step(delta, fall_speed, is_crouching, speed == SPRINT_SPEED)

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

# the way we're facing along the ground
func _flat_forward() -> Vector3:
	var forward = -head.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()

# crouch or stand: shrinks or grows the capsule (only when it changes, not every frame).
# The head follows smoothly in _physics_process
func set_crouch(crouching: bool):
	if crouching == is_crouching:
		return
	is_crouching = crouching
	var height = CROUCH_HEIGHT if crouching else STAND_HEIGHT
	collision_shape.shape.height = height
	collision_shape.position.y = height / 2.0

func take_damage(amount):
	health.take_damage(amount)

func _on_health_changed(current, max):
	print("Health: ", current, " / ", max)

func _on_died():
	Game.player_died()


# KEYS


func add_key(key_id: StringName):
	if key_id not in keys:
		keys.append(key_id)

func has_key(key_id: StringName) -> bool:
	return key_id in keys
