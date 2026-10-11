extends CharacterBody3D

enum State { PATROL, SUSPICIOUS, SEARCHING, ALERT }

@export var patrol_points: Array[Marker3D] = []

@onready var vision = $VisionComponent
@onready var nav_agent = $NavigationAgent3D
@onready var alert_label = $AlertLabel
@onready var detection = $Components/DetectionComponent
@onready var stats = $Components/EnemyStats
@onready var hearing = $HearingComponent

var state = State.PATROL
var patrol_index = 0
var wait_timer = 0.0
var search_timer = 0.0
var last_seen_position = Vector3.ZERO
var tracking_timer = 0.0
var was_alerted = false

func _ready():
	add_to_group("enemy")
	alert_label.visible = false

	detection.detection_changed.connect(_on_detection_changed)
	detection.fully_detected.connect(_on_fully_detected)
	detection.cleared.connect(_on_cleared)

	# wait for nav mesh to load
	set_physics_process(false)
	await get_tree().physics_frame
	set_physics_process(true)

	if not patrol_points.is_empty():
		_go_to_next_point()
	
	hearing.noise_heard.connect(_on_noise_heard)

func _physics_process(delta: float):
	if not is_on_floor():
		velocity += get_gravity() * delta

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


# STATES


func _patrol(delta):
	if patrol_points.is_empty():
		_stop()
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


func _stop():
	velocity.x = 0
	velocity.z = 0

func _go_to_next_point():
	nav_agent.target_position = patrol_points[patrol_index].global_position
	patrol_index = (patrol_index + 1) % patrol_points.size()

func _face_direction(direction, delta):
	if direction.length() < 0.01:
		return
	# turn so that -z (forward) points to direction
	var target_angle = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, delta * 8.0)


# DETECTION


func _on_detection_changed(amount):
	_update_alert_label(amount)
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


# HEARING


func _on_noise_heard(noise_position, _strength):
	if state == State.ALERT:
		return

	last_seen_position = noise_position
	if state == State.SEARCHING:
		nav_agent.target_position = noise_position
		search_timer = stats.search_time
	else:
		_change_state(State.SEARCHING)


# DEBUG


func get_debug_info() -> Dictionary:
	return {"state": State.keys()[state]}
