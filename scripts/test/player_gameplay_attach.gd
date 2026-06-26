class_name PlayerGameplayAttach
extends RefCounted

## Attaches letter collector, shield, and letter shooter to the player.


static func attach(player: CharacterBody2D, word_controller: WordGameController) -> Dictionary:
	var body_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var pickup_center := Vector2.ZERO
	var pickup_size := Vector2(34, 52)
	if body_shape and body_shape.shape is RectangleShape2D:
		var body_rect := body_shape.shape as RectangleShape2D
		pickup_center = body_shape.position
		pickup_size = body_rect.size

	var shield := PlayerShield.new()
	shield.name = "PlayerShield"
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

	var shooter := LetterShooter.new()
	shooter.word_controller = word_controller
	shooter.player_shield = shield
	shooter.unlimited_ammo = false
	shooter.max_ammo = LetterShooter.DEFAULT_CLIP_SIZE
	shooter.starting_ammo = LetterShooter.DEFAULT_CLIP_SIZE
	shooter.sync_to_body(pickup_center)
	player.add_child(shooter)

	const PlayerRollScript := preload("res://scripts/player/player_roll.gd")
	const PlayerActionControllerScript := preload("res://scripts/player/player_action_controller.gd")
	const PlayerClawControllerScript := preload("res://scripts/player/player_claw_controller.gd")

	var roll: Node = PlayerRollScript.new()
	player.add_child(roll)

	var action: Node = PlayerActionControllerScript.new()
	player.add_child(action)

	var claw: PlayerClawController = PlayerClawControllerScript.new()
	claw.configure(word_controller, null)
	claw.sync_to_body(pickup_center)
	player.add_child(claw)

	return {
		"shield": shield,
		"collector": collector,
		"shooter": shooter,
		"roll": roll,
		"action": action,
		"claw": claw,
	}


static func attach_combat(body: CharacterBody2D, owner_kind: String, spawn_position: Vector2) -> Node:
	var scene := load("res://scenes/components/character_combat.tscn") as PackedScene
	var combat: Node = scene.instantiate()
	combat.owner_kind = owner_kind
	body.add_child(combat)
	combat.configure_spawn(spawn_position)
	return combat
