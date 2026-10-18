extends StaticBody3D

# which doors this key opens
@export var key_id: StringName = &"cell_key"

func interact(player):
	player.add_key(key_id)
	print("Picked up ", key_id)
	queue_free()
