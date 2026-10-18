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
# landing noise grows with how fast you were falling when you hit the ground
const LAND_SILENT_SPEED = 3.0    # m/s: slower landings make no noise (a drop of about 0.5 m)
const LAND_LOUDEST_SPEED = 10.0  # m/s: landings this fast are as loud as it gets (a drop of about 5 m)
const NOISE_LAND_MIN = 3.0       # radius of the quietest landing that still makes a noise
const NOISE_LAND_MAX = 12.0      # radius of the loudest landing
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

# mantling (climbing up onto ledges)
const MANTLE_MIN_HEIGHT = 0.3            # anything lower you just walk or jump over
const MANTLE_MAX_HEIGHT = 2.2           # highest ledge you can reach, measured from your feet
const MANTLE_REACH = [0.55, 0.7, 0.85]   # how far ahead of your centre to look for a ledge
const MANTLE_OVER_TIME = 0.2             # seconds to move forward onto the ledge
var is_mantling = false

# hanging from Ledge nodes (Scripts/Environment/ledge.gd)
enum MoveState { NORMAL, HANGING }
const SHIMMY_SPEED = 1.2          # sideways speed while hanging
const HANG_DEPTH = 2.0            # feet this far below the edge: eyes level with it, head (what guards see) below it
const HANG_MAX_HEIGHT = 2.6       # highest ledge you can grab, measured from your feet
const LEDGE_MIN_HEIGHT = 1.0      # lower ledges you just mantle onto
const LEDGE_GRAB_DISTANCE = 0.8   # how far from your centre (along the ground) you can reach a ledge
const PULL_UP_DEPTH = 0.5         # how far in from the edge you stand after pulling up
const REGRAB_TIME = 0.4           # after letting go, don't grab straight back on for this long
var move_state = MoveState.NORMAL
var wall_normal = Vector3.ZERO    # points out from the ledge we hang on, towards us
var current_ledge: Ledge = null
var hang_x = 0.0                  # where along the ledge we are (in the ledge's local X)
var regrab_timer = 0.0


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
	# while the mantle tween moves us, skip normal movement
	if is_mantling:
		return

	regrab_timer = maxf(regrab_timer - delta, 0.0)

	# hanging has its own movement (and no gravity)
	if move_state == MoveState.HANGING:
		_hang(delta)
		return

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
		var pushing_in_air = not is_on_floor() and Input.is_action_pressed("Forward") and regrab_timer <= 0.0
		if (jumped or pushing_in_air) and _try_climb_start():
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
	# As good practice, you should replace UI actions with custom gameplay actions.
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

	_update_footsteps(delta, fall_speed)
	
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
	Game.player_died()
	
func _update_footsteps(delta, fall_speed):
	if is_on_floor() and not was_on_floor:
		_make_landing_noise(fall_speed)
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

# small drops (and the floor flickering for a frame at a seam) are silent;
# bigger falls get louder, up to NOISE_LAND_MAX
func _make_landing_noise(fall_speed):
	if fall_speed < LAND_SILENT_SPEED:
		return
	var t = clamp(inverse_lerp(LAND_SILENT_SPEED, LAND_LOUDEST_SPEED, fall_speed), 0.0, 1.0)
	_make_noise(lerp(NOISE_LAND_MIN, NOISE_LAND_MAX, t))

func _make_noise(loudness):
	NoiseHelper.make(get_tree(), global_position + Vector3(0, 1, 0), loudness)


# CLIMBING: mantling onto low things, hanging from Ledge nodes


# Jump (or pushing forward in the air) was pressed: climb onto something low, else grab a ledge
func _try_climb_start() -> bool:
	if _try_mantle():
		return true
	return _try_grab_ledge()

# the way we're facing along the ground: the camera normally, the wall while hanging
func _flat_forward() -> Vector3:
	if move_state == MoveState.HANGING:
		return -wall_normal
	var forward = -head.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()

func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return space.intersect_ray(query)

# would our capsule, at this height, fit standing on this spot?
func _fits(space: PhysicsDirectSpaceState3D, spot: Vector3, height: float) -> bool:
	var shape = CapsuleShape3D.new()
	shape.radius = collision_shape.shape.radius
	shape.height = height
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# lifted a little so the surface we stand on doesn't count as "in the way"
	query.transform = Transform3D(Basis(), spot + Vector3.UP * (height / 2.0 + 0.05))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return space.intersect_shape(query, 1).is_empty()


# MANTLE (automatic, onto anything low enough with room on top)


# Look for a ledge top in front of us, up to max_height above our feet.
# Returns {} if there's none, otherwise:
#   stand_spot - where we'd stand on it (a little in from the edge)
#   room       - "stand", "crouch", or "none" (no room, or too thin to stand on)
func _find_ledge(max_height: float) -> Dictionary:
	var space = get_world_3d().direct_space_state
	var forward = _flat_forward()
	var feet = global_position

	for reach in MANTLE_REACH:
		# a ray straight down, a little in front of us, from just above our reach
		var from = feet + forward * reach + Vector3.UP * (max_height + 0.1)
		var to = feet + forward * reach + Vector3.UP * MANTLE_MIN_HEIGHT
		var hit = _ray(space, from, to)
		# only flat tops count, not slopes or the side of something
		if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.7:
			continue
		var top: Vector3 = hit.position

		# our arms must be able to get there: first straight up from our head (a ceiling above
		# us would otherwise let us find the top of the ROOF and climb through it)...
		var head_top = feet + Vector3.UP * (collision_shape.shape.height - 0.1)
		var reach_from = Vector3(feet.x, top.y + 0.3, feet.z)
		if reach_from.y > head_top.y and not _ray(space, head_top, reach_from).is_empty():
			return {}
		# ...then across to the top: nothing (like a wall or bars) in between
		if not _ray(space, reach_from, top + Vector3.UP * 0.3).is_empty():
			return {}

		# is the top deep enough to stand on, and is there room above it?
		var inner = top + forward * 0.35
		var deep = _ray(space, inner + Vector3.UP * 0.3, inner - Vector3.UP * 0.3)
		var room = "none"
		var stand_spot = top
		if not deep.is_empty() and absf(deep.position.y - top.y) < 0.15:
			stand_spot = deep.position
			if _fits(space, stand_spot, STAND_HEIGHT):
				room = "stand"
			elif _fits(space, stand_spot, CROUCH_HEIGHT):
				room = "crouch"
		return {"stand_spot": stand_spot, "room": room}
	return {}

