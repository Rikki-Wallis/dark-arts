class_name FootstepComponent extends Node

# Turns a body's movement into gameplay noise (NoiseHelper) that guards can hear:
# a footstep every step_length metres on the floor (quieter crouched, louder sprinting),
# and a landing noise that grows with how fast the body hits the ground.
# The owner calls step() every physics frame, AFTER move_and_slide().

@export var body: CharacterBody3D
@export var step_length: float = 2.0       # metres walked per footstep
@export var noise_height: float = 1.0      # noises come from about chest height

@export_group("Footstep loudness")
# loudness = the radius (in metres) guards can hear it from
@export var noise_crouch: float = 1.5
@export var noise_walk: float = 5.0
@export var noise_sprint: float = 10.0

@export_group("Landing")
@export var land_silent_speed: float = 3.0    # m/s: slower landings make no noise (a drop of about 0.5 m)
@export var land_loudest_speed: float = 10.0  # m/s: landings this fast are as loud as it gets (a drop of about 5 m)
@export var noise_land_min: float = 3.0       # radius of the quietest landing that still makes a noise
@export var noise_land_max: float = 12.0      # radius of the loudest landing

var step_distance = 0.0
var was_on_floor = true

# fall_speed = how fast the body was falling (m/s, positive = down), read BEFORE
# move_and_slide(), which zeroes it on landing
func step(delta: float, fall_speed: float, crouching: bool, sprinting: bool):
	if body.is_on_floor() and not was_on_floor:
		_make_landing_noise(fall_speed)
	was_on_floor = body.is_on_floor()

	if not body.is_on_floor():
		return

	var horizontal_speed = Vector2(body.velocity.x, body.velocity.z).length()
	step_distance += horizontal_speed * delta
	if step_distance >= step_length:
		step_distance = 0.0
		if crouching:
			_make_noise(noise_crouch)
		elif sprinting:
			_make_noise(noise_sprint)
		else:
			_make_noise(noise_walk)

# small drops (and the floor flickering for a frame at a seam) are silent;
# bigger falls get louder, up to noise_land_max
func _make_landing_noise(fall_speed: float):
	if fall_speed < land_silent_speed:
		return
	var t = clampf(inverse_lerp(land_silent_speed, land_loudest_speed, fall_speed), 0.0, 1.0)
	_make_noise(lerp(noise_land_min, noise_land_max, t))

func _make_noise(loudness: float):
	NoiseHelper.make(get_tree(), body.global_position + Vector3.UP * noise_height, loudness)
