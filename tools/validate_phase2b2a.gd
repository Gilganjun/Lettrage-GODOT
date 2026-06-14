extends SceneTree

## Phase 2B2A automated validation — enemy foundation + obstacle escape probe.

const EnemyScript := preload("res://scripts/enemy/enemy.gd")
const EnemyObstacleResponseScript := preload("res://scripts/enemy/enemy_obstacle_response.gd")

const PHASE2B2A_SCENE := "res://scenes/test/phase2b2a_enemy_movement_test.tscn"
const PHASE2B1_SCENE := "res://scenes/test/phase2b1_word_game_test.tscn"
const PHASE2A_SCENE := "res://scenes/test/phase2a_movement_corrected.tscn"
const LEVEL_SCENE := "res://scenes/levels/main2_heallthbartest_level.tscn"
const ENEMY_SCENE := "res://scenes/enemy/enemy.tscn"
const ENEMY_CFG := "res://resources/enemy/enemy_movement_config.tres"
const ENEMY_VISUAL := "res://resources/characters/enemy_visual.tres"
const PLAYER_VISUAL := "res://resources/characters/player_visual.tres"
const ENEMY_SPAWN := "res://resources/enemy/enemy_spawn.json"
const PLAYER_CFG := "res://resources/player/movement_config.tres"
const LEVEL_BASELINE_MARKER := "2031.0498"
const PROBE_SEED := 90210
const PROBE_FRAMES := 540
const OBSTACLE_ZONE_MIN_X := 820.0

const EXPECTED_ENEMY_MOVEMENT := {
	"gravity": 1700.0,
	"jump_speed": 900.0,
	"max_speed": 300.0,
	"acceleration": 1125.0,
	"deceleration": 1125.0,
	"max_falling_speed": 500.0,
	"ladder_climbing_speed": 300.0,
}

const EXPECTED_SPAWN := Vector2(740.0, 406.0)

var _errors: Array[String] = []
var _probe: Dictionary = {}
var _probe_enemy: Node
var _probe_frames := 0
var _probe_positions: Array[Vector2] = []
var _probe_on_floor := 0
var _probe_dir_changes := 0
var _probe_last_dir := 0
var _probe_consecutive_stuck := 0
var _probe_max_consecutive_stuck := 0
var _probe_max_y := 0.0
var _probe_start := Vector2.ZERO
var _probe_max_x := 0.0
var _probe_min_x := 0.0
var _probe_direction_window: Array[int] = []


func _initialize() -> void:
	print("=== Phase 2B2A Validation ===")
	_check_files()
	_check_visual_independence()
	_check_enemy_movement_config()
	_check_enemy_animations()
	_check_spawn_data()
	_check_level_baseline()
	_check_player_config_unchanged()
	_load_scenes()
	call_deferred("_setup_physics_probe")


func _setup_physics_probe() -> void:
	var level_packed: PackedScene = load(LEVEL_SCENE)
	var enemy_packed: PackedScene = load(ENEMY_SCENE)
	if level_packed == null or enemy_packed == null:
		_fail("Physics probe setup failed — scene load")
		_finish()
		return
	var probe := Node2D.new()
	probe.name = "ProbeRoot"
	root.add_child(probe)
	var level: Node = level_packed.instantiate()
	var enemy: Node = enemy_packed.instantiate()
	probe.add_child(level)
	probe.add_child(enemy)
	var spawn_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ENEMY_SPAWN))
	enemy.call("configure_from_gdevelop", spawn_data)
	enemy.call("set_obstacle_rng_seed", PROBE_SEED)
	if level.has_method("collect_ladder_areas"):
		for ladder in level.collect_ladder_areas():
			enemy.call("register_ladder", ladder)
	_probe_enemy = enemy
	_probe_start = enemy.global_position
	_probe_max_y = _probe_start.y
	_probe_max_x = _probe_start.x
	_probe_min_x = _probe_start.x
	var timer := Timer.new()
	timer.wait_time = 1.0 / 60.0
	timer.timeout.connect(_probe_tick.bind(probe, timer))
	root.add_child(timer)
	timer.start()


