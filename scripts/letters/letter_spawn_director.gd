class_name LetterSpawnDirector
extends Node2D

## Profile-driven letter spawning with adaptive pacing and boundary cleanup.

signal letter_spawned(letter: Letter, character: String)
signal letter_deleted_boundary(letter: Letter)
signal letter_expired(letter: Letter)

@export var catalog: AlphabetCatalog
@export var letter_scene: PackedScene
@export var word_controller: WordGameController
@export var profile: LetterSpawnProfile
@export var deterministic_seed: int = -1

var total_spawned: int = 0
var total_collected: int = 0
var total_deleted_boundary: int = 0
var total_expired: int = 0
var last_spawned_letter: String = ""

var _spawn_timer: float = 0.0
var _vowel_timer: float = 0.0
var _sequence_index: int = 1
var _vowel_index: int = 0
var _rng := RandomNumberGenerator.new()
var _active: Array[Letter] = []
var _spawning_paused := false


func _ready() -> void:
	if profile == null:
		profile = LetterSpawnProfile.new()
	if deterministic_seed >= 0:
		_rng.seed = deterministic_seed
	else:
		_rng.randomize()


func _process(delta: float) -> void:
	if _spawning_paused:
		_tick_lifetime()
		_cleanup_boundaries()
		return
	_spawn_timer += delta
	_vowel_timer += delta
	var interval := _effective_spawn_interval()
	if _spawn_timer >= interval:
		_spawn_timer = 0.0
		_spawn_sequence_letter()
	if profile.vowel_spawn_interval > 0.0 and _vowel_timer >= profile.vowel_spawn_interval:
		_vowel_timer = 0.0
		_spawn_vowel_letter()
	_tick_lifetime()
	_cleanup_boundaries()


func register_collected(letter: Letter) -> void:
	total_collected += 1
	_active.erase(letter)


func get_active_count() -> int:
	return _active.size()


func refresh_active_letter_textures() -> void:
	for letter in _active:
		if letter != null and is_instance_valid(letter):
			letter.refresh_texture()


func set_spawning_paused(paused: bool) -> void:
	_spawning_paused = paused


func clear_all_letters() -> void:
	for i in range(_active.size() - 1, -1, -1):
		var letter := _active[i]
		if letter != null and is_instance_valid(letter):
			letter.queue_free()
	_active.clear()
	_spawn_timer = 0.0
	_vowel_timer = 0.0


func cycle_font_set(registry: FontSetRegistry) -> String:
	if registry == null or catalog == null:
		return ""
	registry.cycle_next()
	registry.apply_to_catalog(catalog)
	refresh_active_letter_textures()
	return registry.get_current_name()


func cycle_letter_backdrop(registry: LetterBackdropRegistry) -> String:
	if registry == null:
		return ""
	registry.cycle_next()
	registry.apply_to_letters()
	refresh_active_letter_backdrops()
	return registry.get_current_name()


func refresh_active_letter_backdrops() -> void:
	for letter in _active:
		if letter != null and is_instance_valid(letter):
			letter.refresh_backdrop()


func get_spawn_timer_remaining() -> float:
	return maxf(0.0, _effective_spawn_interval() - _spawn_timer)


func debug_spawn_letter(ch: String) -> void:
	spawn_letter_at(ch.to_upper(), Vector2(_pick_spawn_x(), profile.spawn_y), Vector2.ZERO, false, true)


