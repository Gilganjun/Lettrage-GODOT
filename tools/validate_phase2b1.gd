extends SceneTree

## Phase 2B1 automated validation — word game + Phase 2A regression guards.

const AlphabetCatalogScript := preload("res://scripts/resources/alphabet_catalog.gd")
const DictionaryServiceScript := preload("res://scripts/word_game/dictionary_service.gd")
const PlayerWordStateScript := preload("res://scripts/word_game/player_word_state.gd")
const SpokenAlphabetScript := preload("res://scripts/word_game/spoken_alphabet_service.gd")
const LetterSpawnerScript := preload("res://scripts/letters/letter_spawner.gd")
const LetterScript := preload("res://scripts/letters/letter.gd")

const PHASE2A_SCENE := "res://scenes/test/archive/phase2a_movement_corrected.tscn"
const PHASE2B1_SCENE := "res://scenes/test/archive/phase2b1_word_game_test.tscn"
const LEVEL_SCENE := "res://scenes/levels/main2_heallthbartest_level.tscn"
const LETTER_SCENE := "res://scenes/letters/letter.tscn"
const CATALOG := "res://resources/letters/alphabet_catalog.tres"
const MOVEMENT_CONFIG := "res://resources/player/movement_config.tres"
const LEVEL_BASELINE_MARKER := "2031.0498"

const EXPECTED_MOVEMENT := {
	"gravity": 900.0,
	"jump_speed": 500.0,
	"max_speed": 200.0,
	"sprint_max_speed": 400.0,
}

var _errors: Array[String] = []


func _initialize() -> void:
	print("=== Phase 2B1 Validation ===")
	_check_files()
	_check_alphabet()
	_check_spoken_alphabet()
	_check_dictionary()
	_check_word_state_logic()
	_check_spawner_limit()
	_check_level_baseline()
	_check_movement_config()
	_load_scenes()
	_print_summary()
	quit(0 if _errors.is_empty() else 1)


func _check_files() -> void:
	for path in [
		PHASE2B1_SCENE,
		PHASE2A_SCENE,
		LEVEL_SCENE,
		LETTER_SCENE,
		CATALOG,
		"res://scripts/word_game/dictionary_service.gd",
		"res://scripts/word_game/player_word_state.gd",
		"res://scripts/letters/letter_spawner.gd",
		"res://scripts/letters/letter_spawn_director.gd",
		"res://scripts/letters/letter_spawn_profile.gd",
		"res://resources/letters/rain_spawn_profile.tres",
		"res://scenes/ui/word_game_hud.tscn",
	]:
		if ResourceLoader.exists(path):
			print("[OK] %s" % path)
		else:
			_fail("Missing %s" % path)


func _check_alphabet() -> void:
	var catalog: Resource = load(CATALOG)
	if catalog == null:
		_fail("Alphabet catalog failed to load")
		return
	for letter in catalog.all_letters():
		var path: String = catalog.get_texture_path(letter)
		if ResourceLoader.exists(path):
			print("[OK] texture %s -> %s" % [letter, path])
		else:
			_fail("Missing texture for %s: %s" % [letter, path])
	var packed: PackedScene = load(LETTER_SCENE)
	if packed == null:
		_fail("Letter scene load failed")
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		_fail("Letter scene instantiate failed")
		return
	print("[OK] Letter scene instantiates")
	_check_letter_velocity()


func _check_letter_velocity() -> void:
	var packed: PackedScene = load(LETTER_SCENE)
	var letter: Letter = packed.instantiate()
	letter.catalog = load(CATALOG)
	letter.configure("A", 0, 0.4, Color.WHITE, 180.0)
	if letter.velocity != Vector2(0.0, 180.0):
		_fail("Letter rain velocity expected (0,180) got %s" % str(letter.velocity))
	if int(Letter.Resolution.BULLET_COLLECT) < 0:
		_fail("Letter.Resolution.BULLET_COLLECT invalid")
	letter.queue_free()
	print("[OK] Letter velocity + resolution enums")


