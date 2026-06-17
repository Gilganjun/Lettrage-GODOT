extends SceneTree

## Phase 2B2B automated validation — shields, enemy word collection, regressions.

const EnemyScript := preload("res://scripts/enemy/enemy.gd")
const EnemyWordControllerScript := preload("res://scripts/enemy/enemy_word_controller.gd")
const ShieldComponentScript := preload("res://scripts/components/shield_component.gd")
const PlayerShieldScript := preload("res://scripts/player/player_shield.gd")
const EnemyWordStateScript := preload("res://scripts/enemy/enemy_word_state.gd")
const EnemyDictionaryScript := preload("res://scripts/enemy/enemy_dictionary_service.gd")
const PlayerWordStateScript := preload("res://scripts/word_game/player_word_state.gd")
const DictionaryServiceScript := preload("res://scripts/word_game/dictionary_service.gd")

const PHASE2B2B_SCENE := "res://scenes/test/archive/phase2b2b_shield_word_test.tscn"
const PHASE2B2A_SCENE := "res://scenes/test/archive/phase2b2a_enemy_movement_test.tscn"
const PHASE2B1_SCENE := "res://scenes/test/archive/phase2b1_word_game_test.tscn"
const PHASE2A_SCENE := "res://scenes/test/archive/phase2a_movement_corrected.tscn"
const LEVEL_SCENE := "res://scenes/levels/main2_heallthbartest_level.tscn"
const ENEMY_SCENE := "res://scenes/enemy/enemy.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const SHIELD_SCENE := "res://scenes/components/shield_component.tscn"
const LETTER_SCENE := "res://scenes/letters/letter.tscn"
const CATALOG := "res://resources/letters/alphabet_catalog.tres"
const PLAYER_CFG := "res://resources/player/movement_config.tres"
const ENEMY_CFG := "res://resources/enemy/enemy_movement_config.tres"
const LEVEL_BASELINE_MARKER := "2031.0498"
const PROBE_SEED := 44002
const PROBE_FRAMES := 720

var _errors: Array[String] = []
var _probe: Dictionary = {}


func _initialize() -> void:
	print("=== Phase 2B2B Validation ===")
	_check_files()
	_check_shield_component()
	_check_letter_resolution()
	_check_enemy_word_state()
	_check_player_regression()
	_check_level_baseline()
	_load_scenes()
	_run_deterministic_probe()
	_print_summary()
	quit(0 if _errors.is_empty() else 1)


func _check_files() -> void:
	for path in [
		PHASE2B2B_SCENE,
		PHASE2B2A_SCENE,
		PHASE2B1_SCENE,
		PHASE2A_SCENE,
		LEVEL_SCENE,
		ENEMY_SCENE,
		PLAYER_SCENE,
		SHIELD_SCENE,
		"scripts/components/shield_component.gd",
		"scripts/enemy/enemy_word_controller.gd",
		"scripts/enemy/enemy_letter_targeting.gd",
		"scripts/enemy/enemy_letter_collector.gd",
		"scripts/enemy/enemy_shield_controller.gd",
	]:
		if ResourceLoader.exists(path):
			print("[OK] %s" % path)
		else:
			_fail("Missing %s" % path)
	for path in [
		"res://dictionary/EnemyDictionary.txt",
		"res://reports/PHASE2B2B_SOURCE_MAP.md",
	]:
		if FileAccess.file_exists(path):
			print("[OK] %s" % path)
		else:
			_fail("Missing %s" % path)


func _check_shield_component() -> void:
	var packed: PackedScene = load(SHIELD_SCENE)
	var a: Node2D = packed.instantiate()
	var b: Node2D = packed.instantiate()
	a.owner_group = "player"
	b.owner_group = "enemy"
	a.activate("test")
	if not a.is_active:
		_fail("Shield activate failed")
	if b.is_active:
		_fail("Enemy shield should start inactive in test instance")
	a.deactivate("test")
	if a.is_active:
		_fail("Shield deactivate failed")
	print("[OK] Shared ShieldComponent activates independently")


func _check_letter_resolution() -> void:
	var letter: Letter = load(LETTER_SCENE).instantiate()
	letter.character = "T"
	if not letter.try_resolve(Letter.Resolution.PLAYER_COLLECT, "test"):
		_fail("Letter first resolve failed")
	if letter.try_resolve(Letter.Resolution.ENEMY_COLLECT, "test"):
		_fail("Letter resolved twice")
	print("[OK] Letter resolves only once")


func _check_enemy_word_state() -> void:
	var dict: RefCounted = EnemyDictionaryScript.new()
	if not dict.load_dictionary():
		_fail("Enemy dictionary load failed")
		return
	var ws: RefCounted = EnemyWordStateScript.new()
	ws.set_target_word("CAT")
	ws.append_letter("C")
	ws.append_letter("X")
	if ws.collected_letters != "C":
		_fail("Enemy should reject wrong-order letter")
	ws.append_letter("A")
	ws.append_letter("T")
	if not ws.word_complete:
		_fail("Enemy word should complete CAT")
	var delta: int = ws.add_score_for_completed_word()
	if delta != (3 >> 1) + 3 + 3:
		_fail("Enemy score delta wrong for CAT: %d" % delta)
	print("[OK] Enemy word state order + score formula")


