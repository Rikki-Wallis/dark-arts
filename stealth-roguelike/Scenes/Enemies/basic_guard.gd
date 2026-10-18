extends CharacterBody3D

# The guard's brain: a state machine that decides what to do with what its components
# report (vision, detection meter, hearing, health). How it attacks, animates and shows
# alertness lives in components (MeleeAttackComponent, GuardAnimator, AlertIndicator,
# VisionComponent's cone colour).

enum State { PATROL, SUSPICIOUS, SEARCHING, ALERT, SCRIPTED, DEAD }

# emitted while SCRIPTED when the guard reaches the spot given to walk_to()
signal arrived

@export var patrol_points: Array[Marker3D] = []
# if the guard is following a path but hasn't really moved for this long, it gives up on that spot
@export var stuck_time: float = 1.5
# true = a cutscene drives this guard (see IntroSequence); the level's activate() is
# ignored until the cutscene calls end_script()
@export var scripted_intro: bool = false

@export_group("Takedown")
@export var takedown_range: float = 1.6    # how close you must be (along the ground)
@export var takedown_angle: float = 100.0  # degrees round from where he faces you must be (90 = beside him, 180 = right behind)
@export var takedown_noise: float = 2.0    # a scuffle a guard standing right next to him might hear

@export_group("Alarm")
@export var shout_loudness: float = 15.0   # how far a shout for help carries (walls muffle it)
@export var shout_cooldown: float = 6.0    # seconds between shouts, so a guard doesn't spam them

@export_group("Parts")
@export var vision: VisionComponent
@export var nav_agent: NavigationAgent3D
@export var detection: DetectionComponent
@export var hearing: HearingComponent
@export var health: HealthComponent
@export var stats: EnemyStats
@export var melee: MeleeAttackComponent
@export var animator: GuardAnimator
@export var lantern: Light3D

var state = State.PATROL
var patrol_index = 0
var wait_timer = 0.0
var search_timer = 0.0
var last_seen_position = Vector3.ZERO
var tracking_timer = 0.0
var was_alerted = false
# where the guard started, so it has somewhere to return to without a patrol route
var home_position = Vector3.ZERO
var home_facing = 0.0
# stuck detection: where we last made real progress, and how long since
var stuck_check_position = Vector3.ZERO
var stuck_timer = 0.0
# cutscene control: walking to a walk_to() spot, and the angle to turn to (null = don't turn)
var script_walking = false
var script_facing = null
# alarm: time until we can shout again, whether this search is a hurry (run, not walk),
# and the bodies we've already found (so each one only alarms us once)
var shout_timer = 0.0
var search_hurry = false
var known_bodies: Array[Node3D] = []

func _ready():
	add_to_group("enemy")

	detection.detection_changed.connect(_on_detection_changed)
	detection.fully_detected.connect(_on_fully_detected)
	detection.cleared.connect(_on_cleared)
	hearing.noise_heard.connect(_on_noise_heard)
	health.died.connect(_on_died)

	# a cutscene guard can't notice the player until the cutscene hands him back
	if scripted_intro:
		detection.set_physics_process(false)

	# wait for nav mesh to load
	set_physics_process(false)

	if get_tree().get_first_node_in_group("level_generator") == null:
		await get_tree().physics_frame
		activate()


func _physics_process(delta: float):
	if not is_on_floor():
		velocity += get_gravity() * delta

	shout_timer = maxf(shout_timer - delta, 0.0)
	_look_for_bodies()

	# player last position
	if vision.sees_player:
		last_seen_position = vision.player.global_position
		tracking_timer = stats.tracking_time
	elif state == State.ALERT and tracking_timer > 0:
		# Just lost sight while chasing, still know where player is
		tracking_timer -= delta
		last_seen_position = vision.player.global_position

	match state:
		State.PATROL:
			_patrol(delta)
		State.SUSPICIOUS:
			_suspicious(delta)
		State.SEARCHING:
			_searching(delta)
		State.ALERT:
			_alert(delta)
		State.SCRIPTED:
			_scripted(delta)

	move_and_slide()
	_check_stuck(delta)


# STATES


func _patrol(delta):
	if patrol_points.is_empty():
		# no route: walk back to where we started and face the way we were placed
		if not nav_agent.is_navigation_finished():
			_move_along_path(stats.walk_speed, delta)
		else:
			_stop()
			global_rotation.y = lerp_angle(global_rotation.y, home_facing, delta * 4.0)
		return

	if wait_timer > 0:
		# stand at patrol point
		wait_timer -= delta
		_stop()
		if wait_timer <= 0:
			_go_to_next_point()
	elif nav_agent.is_navigation_finished():
		# start waiting
		wait_timer = stats.wait_time
	else:
		_move_along_path(stats.walk_speed, delta)

func _suspicious(delta):
	# Stand still and stare at where we saw something
	_stop()
	_face_direction(last_seen_position - global_position, delta)

