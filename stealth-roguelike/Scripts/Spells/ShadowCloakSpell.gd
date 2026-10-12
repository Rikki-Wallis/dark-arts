class_name ShadowCloakSpell extends Spell

# Wraps the player in shadow for a while: they count as standing in total
# darkness, even under a torch. It hides you from eyes, not ears.

@export var duration: float = 6.0

func cast(controller: SpellController) -> bool:
	var detector: LightDetector = controller.owner.light_detector

	# casting again while cloaked just refreshes the timer
	var existing = detector.get_node_or_null("ShadowCloakEffect")
	if existing:
		existing.time_left = duration
		return true

	var effect = ShadowCloakEffect.new()
	effect.name = "ShadowCloakEffect"
	effect.time_left = duration
	detector.add_child(effect)
	return true
