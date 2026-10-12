class_name ShadowCloakEffect extends Node

# Added as a child of the player's LightDetector by ShadowCloakSpell.
# While this node exists, the detector reports no light at all, so guards
# see the player as if they were standing in pitch darkness.

var time_left: float = 0.0

func _ready():
	get_parent().light_multiplier = 0.0

func _process(delta):
	time_left -= delta
	if time_left <= 0.0:
		queue_free()

# runs when this node is removed (cloak ran out, or the level was unloaded)
func _exit_tree():
	get_parent().light_multiplier = 1.0
