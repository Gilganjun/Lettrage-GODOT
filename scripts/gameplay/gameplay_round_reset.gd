class_name GameplayRoundReset
extends RefCounted

## Resets combatants, letters, words, ammo, and pickups between rounds.


static func reset_round(ctx: Dictionary) -> void:
	end_round_intro(ctx)
	var letter_spawner: LetterSpawnDirector = ctx.get("letter_spawner")
	var word_controller: WordGameController = ctx.get("word_controller")
	var enemy: Enemy = ctx.get("enemy")
	var player: PlayerMovement = ctx.get("player")
	var player_combat: Node = ctx.get("player_combat")
	var enemy_combat: Node = ctx.get("enemy_combat")
	var player_shooter: LetterShooter = ctx.get("player_shooter")
	var player_action: Node = ctx.get("player_action")
	var action_spawner: Node = ctx.get("action_spawner")
	var player_spawn: Vector2 = ctx.get("player_spawn", Vector2.ZERO)
	var player_landing: Vector2 = ctx.get("player_platform_landing", player_spawn)
	var enemy_spawn: Vector2 = ctx.get("enemy_spawn", Vector2.ZERO)
	var scene_tree: SceneTree = ctx.get("scene_tree")

	if letter_spawner:
		letter_spawner.set_spawning_paused(true)
		letter_spawner.clear_all_letters()
	if word_controller:
		word_controller.debug_clear_word()
	if enemy and enemy.word_controller:
		enemy.word_controller.debug_clear_word()
		enemy.word_controller.pick_new_target_word()
	if enemy:
		enemy.movement_locked = true
		enemy.global_position = enemy_spawn
		enemy.velocity = Vector2.ZERO
		if enemy.has_method("end_action_strike_freeze"):
			enemy.end_action_strike_freeze()
		if enemy.has_method("set_action_sequence_targeted"):
			enemy.set_action_sequence_targeted(false)
	if player:
		player.movement_locked = true
		player.global_position = player_landing
		player.velocity = Vector2.ZERO
		if player.has_method("end_action_strike_freeze"):
			player.end_action_strike_freeze()
		if player.has_method("set_action_sequence_targeted"):
			player.set_action_sequence_targeted(false)
		_reset_player_intro_presentation(player)
	if player_combat and player_combat.has_method("reset_combat"):
		player_combat.reset_combat()
	if enemy_combat and enemy_combat.has_method("reset_combat"):
		enemy_combat.reset_combat()
	if enemy:
		_reset_enemy_visual(enemy)
	if player_shooter:
		if player_shooter.has_method("cancel_aim"):
			player_shooter.cancel_aim()
		player_shooter.set_ammo(player_shooter.max_ammo)
	if player_action and player_action.has_method("reset_for_round"):
		player_action.reset_for_round()
	if enemy and enemy.has_method("get_action_controller"):
		var enemy_action = enemy.get_action_controller()
		if enemy_action and enemy_action.has_method("reset_for_round"):
			enemy_action.reset_for_round()
	_clear_action_collectibles(scene_tree)
	if action_spawner and action_spawner.has_method("set_spawning_paused"):
		action_spawner.set_spawning_paused(true)


static func begin_round_intro(ctx: Dictionary, level_config: LevelGameplayConfig) -> void:
	var player: PlayerMovement = ctx.get("player")
	var player_shield: PlayerShield = ctx.get("player_shield")
	var enemy: Enemy = ctx.get("enemy")
	var landing: Vector2 = ctx.get("player_platform_landing", ctx.get("player_spawn", Vector2.ZERO))
	if player_shield:
		player_shield.set_intro_input_blocked(true)
		player_shield.set_active(true)
	if enemy and enemy.shield_controller:
		enemy.shield_controller.set_intro_shield_forced(true)
	if player:
		var drop_top_y := _resolve_intro_drop_top_y(landing, level_config, player)
		player.begin_round_intro_fall(
			landing,
			level_config.intro_drop_height,
			level_config.intro_fall_ease_power,
			drop_top_y,
		)
		var cam := _get_player_camera(player)
		if cam and cam.has_method("begin_round_intro_cinematic"):
			cam.begin_round_intro_cinematic(
				level_config.intro_close_zoom_percent,
				cam.base_zoom_percent,
			)
		var fall_fx := _get_intro_fall_fx(player)
		if fall_fx:
			fall_fx.begin()
		tick_round_intro(ctx, 0.0, level_config)