func _searching(delta):
	if not nav_agent.is_navigation_finished():
		# run if we're answering a shout or heading for a body
		_move_along_path(stats.chase_speed if search_hurry else stats.walk_speed, delta)
		return

	# Arrived at the last seen spot, turn slowly on the spot, then give up
	_stop()
	rotation.y += delta * 1.5
	search_timer -= delta
	if search_timer <= 0:
		_change_state(State.PATROL)

func _alert(delta):
	# Only repath when the target has moved a bit, not every frame
	if nav_agent.target_position.distance_to(last_seen_position) > 0.5:
		nav_agent.target_position = last_seen_position

	# Look at the target, not along the path, so the vision cone stays on them
	var to_target = last_seen_position - global_position
	to_target.y = 0
	_face_direction(to_target, delta)

	if to_target.length() < stats.catch_distance:
		_stop()
		melee.try_attack()
	else:
		_move_along_path(stats.chase_speed, delta, false)

func _change_state(new_state):
	if new_state == state:
		return
	print("Guard: ", State.keys()[state], " -> ", State.keys()[new_state])
	state = new_state

	# settup
	match state:
		State.PATROL:
			was_alerted = false
			wait_timer = 0.0
			_go_to_next_point()
		State.SEARCHING:
			nav_agent.target_position = last_seen_position
			search_timer = stats.search_time
			search_hurry = false
		State.ALERT:
			was_alerted = true
			_shout()


# MOVEMENT


func _move_along_path(speed, delta, face_path = true):
	if nav_agent.is_navigation_finished():
		_stop()
		return
	# walk toward next corner of path
	var next_pos = nav_agent.get_next_path_position()
	var direction = next_pos - global_position
	direction.y = 0
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if face_path:
		_face_direction(direction, delta)

func activate():
	# a cutscene guard is started by end_script() instead, when the cutscene is done with him
	if scripted_intro:
		return
	home_position = global_position
	home_facing = global_rotation.y
	set_physics_process(true)
	_go_to_next_point()

func _stop():
	velocity.x = 0
	velocity.z = 0

# A guard walking somewhere that stops making progress (caught on a corner, or heading
# for a spot the navmesh can't quite reach) gives up on it instead of freezing forever.
func _check_stuck(delta):
	# only matters while walking a path: not while standing still on purpose, staring
	# (SUSPICIOUS), or chasing (an ALERT guard stops at the player and lets its meter decide)
	var walking = not nav_agent.is_navigation_finished() and wait_timer <= 0.0 \
		and (state == State.PATROL or state == State.SEARCHING)
	if not walking or global_position.distance_to(stuck_check_position) > 0.3:
		stuck_check_position = global_position
		stuck_timer = 0.0
		return

	stuck_timer += delta
	if stuck_timer >= stuck_time:
		stuck_timer = 0.0
		# treat where we are as "arrived": a patrol waits here then carries on to its
		# next point, and a search looks around from here
		nav_agent.target_position = global_position

func _go_to_next_point():
	# drop patrol points that no longer exist (e.g. a roaming route through a removed room)
	var valid_points: Array[Marker3D] = []
	for point in patrol_points:
		if is_instance_valid(point):
			valid_points.append(point)
	patrol_points = valid_points

	if patrol_points.is_empty():
		# no route at all: head home and stand guard there (see _patrol)
		nav_agent.target_position = home_position
		return

	# the route may have got shorter since last time
	patrol_index = patrol_index % patrol_points.size()
	nav_agent.target_position = patrol_points[patrol_index].global_position
	patrol_index = (patrol_index + 1) % patrol_points.size()

func _face_direction(direction, delta):
	if direction.length() < 0.01:
		return
	# turn so that -z (forward) points to direction
	var target_angle = atan2(-direction.x, -direction.z)
	global_rotation.y = lerp_angle(global_rotation.y, target_angle, delta * 8.0)


# CUTSCENE CONTROL (used by IntroSequence)


func begin_script():
	state = State.SCRIPTED
	detection.set_physics_process(false)
	set_physics_process(true)

func walk_to(target: Vector3):
	script_facing = null
	script_walking = true
	nav_agent.target_position = target

func turn_to(angle: float):
	script_facing = angle

# hand the guard back to his normal AI. activate() stores where he is now and the way
# he's facing as home, so with no patrol points he stands guard right here
func end_script():
	scripted_intro = false
	script_walking = false
	script_facing = null
	state = State.PATROL
	detection.set_physics_process(true)
	activate()

func _scripted(delta):
	if script_walking:
		if nav_agent.is_navigation_finished():
			script_walking = false
			_stop()
			arrived.emit()
		else:
			_move_along_path(stats.walk_speed, delta)
		return
	_stop()
	if script_facing != null:
		global_rotation.y = lerp_angle(global_rotation.y, script_facing, delta * 4.0)


# DETECTION


