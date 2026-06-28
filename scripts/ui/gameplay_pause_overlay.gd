class_name GameplayPauseOverlay
extends CanvasLayer

## Global gameplay pause — freezes the scene tree and restores Engine.time_scale on resume.

signal pause_state_changed(is_paused: bool)

@onready var _pause_panel: Control = $PausePanel
@onready var _resume_button: Button = $PausePanel/Center/VBox/ResumeButton

var _saved_time_scale := 1.0
var _is_paused := false


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_resume_button.pressed.connect(resume)
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not event.is_action("pause_game"):
		return
	if _is_paused:
		resume()
	else:
		pause()
	get_viewport().set_input_as_handled()


func pause() -> void:
	if _is_paused:
		return
	_saved_time_scale = Engine.time_scale
	_is_paused = true
	get_tree().paused = true
	_update_ui()
	pause_state_changed.emit(true)


func resume() -> void:
	if not _is_paused:
		return
	get_tree().paused = false
	Engine.time_scale = _saved_time_scale
	_is_paused = false
	_update_ui()
	pause_state_changed.emit(false)


func is_gameplay_paused() -> bool:
	return _is_paused


func _update_ui() -> void:
	_pause_panel.visible = _is_paused
