extends Node
# Owns the flow of the run i.e. which scen is showing and what happens on win or death.

const MAIN_MENU = "res://Scenes/UI/main_menu.tscn"
const LEVEL_SCENE = "res://Scenes/Worlds/test-level.tscn"
const END_SCENE = "res://Scenes/UI/end_screen.tscn"

var run_time = 0.0
var last_run_won = false
var running = false

func _ready():
	await get_tree().process_frame
	var scene = get_tree().current_scene
	if scene and scene.scene_file_path == LEVEL_SCENE:
		running = true
	
func _process(delta):
	if running:
		run_time += delta

func go_to_menu():
	running = false
	_change_scene(MAIN_MENU)

func start_run():
	run_time = 0.0
	running = true
	_change_scene(LEVEL_SCENE)

func level_complete():
	_end_run(true)

func player_died():
	_end_run(false)

func _end_run(won: bool):
	if not running:
		return
	
	running = false
	last_run_won = won
	_change_scene(END_SCENE)

func _change_scene(path: String):
	get_tree().call_deferred("change_scene_to_file", path)
	
	
