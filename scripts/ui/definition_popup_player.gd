class_name DefinitionPopupPlayer
extends CanvasLayer

## Screen-bottom definition bar: WORD - sense, optional continuation row, ◀ ▶ / , . keys.

signal definition_shown(word: String, definition: String, sense_index: int)

const DefinitionServiceScript := preload("res://scripts/word_game/definition_service.gd")
const DEFINITION_FONT := preload("res://assets/PTSans-Bold.ttf")
const PANEL_PAD_X := 28.0
const PANEL_STYLE_PAD_H := 28.0
const SPLIT_WIDTH_MARGIN := 8.0
const ROW1_MAX_INNER_RATIO := 0.62

@export var idle_seconds := 4.0
@export var fade_seconds := 0.35
@export var below_platform_offset := 112.0
@export var bottom_margin := 140.0
@export var max_panel_width := 1100.0
@export var viewport_width_ratio := 0.9
@export var compact_width_threshold := 820.0
@export var compact_height_threshold := 460.0

const BASE_FONT_SIZE := 20
const COMPACT_FONT_SIZE := 17
const NARROW_FONT_SIZE := 18

var definitions: DefinitionService = DefinitionServiceScript.new()

var _screen_root: Control
var _panel: PanelContainer
var _content: VBoxContainer
var _row: HBoxContainer
var _prev_button: Button
var _next_button: Button
var _primary_label: Label
var _continuation_label: Label
var _current_word := ""
var _senses: PackedStringArray = PackedStringArray()
var _sense_index := 0
var _idle_timer := 0.0
var _fade_tween: Tween
var _is_fading := false
var _show_token := 0
var _last_layout_width := -1.0
var _last_font_size := -1
var _anchor_world := Vector2.ZERO
var _has_platform_anchor := false
var _layout_sync_queued := false


func _ready() -> void:
	layer = 24
	if not definitions.load_definitions():
		push_warning(definitions.error_message)
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		return
	_sync_panel_position()
	if not _is_fading and _idle_timer > 0.0:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_begin_fade_out()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_on_viewport_size_changed()


func _on_viewport_size_changed() -> void:
	if _panel == null or not _panel.visible or _current_word.is_empty():
		return
	_last_layout_width = -1.0
	_refresh_row()


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or _is_fading or _idle_timer <= 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_COMMA:
			_show_previous_sense()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_PERIOD:
			_show_next_sense()
			get_viewport().set_input_as_handled()


func bind_player_words(word_controller: WordGameController) -> void:
	if word_controller == null:
		return
	if not word_controller.valid_word_submitted.is_connected(_on_player_valid_word):
		word_controller.valid_word_submitted.connect(_on_player_valid_word)


func set_anchor_world_position(world_position: Vector2) -> void:
	_anchor_world = world_position
	_has_platform_anchor = true
	if _panel != null and _panel.visible:
		_sync_panel_position()


func show_definition(word: String) -> void:
	var senses := definitions.get_senses(word)
	if senses.is_empty():
		return
	_show_token += 1
	_cancel_fade_tween()
	_is_fading = false
	_current_word = word
	_senses = senses
	_sense_index = 0
	_last_layout_width = -1.0
	_last_font_size = -1
	_panel.visible = true
	_panel.modulate.a = 1.0
	_refresh_row()
	_reset_idle_timer()
	definition_shown.emit(word, _senses[_sense_index], _sense_index)


func _on_player_valid_word(word: String, _word_length: int, _score_delta: int) -> void:
	show_definition(word)


func _show_previous_sense() -> void:
	if _senses.size() <= 1:
		return
	_sense_index = (_sense_index - 1 + _senses.size()) % _senses.size()
	_refresh_row()
	_reset_idle_timer()
	definition_shown.emit(_current_word, _senses[_sense_index], _sense_index)


func _show_next_sense() -> void:
	if _senses.size() <= 1:
		return
	_sense_index = (_sense_index + 1) % _senses.size()
	_refresh_row()
	_reset_idle_timer()
	definition_shown.emit(_current_word, _senses[_sense_index], _sense_index)


func _reset_idle_timer() -> void:
	_idle_timer = idle_seconds


func _refresh_row() -> void:
	var has_many := _senses.size() > 1
	_prev_button.visible = has_many
	_next_button.visible = has_many
	_apply_display_text(_current_word, _senses[_sense_index])


func _apply_display_text(word: String, sense: String) -> void:
	var metrics := _layout_metrics()
	var max_content_width: float = metrics.content_width
	_apply_responsive_font(metrics.font_size)
	if absf(max_content_width - _last_layout_width) > 1.0:
		_last_layout_width = max_content_width

	_panel.custom_minimum_size = Vector2.ZERO
	_content.custom_minimum_size = Vector2.ZERO
	_row.custom_minimum_size = Vector2.ZERO

	var split := _split_display_text(word, sense, metrics.font_size)
	_primary_label.text = split[0]
	var continuation: String = split[1]
	_continuation_label.text = continuation
	var has_continuation := not continuation.is_empty()
	_continuation_label.visible = has_continuation
	_primary_label.custom_minimum_size.x = 0
	_primary_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var panel_width := _measure_panel_width(split, metrics)
	_apply_panel_width(panel_width)
	if has_continuation:
		_row.custom_minimum_size.x = _panel_inner_width(panel_width)
	else:
		_row.custom_minimum_size.x = 0
	_queue_layout_sync()


