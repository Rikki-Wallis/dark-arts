class_name ManaComponent extends Node

# The player's mana: refills in darkness, drains in light.

signal mana_changed(current, max_mana)

@export var max_mana: float = 100.0
@export var regen_in_darkness: float = 12.0   # mana per second while hidden in darkness
@export var drain_in_light: float = 6.0       # mana per second while standing in light
@export var light_detector: LightDetector

var current_mana: float

func _ready():
	current_mana = max_mana

func _physics_process(delta):
	# the real light around you, so Shadow Cloak doesn't count as darkness here
	var in_light = light_detector.raw_light_level > 0.0
	var rate = -drain_in_light if in_light else regen_in_darkness
	_set_mana(current_mana + rate * delta)

func can_afford(amount: float) -> bool:
	return current_mana >= amount

func spend(amount: float):
	_set_mana(current_mana - amount)

func _set_mana(value: float):
	var new_value = clamp(value, 0.0, max_mana)
	# only tell the HUD when it actually changed (not every frame at full or empty)
	if not is_equal_approx(new_value, current_mana):
		current_mana = new_value
		mana_changed.emit(current_mana, max_mana)
