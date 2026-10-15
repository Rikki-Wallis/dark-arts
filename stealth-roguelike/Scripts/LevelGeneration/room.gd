class_name Room extends Node3D

@export var size: Vector3 = Vector3(12, 3, 12)
@export var center: Vector3 = Vector3(0, 1.5, 0)

func get_doorways() -> Array[Doorway]:
	var doorways: Array[Doorway] = []
	for node in find_children("*", "Marker3D", true, false):
		if node is Doorway:
			doorways.append(node)
	return doorways

# the footprint as a box in world space, for overlap checks
func get_world_bounds() -> AABB:
	var local = AABB(center - size / 2.0, size)
	return global_transform * local
