class_name LetterCannon
extends Node2D

## Fires horizontally scrolling letters with paced spacing (max ~2 per cluster).

enum FireDirection {
	LEFT_TO_RIGHT,
	RIGHT_TO_LEFT,
}

@export var director_path: NodePath
@export var fire_direction: FireDirection = FireDirection.LEFT_TO_RIGHT
@export var fire_interval: float = 3.2
@export var burst_count: int = 2
@export var burst_max: int = 2
@export var rare_extra_burst_chance: float = 0.07
@export var letter_speed: float = 150.0
@export var burst_letter_spacing_x: float = 0.0
@export var enabled: bool = true
@export var vowel_only: bool = false

var _timer := 0.0
var _director: LetterSpawnDirector
var _burst_busy := false


func _ready() -> void:
	_resolve_director()
	_timer = fire_interval * _rng_fraction()


func _process(delta: float) -> void:
	if not enabled or _burst_busy:
		return
	_resolve_director()
	if _director == null:
		return
	_timer += delta
	if _timer >= fire_interval:
		_timer = 0.0
		_fire_burst()


func _fire_burst() -> void:
	_fire_burst_async()


func _fire_burst_async() -> void:
	if _director == null:
		return
	_burst_busy = true
	var dir_sign := 1 if fire_direction == FireDirection.LEFT_TO_RIGHT else -1
	var count := _pick_burst_count()
	var spawn_local := _director.to_local(global_position)
	var world_y := global_position.y
	var spacing := _effective_burst_spacing()
	var delay := spacing / maxf(letter_speed, 1.0)
	var spawned := 0
	for i in range(count):
		if i > 0:
			await get_tree().create_timer(delay).timeout
			if not is_instance_valid(_director):
				break
		var allow_dense := i >= 2
		if not _director.can_spawn_horizontal_at(
			Vector2(global_position.x, world_y),
			dir_sign,
			allow_dense,
		):
			continue
		var ch := _pick_letter()
		var vel := Vector2(letter_speed * float(dir_sign), 0.0)
		var letter := _director.spawn_letter_at(
			ch,
			spawn_local,
			vel,
			vowel_only,
			true,
			allow_dense,
		)
		if letter:
			spawned += 1
	_burst_busy = false


func _pick_burst_count() -> int:
	var count := clampi(burst_count, 1, burst_max)
	if rare_extra_burst_chance > 0.0 and randf() < rare_extra_burst_chance:
		count += 1
	return mini(count, 3)


func _effective_burst_spacing() -> float:
	if burst_letter_spacing_x > 0.0:
		return burst_letter_spacing_x
	if _director and _director.profile:
		return _director.profile.min_horizontal_spacing_x
	return 200.0


func _pick_letter() -> String:
	if vowel_only:
		var vowels := PackedStringArray(["A", "E", "I", "O", "U"])
		return vowels[randi() % vowels.size()]
	if _director.catalog:
		var letters := _director.catalog.all_letters()
		return letters[randi() % letters.size()]
	return "A"


func _resolve_director() -> void:
	if _director != null and is_instance_valid(_director):
		return
	if director_path.is_empty():
		_director = get_parent() as LetterSpawnDirector
		return
	_director = get_node_or_null(director_path) as LetterSpawnDirector


func _rng_fraction() -> float:
	return randf_range(0.35, 0.85)
