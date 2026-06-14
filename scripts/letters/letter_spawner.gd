class_name LetterSpawner
extends Node2D

## GDevelop group #13 letter drop — timer-based spawn with boundary cleanup.

signal letter_spawned(letter: Letter, character: String)
signal letter_deleted_boundary(letter: Letter)

@export var catalog: AlphabetCatalog
@export var letter_scene: PackedScene
@export var word_controller: WordGameController
@export var spawn_interval: float = 0.3
@export var spawn_x_min: float = 100.0
@export var spawn_x_max: float = 2000.0
@export var spawn_y: float = -256.0
@export var delete_y: float = 648.0
@export var size_min: float = 25.0
@export var size_max: float = 50.0
@export var fall_speed_min: float = 120.0
@export var fall_speed_max: float = 210.0
@export var max_active_letters: int = 30
@export var vowel_spawn_interval: float = 0.2
@export var deterministic_seed: int = -1

var total_spawned: int = 0
var total_collected: int = 0
var total_deleted_boundary: int = 0
var last_spawned_letter: String = ""
var _spawn_timer: float = 0.0
var _vowel_timer: float = 0.0
var _sequence_index: int = 1
var _vowel_index: int = 0
var _rng := RandomNumberGenerator.new()
var _active: Array[Letter] = []


func _ready() -> void:
	if deterministic_seed >= 0:
		_rng.seed = deterministic_seed
	else:
		_rng.randomize()


func _process(delta: float) -> void:
	_spawn_timer += delta
	_vowel_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_sequence_letter()
	if _vowel_timer >= vowel_spawn_interval:
		_vowel_timer = 0.0
		_spawn_vowel_letter()
	_cleanup_boundary()


func register_collected(letter: Letter) -> void:
	total_collected += 1
	_active.erase(letter)


func get_active_count() -> int:
	return _active.size()


func get_spawn_timer_remaining() -> float:
	return maxf(0.0, spawn_interval - _spawn_timer)


func debug_spawn_letter(ch: String) -> void:
	_spawn_letter(ch.to_upper(), true)


func _spawn_sequence_letter() -> void:
	if _active.size() >= max_active_letters:
		return
	var letters := catalog.all_letters() if catalog else PackedStringArray(["A"])
	var idx := clampi(_sequence_index - 1, 0, letters.size() - 1)
	_spawn_letter(letters[idx], false)
	_sequence_index += 1
	if _sequence_index > 26:
		_sequence_index = 1


func _spawn_vowel_letter() -> void:
	if _active.size() >= max_active_letters:
		return
	var vowels := PackedStringArray(["A", "E", "I", "O", "U"])
	var idx := _vowel_index % vowels.size()
	_spawn_letter(vowels[idx], true)
	_vowel_index += 1
	if _vowel_index > 5:
		_vowel_index = 0


func _spawn_letter(ch: String, force_vowel_style: bool) -> void:
	if letter_scene == null or catalog == null:
		return
	if _active.size() >= max_active_letters:
		return
	var letter: Letter = letter_scene.instantiate()
	add_child(letter)
	var x := _rng.randf_range(spawn_x_min, spawn_x_max)
	letter.position = Vector2(x, spawn_y)
	var tex_path := catalog.get_texture_path(ch)
	if not ResourceLoader.exists(tex_path):
		letter.queue_free()
		return
	var ref_size := 100.0
	var target := _rng.randf_range(size_min, size_max)
	var scale_factor := target / ref_size
	var is_vowel := force_vowel_style or catalog.is_vowel(ch)
	var modulate := catalog.random_modulate(is_vowel, _rng)
	var fall := _rng.randf_range(fall_speed_min, fall_speed_max)
	letter.catalog = catalog
	letter.configure(ch, total_spawned, scale_factor, modulate, fall)
	letter.collected.connect(_on_letter_collected)
	_active.append(letter)
	total_spawned += 1
	last_spawned_letter = ch
	letter_spawned.emit(letter, ch)


func _on_letter_collected(letter: Letter, character: String) -> void:
	register_collected(letter)
	if word_controller:
		word_controller.on_letter_collected(character)


func _cleanup_boundary() -> void:
	for i in range(_active.size() - 1, -1, -1):
		var letter := _active[i]
		if letter == null or not is_instance_valid(letter):
			_active.remove_at(i)
			continue
		if letter.global_position.y >= delete_y:
			letter_deleted_boundary.emit(letter)
			total_deleted_boundary += 1
			_active.remove_at(i)
			letter.queue_free()