func _queue_layout_sync() -> void:
	if not is_inside_tree():
		return
	_content.update_minimum_size()
	_panel.update_minimum_size()
	if _layout_sync_queued:
		return
	_layout_sync_queued = true
	call_deferred("_sync_panel_layout")


func _sync_panel_layout() -> void:
	_layout_sync_queued = false
	if _panel == null or not _panel.visible:
		return
	if _continuation_label.visible and not _continuation_label.text.is_empty():
		var inner_width := _panel_inner_width(_panel.custom_minimum_size.x)
		var wrapped_height := _measure_wrapped_height(
			_continuation_label.text,
			inner_width,
			_continuation_label.get_theme_font_size("font_size"),
		)
		_continuation_label.custom_minimum_size.y = maxf(wrapped_height, 1.0)
	else:
		_continuation_label.custom_minimum_size.y = 0.0
	_panel.update_minimum_size()
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	if panel_size == Vector2.ZERO:
		panel_size = _panel.size
	_panel.size = panel_size
	_sync_panel_position()


func _measure_panel_width(split: Array[String], metrics: Dictionary) -> float:
	var font_size: int = metrics.font_size
	var max_panel_width_px: float = metrics.content_width + PANEL_PAD_X
	var row1_width := _measure_text_at(split[0], font_size)
	var nav_width := 0.0
	if _prev_button.visible:
		nav_width = (
			_prev_button.custom_minimum_size.x
			+ _next_button.custom_minimum_size.x
			+ float(_row.get_theme_constant("separation")) * 2.0
		)
	var row_width := row1_width
	if nav_width > 0.0:
		row_width += nav_width + float(_row.get_theme_constant("separation")) * 2.0
	var text_width := row_width
	if not split[1].is_empty():
		text_width = maxf(row_width, _measure_text_at(split[1], font_size))
	return clampf(text_width + PANEL_PAD_X + PANEL_STYLE_PAD_H, 120.0, max_panel_width_px)


func _resolve_panel_width(max_content_width: float, use_full_width: bool) -> float:
	var max_panel_width_px := max_content_width + PANEL_PAD_X
	if use_full_width:
		return max_panel_width_px
	_panel.reset_size()
	var natural := _panel.get_combined_minimum_size()
	if natural.x <= 0.0:
		natural.x = _panel.size.x
	return clampf(natural.x, 120.0, max_panel_width_px)


func _apply_panel_width(panel_width: float) -> void:
	var inner_width := _panel_inner_width(panel_width)
	_panel.custom_minimum_size.x = panel_width
	if _continuation_label.visible:
		_continuation_label.custom_minimum_size.x = inner_width
	else:
		_continuation_label.custom_minimum_size.x = 0


func _panel_inner_width(panel_width: float) -> float:
	return maxf(panel_width - PANEL_PAD_X - PANEL_STYLE_PAD_H, 80.0)


func _split_display_text(word: String, sense: String, font_size: int = BASE_FONT_SIZE) -> Array[String]:
	var cleaned := sense.strip_edges()
	if cleaned.ends_with("…"):
		cleaned = cleaned.substr(0, cleaned.length() - 1).strip_edges()
	var prefix := "%s - " % word
	var full := prefix + cleaned
	var budget := _primary_line_budget()
	if _measure_text_at(full, font_size) <= budget:
		return [full, ""]

	var sense_words := cleaned.split(" ", false)
	var line_words: PackedStringArray = PackedStringArray()
	for sense_word in sense_words:
		var trial_words := line_words.duplicate()
		trial_words.append(sense_word)
		var trial_sense := " ".join(trial_words)
		if _measure_text_at(prefix + trial_sense, font_size) <= budget:
			line_words = trial_words
		else:
			break

	if line_words.is_empty():
		return _split_display_by_characters(prefix, cleaned, budget, font_size)

	var used_count := line_words.size()
	var continuation_words := sense_words.slice(used_count)
	var continuation := " ".join(PackedStringArray(continuation_words))
	return [prefix + " ".join(line_words), continuation]


func _split_display_by_characters(
	prefix: String,
	sense: String,
	budget: float,
	font_size: int = BASE_FONT_SIZE,
) -> Array[String]:
	var chunk := ""
	for i in range(sense.length()):
		var next := chunk + sense[i]
		if _measure_text_at(prefix + next, font_size) <= budget:
			chunk = next
		else:
			break
	if chunk.is_empty() and not sense.is_empty():
		chunk = sense[0]
	var continuation := sense.substr(chunk.length()).strip_edges()
	return [prefix + chunk, continuation]


