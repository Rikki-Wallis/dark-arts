class_name Spell extends Resource

# Base class for every spell. Each spell is a script that extends this and
# overrides cast(), saved as a .tres in Resources/Spells/.

@export var spell_name: String = ""
@export var cooldown: float = 2.0         # seconds before it can be cast again
@export var cast_animation: StringName = &"LeftHandCast"
@export var cast_pose_time: float = 0.4   # how long the hand holds the cast pose

# What the spell actually does. Return false if there was nothing to cast at
# (then no cooldown is used).
func cast(_controller: SpellController) -> bool:
	push_warning("Spell '%s' has no cast() of its own" % spell_name)
	return false
