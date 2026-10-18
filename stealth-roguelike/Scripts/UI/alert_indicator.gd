class_name AlertIndicator extends Label3D

# The "?" / "!" over a guard's head, driven straight by its DetectionComponent:
# a "?" that grows and shifts yellow -> orange as the meter fills, and a red "!" that pops
# in when it's full. Pure display: the guard's script never touches it.

@export var detection: DetectionComponent

func _ready():
	visible = false
	detection.detection_changed.connect(_on_detection_changed)
	detection.fully_detected.connect(_on_fully_detected)

func _on_detection_changed(amount: float):
	if amount <= 0.0:
		visible = false
		return

	visible = true
	if amount >= 1.0:
		text = "!"
		modulate = Color.RED
	else:
		text = "?"
		modulate = Color.YELLOW.lerp(Color.ORANGE_RED, amount)
		scale = Vector3.ONE * lerp(0.4, 1.0, amount)

func _on_fully_detected():
	# pop in
	scale = Vector3.ONE * 0.1
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
