class_name ActionBlockFlash
extends Control

## Brief BLOCK shock flash on each blocked ACTION strike — low opacity, does not cover the fight.

signal flash_finished

const FONT := preload("res://assets/Panton-BlackCaps.otf")
const FLASH_PEAK_ALPHA := 0.3
const FLASH_IN_SEC := 0.05
const FLASH_OUT_SEC := 0.3

@export var flash_peak_alpha := FLASH_PEAK_ALPHA
@export var flash_in_sec := FLASH_IN_SEC
@export var flash_out_sec := FLASH_OUT_SEC

var _active_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


static func spawn_on(layer: CanvasLayer) -> ActionBlockFlash:
	if layer == null:
		return null
	for child in layer.get_children():
		if child is ActionBlockFlash:
			return child as ActionBlockFlash
	var flash := ActionBlockFlash.new()
	layer.add_child(flash)
	_prepare_full_screen(flash)
	return flash


static func ensure_on(parent: Control) -> ActionBlockFlash:
	if parent == null:
		return null
	for child in parent.get_children():
		if child is ActionBlockFlash:
			return child as ActionBlockFlash
	var flash := ActionBlockFlash.new()
	parent.add_child(flash)
	_prepare_full_screen(flash)
	return flash


static func _prepare_full_screen(flash: ActionBlockFlash) -> void:
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.offset_left = 0.0
	flash.offset_top = 0.0
	flash.offset_right = 0.0
	flash.offset_bottom = 0.0
	flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	flash.grow_vertical = Control.GROW_DIRECTION_BOTH
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 100


func play_block_flash(defender_is_player: bool) -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	visible = true
	modulate.a = 0.0
	for child in get_children():
		child.queue_free()
	var panel := _build_panel(defender_is_player)
	add_child(panel)
	_set_full_rect(panel)
	_active_tween = create_tween()
	_active_tween.tween_property(self, "modulate:a", flash_peak_alpha, flash_in_sec)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_active_tween.tween_property(self, "modulate:a", 0.0, flash_out_sec)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_callback(_on_flash_done)


func _build_panel(defender_is_player: bool) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_set_full_rect(center)
	var label := Label.new()
	label.text = "BLOCKED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 108)
	var accent := Color(0.45, 0.82, 1.0, 1.0) if defender_is_player else Color(1.0, 0.55, 0.38, 1.0)
	label.add_theme_color_override("font_color", accent)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.12, 0.85))
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.custom_minimum_size = Vector2(520, 200)
	center.add_child(label)
	var shock := create_tween()
	shock.tween_property(label, "scale", Vector2(1.08, 1.08), flash_in_sec)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	shock.tween_property(label, "scale", Vector2.ONE, flash_out_sec * 0.65)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return root


func _set_full_rect(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH
	node.grow_vertical = Control.GROW_DIRECTION_BOTH


func _on_flash_done() -> void:
	visible = false
	_active_tween = null
	flash_finished.emit()
