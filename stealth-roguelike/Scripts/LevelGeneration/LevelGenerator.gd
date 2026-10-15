class_name LevelGenerator extends Node3D

@export var start_room: PackedScene
@export var exit_room: PackedScene
@export var room_pool: Array[PackedScene] = [] # rooms the generator picks from, Adding duplicates of rooms makes it more commonly picked
@export var room_count: int = 8          
@export var level_seed: int = 0          
@export var max_attempts: int = 300     
@export var max_retries: int = 10 

@onready var rooms_parent: Node3D = $NavigationRegion3D/Rooms
@onready var player: Node3D = get_tree().get_first_node_in_group("player")

var rng = RandomNumberGenerator.new()
var placed_rooms: Array[Room] = []
var open_doorways: Array[Doorway] = []

func _ready():
	var base_seed = level_seed if level_seed != 0 else randi()
	for retry in max_retries:
		rng.seed = base_seed + retry
		if _generate():
			print("Level generated: seed %d, %d rooms" % [rng.seed, placed_rooms.size()])
			_spawn_player()
			return
		_clear()
	push_error("LevelGenerator: couldn't build a level after %d tries" % max_retries)

func _generate() -> bool:
	var start = _spawn_room(start_room)
	start.global_transform = Transform3D.IDENTITY
	placed_rooms.append(start)
	open_doorways.append_array(start.get_doorways())

	# grow the level one room at a time
	var attempts = 0
	while placed_rooms.size() < room_count + 1 and attempts < max_attempts and not open_doorways.is_empty():
		attempts += 1
		var target = open_doorways[rng.randi_range(0, open_doorways.size() - 1)]
		var scene = room_pool[rng.randi_range(0, room_pool.size() - 1)]
		_try_attach(scene, target)

	if not _attach_exit():
		return false

	# anything still open gets a wall
	for doorway in open_doorways:
		doorway.seal()
	return true

# Try to snap a new room onto an open doorway. Returns the room, or null if it didn't fit.
func _try_attach(scene: PackedScene, target: Doorway) -> Room:
	var room = _spawn_room(scene)
	var doorways = room.get_doorways()

	# try each of the new room's doorways, starting from a random one
	var first = rng.randi_range(0, doorways.size() - 1)
	for i in doorways.size():
		var doorway = doorways[(first + i) % doorways.size()]
		_align(room, doorway, target)
		if _overlaps(room):
			continue

		# it fits: connect the two doorways and keep the room
		doorway.connected = true
		target.connected = true
		open_doorways.erase(target)
		for other in doorways:
			if other != doorway:
				open_doorways.append(other)
		placed_rooms.append(room)
		return room

	room.free()
	return null

# Move and turn room so doorway sits exactly on target, facing back the other way.
func _align(room: Room, doorway: Doorway, target: Doorway):
	# where the new doorway needs to end up: on the target, turned 180 degrees
	var wanted = target.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	# where the doorway is inside its own room
	var doorway_in_room = room.global_transform.affine_inverse() * doorway.global_transform
	room.global_transform = wanted * doorway_in_room.affine_inverse()

func _overlaps(room: Room) -> bool:
	var bounds = room.get_world_bounds()
	for other in placed_rooms:
		if bounds.intersects(other.get_world_bounds()):
			return true
	return false

# put the exit on the open doorway furthest from the start, so the player has to cross the level
func _attach_exit() -> bool:
	var start_pos = placed_rooms[0].global_position
	var candidates = open_doorways.duplicate()
	candidates.sort_custom(func(a, b): return a.global_position.distance_to(start_pos) > b.global_position.distance_to(start_pos))
	for doorway in candidates:
		if _try_attach(exit_room, doorway):
			return true
	return false

func _spawn_room(scene: PackedScene) -> Room:
	var room = scene.instantiate() as Room
	assert(room != null, "LevelGenerator: a room scene's root is missing room.gd")
	rooms_parent.add_child(room)
	return room

func _spawn_player():
	var spawn = placed_rooms[0].find_child("PlayerSpawn", true, false)
	if spawn and player:
		player.global_transform = spawn.global_transform

# throw away a failed level before retrying
func _clear():
	for room in placed_rooms:
		room.free()
	placed_rooms.clear()
	open_doorways.clear()
