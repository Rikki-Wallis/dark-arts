extends OmniLight3D

@export var flicker_amount: float = 0.3
@export var flicker_speed: float = 8.0

var base_energy: float
var noise = FastNoiseLite.new()
var time = 0.0

func _ready():
	base_energy = light_energy
	noise.seed = randi()  # each torch flickers differently

func _process(delta):
	time += delta * flicker_speed
	light_energy = base_energy + noise.get_noise_1d(time) * flicker_amount * base_energy