func _on_detection_changed(amount):
	vision.show_alertness(amount)
	if amount > 0.0 and (state == State.PATROL or state == State.SEARCHING):
		if was_alerted:
			# Recently chased you, recognises you instantly
			detection.force_detect()
		else:
			_change_state(State.SUSPICIOUS)

func _on_fully_detected():
	if state == State.SCRIPTED:
		return
	_change_state(State.ALERT)

func _on_cleared():
	# Meter fully drained, go and check where we last saw them
	if state == State.SUSPICIOUS or state == State.ALERT:
		_change_state(State.SEARCHING)


# HEARING


func _on_noise_heard(noise_position, _strength, kind):
	# already chasing, in a cutscene, or dead: a noise doesn't change anything
	if state == State.ALERT or state == State.SCRIPTED or state == State.DEAD:
		return

	if kind == &"shout":
		_hear_shout(noise_position)
		return

	if state == State.SUSPICIOUS:
		# already staring at the player: a noise is worse information, so ignore it
		if vision.sees_player:
			return
		# suspicious but lost sight: turn toward the new noise instead, and stay suspicious
		# (when the meter drains, the search goes to this noise)
		last_seen_position = noise_position
		return

	last_seen_position = noise_position
	if state == State.SEARCHING:
		nav_agent.target_position = noise_position
		search_timer = stats.search_time
	else:
		_change_state(State.SEARCHING)


# HEALTH AND DAMAGE


func take_damage(amount):
	health.take_damage(amount)
	# getting shot means you know exactly where the shooter is
	if health.current_health > 0:
		last_seen_position = vision.player.global_position
		detection.force_detect()



# TAKEDOWN AND DEATH


# can this attacker take us down right now? Only from behind, close, and not while we're chasing them
func can_be_taken_down(attacker: Node3D) -> bool:
	if state == State.ALERT or state == State.SCRIPTED or state == State.DEAD:
		return false
	var to_attacker = attacker.global_position - global_position
	to_attacker.y = 0.0
	if to_attacker.length() > takedown_range:
		return false
	var forward = -global_transform.basis.z
	forward.y = 0.0
	return rad_to_deg(forward.angle_to(to_attacker)) >= takedown_angle

# called by the player (duck typing, like interact()); returns true if it worked
func takedown(attacker: Node3D) -> bool:
	if not can_be_taken_down(attacker):
		return false
	# straight to 0 health, without take_damage()'s "I've been shot, I know where you are"
	# reaction; then a small scuffle (after dying, so only OTHER guards can hear it)
	health.take_damage(health.current_health)
	NoiseHelper.make(get_tree(), global_position, takedown_noise)
	return true

# shot or taken down: leave a body behind (later, other guards could find it)
func _on_died():
	_change_state(State.DEAD)
	set_physics_process(false)
	velocity = Vector3.ZERO
	# stop seeing, hearing, attacking and lighting the place up; other guards can find us now
	remove_from_group("enemy")
	add_to_group("body")
	hearing.remove_from_group("hearing")
	detection.set_physics_process(false)
	vision.set_physics_process(false)
	vision.set_cone_visibility(false)
	melee.set_physics_process(false)
	lantern.visible = false
	# nothing collides with the body (you can walk over it, rays and bullets pass through)
	collision_layer = 0
	animator.play_death()


# ALARM: finding bodies and shouting for help


# a guard on patrol or searching who sees a body he hasn't seen yet raises the alarm
func _look_for_bodies():
	if state != State.PATROL and state != State.SEARCHING:
		return
	for body in get_tree().get_nodes_in_group("body"):
		if body in known_bodies:
			continue
		# a body's origin is at its old standing height; look at the floor where it lies
		if vision.can_see_point(body.global_position + Vector3.DOWN * 0.5):
			known_bodies.append(body)
			_on_body_found(body)
			return

func _on_body_found(body: Node3D):
	print("Guard: found a body")
	# on edge for the rest of the level: he spots you twice as fast from now on
	detection.alarmed = true
	was_alerted = true
	_shout()
	_search_in_a_hurry(body.global_position)

# a shout from another guard: run over there, ready to recognise the player at a glance
func _hear_shout(shout_position: Vector3):
	# our own shout
	if shout_position.distance_to(global_position) < 1.5:
		return
	print("Guard: heard a shout")
	was_alerted = true
	_search_in_a_hurry(shout_position)

func _search_in_a_hurry(target: Vector3):
	last_seen_position = target
	_change_state(State.SEARCHING)
	# (if we were already searching, _change_state didn't set these up, so always do it here)
	nav_agent.target_position = target
	search_timer = stats.search_time
	search_hurry = true

# call for help; guards in earshot come running
func _shout():
	if shout_timer > 0.0:
		return
	shout_timer = shout_cooldown
	print("Guard: shouts for help")
	NoiseHelper.make(get_tree(), global_position + Vector3.UP * 0.8, shout_loudness, &"shout")


# DEBUG


func get_debug_info() -> Dictionary:
	return {"state": State.keys()[state], "on edge": detection.alarmed}
