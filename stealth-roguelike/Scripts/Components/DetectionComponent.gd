class_name DetectionComponent extends Node

signal detection_changed(amount)
signal fully_detected
signal cleared

@export var vision: VisionComponent
@export var detect_time_near: float = 0.5
@export var detect_time_far: float = 3.0
@export var drain_delay: float = 1.5
@export var drain_speed: float = 0.25
@export var crouch_multiplier: float = 0.5

var detection = 0.0
var is_detected = false
var drain_timer = 0.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var old_detection = detection
	
	if vision.sees_player:
		detection += delta / _time_to_detect() * _visibility_multiplier()
		drain_timer = drain_delay
	
	elif drain_timer > 0:
		drain_timer -= delta
	
	else:
		detection -= drain_speed * delta

	detection = clamp(detection, 0.0, 1.0)
	
	if detection != old_detection:
		detection_changed.emit(detection)
	
	if detection >= 1.0 and not is_detected:
		is_detected = true
		fully_detected.emit()
	elif detection <= 0.0 and old_detection > 0.0:
		is_detected = false
		cleared.emit()

func _time_to_detect() -> float:
	var distance = vision.global_position.distance_to(vision.player.head.global_position)
	var t = clamp(distance / vision.view_distance, 0.0, 1.0)
	return lerp(detect_time_near, detect_time_far, t)

func _visibility_multiplier() -> float:
	var multiplier = 1.0
	if vision.player.is_crouching:
		multiplier *= crouch_multiplier
	return multiplier
		
		