func _probe_tick(probe: Node2D, timer: Timer) -> void:
	if _probe_enemy == null:
		timer.stop()
		probe.queue_free()
		_finish()
		return
	_probe_frames += 1
	_probe_positions.append(_probe_enemy.global_position)
	_probe_max_x = maxf(_probe_max_x, _probe_enemy.global_position.x)
	_probe_min_x = minf(_probe_min_x, _probe_enemy.global_position.x)
	if _probe_enemy.is_on_floor():
		_probe_on_floor += 1
	if _probe_enemy.global_position.y > _probe_max_y:
		_probe_max_y = _probe_enemy.global_position.y
	var mc: Node = _probe_enemy.get_node("EnemyMovementController")
	var dir: int = mc.direction if mc else 0
	if dir != 0 and _probe_last_dir != 0 and dir != _probe_last_dir:
		_probe_dir_changes += 1
		_probe_direction_window.append(_probe_frames)
	if dir != 0:
		_probe_last_dir = dir
	var near_obstacle: bool = _probe_enemy.global_position.x >= OBSTACLE_ZONE_MIN_X
	var low_speed: bool = absf(_probe_enemy.velocity.x) < 3.0 and _probe_enemy.is_on_floor()
	if near_obstacle and low_speed:
		_probe_consecutive_stuck += 1
		_probe_max_consecutive_stuck = maxi(_probe_max_consecutive_stuck, _probe_consecutive_stuck)
	else:
		_probe_consecutive_stuck = 0
	if _probe_frames >= PROBE_FRAMES:
		timer.stop()
		timer.queue_free()
		_analyze_physics_probe()
		probe.queue_free()
		_finish()


func _analyze_physics_probe() -> void:
	var end_pos: Vector2 = _probe_enemy.global_position
	var travelled := 0.0
	for j in range(1, _probe_positions.size()):
		travelled += _probe_positions[j - 1].distance_to(_probe_positions[j])
	var response: Node = _probe_enemy.get_node("ObstacleResponse")
	var escaped_forward: bool = _probe_max_x > OBSTACLE_ZONE_MIN_X + 40.0
	var escaped_reverse: bool = _probe_min_x < OBSTACLE_ZONE_MIN_X - 60.0
	var oscillations := 0
	for frame_a in _probe_direction_window:
		var count := 0
		for frame_b in _probe_direction_window:
			if absf(frame_a - frame_b) <= 30:
				count += 1
		if count >= 4:
			oscillations += 1
	_probe = {
		"seed": PROBE_SEED,
		"frames": _probe_frames,
		"start": _probe_start,
		"end": end_pos,
		"path_length": travelled,
		"on_floor_frames": _probe_on_floor,
		"direction_changes": _probe_dir_changes,
		"max_consecutive_stuck": _probe_max_consecutive_stuck,
		"max_fall_y": _probe_max_y,
		"obstacle_decisions": response.total_decisions if response else 0,
		"jumps_chosen": response.jumps_chosen if response else 0,
		"reverses_chosen": response.reverses_chosen if response else 0,
		"stuck_fallbacks": response.stuck_fallbacks if response else 0,
		"max_stuck_duration": response.max_stuck_duration if response else 0.0,
		"last_escape_outcome": response.last_escape_outcome if response else "",
		"min_x": _probe_min_x,
		"max_x": _probe_max_x,
		"oscillation_hits": oscillations,
		"escaped_forward": escaped_forward,
		"escaped_reverse": escaped_reverse,
	}
	if _probe_on_floor < 30:
		_fail("Probe: enemy rarely on floor (%d/%d frames)" % [_probe_on_floor, _probe_frames])
	else:
		print("[OK] Probe: floor contact %d/%d frames" % [_probe_on_floor, _probe_frames])
	if travelled < 80.0:
		_fail("Probe: enemy travelled too little (%.1f px)" % travelled)
	else:
		print("[OK] Probe: travelled %.1f px" % travelled)
	if response == null or response.total_decisions < 1:
		_fail("Probe: no obstacle decisions recorded")
	else:
		print("[OK] Probe: obstacle decisions %d (jumps %d, reverses %d)" % [
			response.total_decisions, response.jumps_chosen, response.reverses_chosen])
	if not escaped_forward and not escaped_reverse:
		_fail("Probe: enemy did not escape obstacle (end x %.1f)" % end_pos.x)
	else:
		print("[OK] Probe: escaped via %s" % ("forward" if escaped_forward else "reverse"))
	if _probe_max_consecutive_stuck > 120:
		_fail("Probe: prolonged stuck near obstacle (%d frames)" % _probe_max_consecutive_stuck)
	else:
		print("[OK] Probe: max consecutive stuck %d frames" % _probe_max_consecutive_stuck)
	if oscillations > 0:
		_fail("Probe: rapid direction oscillation detected (%d windows)" % oscillations)
	else:
		print("[OK] Probe: no rapid oscillation")
	if _probe_max_y > _probe_start.y + 400.0:
		_fail("Probe: unexpected fall depth (max y %.1f)" % _probe_max_y)
	else:
		print("[OK] Probe: fall depth within bounds")


