class_name ActionCollectibleSpawner
extends Node2D

## Occasionally drops a single ACTION pickup from above the playfield.

@export var spawn_interval: float = 25.0
@export var spawn_x_min: float = 120.0
@export var spawn_x_max: float = 840.0
@export var spawn_y: float = -40.0
@export var max_active: int = 1

var _timer := 0.0
var _scene: PackedScene
var _paused := false


func set_spawning_paused(paused: bool) -> void:
	_paused = paused


func _ready() -> void:
	_scene = load("res://scenes/collectibles/action_collectible.tscn") as PackedScene
	_timer = spawn_interval * 0.5


func _physics_process(delta: float) -> void:
	if _paused:
		return
	_timer += delta
	if _timer < spawn_interval:
		return
	_timer = 0.0
	if _active_count() >= max_active:
		return
	_spawn_one()


func _active_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("action_collectible"):
		if is_instance_valid(node):
			count += 1
	return count


func _spawn_one() -> void:
	if _scene == null:
		return
	var pickup: ActionCollectible = _scene.instantiate()
	add_child(pickup)
	pickup.position = Vector2(
		randf_range(spawn_x_min, spawn_x_max),
		spawn_y,
	)
