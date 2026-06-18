class_name LetterCollector
extends Area2D

## Overlap-based letter pickup — attached to Player at runtime.

@export var controller: WordGameController
@export var player_shield: PlayerShield

var _processed_this_frame: Dictionary = {}


func _ready() -> void:
	add_to_group("player_collector")
	collision_layer = 0
	collision_mask = 8
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)


func sync_to_body_shape(center: Vector2 = Vector2.ZERO, size: Vector2 = Vector2(34, 52)) -> void:
	position = center
	for child in get_children():
		if child is CollisionShape2D:
			child.queue_free()
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	add_child(shape_node)


func _physics_process(_delta: float) -> void:
	_processed_this_frame.clear()


func try_collect_letter(letter: Letter) -> bool:
	if letter == null or letter.is_resolved():
		return false
	var player := get_parent() as CharacterBody2D
	if player:
		var combat := player.get_node_or_null("CharacterCombat")
		if combat and combat.blocks_collection():
			return false
		if _blocks_special_moves(player):
			return false
	if player_shield and player_shield.blocks_letter_collection():
		return false
	if controller == null:
		return false
	return LetterCollection.try_player_collect(
		letter,
		controller,
		player_shield,
		"player_collector",
		Letter.Resolution.PLAYER_COLLECT,
	)


func _on_area_entered(area: Area2D) -> void:
	if area == null or not area is Letter:
		return
	var letter := area as Letter
	var id := letter.get_instance_id()
	if _processed_this_frame.has(id):
		return
	if try_collect_letter(letter):
		_processed_this_frame[id] = true


func _blocks_special_moves(player: CharacterBody2D) -> bool:
	for child in player.get_children():
		if child.has_method("blocks_collection") and child.call("blocks_collection"):
			return true
	return false
