extends CanvasLayer

@export var health_component: HealthComponent
@export var light_detector: LightDetector
@export var weapon_controller: WeaponController
@export var spell_controller: SpellController

@onready var health_bar = $HealthFrame/HealthBar
@onready var ammo_label = $MarginContainer/HBoxContainer/AmmoLabel 
@onready var spell_bar = $SpellBar

var spell_slots: Array[SpellSlotUI] = []

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


func _on_health_changed(current, max_hp):
	health_bar.max_value = max_hp
	# slide the health down to its new value
	create_tween().tween_property(health_bar, "value", current, 0.25)
	# brief flash: the whole bar pops toward white, then fades back
	health_bar.modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(health_bar, "modulate", Color.WHITE, 0.3)


func _on_light_level_changed(value):
	pass

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
