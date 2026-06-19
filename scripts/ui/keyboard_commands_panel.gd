extends Control

## Bottom-left help icon that lists all keyboard commands from GameKeyboardCommands.

const GameKeyboardCommands := preload("res://scripts/ui/game_keyboard_commands.gd")

@onready var _toggle_button: Button = $ToggleButton
@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel: PanelContainer = $Panel
@onready var _list: VBoxContainer = $Panel/Margin/Scroll/List


func _ready() -> void:
	_build_list()
	_toggle_button.pressed.connect(_on_toggle_pressed)
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_close()
	set_process_unhandled_input(true)


func _build_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	for section in GameKeyboardCommands.get_sections():
		_add_section(section)


func _add_section(section: Dictionary) -> void:
	var title := Label.new()
	title.text = str(section.get("title", ""))
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35, 1.0))
	_list.add_child(title)
	var entries: Array = section.get("entries", [])
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_list.add_child(_make_row(str(entry.get("keys", "")), str(entry.get("desc", ""))))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_list.add_child(spacer)


func _make_row(keys: String, description: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var key_label := Label.new()
	key_label.text = keys
	key_label.custom_minimum_size = Vector2(108, 0)
	key_label.add_theme_font_size_override("font_size", 12)
	key_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 1.0))
	var desc_label := Label.new()
	desc_label.text = description
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96, 1.0))
	row.add_child(key_label)
	row.add_child(desc_label)
	return row


func is_open() -> bool:
	return _panel.visible


func _open() -> void:
	_backdrop.visible = true
	_panel.visible = true
	_toggle_button.text = "×"


func _close() -> void:
	_backdrop.visible = false
	_panel.visible = false
	_toggle_button.text = "?"


func _on_toggle_pressed() -> void:
	if _panel.visible:
		_close()
	else:
		_open()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
