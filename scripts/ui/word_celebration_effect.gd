class_name WordCelebrationEffect
extends RefCounted

## Valid-word celebration: HUD anchor → screen center → hold → random off-screen exit.

enum Accent { GLIDE, PUNCH, SNAP }

const FONT_PATH := "res://assets/Panton-BlackCaps.otf"
const BASE_FONT_SIZE := 28
const OUTLINE_SIZE := 4
const ENTER_SEC := 0.48
const HOLD_SEC := 0.38
const PULSE_SEC := 0.14
const EXIT_SEC := 0.52
const DESIRED_CENTER_SCALE := 2.45
const PULSE_BOOST := 0.12
const EXIT_MARGIN := 72.0
const MAX_VIEWPORT_WIDTH_RATIO := 0.88
const MAX_VIEWPORT_HEIGHT_RATIO := 0.42
const SHADOW_OFFSET := Vector2(3.0, 4.0)
const SHADOW_ALPHA := 0.45

static var _rng := RandomNumberGenerator.new()
static var _rng_seeded := false


static func _ensure_rng() -> void:
	if _rng_seeded:
		return
	_rng.randomize()
	_rng_seeded = true


static func accent_count() -> int:
	return Accent.size()


static func accent_name(accent: Accent) -> String:
	match accent:
		Accent.GLIDE:
			return "glide"
		Accent.PUNCH:
			return "punch"
		Accent.SNAP:
			return "snap"
	return "glide"


static func pick_accent(last_accent: int) -> Accent:
	_ensure_rng()
	if last_accent < 0:
		return _rng.randi_range(0, accent_count() - 1) as Accent
	var offset := _rng.randi_range(1, accent_count() - 1)
	return ((last_accent + offset) % accent_count()) as Accent


static func play(
	layer: CanvasLayer,
	word: String,
	anchor_center: Vector2,
	screen_center: Vector2,
	text_color: Color,
	accent: Accent,
	on_finished: Callable = Callable(),
) -> void:
	if word.is_empty() or layer == null:
		if on_finished.is_valid():
			on_finished.call()
		return
	_ensure_rng()
	var viewport := layer.get_viewport().get_visible_rect()
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.top_level = true
	layer.add_child(host)
	var label := _make_label(word, text_color)
	var shadow := _make_shadow_label(label)
	host.add_child(shadow)
	host.add_child(label)
	var text_size := _measure_label(label)
	var center_scale := _fit_center_scale(text_size, viewport, DESIRED_CENTER_SCALE)
	_place_host(host, label, shadow, text_size, anchor_center, 1.0)
	label.modulate.a = 0.0
	shadow.modulate.a = 0.0
	var exit_target := _random_exit_target(screen_center, viewport)
	_play_sequence(
		host,
		label,
		shadow,
		text_size,
		anchor_center,
		screen_center,
		exit_target,
		center_scale,
		accent,
		on_finished,
	)