func _finish() -> void:
	_print_probe()
	_print_summary()
	quit(0 if _errors.is_empty() else 1)


func _check_files() -> void:
	for path in [
		PHASE2B2A_SCENE,
		PHASE2B1_SCENE,
		PHASE2A_SCENE,
		LEVEL_SCENE,
		ENEMY_SCENE,
		ENEMY_CFG,
		ENEMY_VISUAL,
		ENEMY_SPAWN,
		"reports/PHASE2B2A_SOURCE_MAP.md",
		"scripts/enemy/enemy_obstacle_sensor.gd",
		"scripts/enemy/enemy_obstacle_response.gd",
	]:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			print("[OK] %s" % path)
		else:
			_fail("Missing %s" % path)


func _check_visual_independence() -> void:
	var enemy: Resource = load(ENEMY_VISUAL)
	var player: Resource = load(PLAYER_VISUAL)
	if enemy == null or player == null:
		_fail("Visual profile load failed")
		return
	if enemy.sprite_frames == player.sprite_frames:
		_fail("Enemy and Player share sprite_frames resource — must be independent paths")
	else:
		print("[OK] Enemy sprite_frames independent from Player")
	if enemy.modulate == player.modulate:
		_fail("Enemy modulate matches Player — expected DarkNight tint")
	else:
		print("[OK] Enemy modulate differs from Player (%s)" % enemy.modulate)


func _check_enemy_movement_config() -> void:
	var cfg: Resource = load(ENEMY_CFG)
	if cfg == null:
		_fail("enemy_movement_config load failed")
		return
	for key in EXPECTED_ENEMY_MOVEMENT:
		if cfg.get(key) != EXPECTED_ENEMY_MOVEMENT[key]:
			_fail("enemy_movement_config.%s expected %s got %s" % [key, EXPECTED_ENEMY_MOVEMENT[key], cfg.get(key)])
	if _errors.is_empty():
		print("[OK] Enemy movement config matches source extract")


func _check_enemy_animations() -> void:
	var visual: Resource = load(ENEMY_VISUAL)
	if visual == null or visual.sprite_frames == null:
		_fail("Enemy SpriteFrames missing")
		return
	for anim in ["Idle", "Run", "Jump", "Fall", "Climb"]:
		if not visual.sprite_frames.has_animation(anim):
			_fail("Enemy missing animation %s" % anim)
		else:
			print("[OK] Enemy animation %s" % anim)


func _check_spawn_data() -> void:
	var text := FileAccess.get_file_as_string(ENEMY_SPAWN)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		_fail("enemy_spawn.json parse failed")
		return
	if float(data.get("source_x", 0)) != EXPECTED_SPAWN.x or float(data.get("source_y", 0)) != EXPECTED_SPAWN.y:
		_fail("Enemy spawn coords mismatch")
	else:
		print("[OK] Enemy spawn (740, 406)")


func _check_level_baseline() -> void:
	var text := FileAccess.get_file_as_string(LEVEL_SCENE)
	if LEVEL_BASELINE_MARKER in text:
		print("[OK] Authoritative level collision marker preserved")
	else:
		_fail("Level missing Phase 2A manual collision marker")


func _check_player_config_unchanged() -> void:
	var cfg: Resource = load(PLAYER_CFG)
	if cfg == null:
		_fail("player movement_config load failed")
		return
	if cfg.gravity != 900.0 or cfg.jump_speed != 500.0 or cfg.max_speed != 200.0:
		_fail("Player movement config changed")
	else:
		print("[OK] Player movement config unchanged")


func _load_scenes() -> void:
	for path in [PHASE2B2A_SCENE, PHASE2B1_SCENE, PHASE2A_SCENE, ENEMY_SCENE]:
		var packed: PackedScene = load(path)
		if packed == null:
			_fail("Failed to load %s" % path)
			continue
		var inst := packed.instantiate()
		if inst == null:
			_fail("Failed to instantiate %s" % path)
		else:
			print("[OK] %s instantiates" % path)
			inst.free()


func _print_probe() -> void:
	print("\n--- Physics probe summary ---")
	for key in _probe:
		print("  %s: %s" % [key, str(_probe[key])])


func _fail(msg: String) -> void:
	_errors.append(msg)
	print("[FAIL] %s" % msg)


func _print_summary() -> void:
	print("\n=== Summary: %d errors ===" % _errors.size())
	print("[INFO] Manual F5 gameplay validation: PENDING USER")
