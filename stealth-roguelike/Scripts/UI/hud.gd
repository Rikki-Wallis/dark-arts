extends CanvasLayer

@export var health_component: HealthComponent
@export var light_detector: LightDetector
@export var weapon_controller: WeaponController
@export var spell_controller: SpellController
@export var mana_component: ManaComponent

@onready var health_bar = $HealthFrame/HealthBar
@onready var mana_bar = $ManaFrame/ManaBar
@onready var mana_frame = $ManaFrame
@onready var ammo_label = $MarginContainer/HBoxContainer/AmmoLabel 
@onready var spell_bar = $SpellBar
@onready var prompt_label = $PromptLabel

var spell_slots: Array[SpellSlotUI] = []

const MANA_FRAME_DARK = Color(0.95, 0.96, 1.0)   # white: hidden in darkness, mana filling
const MANA_FRAME_LIT = Color(1.0, 0.65, 0.3)     # warm: standing in light, mana draining

func _ready():
	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.max_health
	health_component.health_changed.connect(_on_health_changed)
	
	light_detector.light_level_changed.connect(_on_light_level_changed)
	_on_light_level_changed(light_detector.light_level) 
	
	weapon_controller.ammo_changed.connect(_on_ammo_changed)

	_build_spell_slots()
	spell_controller.spell_selected.connect(_on_spell_selected)
	spell_controller.cooldown_changed.connect(_on_cooldown_changed)
	spell_controller.spell_cast.connect(_on_spell_cast)
	_on_spell_selected(spell_controller.current_spell())

	# max_mana, not current_mana: the ManaComponent's own _ready (which fills it) runs after this one
	mana_bar.max_value = mana_component.max_mana
	mana_bar.value = mana_component.max_mana
	mana_component.mana_changed.connect(_on_mana_changed)


func _on_health_changed(current, max_hp):
	health_bar.max_value = max_hp
	# slide the health down to its new value
	create_tween().tween_property(health_bar, "value", current, 0.25)
	# brief flash: the whole bar pops toward white, then fades back
	health_bar.modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(health_bar, "modulate", Color.WHITE, 0.3)


# the mana frame glows warm while you're lit (draining) and white in darkness (filling)
func _on_light_level_changed(value):
	var style = mana_frame.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = MANA_FRAME_DARK.lerp(MANA_FRAME_LIT, value)

func _on_mana_changed(current, max_mana):
	mana_bar.max_value = max_mana
	# mana changes a little every frame, so it already moves smoothly without a tween
	mana_bar.value = current
	for slot in spell_slots:
		slot.affordable = current >= slot.spell.mana_cost

func _on_ammo_changed(current, max_ammo):
	ammo_label.text = "%d / %d" % [current, max_ammo]

# one slot per spell the controller holds, numbered for the 1/2/3 keys
func _build_spell_slots():
	for i in spell_controller.spells.size():
		var slot = SpellSlotUI.new()
		slot.spell = spell_controller.spells[i]
		slot.key_number = i + 1
		spell_bar.add_child(slot)
		spell_slots.append(slot)

func _on_spell_selected(spell):
	for slot in spell_slots:
		slot.selected = slot.spell == spell

func _on_cooldown_changed(spell, remaining, total):
	for slot in spell_slots:
		if slot.spell == spell:
			slot.cooldown_fraction = remaining / total if total > 0.0 else 0.0

func _on_spell_cast(spell):
	for slot in spell_slots:
		if slot.spell == spell:
			slot.flash()

# a short hint under the crosshair, e.g. "[E] Takedown"; empty text hides it
func set_prompt(text: String):
	if prompt_label.text == text:
		return
	prompt_label.text = text
	prompt_label.visible = text != ""
