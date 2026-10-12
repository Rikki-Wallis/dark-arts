class_name Weapon extends Resource

@export var weapon_name: String = ""
@export var damage: float = 0.0
@export var max_ammo: int = 0
@export var fire_cooldown: float = 0.3
@export var max_range: float = 50.0
@export var noise_loudness: float = 25.0
@export var weapon_model: PackedScene
@export var weapon_position: Vector3 = Vector3.ZERO
@export var hold_animation: StringName = &"RightHandGripAction"
