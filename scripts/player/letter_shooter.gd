class_name LetterShooter
extends Node2D

## Vertical letter shot — hold F to aim, release (or tap) to fire. Rapid fire when ammo allows.

signal fired
signal ammo_changed(current: int, clip_size: int)
signal fire_blocked(reason: String)

## Future collectible clip size (Bullet Gun Clip pickup).
const DEFAULT_CLIP_SIZE := 10

@export var word_controller: WordGameController
@export var player_shield: PlayerShield
@export var aim_line_length: float = 260.0
## When true, ammo is not consumed (current gameplay default).
@export var unlimited_ammo: bool = true
@export var starting_ammo: int = DEFAULT_CLIP_SIZE
@export var clip_pickup_size: int = DEFAULT_CLIP_SIZE

var ammo: int = DEFAULT_CLIP_SIZE

var _aiming := false
var _muzzle: Marker2D
var _aim_line: Line2D
var _bullet_scene: PackedScene


func _ready() -> void:
	z_index = 25
	ammo = maxi(0, starting_ammo)
	_bullet_scene = load("res://scenes/letters/letter_bullet.tscn")
	_muzzle = Marker2D.new()
	_muzzle.name = "BulletMuzzle"
	_muzzle.position = Vector2(0, -12)
	add_child(_muzzle)
	_aim_line = Line2D.new()
	_aim_line.name = "AimLine"
	_aim_line.width = 3.0
	_aim_line.default_color = Color(0.35, 1.0, 1.0, 0.85)
	_aim_line.visible = false
	_aim_line.z_index = 1
	add_child(_aim_line)


func _physics_process(_delta: float) -> void:
	_handle_input()
	_update_aim_line()


func sync_to_body(center: Vector2 = Vector2.ZERO) -> void:
	position = center


func can_fire() -> bool:
	return unlimited_ammo or ammo > 0


func add_ammo_clip(amount: int = -1) -> void:
	var add_amount := clip_pickup_size if amount < 0 else amount
	if add_amount <= 0:
		return
	ammo += add_amount
	ammo_changed.emit(ammo, clip_pickup_size)


func set_ammo(count: int) -> void:
	ammo = maxi(0, count)
	ammo_changed.emit(ammo, clip_pickup_size)


func get_debug_info() -> Dictionary:
	return {
		"aiming": _aiming,
		"ammo": ammo,
		"unlimited_ammo": unlimited_ammo,
		"clip_pickup_size": clip_pickup_size,
	}


func _handle_input() -> void:
	var body := get_parent() as CharacterBody2D
	if body:
		var combat := body.get_node_or_null("CharacterCombat")
		if combat and combat.has_method("blocks_collection") and combat.blocks_collection():
			_aiming = false
			return
	# just_pressed before just_released so a quick tap still fires.
	if Input.is_action_just_pressed("player_fire"):
		if can_fire():
			_aiming = true
		else:
			fire_blocked.emit("no_ammo")
	if Input.is_action_just_released("player_fire"):
		if _aiming and can_fire():
			_fire()
		_aiming = false
	elif Input.is_action_pressed("player_fire") and can_fire():
		_aiming = true


func _fire() -> void:
	if not can_fire():
		fire_blocked.emit("no_ammo")
		return
	if _bullet_scene == null or _muzzle == null:
		return
	if not unlimited_ammo:
		ammo -= 1
		ammo_changed.emit(ammo, clip_pickup_size)
	var bullet: LetterBullet = _bullet_scene.instantiate()
	bullet.player_shield = player_shield
	bullet.word_controller = word_controller
	bullet.z_index = 40
	var world := _find_world_node()
	if world:
		world.add_child(bullet)
	else:
		get_tree().current_scene.add_child(bullet)
	bullet.launch(_muzzle.global_position, player_shield != null and player_shield.is_active, Vector2.UP)
	_aiming = false
	fired.emit()


func _update_aim_line() -> void:
	if _aim_line == null or _muzzle == null:
		return
	if not _aiming or not can_fire():
		_aim_line.visible = false
		return
	_aim_line.visible = true
	var start := _muzzle.position
	_aim_line.points = PackedVector2Array([start, start + Vector2(0.0, -aim_line_length)])


func _find_world_node() -> Node2D:
	var n: Node = self
	while n != null:
		if n.name == "World" and n is Node2D:
			return n as Node2D
		n = n.get_parent()
	return null
