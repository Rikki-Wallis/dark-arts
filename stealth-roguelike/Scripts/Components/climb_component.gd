class_name ClimbComponent extends Node

# Climbing for a CharacterBody3D: mantling onto anything low enough with room on top,
# and hanging from hand-placed Ledge nodes (shimmy along them, pull up, drop).
# It never reads input itself: the owner passes in which way it's facing and what it
# wants to do, so the same component could be driven by AI later.
#
# While busy() is true (mantling or hanging) this component moves the body, and the
# owner should skip its own movement and gravity.
#
# The owner must have STAND_HEIGHT and CROUCH_HEIGHT constants and a set_crouch(bool)
# method (duck typing), so a mantle into a low gap can crouch it.

signal mantle_started
signal mantle_finished
signal hang_started(ledge: Ledge)
signal hang_stopped

@export var body: CharacterBody3D
@export var collision_shape: CollisionShape3D

@export_group("Mantle")
@export var mantle_min_height: float = 0.3     # anything lower you just walk or jump over
@export var mantle_max_height: float = 2.2     # highest top you can climb onto, measured from your feet
@export var mantle_reach: Array[float] = [0.55, 0.7, 0.85]   # how far ahead of your centre to look
@export var mantle_over_time: float = 0.2      # seconds to move forward onto the top

@export_group("Ledges")
@export var shimmy_speed: float = 1.2          # sideways speed while hanging
@export var hang_depth: float = 2.0            # feet this far below the edge: eyes level with it, head (what guards see) below it
@export var hang_max_height: float = 2.6       # highest ledge you can grab, measured from your feet
@export var ledge_min_height: float = 1.0      # lower ledges you just mantle onto
@export var ledge_grab_distance: float = 0.8   # how far from your centre (along the ground) you can reach a ledge
@export var pull_up_depth: float = 0.5         # how far in from the edge you stand after pulling up
@export var regrab_time: float = 0.4           # after letting go, don't grab straight back on for this long

var mantling = false
var current_ledge: Ledge = null
var wall_normal = Vector3.ZERO   # points out from the ledge we hang on, towards the body
var hang_x = 0.0                 # where along the ledge we are (in the ledge's local X)
var regrab_timer = 0.0
var facing = Vector3.FORWARD     # flat direction the owner faces, set by try_start()

func _physics_process(delta: float) -> void:
	regrab_timer = maxf(regrab_timer - delta, 0.0)


# FOR THE OWNER


func busy() -> bool:
	return mantling or is_hanging()

func is_hanging() -> bool:
	return current_ledge != null

# false for a moment after letting go, so pushing forward in the air doesn't grab straight back on
func can_grab() -> bool:
	return regrab_timer <= 0.0

# Jump (or pushing forward in the air): climb onto something low, else grab a Ledge.
# forward = the flat direction the owner is facing. Returns true if it started climbing.
func try_start(forward: Vector3) -> bool:
	facing = forward
	if _try_mantle():
		return true
	return _try_grab_ledge()

# call every physics frame while hanging:
#   shimmy  - -1..1, left/right along the ledge
#   pull_up - climb up onto the ledge, if there's room
#   drop    - let go
func hang_update(delta: float, shimmy: float, pull_up: bool, drop: bool):
	if not is_instance_valid(current_ledge):
		_let_go()
		return
	if drop:
		_let_go()
		return
	if pull_up and _try_pull_up():
		return

	# shimmy: positive moves to our right while facing the wall; stop at the ledge's ends
	var right = (-wall_normal).cross(Vector3.UP)
	var along = current_ledge.global_transform.basis.x.normalized()
	var half = current_ledge.length / 2.0
	hang_x = clampf(hang_x + shimmy * signf(right.dot(along)) * shimmy_speed * delta, -half, half)
	body.global_position = _hang_position(current_ledge.point_at(hang_x))


# HELPERS


# the body without a type, for the owner's own members (STAND_HEIGHT, CROUCH_HEIGHT,
# set_crouch): CharacterBody3D doesn't have them, so they're looked up when the game runs
func _owner_api():
	return body

# the flat way we're facing: the owner's facing normally, the wall while hanging
func _flat_forward() -> Vector3:
	if is_hanging():
		return -wall_normal
	return facing

func _space() -> PhysicsDirectSpaceState3D:
	return body.get_world_3d().direct_space_state

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(from, to, body.collision_mask, [body.get_rid()])
	return _space().intersect_ray(query)

# would the body's capsule, at this height, fit standing on this spot?
func _fits(spot: Vector3, height: float) -> bool:
	var shape = CapsuleShape3D.new()
	shape.radius = collision_shape.shape.radius
	shape.height = height
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# lifted a little so the surface we stand on doesn't count as "in the way"
	query.transform = Transform3D(Basis(), spot + Vector3.UP * (height / 2.0 + 0.05))
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return _space().intersect_shape(query, 1).is_empty()

# where the body hangs for a point on a ledge: just off the edge, feet hang_depth below it
func _hang_position(edge_point: Vector3) -> Vector3:
	return edge_point + wall_normal * (collision_shape.shape.radius + 0.05) - Vector3.UP * hang_depth


