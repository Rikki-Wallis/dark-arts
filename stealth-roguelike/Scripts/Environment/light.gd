class_name CustomLight extends Node3D

@export var light_range: float = 5.0                  
@export var angle: float = 45.0               
@export var colour: Color = Color.WHITE
@export var energy: float = 1.0
@export var attenuation: float = 0.2         
@export var angle_attenuation: float = 0.0001      
@export var show_cone: bool = false
@export var cone_opacity: float = 0.1        

func _enter_tree() -> void:
	var spotlight: SpotLight3D = $SpotLight3D
	spotlight.spot_range = light_range
	spotlight.spot_angle = angle
	spotlight.light_color = colour
	spotlight.light_energy = energy
	spotlight.spot_attenuation = attenuation
	spotlight.spot_angle_attenuation = angle_attenuation

	var cone: ClippedCone = $SpotLight3D/LightCone
	cone.visible = show_cone
	cone.cone_color = Color(colour, cone_opacity)
