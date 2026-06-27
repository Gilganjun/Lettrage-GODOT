class_name DefinitionPopupPlayer
extends CanvasLayer

## Single-row definition bar near the bottom of the screen: WORD - sense, with ◀ ▶ and , . keys.

signal definition_shown(word: String, definition: String, sense_index: int)

const DefinitionServiceScript := preload("res://scripts/word_game/definition_service.gd")

@export var idle_seconds := 4.0
@export var fade_seconds := 0.35
@export var bottom_margin := 80.0

var definitions: DefinitionService = DefinitionServiceScript.new()

var _panel: PanelContainer
var _row: HBoxContainer
var _prev_button: Button
var _next_button: Button
var _text_label: Label
var _current_word := ""
var _senses: PackedStringArray = PackedStringArray()
var _sense_index := 0
var _idle_timer := 0.0
var _fade_tween: Tween


func _ready() -> void:
	layer = 24
	if not definitions.load_definitions():
		push_warning(definitions.error_message)
	_build_ui()


func _process(delta: float) -> void:
	if _panel and _panel.visible:
		_position_panel()
	if not _panel.visible or _idle_timer <= 0.0:
		return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_fade_out()


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or _idle_timer <= 0.0:
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
	_stop_fade()
	_current_word = word
	_senses = senses
	_sense_index = 0
	_refresh_row()
	_panel.visible = true
	_panel.modulate.a = 1.0
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
	_text_label.text = "%s - %s" % [_current_word, _senses[_sense_index]]


func _fade_out() -> void:
	_stop_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_panel, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_callback(_hide_panel)


func _hide_panel() -> void:
	_panel.visible = false
	_panel.modulate.a = 1.0
	_current_word = ""
	_senses = PackedStringArray()
	_sense_index = 0


func _stop_fade() -> void:
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

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(_row)

	_prev_button = _make_nav_button("◀", _show_previous_sense)
	_row.add_child(_prev_button)

	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.clip_text = true
	_text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_text_label.custom_minimum_size = Vector2(520.0, 0.0)
	_text_label.add_theme_font_size_override("font_size", 20)
	_text_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
	_row.add_child(_text_label)

	_next_button = _make_nav_button("▶", _show_next_sense)
	_row.add_child(_next_button)

	_prev_button.visible = false
	_next_button.visible = false


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
	if _panel == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	if panel_size == Vector2.ZERO:
		panel_size = _panel.size
	var viewport_rect := viewport.get_visible_rect()
	var x := (viewport_rect.size.x - panel_size.x) * 0.5
	var y := viewport_rect.size.y - panel_size.y - bottom_margin
	_panel.global_position = Vector2(x, y)
