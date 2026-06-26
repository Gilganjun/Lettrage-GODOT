class_name DefinitionPopupPlayer
extends CanvasLayer

## Shows a brief definition popup when the player submits a valid word.

signal definition_shown(word: String, definition: String)

const DefinitionServiceScript := preload("res://scripts/word_game/definition_service.gd")

@export var display_seconds := 4.0
@export var bottom_margin := 140.0

var definitions: RefCounted = DefinitionServiceScript.new()

var _panel: PanelContainer
var _word_label: Label
var _definition_label: Label
var _hide_timer := 0.0


func _ready() -> void:
	layer = 24
	if not definitions.load_definitions():
		push_warning(definitions.error_message)
	_build_ui()


func _process(delta: float) -> void:
	if _hide_timer <= 0.0:
		return
	_hide_timer -= delta
	if _hide_timer <= 0.0:
		_panel.visible = false


func bind_player_words(word_controller: WordGameController) -> void:
	if word_controller == null:
		return
	if not word_controller.valid_word_submitted.is_connected(_on_player_valid_word):
		word_controller.valid_word_submitted.connect(_on_player_valid_word)


func show_definition(word: String) -> void:
	var definition := definitions.get_definition(word)
	if definition.is_empty():
		return
	_word_label.text = word
	_definition_label.text = definition
	_panel.visible = true
	_position_panel()
	_hide_timer = display_seconds
	definition_shown.emit(word, definition)


func _on_player_valid_word(word: String, _word_length: int, _score_delta: int) -> void:
	show_definition(word)


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
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)

	_word_label = Label.new()
	_word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word_label.add_theme_font_size_override("font_size", 24)
	_word_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	column.add_child(_word_label)

	_definition_label = Label.new()
	_definition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_definition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_definition_label.custom_minimum_size = Vector2(420.0, 0.0)
	_definition_label.add_theme_font_size_override("font_size", 18)
	_definition_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	column.add_child(_definition_label)

	call_deferred("_position_panel")


func _position_panel() -> void:
	if _panel == null:
		return
	var viewport := get_viewport().get_visible_rect()
	_panel.reset_size()
	var panel_size := _panel.size
	var x := viewport.position.x + (viewport.size.x - panel_size.x) * 0.5
	var y := viewport.position.y + viewport.size.y - panel_size.y - bottom_margin
	_panel.position = Vector2(x, y)
