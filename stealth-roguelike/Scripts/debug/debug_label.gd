class_name DebugLabel extends Label3D

@export var sources: Array[Node] = []
@export var start_visible: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("debug_label")
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true  # readable through walls
	font_size = 24
	outline_size = 6
	visible = start_visible

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not visible:
		return
	var lines: PackedStringArray = []
	for source in sources:
		if source and source.has_method("get_debug_info"):
			var info = source.get_debug_info()
			for key in info:
				lines.append("%s: %s" % [key, info[key]])
	text = "\n".join(lines)

func toggle():
	visible = not visible
