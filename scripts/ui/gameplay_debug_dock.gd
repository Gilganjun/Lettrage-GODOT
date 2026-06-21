class_name GameplayDebugDock
extends CanvasLayer

## Small collapsible debug icon — expanded panel holds all tuning readouts.

signal expanded_changed(is_expanded: bool)

@onready var _root: Control = $Root
@onready var _toggle: Button = $Root/ToggleButton
@onready var _panel: PanelContainer = $Root/Panel
@onready var _body: Label = $Root/Panel/Margin/Scroll/Body

var _expanded := false


func _ready() -> void:
	layer = 40
	_toggle.pressed.connect(_on_toggle_pressed)
	_collapse()
	set_active(false)


func set_active(active: bool) -> void:
	visible = active
	if not active:
		_collapse()


func is_expanded() -> bool:
	return _expanded


func set_body_text(text: String) -> void:
	if _body:
		_body.text = text


func _on_toggle_pressed() -> void:
	if _expanded:
		_collapse()
	else:
		_expand()


func _expand() -> void:
	_expanded = true
	_panel.visible = true
	_toggle.text = "×"
	expanded_changed.emit(true)


func _collapse() -> void:
	_expanded = false
	_panel.visible = false
	_toggle.text = "⚙"
	expanded_changed.emit(false)
