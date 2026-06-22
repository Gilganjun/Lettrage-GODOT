@tool
extends Node2D

## Level 2 runway — keeps floor collision aligned with the platform sprite.
## Move MainPlatform in the editor; collision follows the sprite automatically.

@export var walk_surface_texture_y := 33.0:
	set(value):
		walk_surface_texture_y = value
		sync_floor_collision()

@export var floor_collision_width := 1920.0:
	set(value):
		floor_collision_width = maxf(value, 32.0)
		sync_floor_collision()

@export var floor_collision_height := 32.0:
	set(value):
		floor_collision_height = maxf(value, 4.0)
		sync_floor_collision()


func _ready() -> void:
	sync_floor_collision()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		sync_floor_collision()


func get_walk_surface_global_y() -> float:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return global_position.y
	return sprite.global_position.y + walk_surface_texture_y * absf(sprite.scale.y)


func sync_floor_collision() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var body := get_node_or_null("StaticBody2D") as StaticBody2D
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D if body else null
	if sprite == null or body == null or shape_node == null or sprite.texture == null:
		return

	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		return
	rect.size = Vector2(floor_collision_width, floor_collision_height)

	var sprite_width := sprite.texture.get_size().x * absf(sprite.scale.x)
	var walk_local_y := walk_surface_texture_y * absf(sprite.scale.y)
	body.position = Vector2(
		sprite.position.x + sprite_width * 0.5,
		sprite.position.y + walk_local_y + floor_collision_height * 0.5,
	)
	body.set_meta("walk_surface_y", get_walk_surface_global_y())
