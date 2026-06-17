extends SceneTree

const SCENE := "res://scenes/test/archive/phase2a_movement_corrected.tscn"

var _scene: Node
var _player: CharacterBody2D
var _frames := 0
var _max_frames := 120
var _ready_done := false


func _initialize() -> void:
	print("=== Phase 2A Physics Probe ===")
	var packed: PackedScene = load(SCENE)
	_scene = packed.instantiate()
	root.add_child(_scene)


func _physics_process(_delta: float) -> bool:
	if not _ready_done:
		_find_player()
		if _player == null:
			return true
		_ready_done = true
		_count_solids()
		var player_cam := _player.get_node("Camera2D") as Camera2D
		print("Player start: pos=%s vel=%s floor=%s mask=%d" % [
			_player.global_position, _player.velocity, _player.is_on_floor(), _player.collision_mask
		])
		print(
			"Camera start: enabled=%s current=%s zoom=%s"
			% [player_cam.enabled, player_cam.is_current(), player_cam.zoom]
		)
		if abs(_player.global_position.x - 279.0) > 0.01 or abs(_player.global_position.y - 231.0) > 0.01:
			print("=== Result: spawn not at (279,231) FAIL ===")
			quit(1)
		if not player_cam.is_current():
			print("=== Result: player camera not current at start FAIL ===")
			quit(1)

	_frames += 1
	if _frames in [1, 15, 30, 60, 90, 120]:
		print("Frame %d: pos=%s vel=%s floor=%s" % [
			_frames, _player.global_position, _player.velocity, _player.is_on_floor()
		])
	if _frames >= _max_frames:
		var on_floor := _player.is_on_floor()
		var y := _player.global_position.y
		# Air spawn (279,231) → lands on Platform1 mask top (~508 feet, ~413 origin)
		var ok := on_floor and y > 380.0 and y < 460.0
		print("=== Result: floor=%s y=%.1f %s ===" % [on_floor, y, "PASS" if ok else "FAIL"])
		quit(0 if ok else 1)
	return true


func _find_player() -> void:
	var root_node := _scene.get_node_or_null("World/PlayerRoot")
	if root_node == null:
		return
	for c in root_node.get_children():
		if c is CharacterBody2D:
			_player = c
			return


func _count_solids() -> void:
	var level := _scene.get_node_or_null("World/Level")
	var count := 0
	if level and level.has_method("collect_collider_nodes"):
		for node in level.collect_collider_nodes():
			if node is StaticBody2D:
				count += 1
	print("Static bodies: %d" % count)