func _layout_metrics() -> Dictionary:
	var viewport := get_viewport()
	if viewport == null:
		return {
			"viewport_size": Vector2(960.0, 540.0),
			"content_width": 520.0,
			"bottom_margin": bottom_margin,
			"font_size": BASE_FONT_SIZE,
		}
	var viewport_size := viewport.get_visible_rect().size
	var width := viewport_size.x
	var height := viewport_size.y
	var is_compact := width < compact_width_threshold or height < compact_height_threshold
	var side_inset := _side_inset(width, is_compact)
	var width_ratio := 0.94 if is_compact else viewport_width_ratio
	var content_width := minf((width - side_inset * 2.0) * width_ratio, max_panel_width)
	var resolved_bottom := bottom_margin
	if is_compact:
		resolved_bottom = clampf(height * 0.09, 32.0, bottom_margin)
	var font_size := BASE_FONT_SIZE
	if width < 720.0:
		font_size = COMPACT_FONT_SIZE
	elif is_compact:
		font_size = NARROW_FONT_SIZE
	return {
		"viewport_size": viewport_size,
		"content_width": maxf(content_width, 200.0),
		"bottom_margin": resolved_bottom,
		"font_size": font_size,
	}


func _side_inset(viewport_width: float, is_compact: bool) -> float:
	if not is_compact:
		return 0.0
	return maxf(12.0, viewport_width * 0.03)


func _content_inner_width() -> float:
	return _layout_metrics().content_width


func _apply_responsive_font(font_size: int) -> void:
	if font_size == _last_font_size:
		return
	_last_font_size = font_size
	_primary_label.add_theme_font_size_override("font_size", font_size)
	_continuation_label.add_theme_font_size_override("font_size", font_size)


func _primary_line_budget() -> float:
	var inner := _content_inner_width() - PANEL_STYLE_PAD_H
	var nav := 0.0
	if _prev_button.visible:
		nav += _prev_button.custom_minimum_size.x
		nav += _next_button.custom_minimum_size.x
		nav += _row.get_theme_constant("separation") * 2.0
	var usable := inner - nav
	var readable_cap := inner * ROW1_MAX_INNER_RATIO
	return maxf(minf(usable, readable_cap) - SPLIT_WIDTH_MARGIN, 80.0)


func _measure_text_at(text: String, font_size: int) -> float:
	if text.is_empty():
		return 0.0
	return DEFINITION_FONT.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
	).x


func _measure_text(text: String, _label: Label = null) -> float:
	var font_size := BASE_FONT_SIZE
	if _primary_label:
		font_size = _primary_label.get_theme_font_size("font_size")
	return _measure_text_at(text, font_size)


func _measure_wrapped_height(text: String, width: float, font_size: int) -> float:
	if text.is_empty() or width <= 0.0:
		return 0.0
	var font := DEFINITION_FONT
	return font.get_multiline_string_size(
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		font_size,
	).y


func _label_font(_label: Label) -> Font:
	return DEFINITION_FONT


func _sync_panel_position() -> void:
	if _panel == null or _screen_root == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var metrics := _layout_metrics()
	var rect := viewport.get_visible_rect()

	var panel_size := _panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		_panel.reset_size()
		panel_size = _panel.get_combined_minimum_size()
		if panel_size == Vector2.ZERO:
			panel_size = _panel.size
		_panel.size = panel_size

	var x := rect.position.x + (rect.size.x - panel_size.x) * 0.5
	var y: float
	if _has_platform_anchor:
		var world_pos := _anchor_world + Vector2(0.0, below_platform_offset)
		var screen_pos: Vector2 = viewport.get_canvas_transform() * world_pos
		y = screen_pos.y
	else:
		y = rect.position.y + rect.size.y - panel_size.y - metrics.bottom_margin

	_panel.global_position = Vector2(x, y)


func _begin_fade_out() -> void:
	if _is_fading or not _panel.visible:
		return
	_is_fading = true
	var token := _show_token
	_cancel_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_panel, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_callback(func() -> void:
		_complete_fade(token)
	)


func _complete_fade(token: int) -> void:
	if token != _show_token or not _is_fading:
		return
	_is_fading = false
	_hide_panel()


func _hide_panel() -> void:
	_panel.visible = false
	_panel.modulate.a = 1.0
	_is_fading = false
	_current_word = ""
	_senses = PackedStringArray()
	_sense_index = 0
	_continuation_label.text = ""
	_continuation_label.visible = false
	_primary_label.text = ""


func _cancel_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _build_ui() -> void:
	_screen_root = Control.new()
	_screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_root)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_root.add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, 0.92)
	style.border_color = Color(0.55, 0.78, 1.0, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(_content)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(_row)

	_prev_button = _make_nav_button("◀", _show_previous_sense)
	_row.add_child(_prev_button)

	_primary_label = _make_text_label()
	_primary_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_row.add_child(_primary_label)

	_next_button = _make_nav_button("▶", _show_next_sense)
	_row.add_child(_next_button)

	_continuation_label = _make_text_label()
	_continuation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_continuation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continuation_label.visible = false
	_content.add_child(_continuation_label)

	_prev_button.visible = false
	_next_button.visible = false


func _make_text_label() -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", DEFINITION_FONT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
	return label


func _make_nav_button(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(36.0, 32.0)
	button.pressed.connect(func() -> void:
		callback.call()
	)
	return button
