class_name LureSpell extends Spell

# Throws a whisper to where you aim. Guards that hear it go and investigate.

@export var max_range: float = 25.0
@export var loudness: float = 12.0   # how far away (metres) the whisper can be heard

func cast(controller: SpellController) -> bool:
	var result = controller.aim_raycast(max_range)
	if result.is_empty():
		return false

	# step a little off the surface, so the wall we hit doesn't muffle the noise
	var point = result.position + result.normal * 0.3
	NoiseHelper.make(controller.get_tree(), point, loudness)
	return true
