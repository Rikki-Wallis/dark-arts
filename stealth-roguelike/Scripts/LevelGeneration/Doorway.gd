class_name Doorway extends Marker3D

const CAP_SCENE = preload("res://Scenes/LevelKits/door_cap.tscn")
var connected = false

func seal():
	var cap = CAP_SCENE.instantiate()
	get_parent().add_child(cap)