func spawn_letter_at(
	ch: String,
	spawn_position: Vector2,
	initial_velocity: Vector2,
	force_vowel_style: bool,
	use_initial_velocity: bool = true,
	allow_dense_horizontal_cluster: bool = false,
) -> Letter:
	if letter_scene == null or catalog == null:
		return null
	if _active.size() >= profile.max_active_letters:
		return null
	if use_initial_velocity and absf(initial_velocity.x) > 20.0:
		var world_pos := to_global(spawn_position)
		var dir_sign := int(signf(initial_velocity.x))
		if not can_spawn_horizontal_at(world_pos, dir_sign, allow_dense_horizontal_cluster):
			return null
	var letter: Letter = letter_scene.instantiate()
	add_child(letter)
	letter.position = spawn_position
	var tex_path := catalog.get_texture_path(ch)
	if not ResourceLoader.exists(tex_path):
		letter.queue_free()
		return null
	var target := _rng.randf_range(profile.size_min, profile.size_max)
	var scale_factor := catalog.compute_spawn_scale(target)
	var spawn_modulate := catalog.get_letter_modulate(ch, _rng)
	var fall := _rng.randf_range(profile.fall_speed_min, profile.fall_speed_max)
	letter.catalog = catalog
	letter.configure(
		ch,
		total_spawned,
		scale_factor,
		spawn_modulate,
		fall,
		initial_velocity,
		use_initial_velocity,
		profile.letter_lifetime,
		profile.letter_fade_start,
		0.0,
		target,
	)
	letter.resolved.connect(_on_letter_resolved)
	_active.append(letter)
	total_spawned += 1
	last_spawned_letter = ch
	letter_spawned.emit(letter, ch)
	return letter


func _effective_spawn_interval() -> float:
	var count := _active.size()
	if count >= profile.throttle_count_high:
		return profile.spawn_interval * profile.throttle_multiplier_high
	if count >= profile.throttle_count_low:
		return profile.spawn_interval * profile.throttle_multiplier_mid
	return profile.spawn_interval


func _spawn_sequence_letter() -> void:
	if _active.size() >= profile.max_active_letters:
		return
	var letters := catalog.all_letters() if catalog else PackedStringArray(["A"])
	var idx := clampi(_sequence_index - 1, 0, letters.size() - 1)
	var ch := letters[idx]
	_spawn_letter_in_profile(ch, false)
	_sequence_index += 1
	if _sequence_index > 26:
		_sequence_index = 1


func _spawn_vowel_letter() -> void:
	if _active.size() >= profile.max_active_letters:
		return
	if profile.vowel_spawn_interval <= 0.0:
		return
	var vowels := PackedStringArray(["A", "E", "I", "O", "U"])
	var idx := _vowel_index % vowels.size()
	_spawn_letter_in_profile(vowels[idx], true)
	_vowel_index = (_vowel_index + 1) % vowels.size()


func _spawn_letter_in_profile(ch: String, force_vowel_style: bool) -> void:
	if profile.kind == LetterSpawnProfile.ProfileKind.LANE_RAIN:
		ch = _pick_lane_biased_letter(ch, force_vowel_style)
	var x := _pick_spawn_x_with_spacing(_lane_center_x(ch, force_vowel_style))
	spawn_letter_at(ch, Vector2(x, profile.spawn_y), Vector2.ZERO, force_vowel_style, false)


func _pick_spawn_x() -> float:
	return _rng.randf_range(profile.spawn_x_min, profile.spawn_x_max)


func _pick_spawn_x_with_spacing(preferred_x: float) -> float:
	var x := preferred_x
	for attempt in range(profile.spawn_spacing_retries):
		if attempt > 0:
			x = _rng.randf_range(profile.spawn_x_min, profile.spawn_x_max)
		if _has_spacing_at(x):
			return x
	return x


func _has_spacing_at(x: float) -> bool:
	for letter in _active:
		if letter == null or not is_instance_valid(letter):
			continue
		if absf(letter.global_position.x - x) < profile.min_spawn_spacing_x:
			return false
	return true


func can_spawn_horizontal_at(
	world_pos: Vector2,
	dir_sign: int,
	allow_dense_cluster: bool = false,
) -> bool:
	var nearby := count_horizontal_neighbors(world_pos, dir_sign)
	if nearby == 0:
		return true
	if nearby == 1:
		return true
	if nearby == 2 and allow_dense_cluster:
		return true
	return false


func count_horizontal_neighbors(world_pos: Vector2, dir_sign: int) -> int:
	var count := 0
	var min_gap := profile.min_horizontal_spacing_x
	var y_tol := profile.horizontal_lane_y_tolerance
	for letter in _active:
		if letter == null or not is_instance_valid(letter):
			continue
		if absf(letter.velocity.x) < 20.0:
			continue
		if int(signf(letter.velocity.x)) != dir_sign:
			continue
		if absf(letter.global_position.y - world_pos.y) > y_tol:
			continue
		if absf(letter.global_position.x - world_pos.x) < min_gap:
			count += 1
	return count


