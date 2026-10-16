extends CharacterBody3D

enum State { PATROL, SUSPICIOUS, SEARCHING, ALERT }

@export var patrol_points: Array[Marker3D] = []

@export var idle_anim: StringName = &"Idle"
@export var death_anim: StringName = &"Death"
@export var walk_anim: StringName = &"Walk"
@export var run_anim: StringName = &"Run"
# one of these is picked at random for each attack (they must not loop)
@export var attack_anims: Array[StringName] = [&"Punch_Left", &"Punch_Right", &"Kick_Left", &"Kick_Right"]
@export var attack_hit_delay: float = 0.3   # seconds into the attack when the hit lands
# if the guard is following a path but hasn't really moved for this long, it gives up on that spot
@export var stuck_time: float = 1.5

@export var outline_material: Material

# vision cone colour: calm at an empty detection meter, alarmed at a full one
@export var cone_calm_color: Color = Color(1.0, 0.9, 0.2)
@export var cone_alert_color: Color = Color(1.0, 0.1, 0.1)

@onready var vision = $VisionComponent
@onready var nav_agent = $NavigationAgent3D
@onready var alert_label = $AlertLabel
@onready var detection = $Components/DetectionComponent
@onready var stats = $Components/EnemyStats
@onready var hearing = $HearingComponent
@onready var health = $Components/HealthComponent
@onready var model_anim: AnimationPlayer = $Model/AnimationPlayer


var state = State.PATROL
var patrol_index = 0
var wait_timer = 0.0
var search_timer = 0.0
var last_seen_position = Vector3.ZERO
var tracking_timer = 0.0
var was_alerted = false
var attack_timer = 0.0
var hit_timer = 0.0   # counts down to the moment an attack connects; 0 = no attack in progress
# where the guard started, so it has somewhere to return to without a patrol route
var home_position = Vector3.ZERO
var home_facing = 0.0
# the cone's see-through amount, kept from the scene so only its colour changes
var cone_alpha = 0.15
# stuck detection: where we last made real progress, and how long since
var stuck_check_position = Vector3.ZERO
var stuck_timer = 0.0

func _ready():
	add_to_group("enemy")
	alert_label.visible = false

	detection.detection_changed.connect(_on_detection_changed)
	detection.fully_detected.connect(_on_fully_detected)
	detection.cleared.connect(_on_cleared)
	hearing.noise_heard.connect(_on_noise_heard)
	health.died.connect(_on_died)
	_apply_outline()

	# the VisionComponent (a child) has already found its cone by now
	if vision.cone:
		cone_alpha = vision.cone.cone_color.a
	_update_cone_colour(0.0)

	# wait for nav mesh to load
	set_physics_process(false)
	
	if get_tree().get_first_node_in_group("level_generator") == null:
		await get_tree().physics_frame
		activate()


func _physics_process(delta: float):
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if attack_timer > 0:
		attack_timer -= delta
	_update_attack_hit(delta)

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

	move_and_slide()
	_check_stuck(delta)
	_update_animation()


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
		_move_along_path(stats.walk_speed, delta)
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
		_try_attack()
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
		State.ALERT:
			was_alerted = true


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


# DETECTION


func _on_detection_changed(amount):
	_update_alert_label(amount)
	_update_cone_colour(amount)
	if amount > 0.0 and (state == State.PATROL or state == State.SEARCHING):
		if was_alerted:
			# Recently chased you, recognises you instantly
			detection.force_detect()
		else:
			_change_state(State.SUSPICIOUS)


func _on_fully_detected():
	alert_label.scale = Vector3.ONE * 0.1
	create_tween().tween_property(alert_label, "scale", Vector3.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_change_state(State.ALERT)

func _on_cleared():
	# Meter fully drained, go and check where we last saw them
	if state == State.SUSPICIOUS or state == State.ALERT:
		_change_state(State.SEARCHING)

func _update_alert_label(amount):
	if amount <= 0.0:
		alert_label.visible = false
		return

	alert_label.visible = true
	if amount >= 1.0:
		alert_label.text = "!"
		alert_label.modulate = Color.RED
	else:
		alert_label.text = "?"
		alert_label.modulate = Color.YELLOW.lerp(Color.ORANGE_RED, amount)
		alert_label.scale = Vector3.ONE * lerp(0.4, 1.0, amount)

# the cone shifts from calm yellow to alarmed red as the detection meter fills
# (and back again as it drains), so the player can read how close they are to being caught
func _update_cone_colour(amount):
	var colour = cone_calm_color.lerp(cone_alert_color, amount)
	vision.set_cone_colour(Color(colour, cone_alpha))


# HEARING


func _on_noise_heard(noise_position, _strength):
	# already chasing: a noise doesn't change anything
	if state == State.ALERT:
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

func _on_died():
	queue_free()


# ATTACK


func _try_attack():
	# only hit what we can actually see, never through a wall
	if attack_timer > 0 or not vision.sees_player:
		return

	# a different punch or kick each time, so attacks don't look repetitive
	if not attack_anims.is_empty():
		model_anim.play(attack_anims.pick_random(), 0.1)
	attack_timer = stats.attack_cooldown
	# the hit itself lands a moment later, counted down in _physics_process; if the guard
	# dies before then it stops processing, so a hit can never land after it's gone
	hit_timer = attack_hit_delay

func _update_attack_hit(delta):
	if hit_timer <= 0.0:
		return
	hit_timer -= delta
	if hit_timer > 0.0:
		return
	# the attack connects now, but only if the player is still in view and within reach
	# (they might have dodged away during the wind-up)
	# (measured flat along the ground, like _alert's reach check)
	var to_player = vision.player.global_position - global_position
	to_player.y = 0.0
	if vision.sees_player and to_player.length() <= stats.catch_distance + 0.5:
		vision.player.take_damage(stats.attack_damage)


# ANIMATION


func _update_animation():
	
	# let an attack play through before going back to walking or idling
	if model_anim.current_animation in attack_anims:
		return
	
	var speed = Vector2(velocity.x, velocity.z).length()
	var anim_name = idle_anim
	if speed > stats.walk_speed + 0.5:
		anim_name = run_anim
	elif speed > 0.1:
		anim_name = walk_anim
	
	if model_anim.current_animation != anim_name:
		model_anim.play(anim_name, 0.2)


# SHADER


func _apply_outline():
	if outline_material == null:
		return
	for mesh in $Model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = outline_material


# DEBUG


func get_debug_info() -> Dictionary:
	return {"state": State.keys()[state]}
