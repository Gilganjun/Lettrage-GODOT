class_name PlayerGameplayAttach
extends RefCounted

## Attaches letter collector + toggle shield to the player without modifying movement.


static func attach(player: CharacterBody2D, word_controller: WordGameController) -> Dictionary:
	var body_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var pickup_center := Vector2.ZERO
	var pickup_size := Vector2(34, 52)
	if body_shape and body_shape.shape is RectangleShape2D:
		var body_rect := body_shape.shape as RectangleShape2D
		pickup_center = body_shape.position
		pickup_size = body_rect.size

	var shield := PlayerShield.new()
	player.add_child(shield)
	shield.attach_to_body(player, pickup_center)
	if shield.shield:
		shield.shield.z_index = 20
		shield.shield.configure_body_shape(pickup_size)

	var collector := LetterCollector.new()
	collector.controller = word_controller
	collector.player_shield = shield
	player.add_child(collector)
	collector.sync_to_body_shape(pickup_center, pickup_size)
	return {"shield": shield, "collector": collector}


static func attach_combat(body: CharacterBody2D, owner_kind: String, spawn_position: Vector2) -> Node:
	var scene := load("res://scenes/components/character_combat.tscn") as PackedScene
	var combat: Node = scene.instantiate()
	combat.owner_kind = owner_kind
	body.add_child(combat)
	combat.configure_spawn(spawn_position)
	return combat
