class_name DefinitionPopupPlayer
extends CanvasLayer

## Definition bar near the bottom: WORD - sense, with optional continuation row and ◀ ▶ / , . keys.

signal definition_shown(word: String, definition: String, sense_index: int)

const DefinitionServiceScript := preload("res://scripts/word_game/definition_service.gd")

@export var idle_seconds := 4.0
@export var fade_seconds := 0.35
@export var bottom_margin := 80.0
@export var max_panel_width := 1100.0
@export var viewport_width_ratio := 0.9
@export var compact_width_threshold := 820.0
@export var compact_height_threshold := 460.0

const BASE_FONT_SIZE := 20
const COMPACT_FONT_SIZE := 17
const NARROW_FONT_SIZE := 18

var definitions: DefinitionService = DefinitionServiceScript.new()

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


func _ready() -> void:
	layer = 24
	if not definitions.load_definitions():
		push_warning(definitions.error_message)
	_build_ui()


func _process(delta: float) -> void:
	if _panel == null:
		return
	if _panel.visible:
		_position_panel()
		if not _is_fading and _idle_timer > 0.0:
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_begin_fade_out()


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
	_refresh_row()
	_panel.visible = true
	_panel.modulate.a = 1.0
	_reset_idle_timer()
	_position_panel()
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
	_apply_responsive_font()
	var split := _split_display_text(word, sense)
	_primary_label.text = split[0]
	var continuation: String = split[1]
	_continuation_label.text = continuation
	_continuation_label.visible = not continuation.is_empty()
	var content_width := _content_inner_width()
	_continuation_label.custom_minimum_size.x = content_width


func _split_display_text(word: String, sense: String) -> Array[String]:
	var prefix := "%s - " % word
	var full := prefix + sense
	var budget := _primary_line_budget()
	if _measure_text(full, _primary_label) <= budget:
		return [full, ""]
	var sense_words := sense.split(" ", false)
	var line_words: PackedStringArray = PackedStringArray()
	for sense_word in sense_words:
		var trial_words := line_words.duplicate()
		trial_words.append(sense_word)
		var trial_sense := " ".join(trial_words)
		if _measure_text(prefix + trial_sense, _primary_label) <= budget:
			line_words = trial_words
		else:
			break
	if line_words.is_empty():
		return _split_display_by_characters(prefix, sense, budget)
	var used_count := line_words.size()
	var continuation_words := sense_words.slice(used_count)
	var continuation := " ".join(PackedStringArray(continuation_words))
	return [prefix + " ".join(line_words), continuation]


func _split_display_by_characters(prefix: String, sense: String, budget: float) -> Array[String]:
	var chunk := ""
	for i in range(sense.length()):
		var next := chunk + sense[i]
		if _measure_text(prefix + next, _primary_label) <= budget:
			chunk = next
		else:
			break
	if chunk.is_empty() and not sense.is_empty():
		chunk = sense[0]
	var continuation := sense.substr(chunk.length()).strip_edges()
	return [prefix + chunk, continuation]


func _content_inner_width() -> float:
	var metrics := _layout_metrics()
	return metrics.content_width


func _layout_metrics() -> Dictionary:
	var viewport := get_viewport()
	if viewport == null:
		return {
			"rect": Rect2(Vector2.ZERO, Vector2(960.0, 540.0)),
			"content_width": 520.0,
			"bottom_margin": bottom_margin,
			"side_inset": 0.0,
			"font_size": BASE_FONT_SIZE,
		}
	var rect := viewport.get_visible_rect()
	var width := rect.size.x
	var height := rect.size.y
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
		"rect": rect,
		"content_width": maxf(content_width, 200.0),
		"bottom_margin": resolved_bottom,
		"side_inset": side_inset,
		"font_size": font_size,
	}


func _side_inset(viewport_width: float, is_compact: bool) -> float:
	if not is_compact:
		return 0.0
	return maxf(12.0, viewport_width * 0.03)


func _apply_responsive_font() -> void:
	var font_size: int = _layout_metrics().font_size
	if font_size == _last_font_size:
		return
	_last_font_size = font_size
	_primary_label.add_theme_font_size_override("font_size", font_size)
	_continuation_label.add_theme_font_size_override("font_size", font_size)


func _primary_line_budget() -> float:
	var budget := _content_inner_width()
	if _prev_button.visible:
		budget -= _prev_button.custom_minimum_size.x
		budget -= _next_button.custom_minimum_size.x
		budget -= _row.get_theme_constant("separation") * 2.0
	return maxf(budget, 120.0)


func _measure_text(text: String, label: Label) -> float:
	if text.is_empty():
		return 0.0
	var font: Font = label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font == null:
		return float(text.length()) * 10.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


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
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

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
	_row.add_child(_primary_label)

	_next_button = _make_nav_button("▶", _show_next_sense)
	_row.add_child(_next_button)

	_continuation_label = _make_text_label()
	_continuation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_continuation_label.visible = false
	_content.add_child(_continuation_label)

	_prev_button.visible = false
	_next_button.visible = false


func _make_text_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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


func _position_panel() -> void:
	if _panel == null or not _panel.visible:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var metrics := _layout_metrics()
	var content_width: float = metrics.content_width
	var font_size: int = metrics.font_size
	if (
		absf(content_width - _last_layout_width) > 1.0
		or font_size != _last_font_size
	) and not _current_word.is_empty() and _sense_index < _senses.size():
		_last_layout_width = content_width
		_apply_display_text(_current_word, _senses[_sense_index])
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	if panel_size == Vector2.ZERO:
		panel_size = _panel.size
	var rect: Rect2 = metrics.rect
	var side_inset: float = metrics.side_inset
	var resolved_bottom: float = metrics.bottom_margin
	var usable_width := rect.size.x - side_inset * 2.0
	var x := rect.position.x + side_inset + (usable_width - panel_size.x) * 0.5
	var y := rect.position.y + rect.size.y - panel_size.y - resolved_bottom
	_panel.global_position = Vector2(x, y)