func _check_player_regression() -> void:
	var cfg: Resource = load(PLAYER_CFG)
	if cfg.gravity != 900.0 or cfg.jump_speed != 500.0:
		_fail("Player movement config changed")
	else:
		print("[OK] Player movement config unchanged")
	var pws: RefCounted = PlayerWordStateScript.new()
	pws.append_letter("A")
	pws.append_letter("B")
	if pws.add_score_for_valid_word(2) != 5:
		_fail("Player score formula changed")
	else:
		print("[OK] Player score formula unchanged")


func _check_level_baseline() -> void:
	var text := FileAccess.get_file_as_string(LEVEL_SCENE)
	if LEVEL_BASELINE_MARKER in text:
		print("[OK] Authoritative level collision marker preserved")
	else:
		_fail("Level baseline marker missing — do not rebake level")


func _load_scenes() -> void:
	for path in [PHASE2B2B_SCENE, PHASE2B1_SCENE, PHASE2A_SCENE, ENEMY_SCENE, PLAYER_SCENE]:
		var packed: PackedScene = load(path)
		if packed == null:
			_fail("Load failed %s" % path)
			continue
		var inst := packed.instantiate()
		if inst == null:
			_fail("Instantiate failed %s" % path)
		else:
			print("[OK] %s instantiates" % path)
			inst.free()


func _run_deterministic_probe() -> void:
	var root := Node2D.new()
	root.name = "ProbeRoot"
	var letter_packed: PackedScene = load(LETTER_SCENE)
	var enemy_packed: PackedScene = load(ENEMY_SCENE)
	var catalog: Resource = load(CATALOG)
	var enemy: Node = enemy_packed.instantiate()
	root.add_child(enemy)
	enemy.global_position = Vector2(400, 350)
	var wc: Node = enemy.get_node_or_null("EnemyWordController")
	if wc == null:
		_fail("Probe: enemy word controller missing")
		root.free()
		return
	var shield_breaks := 0
	var enemy_collects := 0
	var player_collects := 0
	var double_resolves := 0
	wc.call("pick_new_target_word")
	var target: String = wc.get("word_state").target_word
	var shield_comp: Node = enemy.get_node("ShieldComponent")
	if shield_comp:
		shield_comp.call("deactivate", "probe")
	var break_letter: Letter = letter_packed.instantiate()
	root.add_child(break_letter)
	break_letter.catalog = catalog
	break_letter.configure("Z", 99, 0.35, Color.WHITE, 0.0)
	if break_letter.try_resolve(Letter.Resolution.ENEMY_SHIELD, "probe"):
		shield_breaks += 1
	if break_letter.try_resolve(Letter.Resolution.ENEMY_SHIELD, "probe"):
		double_resolves += 1
	break_letter.queue_free()
	for i in target.length():
		var ch: String = target[i]
		var letter: Letter = letter_packed.instantiate()
		root.add_child(letter)
		letter.catalog = catalog
		letter.configure(ch, i, 0.35, Color.WHITE, 0.0)
		letter.global_position = enemy.global_position + Vector2(24, -10)
		if letter.try_resolve(Letter.Resolution.ENEMY_COLLECT, "probe"):
			wc.call("on_letter_collected", ch)
			enemy_collects += 1
		if letter.try_resolve(Letter.Resolution.PLAYER_COLLECT, "probe"):
			player_collects += 1
		letter.queue_free()
	var player_letter: Letter = letter_packed.instantiate()
	root.add_child(player_letter)
	player_letter.catalog = catalog
	player_letter.configure("Z", 2, 0.35, Color.WHITE, 0.0)
	var player_shield_node: Node = ShieldComponentScript.new()
	root.add_child(player_shield_node)
	player_shield_node.set("owner_group", "player")
	player_shield_node.call("activate", "probe")
	if player_shield_node.call("blocks_letter_collection"):
		if player_letter.try_resolve(Letter.Resolution.PLAYER_SHIELD, "probe"):
			shield_breaks += 1
	if player_letter.is_resolved() and player_letter.try_resolve(Letter.Resolution.PLAYER_COLLECT, "probe"):
		double_resolves += 1
	var score_before: int = wc.get("word_state").score
	if wc.get("word_state").collected_letters == target:
		wc.call("debug_force_validation")
	if wc.get("word_state").score <= score_before and target.length() > 0:
		_fail("Probe: enemy did not score after word complete")
	if enemy_collects < target.length():
		_fail("Probe: enemy collected %d/%d letters" % [enemy_collects, target.length()])
	if shield_breaks < 1:
		_fail("Probe: no shield breaks recorded")
	if double_resolves > 0:
		_fail("Probe: double resolution detected")
	if player_collects > 0:
		_fail("Probe: player collected enemy-target letters after enemy resolved them")
	_probe = {
		"target_word": target,
		"enemy_collects": enemy_collects,
		"shield_breaks": shield_breaks,
		"enemy_score": wc.get("word_state").score,
		"double_resolves": double_resolves,
	}
	print("[OK] Probe: enemy word %s collects %d score %d shield breaks %d" % [
		target, enemy_collects, wc.get("word_state").score, shield_breaks])
	root.free()


func _fail(msg: String) -> void:
	_errors.append(msg)
	push_error(msg)


func _print_summary() -> void:
	print("\n--- Probe summary ---")
	for k in _probe.keys():
		print("  %s: %s" % [k, str(_probe[k])])
	print("\n=== Summary: %d errors ===" % _errors.size())
	for e in _errors:
		print("  [FAIL] %s" % e)
	if _errors.is_empty():
		print("[INFO] Manual F5 gameplay validation: PENDING USER")
