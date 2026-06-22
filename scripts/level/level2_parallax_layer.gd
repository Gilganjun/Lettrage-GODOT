extends Node2D

## Foreground parallax — drifts based on player movement only (not enemy / camera clamp).

@export_range(0.0, 1.0, 0.01) var parallax_strength := 0.22

var _anchor_x := 0.0
var _player: Node2D
var _origin_player_x := 0.0


func _ready() -> void:
	_anchor_x = position.x
	z_as_relative = false
	call_deferred("_bind_player")


func _bind_player() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D:
			_player = node
			_origin_player_x = _player.global_position.x
			return


func reset_scroll_origin() -> void:
	if _player != null and is_instance_valid(_player):
		_origin_player_x = _player.global_position.x
	position.x = _anchor_x


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_bind_player()
		if _player == null:
			return
	var scroll_x := _player.global_position.x - _origin_player_x
	position.x = _anchor_x + scroll_x * parallax_strength