static func _play_sequence(
	host: Control,
	label: Label,
	shadow: Label,
	text_size: Vector2,
	anchor_center: Vector2,
	screen_center: Vector2,
	exit_target: Vector2,
	center_scale: float,
	accent: Accent,
	on_finished: Callable,
) -> void:
	var enter_trans := Tween.TRANS_QUAD
	var enter_ease := Tween.EASE_OUT
	match accent:
		Accent.PUNCH:
			enter_trans = Tween.TRANS_BACK
		Accent.SNAP:
			enter_trans = Tween.TRANS_CUBIC
			enter_ease = Tween.EASE_OUT
	var center_pos := _host_position_for_center(text_size, screen_center, center_scale)
	var pulse_scale := center_scale + PULSE_BOOST
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(host, "global_position", center_pos, ENTER_SEC)\
		.set_trans(enter_trans).set_ease(enter_ease)
	tween.tween_property(host, "scale", Vector2(center_scale, center_scale), ENTER_SEC)\
		.set_trans(enter_trans).set_ease(enter_ease)
	tween.tween_property(label, "modulate:a", 1.0, ENTER_SEC * 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(shadow, "modulate:a", SHADOW_ALPHA, ENTER_SEC * 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(HOLD_SEC * 0.45)
	var pulse := tween.chain().set_parallel(true)
	pulse.tween_property(host, "scale", Vector2(pulse_scale, pulse_scale), PULSE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if accent == Accent.PUNCH:
		pulse.tween_property(label, "modulate", Color(1.0, 0.98, 0.62, 1.0), PULSE_SEC * 0.45)
	tween.chain().tween_property(host, "scale", Vector2(center_scale, center_scale), PULSE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if accent == Accent.PUNCH:
		tween.chain().tween_property(label, "modulate", Color.WHITE, PULSE_SEC * 0.55)
	tween.chain().tween_interval(HOLD_SEC * 0.55)
	var exit_scale := maxf(center_scale * 0.42, 0.65)
	var exit := tween.chain().set_parallel(true)
	exit.tween_property(
		host,
		"global_position",
		_host_position_for_center(text_size, exit_target, exit_scale),
		EXIT_SEC,
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	exit.tween_property(host, "scale", Vector2(exit_scale, exit_scale), EXIT_SEC)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	exit.tween_property(label, "modulate:a", 0.0, EXIT_SEC)
	exit.tween_property(shadow, "modulate:a", 0.0, EXIT_SEC)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(host):
			host.queue_free()
		if on_finished.is_valid():
			on_finished.call()
	)


static func _make_shadow_label(source: Label) -> Label:
	var shadow := Label.new()
	shadow.text = source.text
	shadow.add_theme_font_override("font", source.get_theme_font("font"))
	shadow.add_theme_font_size_override("font_size", source.get_theme_font_size("font_size"))
	shadow.add_theme_color_override("font_color", Color(0.02, 0.04, 0.08, 1.0))
	shadow.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.9))
	shadow.add_theme_constant_override("outline_size", source.get_theme_constant("outline_size"))
	shadow.horizontal_alignment = source.horizontal_alignment
	shadow.vertical_alignment = source.vertical_alignment
	shadow.show_behind_parent = true
	shadow.position = SHADOW_OFFSET
	shadow.modulate.a = 0.0
	return shadow


static func _make_label(word: String, text_color: Color) -> Label:
	var label := Label.new()
	label.text = word
	label.add_theme_font_override("font", load(FONT_PATH))
	label.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.14, 0.95))
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func _measure_label(label: Label) -> Vector2:
	var font: Font = label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font != null and not label.text.is_empty():
		var size := font.get_string_size(
			label.text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			font_size,
		)
		var height := font.get_height(font_size)
		return Vector2(maxf(size.x, 8.0), maxf(height, float(font_size)))
	label.reset_size()
	return label.get_minimum_size()


static func _fit_center_scale(text_size: Vector2, viewport: Rect2, desired: float) -> float:
	if text_size.x <= 0.0 and text_size.y <= 0.0:
		return desired
	var scale := desired
	if text_size.x > 0.0:
		var scaled_w := text_size.x * scale
		var max_w := viewport.size.x * MAX_VIEWPORT_WIDTH_RATIO
		if scaled_w > max_w:
			scale = minf(scale, desired * (max_w / scaled_w))
	if text_size.y > 0.0:
		var scaled_h := text_size.y * scale
		var max_h := viewport.size.y * MAX_VIEWPORT_HEIGHT_RATIO
		if scaled_h > max_h:
			scale = minf(scale, desired * (max_h / scaled_h))
	return scale


static func _place_host(
	host: Control,
	label: Label,
	shadow: Label,
	text_size: Vector2,
	center: Vector2,
	host_scale: float,
) -> void:
	host.scale = Vector2(host_scale, host_scale)
	host.global_position = _host_position_for_center(text_size, center, host_scale)
	label.custom_minimum_size = text_size
	label.size = text_size
	if shadow != null:
		shadow.custom_minimum_size = text_size
		shadow.size = text_size


static func _host_position_for_center(text_size: Vector2, center: Vector2, host_scale: float) -> Vector2:
	return center - (text_size * host_scale * 0.5)


static func _random_exit_target(origin: Vector2, viewport: Rect2) -> Vector2:
	var angle := _rng.randf_range(0.0, TAU)
	var direction := Vector2.from_angle(angle)
	var half := viewport.size * 0.5
	var reach := 0.0
	if absf(direction.x) > 0.001:
		reach = maxf(reach, (half.x + EXIT_MARGIN) / absf(direction.x))
	if absf(direction.y) > 0.001:
		reach = maxf(reach, (half.y + EXIT_MARGIN) / absf(direction.y))
	return origin + direction * reach
