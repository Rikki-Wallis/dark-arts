extends CharacterBody3D

@export var patrol_points: Array[Marker3D] = []
@export var walk_speed: float = 2.5
@export var wait_time: float = 2.0

@onready var vision = $VisionComponent
@onready var nav_agent = $NavigationAgent3D
@onready var alert_label = $AlertLabel
@onready var detection = $Components/DetectionComponent

var patrol_index = 0
var wait_timer = 0.0

func _ready():
	add_to_group("enemy")
	# wait for nav mesh to load
	set_physics_process(false)
	await get_tree().physics_frame
	set_physics_process(true)
	
	if not patrol_points.is_empty():
		_go_to_next_point()
	
	# vision
	detection.detection_changed.connect(_on_detection_changed)
	detection.fully_detected.connect(_on_fully_detected)
	
	# alert label
	alert_label.visible = false

func _physics_process(delta: float):
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if patrol_points.is_empty():
		move_and_slide()
		return
		
	if wait_timer > 0:
		# stand at patrol point
		wait_timer -= delta
		velocity.x = 0
		velocity.z = 0
		
		if wait_timer <= 0:
			_go_to_next_point()
		
	elif nav_agent.is_navigation_finished():
		# start waiting
		wait_timer = wait_time
	
	else:
		# walk toward next corner of path
		var next_pos = nav_agent.get_next_path_position()
		var direction = next_pos - global_position
		direction.y = 0
		direction = direction.normalized()
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
		_face_direction(direction, delta)
	
	move_and_slide()


func _go_to_next_point():
	nav_agent.target_position = patrol_points[patrol_index].global_position
	patrol_index = (patrol_index + 1) % patrol_points.size()


func _face_direction(direction, delta):
	if direction.length() < 0.01:
		return
	
	# turn so that -z (forward) points to direction
	var target_angle = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, delta * 8.0)
	
func _on_detection_changed(amount):
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

func _on_fully_detected():
	alert_label.scale = Vector3.ONE * 0.1
	create_tween().tween_property(alert_label, "scale", Vector3.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
