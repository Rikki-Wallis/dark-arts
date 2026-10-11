extends CanvasLayer

@export var health_component: HealthComponent
@export var light_detector: LightDetector

@onready var health_bar = $MarginContainer/HBoxContainer/HealthBar
@onready var light_gem = $MarginContainer/HBoxContainer/LightGem

const GEM_DARK = Color(0.05, 0.05, 0.15) 
const GEM_LIT = Color(1.0, 0.9, 0.4)      

func _ready():
	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.max_health
	health_component.health_changed.connect(_on_health_changed)
	
	light_detector.light_level_changed.connect(_on_light_level_changed)
	_on_light_level_changed(light_detector.light_level) 

func _on_health_changed(current, max_hp):
	health_bar.max_value = max_hp
	# slide bar effect
	create_tween().tween_property(health_bar, "value", current, 0.25)

func _on_light_level_changed(value):
	light_gem.color = GEM_DARK.lerp(GEM_LIT, value)
