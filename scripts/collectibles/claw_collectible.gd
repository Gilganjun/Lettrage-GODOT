class_name ClawCollectible
extends Node2D

## Falling CLAW pickup — grants limited claw charges.

signal collected

const PICKUP_RANGE := 55.0
const DEFAULT_DISPLAY_WORLD_SIZE := 72.0

@export var fall_speed: float = 140.0
@export var lifetime: float = 18.0
@export var display_world_size: float = DEFAULT_DISPLAY_WORLD_SIZE
@export var pickup_range: float = PICKUP_RANGE

var _age := 0.0
var _resolved := false


func _ready() -> void:
	add_to_group("claw_collectible")
	z_index = 80
	_build_visual()


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	position.y += fall_speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_try_collect_nearby()


func _build_visual() -> void:
	var hook := Polygon2D.new()
	hook.name = "Icon"
	hook.color = Color(0.35, 0.92, 1.0, 1.0)
	hook.polygon = PackedVector2Array([
		Vector2(-10, -18),
		Vector2(10, -18),
		Vector2(10, 4),
		Vector2(4, 12),
		Vector2(-2, 4),
		Vector2(-10, 4),
	])
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.2, 0.55, 0.75, 1.0)
	ring.closed = true
	var r := display_world_size * 0.34
	ring.points = PackedVector2Array([
		Vector2(-r, -r * 0.2),
		Vector2(0, -r),
		Vector2(r, -r * 0.2),
		Vector2(r * 0.55, r * 0.55),
		Vector2(-r * 0.55, r * 0.55),
	])
	add_child(ring)
	add_child(hook)


func _try_collect_nearby() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D and _can_collect(node as CharacterBody2D):
			_try_collect_for_player(node as CharacterBody2D)
			return


func _can_collect(body: CharacterBody2D) -> bool:
	return global_position.distance_to(_collector_point(body)) <= pickup_range


func _collector_point(body: CharacterBody2D) -> Vector2:
	if body.has_method("get_action_pickup_point"):
		return body.call("get_action_pickup_point")
	return body.global_position


func _try_collect_for_player(body: CharacterBody2D) -> void:
	var controller := _find_player_claw_controller(body)
	if controller == null:
		return
	if controller.get_charges() >= controller.max_claw_charges:
		return
	controller.add_charge()
	PowerUpCollectSfx.play_claw(self)
	_resolve_player_pickup("CLAW", "claw")


func _resolve_pickup() -> void:
	_resolved = true
	collected.emit()
	queue_free()


func _resolve_player_pickup(label_text: String, slot_id: String) -> void:
	_resolved = true
	collected.emit()
	CollectiblePickupFlyFx.begin_player_pickup(self, label_text, slot_id, display_world_size)


func _find_player_claw_controller(player: CharacterBody2D) -> PlayerClawController:
	for child in player.get_children():
		if child is PlayerClawController:
			return child as PlayerClawController
	return null
