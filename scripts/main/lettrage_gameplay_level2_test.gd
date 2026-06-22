extends "res://scripts/main/lettrage_gameplay.gd"

## Full gameplay loop wired to the Level 2 test scene (does not touch production Level 1).

const LEVEL2_LEVEL_SCENE := preload("res://scenes/levels/level2_test_level.tscn")
const LEVEL2_GAMEPLAY_SCENE := "res://scenes/test/level2_test_gameplay.tscn"


func _enter_tree() -> void:
	level_scene = LEVEL2_LEVEL_SCENE


func _ready() -> void:
	_configure_level2_visual_defaults()
	super._ready()
	_configure_level2_spawners()
	_configure_level2_letter_vfx()
	_assert_level2_mounted()


func _configure_level2_letter_vfx() -> void:
	# Foreground parallax uses z_as_relative=false at z_index 85, which draws over the
	# default LetterSpawner layer and hides shatter/rebound collect VFX on the platform.
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
	_configure_level2_enemy_patrol()


func _configure_level2_enemy_patrol() -> void:
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


func _begin_match_after_level_ready() -> void:
	_resolve_player_platform_landing()
	if level_root.has_method("reset_scroll_presentation"):
		level_root.reset_scroll_presentation(_player)
	match_controller.setup(match_overlay, _round_reset_context())
	if level_root.has_method("reset_scroll_presentation"):
		if not match_controller.round_started.is_connected(_on_level2_round_started_refresh_scroll):
			match_controller.round_started.connect(_on_level2_round_started_refresh_scroll)
	_start_match()


func _on_level2_round_started_refresh_scroll(_round_number: int) -> void:
	if level_root.has_method("reset_scroll_presentation"):
		level_root.reset_scroll_presentation(_player)
	if level_root.has_method("sync_layout_from_platform"):
		level_root.sync_layout_from_platform()
	_configure_level2_enemy_patrol()
	if _enemy and level_root.has_method("get_enemy_platform_landing_position"):
		var landing: Vector2 = level_root.get_enemy_platform_landing_position(_enemy)
		_enemy.global_position = landing
		_enemy_spawn = landing


func _configure_level2_visual_defaults() -> void:
	if visual_pass == null:
		return
	var blur := visual_pass.get_node_or_null("BackgroundBlur") as BackgroundBlur
	if blur:
		blur.enabled = false
	var band := visual_pass.get_node_or_null("GameplayFocusBand") as GameplayFocusBand
	if band:
		# Level 1 play-band overlay (y=180 hard edge + grey modulate) fights Level 2 art.
		band.background_modulate = Color(1.0, 1.0, 1.0, 1.0)
		band.decoration_modulate = Color(1.0, 1.0, 1.0, 1.0)
		band.play_band_color = Color(0.0, 0.0, 0.0, 0.0)
	var platform_pass := visual_pass.get_node_or_null("PlatformReadability") as PlatformReadability
	if platform_pass:
		platform_pass.enabled = false


func _configure_level2_spawners() -> void:
	var cannon_left := world.get_node_or_null("CannonLeft") as Node2D
	if cannon_left:
		cannon_left.position = Vector2(120.0, 300.0)
	var cannon_right := world.get_node_or_null("CannonRight") as Node2D
	if cannon_right:
		cannon_right.position = Vector2(1800.0, 300.0)
	if action_spawner:
		action_spawner.spawn_x_min = 200.0
		action_spawner.spawn_x_max = 1720.0
	if letter_spawner and letter_spawner.profile:
		letter_spawner.profile.spawn_x_min = 120.0
		letter_spawner.profile.spawn_x_max = 1800.0


func _assert_level2_mounted() -> void:
	if level_root == null:
		push_error("Level 2 test: level_root is missing — open %s and press F6" % LEVEL2_GAMEPLAY_SCENE)
		return
	if level_root.get_scene_file_path() != LEVEL2_LEVEL_SCENE.resource_path:
		push_error(
			"Level 2 test mounted wrong level scene: %s (expected %s)"
			% [level_root.get_scene_file_path(), LEVEL2_LEVEL_SCENE.resource_path]
		)
