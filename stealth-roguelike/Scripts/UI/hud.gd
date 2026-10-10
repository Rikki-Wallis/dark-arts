extends CanvasLayer

@export var health_component: HealthComponent
@onready var health_bar = $MarginContainer/HealthBar

func _ready():
	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.max_health
	health_component.health_changed.connect(_on_health_changed)

func _on_health_changed(current, max_hp):
	health_bar.max_value = max_hp
	# slide bar effect
	create_tween().tween_property(health_bar, "value", current, 0.25)