func _try_mantle() -> bool:
	var ledge = _find_ledge(MANTLE_MAX_HEIGHT)
	if ledge.is_empty() or ledge["room"] == "none":
		return false
	_mantle_to(ledge["stand_spot"], ledge["room"] == "crouch")
	return true

# climb: rise straight up until our feet clear the top, then move forward onto it
func _mantle_to(spot: Vector3, crouch: bool):
	move_state = MoveState.NORMAL
	current_ledge = null
	is_mantling = true
	velocity = Vector3.ZERO
	if crouch:
		is_crouching = true
		collision_shape.shape.height = CROUCH_HEIGHT
		collision_shape.position.y = CROUCH_HEIGHT / 2.0

	# higher climbs take a little longer
	var climb = spot.y - global_position.y
	var up_time = lerp(0.2, 0.45, clampf(inverse_lerp(MANTLE_MIN_HEIGHT, MANTLE_MAX_HEIGHT, climb), 0.0, 1.0))
	var rise = Vector3(global_position.x, spot.y + 0.05, global_position.z)

	var tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", rise, up_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", spot + Vector3.UP * 0.05, MANTLE_OVER_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): is_mantling = false)


# HANGING FROM LEDGE NODES


# grab the nearest Ledge in reach that we're facing; returns true if we grabbed one
func _try_grab_ledge() -> bool:
	var feet = global_position
	var best: Ledge = null
	var best_point = Vector3.ZERO
	var best_distance = LEDGE_GRAB_DISTANCE

	for node in get_tree().get_nodes_in_group("ledge"):
		var ledge: Ledge = node
		var point = ledge.closest_point(feet)
		var height = point.y - feet.y
		if height < LEDGE_MIN_HEIGHT or height > HANG_MAX_HEIGHT:
			continue
		var to_us = feet - point
		to_us.y = 0.0
		# we must be on the hanging side of it...
		if to_us.dot(ledge.out()) <= 0.0:
			continue
		# ...close enough...
		var distance = to_us.length()
		if distance > best_distance:
			continue
		# ...and roughly facing it
		if _flat_forward().dot(-ledge.out()) < 0.3:
			continue
		best = ledge
		best_point = point
		best_distance = distance

	if best == null:
		return false

	# hang just off the edge, with our feet HANG_DEPTH below it
	var radius = collision_shape.shape.radius
	var hang_pos = best_point + best.out() * (radius + 0.05) - Vector3.UP * HANG_DEPTH
	if not _fits(get_world_3d().direct_space_state, hang_pos, STAND_HEIGHT):
		return false   # e.g. the floor or a wall is in the way

	current_ledge = best
	hang_x = best.to_local(best_point).x
	wall_normal = best.out()
	move_state = MoveState.HANGING
	velocity = Vector3.ZERO
	is_crouching = false
	collision_shape.shape.height = STAND_HEIGHT
	collision_shape.position.y = STAND_HEIGHT / 2.0
	global_position = hang_pos
	return true

func _hang(delta: float):
	if not is_instance_valid(current_ledge):
		_let_go()
		return
	if Input.is_action_just_pressed("Crouch") or Input.is_action_just_pressed("Backward"):
		_let_go()
		return
	if Input.is_action_just_pressed("Jump") or Input.is_action_pressed("Forward"):
		if _try_pull_up():
			return

	# shimmy: Right moves to our right while facing the wall; stop at the ledge's ends
	var right = (-wall_normal).cross(Vector3.UP)
	var along = current_ledge.global_transform.basis.x.normalized()
	var dir = Input.get_axis("Left", "Right") * signf(right.dot(along))
	var half = current_ledge.length / 2.0
	hang_x = clampf(hang_x + dir * SHIMMY_SPEED * delta, -half, half)

	var radius = collision_shape.shape.radius
	global_position = current_ledge.point_at(hang_x) + wall_normal * (radius + 0.05) - Vector3.UP * HANG_DEPTH

# pull up onto the ledge, only if there's floor on top and room for us
func _try_pull_up() -> bool:
	var space = get_world_3d().direct_space_state
	var spot = current_ledge.point_at(hang_x) - wall_normal * PULL_UP_DEPTH
	var ground = _ray(space, spot + Vector3.UP * 0.3, spot - Vector3.UP * 0.3)
	if ground.is_empty():
		return false   # nothing to stand on (e.g. a thin rail)
	spot = ground.position
	if _fits(space, spot, STAND_HEIGHT):
		_mantle_to(spot, false)
		return true
	if _fits(space, spot, CROUCH_HEIGHT):
		_mantle_to(spot, true)
		return true
	return false

# drop off the ledge
func _let_go():
	move_state = MoveState.NORMAL
	current_ledge = null
	velocity = wall_normal * 1.0
	regrab_timer = REGRAB_TIME


# KEYS


func add_key(key_id: StringName):
	if key_id not in keys:
		keys.append(key_id)

func has_key(key_id: StringName) -> bool:
	return key_id in keys
