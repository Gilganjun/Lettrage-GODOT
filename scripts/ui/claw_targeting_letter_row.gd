class_name ClawTargetingLetterRow
extends Control

## Horizontal letter picker shown under the player during claw targeting.

const FONT_PATH := "res://assets/Panton-BlackCaps.otf"

@export var anchor_offset_y: float = 52.0
@export var slot_min_width: float = 30.0
@export var slot_height: float = 36.0
@export var slot_gap: float = 5.0
@export var max_slots: int = 14
@export var fade_speed: float = 12.0
@export var selected_slot_scale: float = 1.5
@export var selected_font_size: int = 32
@export var normal_font_size: int = 22

var _row: HBoxContainer
var _backdrop: PanelContainer
var _font: Font
var _anchor_world := Vector2.ZERO
var _active := false
var _slot_roots: Array[Control] = []
var _slots: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _slot_letter_ids: Array[int] = []
var _slot_target_alpha: Array[float] = []
var _slot_selected: Array[bool] = []
var _synced_letter_ids: Array[int] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 35
	_font = load(FONT_PATH) as Font
	_backdrop = PanelContainer.new()
	_backdrop.name = "Backdrop"
	_backdrop.visible = false
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.1, 0.82)
	panel_style.border_color = Color(0.45, 0.95, 1.0, 0.55)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 8.0
	panel_style.content_margin_right = 8.0
	panel_style.content_margin_top = 5.0
	panel_style.content_margin_bottom = 5.0
	_backdrop.add_theme_stylebox_override("panel", panel_style)
	add_child(_backdrop)
	_row = HBoxContainer.new()
	_row.name = "LetterRow"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.clip_contents = false
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", int(slot_gap))
	_backdrop.add_child(_row)
	_backdrop.clip_contents = false
	clip_contents = false
	visible = false


func show_for_targeting() -> void:
	_active = true
	visible = true
	_backdrop.visible = true


func hide_row() -> void:
	_active = false
	visible = false
	_backdrop.visible = false
	_synced_letter_ids.clear()
	_clear_slots()


func sync(
	targets: Array[Letter],
	selected_index: int,
	anchor_world: Vector2,
	structure_changed: bool = false,
) -> void:
	if not _active:
		return
	_anchor_world = anchor_world
	var clamped_index := clampi(selected_index, 0, maxi(targets.size() - 1, 0))
	var desired_ids := _target_ids(targets)
	if not structure_changed and desired_ids == _synced_letter_ids:
		_apply_selection(clamped_index)
		_update_layout()
		_update_anchor_position()
		return
	_apply_structure(targets, desired_ids, clamped_index, structure_changed)
	_synced_letter_ids = desired_ids.duplicate()
	_apply_selection(clamped_index)
	_update_layout()
	_update_anchor_position()


func _target_ids(targets: Array[Letter]) -> Array[int]:
	var ids: Array[int] = []
	var count := mini(targets.size(), max_slots)
	for i in count:
		var letter := targets[i]
		if letter != null and is_instance_valid(letter):
			ids.append(letter.get_instance_id())
	return ids


func _apply_selection(selected_index: int) -> void:
	for i in _slots.size():
		var selected := i == selected_index and _slot_target_alpha[i] > 0.01
		_slot_selected[i] = selected
		_style_slot(i, selected)


func _apply_structure(
	targets: Array[Letter],
	desired_ids: Array[int],
	selected_index: int,
	_initial_snapshot: bool,
) -> void:
	var previous_ids: Dictionary = {}
	for id in _synced_letter_ids:
		previous_ids[id] = true
	var count := desired_ids.size()
	_ensure_slot_count(count)
	for i in count:
		var letter := targets[i]
		var letter_id := desired_ids[i]
		var is_new_to_row := not previous_ids.has(letter_id)
		_slot_letter_ids[i] = letter_id
		_slot_selected[i] = i == selected_index
		if letter != null and is_instance_valid(letter):
			_labels[i].text = letter.character
		_style_slot(i, _slot_selected[i])
		_slot_roots[i].visible = true
		_slots[i].visible = true
		_slot_target_alpha[i] = 1.0
		_slots[i].modulate.a = 0.0 if is_new_to_row else 1.0
		_slot_roots[i].modulate.a = _slots[i].modulate.a
	for i in range(count, _slots.size()):
		_slot_target_alpha[i] = 0.0


