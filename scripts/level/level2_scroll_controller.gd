extends Node

## Level 2 horizontal scroll — child Camera2D follows the player vertically; local X offset
## clamps the view so the player can walk toward screen edges on the 1920px runway.

const VIEWPORT_WIDTH := 960.0

@export var level_width := 1920.0

var _player: Node2D
var _camera: Camera2D


func is_active() -> bool:
	return _player != null and _camera != null and is_instance_valid(_player)


func setup(player: Node2D, width: float = 1920.0) -> void:
	_player = player
	level_width = width
	_camera = null
	if _player == null:
		return
	_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if _camera == null:
		push_error("Level2ScrollController: player Camera2D missing")
		return
	_camera.top_level = false
	_camera.position_smoothing_enabled = false
	_camera.limit_smoothed = false
	_camera.enabled = true
	_camera.make_current()
	_apply_scroll_offset(true)


func _physics_process(_delta: float) -> void:
	if _player == null or _camera == null:
		return
	if not is_instance_valid(_player):
		return
	_apply_scroll_offset(false)


func _visible_half_width() -> float:
	if _camera == null:
		return VIEWPORT_WIDTH * 0.5
	var zoom_x := maxf(_camera.zoom.x, 0.01)
	return (VIEWPORT_WIDTH * 0.5) / zoom_x


func _apply_scroll_offset(_snap: bool) -> void:
	var intro_active: bool = false
	if _camera.has_method("is_round_intro_active"):
		intro_active = _camera.is_round_intro_active()
	if not intro_active:
		_camera.position_smoothing_enabled = false
	var half_w := _visible_half_width()
	var min_x := half_w
	var max_x := maxf(min_x, level_width - half_w)
	var desired_global_x := clampf(_player.global_position.x, min_x, max_x)
	var offset_x := desired_global_x - _player.global_position.x
	_camera.position = Vector2(offset_x, 0.0)
