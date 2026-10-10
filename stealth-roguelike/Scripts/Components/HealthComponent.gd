class_name HealthComponent extends Node

# signals
signal health_changed(current, max)
signal died

@export var max_health: float = 100.0
var current_health: float

func _ready() -> void:
	current_health = max_health

func take_damage(amount: float):
	if current_health <= 0:
		return
	
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	
	if current_health == 0:
		died.emit()

func heal(amount: float):
	if current_health <= 0:
		return
	
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