# MANTLE (automatic, onto anything low enough with room on top)


# Look for a top in front of us, up to max_height above our feet.
# Returns {} if there's none, otherwise:
#   stand_spot - where we'd stand on it (a little in from the edge)
#   room       - "stand", "crouch", or "none" (no room, or too thin to stand on)
func _find_top(max_height: float) -> Dictionary:
	var forward = _flat_forward()
	var feet = body.global_position

	for reach in mantle_reach:
		# a ray straight down, a little in front of us, from just above our reach
		var from = feet + forward * reach + Vector3.UP * (max_height + 0.1)
		var to = feet + forward * reach + Vector3.UP * mantle_min_height
		var hit = _ray(from, to)
		# only flat tops count, not slopes or the side of something
		if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.7:
			continue
		var top: Vector3 = hit.position

		# our arms must be able to get there: first straight up from our head (a ceiling above
		# us would otherwise let us find the top of the ROOF and climb through it)...
		var head_top = feet + Vector3.UP * (collision_shape.shape.height - 0.1)
		var reach_from = Vector3(feet.x, top.y + 0.3, feet.z)
		if reach_from.y > head_top.y and not _ray(head_top, reach_from).is_empty():
			return {}
		# ...then across to the top: nothing (like a wall or bars) in between
		if not _ray(reach_from, top + Vector3.UP * 0.3).is_empty():
			return {}

		# is the top deep enough to stand on, and is there room above it?
		var inner = top + forward * 0.35
		var deep = _ray(inner + Vector3.UP * 0.3, inner - Vector3.UP * 0.3)
		var room = "none"
		var stand_spot = top
		if not deep.is_empty() and absf(deep.position.y - top.y) < 0.15:
			stand_spot = deep.position
			if _fits(stand_spot, _owner_api().STAND_HEIGHT):
				room = "stand"
			elif _fits(stand_spot, _owner_api().CROUCH_HEIGHT):
				room = "crouch"
		return {"stand_spot": stand_spot, "room": room}
	return {}

func _try_mantle() -> bool:
	var found = _find_top(mantle_max_height)
	if found.is_empty() or found["room"] == "none":
		return false
	_mantle_to(found["stand_spot"], found["room"] == "crouch")
	return true

# climb: rise straight up until our feet clear the top, then move forward onto it
func _mantle_to(spot: Vector3, crouch: bool):
	if is_hanging():
		current_ledge = null
		hang_stopped.emit()
	mantling = true
	body.velocity = Vector3.ZERO
	if crouch:
		_owner_api().set_crouch(true)
	mantle_started.emit()

	# higher climbs take a little longer
	var climb = spot.y - body.global_position.y
	var up_time = lerp(0.2, 0.45, clampf(inverse_lerp(mantle_min_height, mantle_max_height, climb), 0.0, 1.0))
	var rise = Vector3(body.global_position.x, spot.y + 0.05, body.global_position.z)

	var tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(body, "global_position", rise, up_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "global_position", spot + Vector3.UP * 0.05, mantle_over_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_on_mantle_finished)

func _on_mantle_finished():
	mantling = false
	mantle_finished.emit()


# HANGING FROM LEDGE NODES


# grab the nearest Ledge in reach that we're facing; returns true if we grabbed one
func _try_grab_ledge() -> bool:
	var feet = body.global_position
	var best: Ledge = null
	var best_point = Vector3.ZERO
	var best_distance = ledge_grab_distance

	for node in get_tree().get_nodes_in_group("ledge"):
		var ledge: Ledge = node
		var point = ledge.closest_point(feet)
		var height = point.y - feet.y
		if height < ledge_min_height or height > hang_max_height:
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

	wall_normal = best.out()
	var hang_pos = _hang_position(best_point)
	if not _fits(hang_pos, _owner_api().STAND_HEIGHT):
		return false   # e.g. the floor or a wall is in the way

	current_ledge = best
	hang_x = best.to_local(best_point).x
	body.velocity = Vector3.ZERO
	_owner_api().set_crouch(false)
	body.global_position = hang_pos
	hang_started.emit(best)
	return true

# pull up onto the ledge, only if there's floor on top and room for us
func _try_pull_up() -> bool:
	var spot = current_ledge.point_at(hang_x) - wall_normal * pull_up_depth
	var ground = _ray(spot + Vector3.UP * 0.3, spot - Vector3.UP * 0.3)
	if ground.is_empty():
		return false   # nothing to stand on (e.g. a thin rail)
	spot = ground.position
	if _fits(spot, _owner_api().STAND_HEIGHT):
		_mantle_to(spot, false)
		return true
	if _fits(spot, _owner_api().CROUCH_HEIGHT):
		_mantle_to(spot, true)
		return true
	return false

# drop off the ledge
func _let_go():
	current_ledge = null
	body.velocity = wall_normal * 1.0
	regrab_timer = regrab_time
	hang_stopped.emit()
