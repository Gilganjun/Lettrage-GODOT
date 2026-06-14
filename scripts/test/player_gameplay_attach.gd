class_name PlayerGameplayAttach
extends RefCounted

## Attaches letter collector + toggle shield to the player without modifying movement.


static func attach(player: CharacterBody2D, word_controller: WordGameController) -> Dictionary:
	var shield := PlayerShield.new()
	player.add_child(shield)
	var half_h := 40.0
	if player.has_method("get") and player.get("collision_shape"):
		pass
	shield.attach_to_body(player, Vector2(0, -6))
	var collector := LetterCollector.new()
	collector.controller = word_controller
	collector.player_shield = shield
	player.add_child(collector)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 52)
	shape_node.shape = rect
	collector.add_child(shape_node)
	collector.position = Vector2(0, -4)
	return {"shield": shield, "collector": collector}
