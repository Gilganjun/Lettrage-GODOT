extends Node2D

## Phase 2C1 — health, word damage, injury, death and test respawn.

const LEVEL_SCENE := preload("res://scenes/levels/main2_heallthbartest_level.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const CATALOG := preload("res://resources/letters/alphabet_catalog.tres")
const LETTER_SCENE := preload("res://scenes/letters/letter.tscn")
const LayoutBuilder := preload("res://scripts/level/gdevelop_layout_builder.gd")
const PlayerAttach := preload("res://scripts/test/player_gameplay_attach.gd")
const TRANSFORMS_PATH := "res://resources/phase2a/instance_transforms.json"
const ENEMY_SPAWN_PATH := "res://resources/enemy/enemy_spawn.json"

const POP_SOUNDS := [
	preload("res://assets/463388__vilkas-sound__vs-pop-4.mp3"),
	preload("res://assets/463389__vilkas-sound__vs-pop-3.mp3"),
]

@onready var world: Node2D = $World
@onready var level_root: Node2D = $World/Level
@onready var player_root: Node2D = $World/PlayerRoot
@onready var enemy_root: Node2D = $World/EnemyRoot
@onready var letter_spawner: LetterSpawner = $World/LetterSpawner
@onready var word_controller: WordGameController = $WordGameController
@onready var collision_debug: Node2D = $World/CollisionDebug
@onready var hud: Control = $UI/WordGameHud
@onready var combat_hud: Control = $UI/CombatHud
@onready var top_bar: Control = $UI/TopBar
@onready var damage_bridge: Node = $WordDamageBridge

var _collider_nodes: Array[Node] = []
var _debug_enabled := false
var _word_debug := false
var _player_row: Dictionary = {}
var _enemy_row: Dictionary = {}
var _enemy: Enemy
var _player_shield: PlayerShield
var _player_combat: Node
var _enemy_combat: Node
var _player_spawn := Vector2(279.0, 231.0)


func _ready() -> void:
	for stream in POP_SOUNDS:
		word_controller.collect_sounds.append(stream)
	word_controller.valid_word_sound = preload("res://assets/487436__elijahdanie__game-win.mp3")
	word_controller.invalid_word_sound = preload("res://assets/369520__kinoton__bass-power-down.wav")
	word_controller.delete_letter_sound = preload("res://assets/176238__melissapons__sci-fi-short-error.wav")
	letter_spawner.catalog = CATALOG
	letter_spawner.letter_scene = LETTER_SCENE
	letter_spawner.word_controller = word_controller
	_load_transform_rows()
	_spawn_player()
	_spawn_enemy()
	_setup_combat()
	_collect_level_colliders()
	collision_debug.setup(_collider_nodes)
	collision_debug.set_debug_enabled(_debug_enabled)
	if hud.has_method("setup"):
		hud.setup(word_controller, letter_spawner)
	if hud.has_method("set_enemy"):
		hud.set_enemy(_enemy)
	if hud.has_method("set_player_shield"):
		hud.set_player_shield(_player_shield)
	if hud.has_method("set_debug_visible"):
		hud.set_debug_visible(_word_debug)
	if combat_hud.has_method("setup"):
		combat_hud.setup(_player_combat, _enemy_combat, damage_bridge)
	if combat_hud.has_method("bind_words"):
		combat_hud.bind_words(word_controller, _enemy)
	if hud.has_method("set_word_display_on_combat_hud"):
		hud.set_word_display_on_combat_hud(true)
	combat_hud.set_debug_visible(_word_debug)
	_apply_hud_chrome_visibility()
	call_deferred("_activate_player_camera")


func _setup_combat() -> void:
	damage_bridge.player_combat = _player_combat
	damage_bridge.enemy_combat = _enemy_combat
	damage_bridge.bind_word_systems(word_controller, _enemy.word_controller)
	if _enemy_combat:
		_enemy_combat.respawn_completed.connect(_on_enemy_respawned)
	if _player_combat:
		_player_combat.respawn_completed.connect(_on_player_respawned)


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
	var attached := PlayerAttach.attach(player, word_controller)
	_player_shield = attached.get("shield")
	_player_combat = PlayerAttach.attach_combat(player, "player", _player_spawn)
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
	_enemy = enemy
	_enemy_combat = PlayerAttach.attach_combat(enemy, "enemy", enemy.global_position)
	if level_root.has_method("collect_ladder_areas"):
		for ladder in level_root.collect_ladder_areas():
			enemy.register_ladder(ladder)


func _on_player_respawned() -> void:
	word_controller.debug_clear_word()


func _on_enemy_respawned() -> void:
	if _enemy and _enemy.word_controller:
		_enemy.word_controller.pick_new_target_word()


func _activate_player_camera() -> void:
	for c in player_root.get_children():
		if c is CharacterBody2D and c.has_method("activate_follow_camera"):
			c.activate_follow_camera()


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
	collision_debug.set_player(_get_player())


func _get_player() -> CharacterBody2D:
	for c in player_root.get_children():
		if c is CharacterBody2D:
			return c
	return null


func get_enemy() -> Enemy:
	return _enemy


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_F2 and event.shift_pressed:
			_word_debug = not _word_debug
			if hud.has_method("set_debug_visible"):
				hud.set_debug_visible(_word_debug)
			combat_hud.set_debug_visible(_word_debug)
			_apply_hud_chrome_visibility()
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


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_collision_debug"):
		_debug_enabled = not _debug_enabled
		collision_debug.set_debug_enabled(_debug_enabled)
	if Input.is_action_just_pressed("submit_word"):
		if _player_combat == null or not _player_combat.blocks_word_submit():
			word_controller.submit_word()
	if Input.is_action_just_pressed("delete_letter"):
		if _player_combat == null or not _player_combat.blocks_word_submit():
			word_controller.delete_last_letter()
	if _debug_enabled:
		collision_debug.queue_redraw()
	if _word_debug and hud.has_method("refresh_enemy_debug"):
		hud.refresh_enemy_debug()
	if hud.has_method("refresh_combat_hud"):
		hud.refresh_combat_hud()
	if combat_hud.has_method("refresh_debug"):
		combat_hud.refresh_debug()


func _apply_hud_chrome_visibility() -> void:
	if top_bar:
		top_bar.visible = _word_debug
