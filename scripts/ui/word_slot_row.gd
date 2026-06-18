extends Control
class_name WordSlotRow

## Framed letter slots for combat HUD word display.

@export var max_slots := 6
@export var slot_size := Vector2(30, 34)
@export var filled_style: StyleBoxFlat
@export var empty_style: StyleBoxFlat
@export var font_size := 18

@onready var row: HBoxContainer = $Row

var _font: Font
var _built := false


func _ready() -> void:
	_font = load("res://assets/Panton-BlackCaps.otf")
	_ensure_styles()
	_build_slots()
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _ensure_styles() -> void:
	if filled_style == null:
		filled_style = StyleBoxFlat.new()
		filled_style.bg_color = Color(0.08, 0.07, 0.05, 0.88)
		filled_style.border_color = Color(0.92, 0.76, 0.28, 1.0)
		filled_style.set_border_width_all(2)
		filled_style.set_corner_radius_all(4)
		filled_style.content_margin_left = 2
		filled_style.content_margin_right = 2
		filled_style.content_margin_top = 1
		filled_style.content_margin_bottom = 1
	if empty_style == null:
		empty_style = filled_style.duplicate()
		empty_style.bg_color = Color(0.05, 0.05, 0.07, 0.55)
		empty_style.border_color = Color(0.45, 0.42, 0.38, 0.75)


func _build_slots() -> void:
	if _built:
		return
	_built = true
	for child in row.get_children():
		child.queue_free()
	var gap := 3
	for i in max_slots:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = slot_size
		panel.add_theme_stylebox_override("panel", empty_style.duplicate())
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_font_override("font", _font)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.55, 1.0))
		label.text = "_"
		panel.add_child(label)
		row.add_child(panel)
	custom_minimum_size = Vector2(
		max_slots * slot_size.x + (max_slots - 1) * gap,
		slot_size.y,
	)


func set_word(word: String, accent: Color = Color(0.95, 0.92, 0.55, 1.0)) -> void:
	if not _built:
		_build_slots()
	var slots := row.get_children()
	var shown := word.substr(0, max_slots)
	for i in slots.size():
		var panel := slots[i] as PanelContainer
		var label := panel.get_child(0) as Label
		if i < shown.length():
			label.text = shown[i]
			panel.add_theme_stylebox_override("panel", filled_style)
			label.add_theme_color_override("font_color", accent)
		else:
			label.text = "_"
			panel.add_theme_stylebox_override("panel", empty_style)
			label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48, 0.8))


func get_slot_center(slot_index: int) -> Vector2:
	var slots := row.get_children()
	if slot_index < 0 or slot_index >= slots.size():
		return global_position
	var panel := slots[slot_index] as Control
	return panel.get_global_rect().get_center()


func get_trailing_slot_center(word_length: int) -> Vector2:
	return get_slot_center(clampi(word_length, 0, max_slots - 1))
