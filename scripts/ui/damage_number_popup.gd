class_name DamageNumberPopup
extends Control

## Floating "-10" style damage readout — lingers on the victim, then rises to the health bar.

const FONT := preload("res://assets/Panton-BlackCaps.otf")

## Screen-space offsets so rapid hits fan out instead of stacking.
const SLOT_OFFSETS: Array[Vector2] = [
	Vector2(0.0, -14.0),
	Vector2(-50.0, -30.0),
	Vector2(50.0, -30.0),
	Vector2(-68.0, 2.0),
	Vector2(68.0, 2.0),
	Vector2(-40.0, 24.0),
	Vector2(40.0, 24.0),
	Vector2(0.0, 36.0),
]

@export var linger_duration := 2.0
@export var travel_duration := 2.0
@export var hold_before_fade := 0.55
@export var fade_duration := 0.75
@export var pop_duration := 0.26
@export var fade_in_duration := 0.22
@export var font_size := 36

var _rng := RandomNumberGenerator.new()


static func slot_count() -> int:
	return SLOT_OFFSETS.size()


static func spawn(
	layer: Control,
	amount: int,
	start_screen: Vector2,
	target_screen: Vector2,
	color: Color,
	slot_index: int = 0,
) -> void:
	if layer == null or amount <= 0:
		return
	var popup := DamageNumberPopup.new()
	layer.add_child(popup)
	popup._play(amount, start_screen, target_screen, color, slot_index)


func _play(
	amount: int,
	start_screen: Vector2,
	target_screen: Vector2,
	color: Color,
	slot_index: int,
) -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 20 + (slot_index % slot_count())
	var slot_offset := SLOT_OFFSETS[slot_index % SLOT_OFFSETS.size()]
	var micro_jitter := Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-3.0, 3.0))
	var from_pos := start_screen + slot_offset + micro_jitter
	var label := _build_label(amount, color)
	add_child(label)
	_fit_centered_label(label)
	position = from_pos
	scale = Vector2(0.55, 0.55)
	modulate.a = 0.0
	_animate(from_pos, target_screen)


func _build_label(amount: int, color: Color) -> Label:
	var label := Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02, 0.92))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _fit_centered_label(label: Label) -> void:
	label.reset_size()
	var size := label.get_combined_minimum_size()
	label.custom_minimum_size = size
	label.size = size
	label.position = -size * 0.5


func _animate(from_pos: Vector2, target_pos: Vector2) -> void:
	var travel_begin := fade_in_duration + linger_duration
	var fade_delay := travel_begin + travel_duration + hold_before_fade

	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(self, "modulate:a", 1.0, fade_in_duration).set_ease(Tween.EASE_OUT)
	intro.tween_property(self, "scale", Vector2(1.1, 1.1), pop_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var linger := create_tween()
	linger.tween_property(self, "scale", Vector2.ONE, 0.12).set_delay(0.06)
	linger.parallel().tween_method(
		func(t: float) -> void:
			position = from_pos + Vector2(0.0, lerpf(0.0, -10.0, t)),
		0.0,
		1.0,
		linger_duration,
	).set_delay(fade_in_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	var motion := create_tween()
	motion.tween_method(
		func(t: float) -> void:
			var linger_end := from_pos + Vector2(0.0, -10.0)
			position = linger_end.lerp(target_pos, t),
		0.0,
		1.0,
		travel_duration,
	).set_delay(travel_begin).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	motion.parallel().tween_property(self, "modulate:a", 0.0, fade_duration)\
		.set_delay(fade_delay).set_ease(Tween.EASE_IN)
	motion.tween_callback(queue_free)
