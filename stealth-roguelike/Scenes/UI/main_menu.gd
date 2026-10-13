extends Control

@onready var play_button = $CenterContainer/VBoxContainer/PlayButton
@onready var quit_button = $CenterContainer/VBoxContainer/QuitButton

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	play_button.pressed.connect(Game.start_run)
	quit_button.pressed.connect(get_tree().quit)
	# so Enter / a controller can start the game without the mouse
	play_button.grab_focus()
