extends Node2D

## Phase 2C3 — production playable loop (best-of-3 rounds, countdown, win/loss).
## Enable debug_mode in the Inspector, or press Shift+F2 — opens a small ⚙ dock.

const GameKeyboardCommands := preload("res://scripts/ui/game_keyboard_commands.gd")
const LEVEL_SCENE := preload("res://scenes/levels/main2_heallthbartest_level.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const CATALOG := preload("res://resources/letters/alphabet_catalog.tres")
const LETTER_SCENE := preload("res://scenes/letters/letter.tscn")
const DEFAULT_LEVEL_CONFIG := preload("res://resources/gameplay/level1_config.tres")
const LayoutBuilder := preload("res://scripts/level/gdevelop_layout_builder.gd")
const PlayerAttach := preload("res://scripts/test/player_gameplay_attach.gd")
const WordGameFeatures := preload("res://scripts/word_game/word_game_features.gd")
const FontSetRegistry := preload("res://scripts/resources/font_set_registry.gd")
const LetterBackdropRegistry := preload("res://scripts/letters/letter_backdrop_registry.gd")
const TRANSFORMS_PATH := "res://resources/phase2a/instance_transforms.json"
const ENEMY_SPAWN_PATH := "res://resources/enemy/enemy_spawn.json"
const LANE_PROFILE := preload("res://resources/letters/lane_rain_spawn_profile.tres")
const POP_SOUNDS := [
	preload("res://assets/463388__vilkas-sound__vs-pop-4.mp3"),
	preload("res://assets/463389__vilkas-sound__vs-pop-3.mp3"),
]

@export var level_config: LevelGameplayConfig
@export var level_scene: PackedScene
@export var debug_mode: bool = false

@onready var world: Node2D = $World
@onready var level_root: Node2D = $World/Level
@onready var player_root: Node2D = $World/PlayerRoot
@onready var enemy_root: Node2D = $World/EnemyRoot
@onready var letter_spawner: LetterSpawner = $World/LetterSpawner
@onready var word_controller: WordGameController = $WordGameController
@onready var collision_debug: Node2D = $World/CollisionDebug
@onready var hud: Control = $UI/WordGameHud
@onready var combat_hud: Control = $UI/CombatHud
@onready var word_celebration: CanvasLayer = $UI/WordCelebrationPlayer
@onready var word_garble_player: CanvasLayer = $UI/WordGarblePlayer
@onready var debug_dock: GameplayDebugDock = $UI/GameplayDebugDock
@onready var damage_bridge: Node = $WordDamageBridge
@onready var visual_pass: Phase2C1VisualPass = $Phase2C1VisualPass
@onready var match_overlay: MatchOverlay = $UI/MatchOverlay
@onready var match_controller: MatchController = $MatchController
@onready var action_spawner: Node = $World/ActionCollectibleSpawner

var _collider_nodes: Array[Node] = []
var _collision_debug_enabled := false
var _font_sets: FontSetRegistry
var _letter_backdrops: LetterBackdropRegistry
var _debug_font_name := ""
var _debug_backdrop_name := ""
var _player_row: Dictionary = {}
var _enemy_row: Dictionary = {}
var _enemy: Enemy
var _player: PlayerMovement
var _player_shield: PlayerShield
var _player_combat: Node
var _enemy_combat: Node
var _player_shooter: LetterShooter
var _player_action: Node
var _player_spawn := Vector2(279.0, 231.0)
var _player_platform_landing := Vector2(279.0, 413.0)
var _enemy_spawn := Vector2(740.0, 406.0)


func _ready() -> void:
	_ensure_level_mounted()
	if level_config == null:
		level_config = DEFAULT_LEVEL_CONFIG
	for stream in POP_SOUNDS:
		word_controller.collect_sounds.append(stream)
	word_controller.valid_word_sound = preload("res://assets/487436__elijahdanie__game-win.mp3")
	word_controller.invalid_word_sound = preload("res://assets/369520__kinoton__bass-power-down.wav")
	word_controller.delete_letter_sound = preload("res://assets/176238__melissapons__sci-fi-short-error.wav")
	letter_spawner.catalog = CATALOG
	letter_spawner.letter_scene = LETTER_SCENE
	letter_spawner.word_controller = word_controller
	letter_spawner.profile = LANE_PROFILE
	letter_spawner.set_spawning_paused(true)
	_apply_level_font()
	_load_transform_rows()
	_spawn_player()
	_spawn_enemy()
	_setup_debug_tools()
	_setup_combat()
	_wire_hud()
	if visual_pass:
		visual_pass.setup(
			level_root,
			letter_spawner,
			word_controller,
			_enemy,
			combat_hud,
			player_root,
			enemy_root,
		)
	_apply_debug_visibility()
	match_controller.config = level_config
	call_deferred("_begin_match_after_level_ready")
	# Player._ready() already enables the follow camera — do not call activate_follow_camera
	# again after the match intro starts or it resets zoom to base immediately.


func _ensure_level_mounted() -> void:
	if level_scene == null:
		return
	var existing := world.get_node_or_null("Level") as Node2D
	if existing != null and existing.get_scene_file_path() == level_scene.resource_path:
		level_root = existing
		return
	if existing != null:
		existing.queue_free()
	var level := level_scene.instantiate() as Node2D
	level.name = "Level"
	world.add_child(level)
	world.move_child(level, 0)
	level_root = level


func _setup_debug_tools() -> void:
	_ensure_debug_registries()
	_collect_level_colliders()
	if collision_debug:
		collision_debug.setup(_collider_nodes)
		collision_debug.set_debug_enabled(false)


func _ensure_debug_registries() -> void:
	if not debug_mode:
		return
	if _font_sets == null:
		_font_sets = FontSetRegistry.create()
		_debug_font_name = _font_sets.get_current_name()
	if _letter_backdrops == null:
		_letter_backdrops = LetterBackdropRegistry.create()
		_letter_backdrops.apply_to_letters()
		_debug_backdrop_name = _letter_backdrops.get_current_name()


func _cycle_font_set() -> void:
	_ensure_debug_registries()
	if _font_sets == null:
		return
	_debug_font_name = letter_spawner.cycle_font_set(_font_sets)


func _cycle_letter_backdrop() -> void:
	_ensure_debug_registries()
	if _letter_backdrops == null:
		return
	_debug_backdrop_name = letter_spawner.cycle_letter_backdrop(_letter_backdrops)


func _apply_level_font() -> void:
	var registry := FontSetRegistry.create()
	if not registry.apply_to_catalog_by_id(CATALOG, level_config.font_set_id):
		registry.apply_to_catalog(CATALOG)


func _round_reset_context() -> Dictionary:
	return {
		"letter_spawner": letter_spawner,
		"word_controller": word_controller,
		"enemy": _enemy,
		"player": _player,
		"player_combat": _player_combat,
		"enemy_combat": _enemy_combat,
		"player_shooter": _player_shooter,
		"player_action": _player_action,
		"player_shield": _player_shield,
		"action_spawner": action_spawner,
		"player_spawn": _player_spawn,
		"player_platform_landing": _player_platform_landing,
		"enemy_spawn": _enemy_spawn,
		"scene_tree": get_tree(),
	}


func _start_match() -> void:
	match_controller.start_match()


func _setup_combat() -> void:
	damage_bridge.player_combat = _player_combat
	damage_bridge.enemy_combat = _enemy_combat
	damage_bridge.bind_word_systems(word_controller, _enemy.word_controller)
	if _player_combat:
		_player_combat.auto_respawn_on_death = false
		_player_combat.death_started.connect(_on_player_death_started)
	if _enemy_combat:
		_enemy_combat.auto_respawn_on_death = false
		_enemy_combat.death_started.connect(_on_enemy_death_started)


func _on_player_death_started(_source: String) -> void:
	match_controller.on_player_death()


func _on_enemy_death_started(_source: String) -> void:
	match_controller.on_enemy_death()


func _spawn_player() -> void:
	if _player_row.is_empty():
		push_error("Player transform row missing")
		return
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player_root.add_child(player)
	var spawn_row := _player_row.duplicate()
	if level_root.has_method("get_player_spawn_position"):
		_player_spawn = level_root.get_player_spawn_position()
		spawn_row["source_x"] = _player_spawn.x
		spawn_row["source_y"] = _player_spawn.y
	if player.has_method("configure_from_gdevelop"):
		player.configure_from_gdevelop(spawn_row)
	player.z_index = 100
	_player = player as PlayerMovement
	_player.movement_locked = true
	var attached := PlayerAttach.attach(player, word_controller)
	_player_shield = attached.get("shield")
	_player_shooter = attached.get("shooter")
	_player_action = attached.get("action")
	if _player_action:
		_player_action.debug_infinite_action = debug_mode
	_player_combat = PlayerAttach.attach_combat(player, "player", _player_spawn)
	_player_combat.auto_respawn_on_death = false
	if level_root.has_method("collect_ladder_areas"):
		for ladder in level_root.collect_ladder_areas():
			if player.has_method("register_ladder"):
				player.register_ladder(ladder)


func _spawn_enemy() -> void:
	if _enemy_row.is_empty():
		push_error("Enemy spawn row missing")
		return
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy_root.add_child(enemy)
	enemy.configure_from_gdevelop(_enemy_row)
	enemy.z_index = 90
	enemy.movement_locked = true
	_enemy = enemy
	_enemy_spawn = enemy.global_position
	_enemy_combat = PlayerAttach.attach_combat(enemy, "enemy", _enemy_spawn)
	_enemy_combat.auto_respawn_on_death = false
	if level_root.has_method("collect_ladder_areas"):
		for ladder in level_root.collect_ladder_areas():
			enemy.register_ladder(ladder)


func _wire_hud() -> void:
	if hud.has_method("setup"):
		hud.setup(word_controller, letter_spawner)
	if hud.has_method("set_enemy"):
		hud.set_enemy(_enemy)
	if hud.has_method("set_player_shield"):
		hud.set_player_shield(_player_shield)
	if hud.has_method("set_debug_visible"):
		hud.set_debug_visible(debug_mode)
	if combat_hud.has_method("setup"):
		combat_hud.setup(_player_combat, _enemy_combat, damage_bridge)
	if combat_hud.has_method("bind_words"):
		combat_hud.bind_words(word_controller, _enemy)
	if combat_hud.has_method("bind_combat_actions"):
		combat_hud.bind_combat_actions(_player_shooter, _player_action)
	if combat_hud.has_method("bind_enemy_action") and _enemy:
		combat_hud.bind_enemy_action(_enemy.get_action_controller())
	if hud.has_method("set_word_display_on_combat_hud"):
		hud.set_word_display_on_combat_hud(true)
	if word_celebration.has_method("setup"):
		word_celebration.setup(combat_hud)
	if word_celebration.has_method("bind_player_words"):
		word_celebration.bind_player_words(word_controller)
	if word_celebration.has_method("bind_enemy_words"):
		word_celebration.bind_enemy_words(_enemy)
	if word_garble_player and word_garble_player.has_method("setup"):
		word_garble_player.setup(combat_hud, word_controller)
	WordGameFeatures.attach_profanity_reactions($UI, word_controller, _enemy)
	combat_hud.set_debug_visible(debug_mode)


func _apply_debug_visibility() -> void:
	if _player_action:
		_player_action.debug_infinite_action = debug_mode
	if hud.has_method("set_debug_visible"):
		hud.set_debug_visible(debug_mode)
	combat_hud.set_debug_visible(debug_mode)
	if debug_dock:
		debug_dock.set_active(debug_mode)
	if collision_debug:
		var show_collision := debug_mode and _collision_debug_enabled
		collision_debug.visible = show_collision
		collision_debug.set_debug_enabled(show_collision)
	if debug_mode and debug_dock and debug_dock.is_expanded():
		_refresh_debug_dock()


func _sync_debug_mode(enabled: bool) -> void:
	debug_mode = enabled
	if debug_mode:
		_ensure_debug_registries()
	else:
		_collision_debug_enabled = false
	_apply_debug_visibility()


func _refresh_debug_dock() -> void:
	if debug_dock == null:
		return
	var sections: PackedStringArray = []
	sections.append("Debug mode — Shift+F2 to hide | V/F3 collision overlay")
	if not _debug_font_name.is_empty():
		sections.append("Font: %s (0 cycle) | Backdrop: %s (9 cycle)" % [_debug_font_name, _debug_backdrop_name])
	if hud.has_method("get_controls_text"):
		sections.append(hud.get_controls_text())
	if hud.has_method("get_word_debug_text"):
		var word_text: String = hud.get_word_debug_text()
		if not word_text.is_empty():
			sections.append(word_text)
	if hud.has_method("get_enemy_debug_text"):
		var enemy_text: String = hud.get_enemy_debug_text()
		if not enemy_text.is_empty():
			sections.append(enemy_text)
	if combat_hud.has_method("get_debug_text"):
		var combat_text: String = combat_hud.get_debug_text()
		if not combat_text.is_empty():
			sections.append(combat_text)
	sections.append("— Keyboard —")
	sections.append(GameKeyboardCommands.format_as_text())
	debug_dock.set_body_text("\n\n".join(sections))


func _begin_match_after_level_ready() -> void:
	_resolve_player_platform_landing()
	if level_root.has_method("reset_scroll_presentation"):
		level_root.reset_scroll_presentation()
	match_controller.setup(match_overlay, _round_reset_context())
	if level_root.has_method("reset_scroll_presentation"):
		if not match_controller.round_started.is_connected(_on_round_started_refresh_scroll):
			match_controller.round_started.connect(_on_round_started_refresh_scroll)
	_start_match()


func _on_round_started_refresh_scroll(_round_number: int) -> void:
	if level_root.has_method("reset_scroll_presentation"):
		level_root.reset_scroll_presentation()


func _resolve_player_platform_landing() -> void:
	if level_root.has_method("get_player_platform_landing_position"):
		_player_platform_landing = level_root.get_player_platform_landing_position(_player)
	else:
		_player_platform_landing = _player_spawn
	if _player:
		_player.global_position = _player_platform_landing
	if _player_combat and _player_combat.has_method("configure_spawn"):
		_player_combat.configure_spawn(_player_platform_landing)
	if collision_debug and _player:
		collision_debug.set_player(_player)


func _load_transform_rows() -> void:
	var transforms: Dictionary = LayoutBuilder.load_json(TRANSFORMS_PATH)
	for row in transforms.get("visual_instances", []):
		if row.get("name") == "Player":
			_player_row = row
	_enemy_row = LayoutBuilder.load_json(ENEMY_SPAWN_PATH)


func _collect_level_colliders() -> void:
	_collider_nodes.clear()
	if level_root.has_method("collect_collider_nodes"):
		for node in level_root.collect_collider_nodes():
			_collider_nodes.append(node)


func _process(_delta: float) -> void:
	if debug_mode and Input.is_action_just_pressed("toggle_collision_debug"):
		_collision_debug_enabled = not _collision_debug_enabled
		_apply_debug_visibility()
	if debug_mode and _collision_debug_enabled and collision_debug:
		collision_debug.queue_redraw()
	if debug_mode and debug_dock and debug_dock.is_expanded():
		_refresh_debug_dock()
	if hud.has_method("refresh_combat_hud"):
		hud.refresh_combat_hud()
	if Input.is_action_just_pressed("submit_word"):
		if not _blocks_word_submit():
			word_controller.submit_word()
	if Input.is_action_just_pressed("delete_letter"):
		if not _blocks_word_submit():
			word_controller.delete_last_letter()


func _blocks_word_submit() -> bool:
	if match_controller.blocks_word_submit():
		return true
	if _player_combat and _player_combat.blocks_word_submit():
		return true
	if _player_action and _player_action.has_method("blocks_word_submit") and _player_action.blocks_word_submit():
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2 and event.shift_pressed:
			_sync_debug_mode(not debug_mode)
			get_viewport().set_input_as_handled()
			return
	if not debug_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_F7:
			_debug_enemy_nearly_dead()
		elif event.keycode == KEY_F8:
			letter_spawner.debug_spawn_letter("Z")
		elif event.keycode == KEY_F9:
			word_controller.debug_clear_word()
		elif event.keycode == KEY_F10:
			if _enemy:
				_enemy.debug_force_shield(true)
		elif event.keycode == KEY_F11:
			if _enemy:
				_enemy.debug_force_validation()
		elif event.keycode == KEY_F12:
			if _enemy:
				_enemy.debug_clear_word()
		elif event.keycode == KEY_0 and not event.alt_pressed:
			_cycle_font_set()
		elif event.keycode == KEY_9 and not event.alt_pressed:
			_cycle_letter_backdrop()
		elif event.alt_pressed:
			_handle_combat_debug_keys(event.keycode)


func _handle_combat_debug_keys(keycode: Key) -> void:
	match keycode:
		KEY_1:
			if _player_combat:
				_player_combat.debug_damage(10)
		KEY_2:
			if _enemy_combat:
				_enemy_combat.debug_damage(10)
		KEY_3:
			if _player_combat:
				_player_combat.debug_heal_full()
		KEY_4:
			if _enemy_combat:
				_enemy_combat.debug_heal_full()
		KEY_5:
			if _player_combat:
				_player_combat.force_death("debug")
		KEY_6:
			if _enemy_combat:
				_enemy_combat.force_death("debug")
		KEY_0:
			if _player_combat:
				_player_combat.reset_combat()
			if _enemy_combat:
				_enemy_combat.reset_combat()


func _debug_enemy_nearly_dead() -> void:
	if _enemy_combat and _enemy_combat.has_method("debug_set_health"):
		_enemy_combat.debug_set_health(2)
