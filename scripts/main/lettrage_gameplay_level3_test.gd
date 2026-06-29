extends "res://scripts/main/lettrage_gameplay.gd"

## Full gameplay loop wired to Level 3 Sunset (does not touch production Level 1).

const LEVEL3_LEVEL_SCENE := preload("res://scenes/levels/level3_sunset_level.tscn")
const LEVEL3_GAMEPLAY_SCENE := "res://scenes/test/level3_sunset_gameplay.tscn"


func _enter_tree() -> void:
	level_scene = LEVEL3_LEVEL_SCENE


func _ready() -> void:
	_configure_level3_visual_defaults()
	super._ready()
	_configure_level3_spawners()
	_configure_level3_letter_vfx()
	_assert_level3_mounted()


func _configure_level3_letter_vfx() -> void:
	if letter_spawner:
		letter_spawner.z_as_relative = false
		letter_spawner.z_index = 100


func _spawn_enemy() -> void:
	if level_root.has_method("sync_layout_from_platform"):
		level_root.sync_layout_from_platform()
	if level_root.has_method("get_enemy_spawn_position") and not _enemy_row.is_empty():
		var spawn_x: float = level_root.get_enemy_spawn_position().x
		_enemy_row = _enemy_row.duplicate()
		_enemy_row["source_x"] = spawn_x
		if level_root.has_method("get_character_landing_at_x"):
			_enemy_row["source_y"] = level_root.get_character_landing_at_x(spawn_x).y
	super._spawn_enemy()
	if _enemy and level_root.has_method("get_enemy_platform_landing_position"):
		var landing: Vector2 = level_root.get_enemy_platform_landing_position(_enemy)
		_enemy.global_position = landing
		_enemy_spawn = landing
		if _enemy_combat and _enemy_combat.has_method("configure_spawn"):
			_enemy_combat.configure_spawn(landing)
	_configure_level3_enemy_patrol()


func _configure_level3_enemy_patrol() -> void:
	if _enemy == null or level_root == null:
		return
	if not level_root.has_method("get_patrol_bounds"):
		return
	var movement := _enemy.get_node_or_null("EnemyMovementController")
	if movement == null or not movement.has_method("configure_patrol"):
		return
	var bounds: Vector2 = level_root.get_patrol_bounds()
	movement.configure_patrol(bounds.x, bounds.y, _enemy.global_position.x)
	var targeting := _enemy.get_node_or_null("EnemyLetterTargeting")
	if targeting:
		targeting.patrol_min_x = bounds.x
		targeting.patrol_max_x = bounds.y


func _spawn_player() -> void:
	super._spawn_player()
	if _player == null:
		return
	_player.z_as_relative = false
	_player.z_index = 120
	var sprite := _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.visible = true


func _resolve_player_platform_landing() -> void:
	if level_root.has_method("sync_layout_from_platform"):
		level_root.sync_layout_from_platform()
	if _player and level_root.has_method("apply_camera_limits"):
		level_root.apply_camera_limits(_player.get_node_or_null("Camera2D") as Camera2D)
	super._resolve_player_platform_landing()
	if _player:
		_player.z_as_relative = false
		_player.z_index = 120
		var sprite := _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			sprite.visible = true
		if level_root.has_method("reset_scroll_presentation"):
			level_root.reset_scroll_presentation(_player)


func _get_scroll_presentation_player() -> Node2D:
	return _player


func _on_round_started_refresh_scroll(round_number: int) -> void:
	super._on_round_started_refresh_scroll(round_number)
	if level_root.has_method("sync_layout_from_platform"):
		level_root.sync_layout_from_platform()
	_configure_level3_enemy_patrol()
	if _enemy and level_root.has_method("get_enemy_platform_landing_position"):
		var landing: Vector2 = level_root.get_enemy_platform_landing_position(_enemy)
		_enemy.global_position = landing
		_enemy_spawn = landing


func _configure_level3_visual_defaults() -> void:
	if visual_pass == null:
		return
	var blur := visual_pass.get_node_or_null("BackgroundBlur") as BackgroundBlur
	if blur:
		blur.enabled = false
	var band := visual_pass.get_node_or_null("GameplayFocusBand") as GameplayFocusBand
	if band:
		band.background_modulate = Color(1.0, 1.0, 1.0, 1.0)
		band.decoration_modulate = Color(1.0, 1.0, 1.0, 1.0)
		band.play_band_color = Color(0.0, 0.0, 0.0, 0.0)
	var platform_pass := visual_pass.get_node_or_null("PlatformReadability") as PlatformReadability
	if platform_pass:
		platform_pass.enabled = false


func _configure_level3_spawners() -> void:
	var cannon_left := world.get_node_or_null("CannonLeft") as Node2D
	if cannon_left:
		cannon_left.position = Vector2(120.0, 300.0)
	var cannon_right := world.get_node_or_null("CannonRight") as Node2D
	if cannon_right:
		cannon_right.position = Vector2(1800.0, 300.0)
	if action_spawner:
		action_spawner.spawn_x_min = 200.0
		action_spawner.spawn_x_max = 1720.0
	if claw_spawner:
		claw_spawner.spawn_x_min = 200.0
		claw_spawner.spawn_x_max = 1720.0
	if letter_spawner and letter_spawner.profile:
		letter_spawner.profile.spawn_x_min = 120.0
		letter_spawner.profile.spawn_x_max = 1800.0


func _assert_level3_mounted() -> void:
	if level_root == null:
		push_error("Level 3 Sunset: level_root is missing — open %s and press F6" % LEVEL3_GAMEPLAY_SCENE)
		return
	if level_root.get_scene_file_path() != LEVEL3_LEVEL_SCENE.resource_path:
		push_error(
			"Level 3 Sunset mounted wrong level scene: %s (expected %s)"
			% [level_root.get_scene_file_path(), LEVEL3_LEVEL_SCENE.resource_path]
		)