func _lane_center_x(ch: String, force_vowel_style: bool) -> float:
	var width := profile.spawn_x_max - profile.spawn_x_min
	var lane := _lane_index_for_letter(ch, force_vowel_style)
	var lane_start := profile.spawn_x_min
	var lane_width := width
	if profile.kind == LetterSpawnProfile.ProfileKind.LANE_RAIN:
		if lane == 0:
			lane_width = width * profile.lane_vowel_end
		elif lane == 1:
			lane_start = profile.spawn_x_min + width * profile.lane_vowel_end
			lane_width = width * (profile.lane_common_end - profile.lane_vowel_end)
		else:
			lane_start = profile.spawn_x_min + width * profile.lane_common_end
			lane_width = width * (1.0 - profile.lane_common_end)
	return lane_start + _rng.randf_range(lane_width * 0.1, lane_width * 0.9)


func _lane_index_for_letter(ch: String, force_vowel_style: bool) -> int:
	if force_vowel_style or catalog.is_vowel(ch):
		return 0
	if ch in LetterSpawnProfile.RARE_CONSONANTS:
		return 2
	return 1


func _pick_lane_biased_letter(default_ch: String, force_vowel_style: bool) -> String:
	if force_vowel_style:
		return default_ch
	var ch := default_ch
	if catalog.is_vowel(ch):
		if profile.lane_rain_vowel_reroll_chance > 0.0 and _rng.randf() < profile.lane_rain_vowel_reroll_chance:
			ch = _pick_random_vowel()
	else:
		if profile.lane_rain_consonant_reroll_chance > 0.0 and _rng.randf() < profile.lane_rain_consonant_reroll_chance:
			ch = _pick_random_common_consonant()
	return ch


func _pick_random_vowel() -> String:
	var vowels := PackedStringArray(["A", "E", "I", "O", "U"])
	return vowels[_rng.randi_range(0, vowels.size() - 1)]


func _pick_random_common_consonant() -> String:
	var common := _common_consonants()
	if common.is_empty():
		return "T"
	return common[_rng.randi_range(0, common.size() - 1)]


func _common_consonants() -> PackedStringArray:
	var out: PackedStringArray = []
	for ch in catalog.all_letters():
		if catalog.is_vowel(ch):
			continue
		if ch in LetterSpawnProfile.RARE_CONSONANTS:
			continue
		out.append(ch)
	return out


func _tick_lifetime() -> void:
	for i in range(_active.size() - 1, -1, -1):
		var letter := _active[i]
		if letter == null or not is_instance_valid(letter):
			_active.remove_at(i)
			continue
		if letter.is_expired():
			letter_expired.emit(letter)
			total_expired += 1
			_active.remove_at(i)
			letter.try_resolve(Letter.Resolution.EXPIRED, "lifetime")


func _on_letter_resolved(letter: Letter, outcome: Letter.Resolution, _character: String) -> void:
	if outcome == Letter.Resolution.PLAYER_COLLECT or outcome == Letter.Resolution.ENEMY_COLLECT:
		register_collected(letter)
	if outcome == Letter.Resolution.BULLET_COLLECT:
		register_collected(letter)
	_active.erase(letter)


func _cleanup_boundaries() -> void:
	for i in range(_active.size() - 1, -1, -1):
		var letter := _active[i]
		if letter == null or not is_instance_valid(letter):
			_active.remove_at(i)
			continue
		var pos := letter.global_position
		if (
			pos.y >= profile.delete_y
			or pos.x <= profile.delete_x_min
			or pos.x >= profile.delete_x_max
		):
			letter_deleted_boundary.emit(letter)
			total_deleted_boundary += 1
			_active.remove_at(i)
			letter.try_resolve(Letter.Resolution.BOUNDARY, "boundary")
