class_name ActionCollectible
extends Node2D

## Falling ACTION pickup — grants one special attack charge.

signal collected

const FIST_TEXTURE_PATH := "res://assets/Fist_Icon.png"
const DEFAULT_DISPLAY_WORLD_SIZE := 90.0
## Shared with enemy icon chase — keep in sync with EnemyActionController.ICON_PICKUP_RANGE.
const PICKUP_RANGE := 55.0

@export var fall_speed: float = 140.0
@export var lifetime: float = 18.0
@export var display_world_size: float = DEFAULT_DISPLAY_WORLD_SIZE
@export var pickup_range: float = PICKUP_RANGE

var _age := 0.0
var _resolved := false


func _ready() -> void:
	add_to_group("action_collectible")
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
	var texture := _load_fist_texture()
	var sprite := Sprite2D.new()
	sprite.name = "Icon"
	sprite.centered = true
	sprite.texture = texture
	if texture:
		var tex_size := texture.get_size()
		var ref := maxf(maxf(tex_size.x, tex_size.y), 1.0)
		var scale_factor := display_world_size / ref
		sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(sprite)


func _load_fist_texture() -> Texture2D:
	if ResourceLoader.exists(FIST_TEXTURE_PATH):
		var imported := load(FIST_TEXTURE_PATH) as Texture2D
		if imported != null:
			return imported
	var image := Image.new()
	if image.load(FIST_TEXTURE_PATH) == OK:
		return ImageTexture.create_from_image(image)
	push_warning("ActionCollectible: missing texture at %s" % FIST_TEXTURE_PATH)
	return null


func _try_collect_nearby() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is CharacterBody2D and _can_collect(node as CharacterBody2D):
			_try_collect_for_enemy(node as CharacterBody2D)
			return
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
	var controller := _find_player_action_controller(body)
	if controller == null:
		return
	if controller.get_charges() >= controller.max_action_charges:
		return
	controller.add_charge(1)
	PowerUpCollectSfx.play_combat(self)
	_resolve_player_pickup("COMBAT", "combat")


func _try_collect_for_enemy(body: CharacterBody2D) -> void:
	if not body.has_method("get_action_controller"):
		return
	var controller = body.call("get_action_controller")
	if controller == null:
		return
	if controller.get_charges() >= controller.max_action_charges:
		return
	controller.add_charge(1)
	_resolve_pickup()


func _resolve_pickup() -> void:
	_resolved = true
	collected.emit()
	queue_free()


func _resolve_player_pickup(label_text: String, slot_id: String) -> void:
	_resolved = true
	collected.emit()
	CollectiblePickupFlyFx.begin_player_pickup(self, label_text, slot_id, display_world_size)


func _find_player_action_controller(player: CharacterBody2D) -> Node:
	for child in player.get_children():
		if child.has_method("add_charge"):
			return child
	return null
