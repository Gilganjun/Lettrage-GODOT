class_name SlowMotionBannerFx
extends Control

## Small bottom-right "SLOW MOTION" flash when gameplay slow-mo starts.

const FONT := preload("res://assets/Panton-BlackCaps.otf")
const TEXT := "SLOW MOTION"
const FLASH_IN_SEC := 0.07
const FLASH_HOLD_SEC := 0.12
const FLASH_OUT_SEC := 0.28
const PULSE_COUNT := 2
const RIGHT_MARGIN := 18.0
const BOTTOM_MARGIN := 18.0

var _label: Label
var _active_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.text = TEXT
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.offset_left = -240.0
	_label.offset_top = -44.0
	_label.offset_right = -RIGHT_MARGIN
	_label.offset_bottom = -BOTTOM_MARGIN
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.modulate.a = 0.0
	add_child(_label)
	visible = true


static func ensure_on(parent: Control) -> SlowMotionBannerFx:
	if parent == null:
		return null
	for child in parent.get_children():
		if child is SlowMotionBannerFx:
			return child as SlowMotionBannerFx
	var banner := SlowMotionBannerFx.new()
	banner.name = "SlowMotionBannerFx"
	parent.add_child(banner)
	return banner


func play_flash() -> void:
	if _label == null:
		return
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_label.scale = Vector2.ONE
	_active_tween = create_tween()
	_active_tween.set_ignore_time_scale(true)
	for pulse in PULSE_COUNT:
		_active_tween.tween_property(_label, "modulate:a", 1.0, FLASH_IN_SEC)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		_active_tween.parallel().tween_property(_label, "scale", Vector2(1.06, 1.06), FLASH_IN_SEC)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_active_tween.tween_property(_label, "modulate:a", 0.35, FLASH_HOLD_SEC)
		_active_tween.parallel().tween_property(_label, "scale", Vector2.ONE, FLASH_HOLD_SEC * 0.65)
	_active_tween.tween_property(_label, "modulate:a", 0.0, FLASH_OUT_SEC)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_callback(_on_flash_done)


func _on_flash_done() -> void:
	_active_tween = null
	if _label:
		_label.modulate.a = 0.0
		_label.scale = Vector2.ONE
