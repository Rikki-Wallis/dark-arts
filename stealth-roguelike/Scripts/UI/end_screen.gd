extends Control

@onready var title_label = $CenterContainer/VBoxContainer/TitleLabel
@onready var time_label = $CenterContainer/VBoxContainer/TimeLabel
@onready var retry_button = $CenterContainer/VBoxContainer/RetryButton
@onready var main_menu_button = $CenterContainer/VBoxContainer/MenuButton

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	title_label.text = "You escaped" if Game.last_run_won else "You were caught"
	time_label.text = "Time: %.1f s" % Game.run_time

	retry_button.pressed.connect(Game.start_run)
	main_menu_button.pressed.connect(Game.go_to_menu)
