extends CanvasLayer

@onready var resume_button = $Dim/CenterContainer/VBoxContainer/ResumeButton
@onready var menu_button = $Dim/CenterContainer/VBoxContainer/MenuButton
@onready var quit_button = $Dim/CenterContainer/VBoxContainer/QuitButton

func _ready():
	visible = false
	resume_button.pressed.connect(_resume)
	menu_button.pressed.connect(_to_menu)
	quit_button.pressed.connect(get_tree().quit)

func _unhandled_input(event):
	if event.is_action_pressed("Pause"):
		if get_tree().paused:
			_resume()
		else:
			_pause()
		# stop the player from also reacting to this key press
		get_viewport().set_input_as_handled()

func _pause():
	get_tree().paused = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	resume_button.grab_focus()

func _resume():
	get_tree().paused = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _to_menu():
	# unpause first, or the main menu would start frozen
	get_tree().paused = false
	Game.go_to_menu()
