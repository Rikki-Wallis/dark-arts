class_name SpellSlotUI extends Control

# One spell slot on the HUD: navy body, white frame (bold when selected),
# white cooldown that drains from the top, key number, and icon or initial.

@export var line_color: Color = Color(0.9, 0.92, 1.0)
@export var body_color: Color = Color(0.07, 0.1, 0.26)

var spell: Spell
var key_number = 1

var selected = false:
	set(value):
		selected = value
		queue_redraw()

# false while the player doesn't have enough mana for this spell
var affordable = true:
	set(value):
		affordable = value
		queue_redraw()

# 1 = just cast, 0 = ready
var cooldown_fraction = 0.0:
	set(value):
		cooldown_fraction = clamp(value, 0.0, 1.0)
		queue_redraw()

func _ready():
	custom_minimum_size = Vector2(56, 56)

# a quick pulse when this spell is cast
func flash():
	modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)

func _draw():
	var box = Rect2(Vector2.ZERO, size)
	var font = get_theme_default_font()

	# body, then the cooldown: white covering the top part, shrinking as it recharges
	draw_rect(box, body_color)
	if cooldown_fraction > 0.0:
		draw_rect(Rect2(0, 0, size.x, size.y * cooldown_fraction), line_color)

	# icon if the spell has one, otherwise its first letter; faded when you can't afford it
	var ink = Color(line_color, 1.0 if affordable else 0.3)
	if spell and spell.icon:
		draw_texture_rect(spell.icon, box.grow(-10), false, Color(1, 1, 1, ink.a))
	elif spell:
		var letter = spell.spell_name.left(1)
		var baseline = Vector2(0, size.y * 0.5 + 10)
		# navy outline first, so the letter shows on both the navy body and the white cooldown
		draw_string_outline(font, baseline, letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, 6, body_color)
		draw_string(font, baseline, letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, ink)

	# frame and key number: bright and bold when selected, thin and dim otherwise
	var frame_color = line_color if selected else Color(line_color, 0.4)
	draw_rect(box, frame_color, false, 3.0 if selected else 1.0)
	draw_string(font, Vector2(4, 14), str(key_number), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, frame_color)
