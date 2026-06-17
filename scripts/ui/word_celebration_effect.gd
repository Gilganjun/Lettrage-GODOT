class_name WordCelebrationEffect
extends RefCounted

## Tween presets for valid-word celebration overlays.

enum Style {
	CENTER_SLIDE,
	BIG_BOUNCE,
	PUNCH_FLASH,
	OPPONENT_SLIDE,
}

const FONT_PATH := "res://assets/Panton-BlackCaps.otf"
const OUTLINE_SIZE := 3

static func style_count() -> int:
	return Style.size()


static func style_name(style: Style) -> String:
	match style:
		Style.CENTER_SLIDE:
			return "center_slide"
		Style.BIG_BOUNCE:
			return "big_bounce"
		Style.PUNCH_FLASH:
			return "punch_flash"
		Style.OPPONENT_SLIDE:
			return "opponent_slide"
	return "center_slide"


static func pick_style(rotate: bool, last_style: int, explicit: int = -1) -> Style:
	if explicit >= 0 and explicit < style_count():
		return explicit as Style
	if not rotate:
		return Style.CENTER_SLIDE
	return ((last_style + 1) % style_count()) as Style


static func play(
	layer: CanvasLayer,
	word: String,
	anchor_center: Vector2,
	screen_center: Vector2,
	exit_target: Vector2,
	opponent_anchor: Vector2,
	text_color: Color,
	style: Style,
) -> void:
	if word.is_empty() or layer == null:
		return
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host)
	var label := _make_label(word, text_color)
	host.add_child(label)
	_layout_label(host, label, anchor_center, 1.0)
	match style:
		Style.CENTER_SLIDE:
			_play_center_slide(host, label, anchor_center, screen_center, exit_target)
		Style.BIG_BOUNCE:
			_play_big_bounce(host, label, anchor_center, screen_center, exit_target)
		Style.PUNCH_FLASH:
			_play_punch_flash(host, label, anchor_center, screen_center, exit_target)
		Style.OPPONENT_SLIDE:
			_play_opponent_slide(host, label, anchor_center, screen_center, opponent_anchor)


static func _make_label(word: String, text_color: Color) -> Label:
	var label := Label.new()
	label.text = word
	label.add_theme_font_override("font", load(FONT_PATH))
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func _layout_label(host: Control, label: Label, center: Vector2, scale: float) -> void:
	label.reset_size()
	var size := label.get_minimum_size()
	if size == Vector2.ZERO:
		size = label.size
	host.scale = Vector2(scale, scale)
	host.global_position = center - (size * scale * 0.5)


static func _center_for_label(label: Label, center: Vector2, scale: float) -> Vector2:
	var size := label.get_minimum_size()
	if size == Vector2.ZERO:
		size = label.size
	return center - (size * scale * 0.5)


static func _play_center_slide(
	host: Control,
	label: Label,
	anchor_center: Vector2,
	screen_center: Vector2,
	exit_target: Vector2,
) -> void:
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(host, "global_position", _center_for_label(label, screen_center, 2.2), 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(host, "scale", Vector2(2.2, 2.2), 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.35)
	var exit := tween.chain().set_parallel(true)
	exit.tween_property(host, "global_position", _center_for_label(label, exit_target, 0.8), 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	exit.tween_property(host, "scale", Vector2(0.8, 0.8), 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	exit.tween_property(label, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(host.queue_free)


static func _play_big_bounce(
	host: Control,
	label: Label,
	anchor_center: Vector2,
	screen_center: Vector2,
	exit_target: Vector2,
) -> void:
	var pop_pos := anchor_center + Vector2(0.0, 40.0)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(host, "global_position", _center_for_label(label, pop_pos, 3.0), 0.5)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(host, "scale", Vector2(3.0, 3.0), 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.3)
	var to_center := tween.chain().set_parallel(true)
	to_center.tween_property(host, "global_position", _center_for_label(label, screen_center, 2.0), 0.45)\
		.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	to_center.tween_property(host, "scale", Vector2(2.0, 2.0), 0.45)\
		.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	var exit := tween.chain().set_parallel(true)
	exit.tween_property(host, "global_position", _center_for_label(label, exit_target, 1.0), 0.5)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	exit.tween_property(host, "scale", Vector2(1.0, 1.0), 0.5)
	exit.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(host.queue_free)


static func _play_punch_flash(
	host: Control,
	label: Label,
	anchor_center: Vector2,
	screen_center: Vector2,
	exit_target: Vector2,
) -> void:
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(host, "global_position", _center_for_label(label, screen_center, 2.6), 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(host, "scale", Vector2(2.6, 2.6), 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(host, "scale", Vector2(2.35, 2.35), 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_property(host, "scale", Vector2(2.55, 2.55), 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_interval(0.25)
	var flash := tween.chain()
	flash.tween_property(label, "modulate", Color(1.0, 0.98, 0.55, 1.0), 0.08)
	flash.tween_property(label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
	var exit := tween.chain().set_parallel(true)
	exit.tween_property(host, "global_position", _center_for_label(label, exit_target, 0.7), 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(host.queue_free)


static func _play_opponent_slide(
	host: Control,
	label: Label,
	anchor_center: Vector2,
	screen_center: Vector2,
	opponent_anchor: Vector2,
) -> void:
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(host, "global_position", _center_for_label(label, screen_center, 2.0), 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(host, "scale", Vector2(2.0, 2.0), 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.25)
	var exit := tween.chain().set_parallel(true)
	exit.tween_property(host, "global_position", _center_for_label(label, opponent_anchor, 1.0), 0.5)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	exit.tween_property(host, "scale", Vector2(1.0, 1.0), 0.5)\
		.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	exit.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(host.queue_free)
