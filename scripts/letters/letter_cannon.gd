class_name LetterCannon
extends Node2D

## Fires horizontal letter bursts using a LetterSpawnDirector.

enum FireDirection {
	LEFT_TO_RIGHT,
	RIGHT_TO_LEFT,
}

@export var director_path: NodePath
@export var fire_direction: FireDirection = FireDirection.LEFT_TO_RIGHT
@export var fire_interval: float = 2.5
@export var burst_count: int = 3
@export var burst_delay: float = 0.12
@export var letter_speed: float = 300.0
@export var enabled: bool = true
@export var vowel_only: bool = false

var _timer := 0.0
var _director: LetterSpawnDirector


func _ready() -> void:
	_resolve_director()
	_timer = fire_interval * 0.5


func _process(delta: float) -> void:
	if not enabled:
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
	var spawn_pos := _director.to_local(global_position)
	for i in range(burst_count):
		var ch := _pick_letter()
		var vel := Vector2(letter_speed, 0.0)
		if fire_direction == FireDirection.RIGHT_TO_LEFT:
			vel.x = -letter_speed
		_director.spawn_letter_at(ch, spawn_pos, vel, vowel_only, true)
		if i < burst_count - 1:
			await get_tree().create_timer(burst_delay).timeout


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
