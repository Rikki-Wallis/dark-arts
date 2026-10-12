extends CharacterBody3D

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var arms_anim = $Head/Camera3D/LeftHand/AnimationPlayer
@onready var collision_shape = $CollisionShape3D
@onready var ceiling_check = $CeilingCheck
@onready var interact_ray = $Head/Camera3D/InteractRay
@onready var health = $Components/HealthComponent
@onready var light_detector = $LightDetector2
@onready var weapon_controller = $Components/WeaponController

# vars
var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5

const SENSITIVITY = 0.003

# footstep noise	
const STEP_LENGTH = 2.0
const NOISE_CROUCH = 1.5
const NOISE_WALK = 5.0
const NOISE_SPRINT = 10.0
const NOISE_LAND = 8.0
var step_distance = 0.0
var was_on_floor = true

# head bob
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

# fov
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5
# crouch
const CROUCH_SPEED = 2.5
const STAND_HEIGHT = 2.0
const CROUCH_HEIGHT = 1.2
const STAND_HEAD_Y = 1.7
const CROUCH_HEAD_Y = 0.8
var is_crouching = false

# Runs at beggining of scene, get rid of cursor
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Set idle animation for left hand
	arms_anim.play("LeftHand")
	# Make sure interact ray doesnt collide with player model
	interact_ray.add_exception(self)
	# Init health
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))
	
	if event.is_action_pressed("Toggle Debug"):
		get_tree().call_group("debug_label", "toggle")
	
	if event.is_action_pressed("Holster"):
		if weapon_controller.current_weapon:
			weapon_controller.equip(null)
		else:
			weapon_controller.equip(preload("res://Resources/Weapons/pistol.tres"))

	
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle crouch
	if Input.is_action_pressed("Crouch"):
		is_crouching = true
	elif is_crouching and not ceiling_check.is_colliding():
		is_crouching = false
	# lower the capsules top
	var target_height = CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	collision_shape.shape.height = target_height
	collision_shape.position.y = target_height / 2.0
	# lower head down
	var target_head_y = CROUCH_HEAD_Y if is_crouching else STAND_HEAD_Y
	head.position.y = lerp(head.position.y, target_head_y, delta * 10.0)
	
	# Handle interact
	if Input.is_action_just_pressed("Interact") and interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		if target.has_method("interact"):
			target.interact(self)
	
	# Handle weapon
	if Input.is_action_just_pressed("UseWeapon"):
		weapon_controller.fire()
	
	# Handle jump
	if Input.is_action_just_pressed("Jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY
	
	# Handle sprint
	if Input.is_action_pressed("Sprint") and is_on_floor() and not is_crouching:
		speed = SPRINT_SPEED
	elif not is_crouching:
		speed = WALK_SPEED
	else:
		speed = CROUCH_SPEED
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
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
	move_and_slide()
	
	_update_footsteps(delta)
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
	
func take_damage(amount):
	health.take_damage(amount)
	
func _on_health_changed(current, max):
	print("Health: ", current, " / ", max)
	
func _on_died():
	print("Player died")
	get_tree().reload_current_scence()
	
func _update_footsteps(delta):
	if is_on_floor() and not was_on_floor:
		_make_noise(NOISE_LAND)
	was_on_floor = is_on_floor()

	if not is_on_floor():
		return

	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	step_distance += horizontal_speed * delta
	if step_distance >= STEP_LENGTH:
		step_distance = 0.0
		_make_noise(_footstep_loudness())

func _footstep_loudness() -> float:
	if is_crouching:
		return NOISE_CROUCH
	if speed == SPRINT_SPEED:
		return NOISE_SPRINT
	return NOISE_WALK

func _make_noise(loudness):
	NoiseHelper.make(get_tree(), global_position + Vector3(0, 1, 0), loudness)
