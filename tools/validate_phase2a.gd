extends SceneTree

const PHASE1_SCENE := "res://scenes/test/archive/animation_test.tscn"
const PHASE2A_SCENE := "res://scenes/test/archive/phase2a_movement_test.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const PLAYER_PROFILE := "res://resources/characters/player_visual.tres"
const MOVEMENT_ANIMS := ["Idle", "Run", "Jump", "Fall", "Climb"]

var _errors: Array[String] = []


func _initialize() -> void:
	print("=== Lettrage Phase 2A Validation (Godot) ===")
	_check_core_files()
	_check_input_actions()
	_validate_player_profile()
	_load_scene(PHASE1_SCENE, "Phase 1 animation test")
	_load_scene(PHASE2A_SCENE, "Phase 2A movement test")
	_load_player_scene()
	_print_summary()
	quit(0 if _errors.is_empty() else 1)


func _check_core_files() -> void:
	for path in [
		"res://project.godot",
		"res://resources/phase2a/layout_manifest.json",
		PHASE1_SCENE,
		PHASE2A_SCENE,
		PLAYER_SCENE,
		PLAYER_PROFILE,
		"res://resources/player/movement_config.tres",
	]:
		if FileAccess.file_exists(path):
			print("[OK] %s" % path)
		else:
			_fail("%s missing" % path)


func _check_input_actions() -> void:
	for action in ["move_left", "move_right", "jump", "climb_up", "climb_down"]:
		if InputMap.has_action(action):
			print("[OK] input action '%s'" % action)
		else:
			_fail("input action '%s' missing" % action)


func _validate_player_profile() -> void:
	var profile = load(PLAYER_PROFILE)
	if profile == null:
		_fail("player_visual.tres failed to load")
		return
	if profile.sprite_frames == null:
		_fail("player SpriteFrames missing")
		return
	for anim in MOVEMENT_ANIMS:
		if not profile.sprite_frames.has_animation(anim):
			_fail("player missing movement animation '%s'" % anim)
		else:
			print("[OK] player animation '%s'" % anim)


func _load_scene(path: String, label: String) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		_fail("Could not load %s" % label)
		return
	var node := packed.instantiate()
	if node == null:
		_fail("Could not instantiate %s" % label)
		return
	print("[OK] %s instantiates" % label)
	node.free()


func _load_player_scene() -> void:
	var packed: PackedScene = load(PLAYER_SCENE)
	if packed == null:
		_fail("Could not load player scene")
		return
	var player := packed.instantiate()
	if player == null:
		_fail("Could not instantiate player scene")
		return
	if not player.has_node("CollisionShape2D"):
		_fail("Player missing CollisionShape2D")
	else:
		print("[OK] Player collision node exists")
	if not player.has_node("AnimatedSprite2D"):
		_fail("Player missing AnimatedSprite2D")
	else:
		print("[OK] Player visual node exists")
	player.free()


func _fail(msg: String) -> void:
	_errors.append(msg)
	print("[FAIL] %s" % msg)


func _print_summary() -> void:
	print("\n=== Summary: %d errors ===" % _errors.size())
	for e in _errors:
		print("  ERROR: %s" % e)
	if _errors.is_empty():
		print("Phase 2A validation PASSED")
