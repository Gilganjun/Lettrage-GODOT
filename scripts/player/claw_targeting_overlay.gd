class_name ClawTargetingOverlay
extends Node2D

## World-space cycle hints — alternate ◀ / ▶ chevrons beside the selected letter.

enum CycleSide { NONE, LEFT, RIGHT }

@export var arrow_half_period: float = 0.5
@export var arrow_gap: float = 12.0
@export var chevron_size: float = 14.0

var _left_chevron: Polygon2D
var _right_chevron: Polygon2D
var _flash_time := 0.0
var _active_side := CycleSide.NONE


func _ready() -> void:
	top_level = true
	z_index = 130
	_left_chevron = _make_chevron(false)
	_right_chevron = _make_chevron(true)
	hide_overlay()


func hide_overlay() -> void:
	_active_side = CycleSide.NONE
	for chevron in [_left_chevron, _right_chevron]:
		if chevron == null:
			continue
		chevron.visible = false
		chevron.hide()


func reset_flash() -> void:
	_flash_time = 0.0
	_active_side = CycleSide.NONE


func get_active_cycle_side() -> CycleSide:
	return _active_side


func tick(delta: float, selected: Letter, hints_enabled: bool) -> void:
	if not hints_enabled:
		hide_overlay()
		return
	_flash_time += delta
	if selected == null or not is_instance_valid(selected):
		hide_overlay()
		return
	var period := maxf(arrow_half_period * 2.0, 0.01)
	var show_left := fmod(_flash_time, period) < arrow_half_period
	_active_side = CycleSide.LEFT if show_left else CycleSide.RIGHT
	var letter_pos := selected.global_position
	var half_w := _letter_half_width(selected)
	var y_offset := _letter_vertical_nudge(selected)
	_place_chevron(
		_left_chevron,
		letter_pos + Vector2(-half_w - arrow_gap, y_offset),
		show_left,
	)
	_place_chevron(
		_right_chevron,
		letter_pos + Vector2(half_w + arrow_gap, y_offset),
		not show_left,
	)


func _place_chevron(chevron: Polygon2D, world_pos: Vector2, show_chevron: bool) -> void:
	chevron.visible = show_chevron
	if not show_chevron:
		return
	chevron.global_position = world_pos
	chevron.scale = Vector2.ONE
	chevron.rotation = 0.0
	chevron.color = Color(1.0, 0.93, 0.32, 1.0)


func _make_chevron(pointing_right: bool) -> Polygon2D:
	var chevron := Polygon2D.new()
	chevron.name = "ChevronRight" if pointing_right else "ChevronLeft"
	chevron.polygon = _chevron_polygon(pointing_right)
	chevron.color = Color(1.0, 0.93, 0.32, 1.0)
	add_child(chevron)
	return chevron


func _chevron_polygon(pointing_right: bool) -> PackedVector2Array:
	var s := chevron_size
	if pointing_right:
		return PackedVector2Array([
			Vector2(-s * 0.55, -s),
			Vector2(s * 0.75, 0.0),
			Vector2(-s * 0.55, s),
		])
	return PackedVector2Array([
		Vector2(s * 0.55, -s),
		Vector2(-s * 0.75, 0.0),
		Vector2(s * 0.55, s),
	])


func _letter_half_width(letter: Letter) -> float:
	var sprite := letter.get_sprite()
	if sprite == null or sprite.texture == null:
		return 22.0
	var tex_size := sprite.texture.get_size() * letter.get_display_scale()
	return maxf(18.0, tex_size.x * 0.52)


func _letter_vertical_nudge(letter: Letter) -> float:
	var sprite := letter.get_sprite()
	if sprite == null or sprite.texture == null:
		return 0.0
	var tex_size := sprite.texture.get_size() * letter.get_display_scale()
	return -tex_size.y * 0.04
