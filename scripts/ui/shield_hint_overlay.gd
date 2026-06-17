class_name ShieldHintOverlay
extends Control

## Bottom-center shield reminder with auto-sized dark panel.

@onready var _panel: PanelContainer = $Center/Panel
@onready var _label: Label = $Center/Panel/Label

var _player_shield: PlayerShield
var _flash_time := 0.0
var _hint_mode := "hidden"


func _ready() -> void:
	visible = false
	modulate = Color(1, 1, 1, 1)


func bind_shield(shield: PlayerShield) -> void:
	if _player_shield == shield:
		_refresh()
		return
	_player_shield = shield
	if _player_shield == null:
		visible = false
		return
	if not _player_shield.shield_toggled.is_connected(_on_shield_state_changed):
		_player_shield.shield_toggled.connect(_on_shield_state_changed)
	if not _player_shield.latch_changed.is_connected(_on_shield_state_changed):
		_player_shield.latch_changed.connect(_on_shield_state_changed)
	if not _player_shield.hold_session_changed.is_connected(_on_shield_state_changed):
		_player_shield.hold_session_changed.connect(_on_shield_state_changed)
	_refresh()


func _process(delta: float) -> void:
	if not visible or _hint_mode != "latched":
		return
	_flash_time += delta
	var pulse := (sin(_flash_time * 2.4) + 1.0) * 0.5
	modulate.a = lerpf(0.45, 1.0, pulse)


func _on_shield_state_changed(_arg = null) -> void:
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	if _player_shield == null or not _player_shield.is_active:
		_hint_mode = "hidden"
		visible = false
		return
	if _player_shield.is_latched:
		_hint_mode = "latched"
		_set_hint_text("Shield locked")
		return
	if _player_shield.is_hold_blocking:
		_hint_mode = "hold"
		_set_hint_text("Release to stop shield")
		return
	_hint_mode = "hidden"
	visible = false


func _set_hint_text(text: String) -> void:
	_label.text = text
	modulate.a = 1.0
	visible = true
	_panel.reset_size()
	call_deferred("_panel.reset_size")
