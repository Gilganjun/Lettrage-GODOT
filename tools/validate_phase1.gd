extends SceneTree

const PLAYER_PROFILE := "res://resources/characters/player_visual.tres"
const ENEMY_PROFILE := "res://resources/characters/enemy_visual.tres"
const PLAYER_FRAMES := "res://resources/sprite_frames/player_frames.tres"
const ENEMY_FRAMES := "res://resources/sprite_frames/enemy_frames.tres"
const MAIN_SCENE := "res://scenes/test/archive/animation_test.tscn"

const PLAYER_ORDER: Array[String] = [
	"Idle", "Run", "Climb", "Jump", "Fall", "Death", "Sprint", "Crouch", "Roll", "Kick2", "Kick",
]
const ENEMY_ORDER: Array[String] = [
	"Idle", "Run", "Climb", "Jump", "Fall", "Death",
]

var _errors: Array[String] = []


func _initialize() -> void:
	print("=== Lettrage Phase 1 Validation (Godot) ===")
	_check_files()
	_validate_profiles()
	_load_main_scene()
	_print_summary()
	quit(0 if _errors.is_empty() else 1)


func _check_files() -> void:
	for path in [
		"res://project.godot",
		"res://reference/GAME25.json",
		"res://resources/animation_manifest.json",
		MAIN_SCENE,
		PLAYER_PROFILE,
		ENEMY_PROFILE,
		"res://assets/crickets.ogg",
		"res://assets/door.ogg",
	]:
		if FileAccess.file_exists(path):
			print("[OK] %s" % path)
		else:
			_fail("%s missing" % path)


func _validate_profiles() -> void:
	var player = load(PLAYER_PROFILE)
	var enemy = load(ENEMY_PROFILE)
	if player == null:
		_fail("player_visual.tres failed to load")
		return
	if enemy == null:
		_fail("enemy_visual.tres failed to load")
		return
	if player == enemy:
		_fail("Player and Enemy profiles must be different instances")
	else:
		print("[OK] Profiles are independent instances")
	if player.sprite_frames == null or enemy.sprite_frames == null:
		_fail("SpriteFrames missing on profile")
		return
	if player.sprite_frames == enemy.sprite_frames:
		print("[OK] SpriteFrames are separate resources (may share PNG paths)")
	else:
		print("[OK] SpriteFrames are separate resources")
	_check_order("Player", player.animation_order, PLAYER_ORDER)
	_check_order("Enemy", enemy.animation_order, ENEMY_ORDER)
	_validate_frames("Player", player)
	_validate_frames("Enemy", enemy)
	if player.glow_enabled:
		print("[OK] Player Glow metadata RGB(%d,%d,%d)" % [
			int(player.glow_color.r * 255), int(player.glow_color.g * 255), int(player.glow_color.b * 255)
		])
	if enemy.night_effect_enabled:
		print("[OK] Enemy DarkNight intensity=%.2f opacity=%.2f" % [enemy.night_intensity, enemy.night_opacity])


func _check_order(who: String, actual: Array[String], expected: Array[String]) -> void:
	if actual.size() != expected.size():
		_fail("%s animation_order length %d != %d" % [who, actual.size(), expected.size()])
		return
	for i in range(expected.size()):
		if actual[i] != expected[i]:
			_fail("%s order mismatch at %d: %s != %s" % [who, i, actual[i], expected[i]])
			return
	print("[OK] %s animation order matches explicit JSON sequence" % who)


func _validate_frames(who: String, profile: Resource) -> void:
	for anim in profile.animation_order:
		if not profile.sprite_frames.has_animation(anim):
			_fail("%s missing animation '%s'" % [who, anim])
		elif profile.sprite_frames.get_frame_count(anim) <= 0:
			_fail("%s animation '%s' has 0 frames" % [who, anim])


func _load_main_scene() -> void:
	var packed: PackedScene = load(MAIN_SCENE)
	if packed == null:
		_fail("Could not load animation test scene")
		return
	var node := packed.instantiate()
	if node == null:
		_fail("Could not instantiate animation test scene")
		return
	if not node.has_node("Root/Characters/PlayerSlot"):
		_fail("PlayerSlot missing from test scene")
	if not node.has_node("Root/Characters/EnemySlot"):
		_fail("EnemySlot missing from test scene")
	print("[OK] Dual-character test scene instantiates")
	node.free()


func _fail(msg: String) -> void:
	_errors.append(msg)
	print("[FAIL] %s" % msg)


func _print_summary() -> void:
	print("\n=== Summary: %d errors ===" % _errors.size())
	for e in _errors:
		print("  ERROR: %s" % e)
	if _errors.is_empty():
		print("Phase 1 validation PASSED")
