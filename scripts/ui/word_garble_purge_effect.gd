class_name WordGarblePurgeEffect
extends RefCounted

## Explodes HUD letters outward, then drops them off-screen.

const FONT_PATH := "res://assets/Panton-BlackCaps.otf"
const LETTER_COLOR := Color(0.95, 0.97, 0.2, 1.0)
const MESSAGE_COLOR := Color(1.0, 0.72, 0.45, 1.0)
const MESSAGE_HOLD_SEC := 5.0
const MESSAGE_FADE_IN_SEC := 0.2
const MESSAGE_FADE_OUT_SEC := 0.4
const LETTER_ANIM_FINISH_SEC := 1.55


static func play(
	layer: CanvasLayer,
	word: String,
	letter_positions: PackedVector2Array,
	message: String,
	message_anchor: Vector2,
	on_letters_finished: Callable,
) -> void:
	if layer == null or word.is_empty():
		if on_letters_finished.is_valid():
			on_letters_finished.call()
		return
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host)
	var viewport := layer.get_viewport().get_visible_rect()
	var fall_target_y := viewport.end.y + 80.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in word.length():
		var ch := word.substr(i, 1)
		var label := _make_letter_label(ch)
		host.add_child(label)
		var pos := letter_positions[i] if i < letter_positions.size() else letter_positions[0]
		var size := label.get_minimum_size()
		label.position = pos - size * 0.5
		var burst := Vector2(rng.randf_range(-110.0, 110.0), rng.randf_range(20.0, 90.0))
		var spin := deg_to_rad(rng.randf_range(-220.0, 220.0))
		var fall_time := rng.randf_range(0.75, 1.15)
		var delay := float(i) * 0.02
		var burst_pos := label.position + burst
		var fall_pos := Vector2(burst_pos.x + rng.randf_range(-36.0, 36.0), fall_target_y)
		var tween := host.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(label, "position", burst_pos, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "rotation", spin, 0.14)
		tween.tween_property(label, "position", fall_pos, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(label, "modulate:a", 0.0, fall_time * 0.85)
		tween.parallel().tween_property(label, "scale", Vector2(0.65, 0.65), fall_time)
	var message_label := _make_message_label(message)
	host.add_child(message_label)
	message_label.position = message_anchor
	message_label.modulate.a = 0.0
	message_label.scale = Vector2(0.92, 0.92)
	var msg_tween := host.create_tween()
	msg_tween.tween_property(message_label, "modulate:a", 1.0, MESSAGE_FADE_IN_SEC)
	msg_tween.parallel().tween_property(message_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	msg_tween.tween_interval(MESSAGE_HOLD_SEC)
	msg_tween.tween_property(message_label, "modulate:a", 0.0, MESSAGE_FADE_OUT_SEC)
	var letters_done := host.create_tween()
	letters_done.tween_interval(LETTER_ANIM_FINISH_SEC)
	letters_done.tween_callback(func():
		if on_letters_finished.is_valid():
			on_letters_finished.call()
	)
	var host_done := host.create_tween()
	host_done.tween_interval(MESSAGE_FADE_IN_SEC + MESSAGE_HOLD_SEC + MESSAGE_FADE_OUT_SEC + 0.05)
	host_done.tween_callback(host.queue_free)


static func _make_letter_label(character: String) -> Label:
	var label := Label.new()
	label.text = character
	label.add_theme_font_override("font", load(FONT_PATH))
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", LETTER_COLOR)
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.45, 0.25, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func _make_message_label(message: String) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(420.0, 0.0)
	label.add_theme_font_override("font", load(FONT_PATH))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", MESSAGE_COLOR)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