func _check_spoken_alphabet() -> void:
	var spoken: RefCounted = SpokenAlphabetScript.new()
	for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		for voice in 3:
			var path: String = spoken.path_for_letter(letter, voice)
			if ResourceLoader.exists(path):
				print("[OK] spoken %s voice %d -> %s" % [letter, voice + 1, path.get_file()])
			else:
				_fail("Missing spoken clip for %s voice %d: %s" % [letter, voice + 1, path])
	var sample: String = spoken.get_spoken_path("M")
	if sample.is_empty() or not ResourceLoader.exists(sample):
		_fail("Random spoken path failed for M: %s" % sample)
	else:
		print("[OK] SpokenAlphabetService random path resolves")


func _check_dictionary() -> void:
	var svc: RefCounted = DictionaryServiceScript.new()
	if not svc.load_dictionary():
		_fail("Dictionary load failed: %s" % svc.error_message)
		return
	print("[OK] Dictionary loaded %d words in %.1f ms" % [svc.word_count, svc.load_time_ms])
	if not svc.contains_word("A"):
		_fail("Dictionary missing word A")
	if not svc.contains_word("CAT"):
		_fail("Dictionary missing word CAT")
	if svc.contains_word("ZZNOTAWORD"):
		_fail("Dictionary falsely contains ZZNOTAWORD")
	if not svc.contains_word("a"):
		_fail("Dictionary case normalization failed for 'a'")


func _check_word_state_logic() -> void:
	var ws: RefCounted = PlayerWordStateScript.new()
	ws.append_letter("C")
	ws.append_letter("A")
	ws.append_letter("T")
	if ws.current_word != "CAT":
		_fail("Append order expected CAT got %s" % ws.current_word)
	ws.delete_last_letter()
	if ws.current_word != "CA":
		_fail("Delete last expected CA got %s" % ws.current_word)
	var before: int = ws.score
	var delta: int = ws.add_score_for_valid_word(4)
	if delta != 10:
		_fail("Score delta for len 4 expected 10 got %d" % delta)
	if ws.score != before + 10:
		_fail("Score not updated correctly")
	ws.clear_word()
	if not ws.current_word.is_empty():
		_fail("Clear word failed")
	print("[OK] Word state append/delete/score")


func _check_spawner_limit() -> void:
	var spawner: Node = LetterSpawnerScript.new()
	var profile: Resource = load("res://resources/letters/rain_spawn_profile.tres")
	spawner.profile = profile
	spawner.profile.max_active_letters = 3
	spawner.catalog = load(CATALOG)
	spawner.letter_scene = load(LETTER_SCENE)
	var root := Node2D.new()
	root.add_child(spawner)
	spawner.debug_spawn_letter("A")
	spawner.debug_spawn_letter("B")
	spawner.debug_spawn_letter("C")
	spawner.debug_spawn_letter("D")
	if spawner.get_active_count() > 3:
		_fail("Spawner exceeded max_active_letters")
	else:
		print("[OK] Spawner respects active-letter limit")
	root.free()


func _check_level_baseline() -> void:
	if not FileAccess.file_exists(LEVEL_SCENE):
		_fail("Level scene missing")
		return
	var text := FileAccess.get_file_as_string(LEVEL_SCENE)
	if LEVEL_BASELINE_MARKER in text:
		print("[OK] Authoritative level contains Phase 2A manual collision marker")
	else:
		_fail("Level scene missing manual Platform1_003 collision marker — do not rebake blindly")


func _check_movement_config() -> void:
	var cfg: PlayerMovementConfig = load(MOVEMENT_CONFIG)
	if cfg == null:
		_fail("movement_config load failed")
		return
	for key in EXPECTED_MOVEMENT:
		if cfg.get(key) != EXPECTED_MOVEMENT[key]:
			_fail("movement_config.%s changed (expected %s)" % [key, EXPECTED_MOVEMENT[key]])
	if _errors.is_empty():
		print("[OK] Player movement config unchanged")


func _load_scenes() -> void:
	for path in [PHASE2A_SCENE, PHASE2B1_SCENE]:
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


func _fail(msg: String) -> void:
	_errors.append(msg)
	print("[FAIL] %s" % msg)


func _print_summary() -> void:
	print("\n=== Summary: %d errors ===" % _errors.size())
	print("[INFO] Manual F5 gameplay validation: PENDING USER")