static func tick_round_intro(
	ctx: Dictionary,
	progress: float,
	_level_config: LevelGameplayConfig = null,
) -> void:
	var player: PlayerMovement = ctx.get("player")
	if player and player.round_intro_fall_active:
		player.tick_round_intro_fall(progress)
	var cam := _get_player_camera(player)
	if cam and cam.has_method("tick_round_intro_cinematic"):
		cam.tick_round_intro_cinematic(progress)
	var fall_fx := _get_intro_fall_fx(player)
	if fall_fx:
		fall_fx.tick(progress)


static func end_round_intro(ctx: Dictionary) -> void:
	var player: PlayerMovement = ctx.get("player")
	var player_shield: PlayerShield = ctx.get("player_shield")
	var enemy: Enemy = ctx.get("enemy")
	if player and player.round_intro_fall_active:
		player.end_round_intro_fall()
	var cam := _get_player_camera(player)
	if cam and cam.has_method("end_round_intro_cinematic"):
		cam.end_round_intro_cinematic()
	var fall_fx := _get_intro_fall_fx(player)
	if fall_fx:
		fall_fx.end()
	if player_shield:
		player_shield.set_intro_input_blocked(false)
		player_shield.set_active(false)
	if enemy and enemy.shield_controller:
		enemy.shield_controller.set_intro_shield_forced(false)


static func begin_round_play(ctx: Dictionary) -> void:
	var letter_spawner: LetterSpawnDirector = ctx.get("letter_spawner")
	var enemy: Enemy = ctx.get("enemy")
	var player: PlayerMovement = ctx.get("player")
	var action_spawner: Node = ctx.get("action_spawner")
	if player:
		player.movement_locked = false
	if enemy:
		enemy.movement_locked = false
	if letter_spawner:
		letter_spawner.set_spawning_paused(false)
	if action_spawner and action_spawner.has_method("set_spawning_paused"):
		action_spawner.set_spawning_paused(false)


static func _get_player_camera(player: PlayerMovement) -> Camera2D:
	if player == null:
		return null
	return player.get_node_or_null("Camera2D") as Camera2D


static func _get_intro_fall_fx(player: PlayerMovement) -> IntroFallFx:
	if player == null:
		return null
	return player.get_node_or_null("IntroFallFx") as IntroFallFx


static func _resolve_intro_drop_top_y(
	landing: Vector2,
	level_config: LevelGameplayConfig,
	player: PlayerMovement,
) -> float:
	if not level_config.intro_use_drop_top_y:
		return NAN
	var from_height := landing.y - level_config.intro_drop_height
	var from_top := level_config.intro_drop_top_y
	var cam := _get_player_camera(player)
	if cam:
		from_top = minf(from_top, float(cam.limit_top) + 48.0)
	return minf(from_top, from_height)


static func _reset_player_intro_presentation(player: PlayerMovement) -> void:
	if player and player.has_method("cancel_round_intro_land_pose"):
		player.cancel_round_intro_land_pose()
	var cam := _get_player_camera(player)
	if cam and cam.has_method("reset_strike_presentation"):
		cam.reset_strike_presentation()
	elif cam and cam.has_method("end_action_cinematic"):
		cam.end_action_cinematic()
		if cam.has_method("reset_to_base"):
			cam.reset_to_base()
	if cam and cam.has_method("end_round_intro_cinematic"):
		cam.end_round_intro_cinematic()
	var fall_fx := _get_intro_fall_fx(player)
	if fall_fx:
		fall_fx.end()


static func _clear_action_collectibles(scene_tree: SceneTree) -> void:
	if scene_tree == null:
		return
	for node in scene_tree.get_nodes_in_group("action_collectible"):
		if is_instance_valid(node):
			node.queue_free()


static func _reset_enemy_visual(enemy: Enemy) -> void:
	if enemy.sprite == null:
		return
	enemy.sprite.speed_scale = 1.0
	if enemy.sprite.sprite_frames and enemy.sprite.sprite_frames.has_animation("Idle"):
		enemy.sprite.play("Idle")
	enemy.movement_state = EnemyAnimation.MovementState.IDLE
	if enemy.animation_controller:
		enemy.animation_controller.apply_state(enemy.movement_state, enemy.facing, INF)