func _process(delta: float) -> void:
	if not _active:
		return
	var any_fading := false
	for i in _slots.size():
		var target := _slot_target_alpha[i]
		var current := _slots[i].modulate.a
		if is_equal_approx(current, target):
			continue
		var next := move_toward(current, target, fade_speed * delta)
		_slots[i].modulate.a = next
		_labels[i].modulate.a = next
		if i < _slot_roots.size():
			_slot_roots[i].modulate.a = next
		any_fading = true
		if is_equal_approx(next, 0.0) and target <= 0.0:
			_slot_roots[i].visible = false
	if any_fading:
		_row.queue_sort()
		_update_layout()
	_update_anchor_position()


func _ensure_slot_count(count: int) -> void:
	while _slots.size() < count:
		_add_slot()
	while _slots.size() > count:
		_remove_slot_at(_slots.size() - 1)


func _add_slot() -> void:
	var root := Control.new()
	root.name = "SlotRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = false
	root.custom_minimum_size = Vector2(slot_min_width, slot_height)
	var panel := PanelContainer.new()
	panel.name = "SlotPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(slot_min_width, slot_height)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", normal_font_size)
	panel.add_child(label)
	root.add_child(panel)
	_row.add_child(root)
	_slot_roots.append(root)
	_slots.append(panel)
	_labels.append(label)
	_slot_letter_ids.append(-1)
	_slot_target_alpha.append(0.0)
	_slot_selected.append(false)


func _remove_slot_at(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var root := _slot_roots[index]
	if is_instance_valid(root):
		root.queue_free()
	_slot_roots.remove_at(index)
	_slots.remove_at(index)
	_labels.remove_at(index)
	_slot_letter_ids.remove_at(index)
	_slot_target_alpha.remove_at(index)
	_slot_selected.remove_at(index)


func _clear_slots() -> void:
	for root in _slot_roots:
		if is_instance_valid(root):
			root.queue_free()
	_slot_roots.clear()
	_slots.clear()
	_labels.clear()
	_slot_letter_ids.clear()
	_slot_target_alpha.clear()
	_slot_selected.clear()
	_synced_letter_ids.clear()


func _style_slot(index: int, selected: bool) -> void:
	if index < 0 or index >= _slots.size():
		return
	var root := _slot_roots[index]
	var panel := _slots[index]
	var label := _labels[index]
	var style := StyleBoxFlat.new()
	var footprint_w := slot_min_width
	var footprint_h := slot_height
	if selected:
		footprint_w = slot_min_width * selected_slot_scale
		footprint_h = slot_height * selected_slot_scale
		style.bg_color = Color(0.22, 0.18, 0.05, 0.95)
		style.border_color = Color(1.0, 0.92, 0.35, 1.0)
		label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35, 1.0))
		label.add_theme_font_size_override("font_size", selected_font_size)
		root.z_index = 2
	else:
		style.bg_color = Color(0.1, 0.1, 0.14, 0.88)
		style.border_color = Color(0.55, 0.62, 0.72, 0.65)
		label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92, 0.9))
		label.add_theme_font_size_override("font_size", normal_font_size)
		root.z_index = 0
	root.custom_minimum_size = Vector2(footprint_w, footprint_h)
	panel.custom_minimum_size = Vector2(slot_min_width, slot_height)
	panel.pivot_offset = Vector2(slot_min_width * 0.5, slot_height * 0.5)
	panel.scale = Vector2.ONE * (selected_slot_scale if selected else 1.0)
	panel.position = Vector2(
		(footprint_w - slot_min_width) * 0.5,
		(footprint_h - slot_height) * 0.5,
	)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", style)


func _slot_layout_width(index: int) -> float:
	if index < 0 or index >= _slot_roots.size():
		return slot_min_width
	return _slot_roots[index].custom_minimum_size.x


func _update_layout() -> void:
	if _row == null:
		return
	var visible_width := 0.0
	var visible_count := 0
	for i in _slots.size():
		if _slot_roots[i].visible or _slot_roots[i].modulate.a > 0.01:
			visible_width += _slot_layout_width(i)
			visible_count += 1
	if visible_count > 1:
		visible_width += slot_gap * float(visible_count - 1)
	var row_height := slot_height * selected_slot_scale
	var pad := Vector2(16.0, 10.0)
	_backdrop.custom_minimum_size = Vector2(visible_width, row_height) + pad
	_backdrop.reset_size()
	size = _backdrop.size


func _update_anchor_position() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var screen := viewport.get_canvas_transform() * (_anchor_world + Vector2(0.0, anchor_offset_y))
	global_position = screen - Vector2(size.x * 0.5, 0.0)
