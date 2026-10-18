class_name IntroSequence extends Node

# The start room's intro: a guard walks in and drops food into the cell, then turns to
# leave and, without noticing, drops the cell key outside the bars (within reach through
# them if you crouch). He goes to stand at the doorway with his back to the cell. The
# player can look around but not move until it's done. SkipCutscene jumps straight to the end.

@export var guard: Node3D             # the guard who brings the food (Scripted Intro ticked)
@export var cell_front: Marker3D      # where he stands to drop the food (its -Z faces the cell)
@export var guard_post: Marker3D      # where he waits afterwards (its -Z = where he looks)
@export var key_drop: Marker3D        # where the key lands, outside the cell
@export var food: Node3D              # hidden until he drops it into the cell
@export var key_scene: PackedScene    # key_pickup.tscn
@export var start_delay: float = 1.5  # seconds before he walks in
@export var hand_over_time: float = 2.0
@export var key_slip_delay: float = 0.4  # seconds after he turns to leave that the key falls
@export var post_turn_time: float = 1.0

var player
var running = false
var finished = false
var food_dropped = false
var key_dropped = false

func _ready():
	food.visible = false
	# in a generated level, wait until the navmesh is baked; otherwise start straight away
	var generator = get_tree().get_first_node_in_group("level_generator")
	if generator:
		generator.level_ready.connect(_start, CONNECT_ONE_SHOT)
	else:
		await get_tree().physics_frame
		_start()

func _unhandled_input(event):
	if running and event.is_action_pressed("SkipCutscene"):
		_skip()

func _start():
	player = get_tree().get_first_node_in_group("player")
	player.controls_locked = true
	running = true
	guard.begin_script()

	# after every pause, stop if the player skipped meanwhile
	await get_tree().create_timer(start_delay).timeout
	if finished: return
	guard.walk_to(cell_front.global_position)
	await guard.arrived
	if finished: return
	guard.turn_to(cell_front.global_rotation.y)

	await get_tree().create_timer(hand_over_time).timeout
	if finished: return
	_drop_food()

	await get_tree().create_timer(1.0).timeout
	if finished: return
	# he turns to leave, and the key slips off his belt as he does
	var to_post = guard_post.global_position - guard.global_position
	guard.turn_to(atan2(-to_post.x, -to_post.z))
	await get_tree().create_timer(key_slip_delay).timeout
	if finished: return
	_drop_key()
	await get_tree().create_timer(0.3).timeout
	if finished: return
	guard.walk_to(guard_post.global_position)
	await guard.arrived
	if finished: return
	guard.turn_to(guard_post.global_rotation.y)

	await get_tree().create_timer(post_turn_time).timeout
	if finished: return
	_finish()

# the tray is pushed in through the bars at hand height and drops to the floor
func _drop_food():
	if food_dropped:
		return
	food_dropped = true
	food.visible = true
	var rest_y = food.position.y
	food.position.y = rest_y + 1.0
	create_tween().tween_property(food, "position:y", rest_y, 0.35) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# the key falls straight down from the guard's belt (at his side) and bounces on the
# floor. key_drop gives the floor height, and is where the key appears on a skip
func _drop_key(animate = true):
	if key_dropped:
		return
	key_dropped = true
	var key = key_scene.instantiate()
	key_drop.add_child(key)
	if not animate:
		return
	# beside his hip; the key's origin sits about 0.3 m below the model, hence the -0.3
	var side = guard.global_transform.basis.x * 0.3
	key.global_position = guard.global_position + side + Vector3(0.0, -0.3, 0.0)
	# only the height is animated, so it drops straight down
	create_tween().tween_property(key, "global_position:y", key_drop.global_position.y, 0.5) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# jump straight to the end: food and key dropped, guard at his post
func _skip():
	# the key just appears where it lands (he may not have walked in yet)
	_drop_food()
	_drop_key(false)
	var post = guard_post.global_position
	guard.global_position = Vector3(post.x, guard.global_position.y, post.z)
	guard.global_rotation.y = guard_post.global_rotation.y
	_finish()

func _finish():
	if finished:
		return
	finished = true
	running = false
	player.controls_locked = false
	guard.end_script()
