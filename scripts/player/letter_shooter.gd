class_name LetterShooter
extends Node2D

## Press F to show aim line and fire on release. Hold F while standing still (1s) for precision arc aim.

signal fired
signal ammo_changed(current: int, clip_size: int)
signal fire_blocked(reason: String)

const DEFAULT_CLIP_SIZE := 10
const PRECISION_CHARGE_TIME := 1.0
const PRECISION_MAX_ANGLE_DEG := 45.0
const PRECISION_ROTATE_SPEED_DEG := (45.0 / 1.5) * 2.0
const STILL_VELOCITY_X := 12.0
const STILL_VELOCITY_Y := 8.0

@export var word_controller: WordGameController
@export var player_shield: PlayerShield
@export var aim_line_length: float = 260.0
@export var aim_pivot_offset: Vector2 = Vector2(0.0, -48.0)
@export var aim_arc_radius: float = 72.0
@export var unlimited_ammo: bool = false
@export var max_ammo: int = DEFAULT_CLIP_SIZE
@export var starting_ammo: int = DEFAULT_CLIP_SIZE
@export var ammo_per_shot: int = 1
@export var ammo_regen_interval: float = 1.0
@export var clip_pickup_size: int = DEFAULT_CLIP_SIZE

var ammo: int = DEFAULT_CLIP_SIZE
var _regen_timer := 0.0

var _aiming := false
var _precision_aim_active := false
var _still_hold_time := 0.0
var _aim_angle_deg := 0.0
var _muzzle: Marker2D
var _aim_line: Line2D
var _aim_arc: Line2D
var _bullet_scene: PackedScene


func _ready() -> void:
	z_index = 25
	ammo = maxi(0, starting_ammo)
	_bullet_scene = load("res://scenes/letters/letter_bullet.tscn")
	_muzzle = Marker2D.new()
	_muzzle.name = "BulletMuzzle"
	_muzzle.position = Vector2(0, -12)
	add_child(_muzzle)
	_aim_arc = Line2D.new()
	_aim_arc.name = "AimArc"
	_aim_arc.width = 2.5
	_aim_arc.default_color = Color(0.35, 1.0, 1.0, 0.38)
	_aim_arc.visible = false
	_aim_arc.z_index = 0
	add_child(_aim_arc)
	_aim_line = Line2D.new()
	_aim_line.name = "AimLine"
	_aim_line.width = 3.0
	_aim_line.default_color = Color(0.35, 1.0, 1.0, 0.9)
	_aim_line.visible = false
	_aim_line.z_index = 1
	add_child(_aim_line)


func _physics_process(delta: float) -> void:
	_regen_ammo(delta)
	_handle_input(delta)
	_update_aim_visuals()


func sync_to_body(center: Vector2 = Vector2.ZERO) -> void:
	position = center


func can_fire() -> bool:
	return unlimited_ammo or ammo > 0


func is_aim_mode_active() -> bool:
	return _precision_aim_active


func add_ammo_clip(amount: int = -1) -> void:
	var add_amount := clip_pickup_size if amount < 0 else amount
	if add_amount <= 0:
		return
	ammo = mini(max_ammo, ammo + add_amount)
	ammo_changed.emit(ammo, max_ammo)


func set_ammo(count: int) -> void:
	ammo = clampi(count, 0, max_ammo)
	ammo_changed.emit(ammo, max_ammo)


func cancel_aim() -> void:
	_reset_aim_state()


func _regen_ammo(delta: float) -> void:
	if unlimited_ammo or ammo >= max_ammo:
		return
	_regen_timer += delta
	while _regen_timer >= ammo_regen_interval and ammo < max_ammo:
		_regen_timer -= ammo_regen_interval
		ammo += 1
		ammo_changed.emit(ammo, max_ammo)


func get_debug_info() -> Dictionary:
	return {
		"aiming": _aiming,
		"precision_aim": _precision_aim_active,
		"aim_angle_deg": _aim_angle_deg,
		"still_hold_time": _still_hold_time,
		"ammo": ammo,
		"unlimited_ammo": unlimited_ammo,
		"clip_pickup_size": clip_pickup_size,
	}


func _handle_input(delta: float) -> void:
	var body := get_parent() as CharacterBody2D
	if body and _player_blocks_gun(body):
		_reset_aim_state()
		return
	if body:
		var combat := body.get_node_or_null("CharacterCombat")
		if combat and combat.has_method("blocks_collection") and combat.blocks_collection():
			_reset_aim_state()
			return
	if not can_fire():
		_reset_aim_state()
		return
	if Input.is_action_just_pressed("player_fire"):
		_aiming = true
		_precision_aim_active = false
		_still_hold_time = 0.0
		_aim_angle_deg = 0.0
	elif Input.is_action_pressed("player_fire"):
		_aiming = true
		_tick_precision_charge(body, delta)
		if _precision_aim_active:
			_update_aim_rotation(delta)
	elif Input.is_action_just_released("player_fire"):
		if _aiming:
			_fire()
		_reset_aim_state()


func _tick_precision_charge(body: CharacterBody2D, delta: float) -> void:
	if _is_player_standing_still(body):
		_still_hold_time += delta
		if _still_hold_time >= PRECISION_CHARGE_TIME:
			_precision_aim_active = true
	else:
		_still_hold_time = 0.0
		if _precision_aim_active:
			_precision_aim_active = false
			_aim_angle_deg = 0.0


func _is_player_standing_still(body: CharacterBody2D) -> bool:
	if body == null:
		return false
	if not body.is_on_floor():
		return false
	if body is PlayerMovement and (body as PlayerMovement).is_on_ladder:
		return false
	return absf(body.velocity.x) <= STILL_VELOCITY_X and absf(body.velocity.y) <= STILL_VELOCITY_Y


func _update_aim_rotation(delta: float) -> void:
	if Input.is_action_pressed("move_left"):
		_aim_angle_deg -= PRECISION_ROTATE_SPEED_DEG * delta
	if Input.is_action_pressed("move_right"):
		_aim_angle_deg += PRECISION_ROTATE_SPEED_DEG * delta
	_aim_angle_deg = clampf(_aim_angle_deg, -PRECISION_MAX_ANGLE_DEG, PRECISION_MAX_ANGLE_DEG)


func _get_aim_direction() -> Vector2:
	if _precision_aim_active:
		return Vector2.UP.rotated(deg_to_rad(_aim_angle_deg))
	return Vector2.UP


func _reset_aim_state() -> void:
	_aiming = false
	_precision_aim_active = false
	_still_hold_time = 0.0
	_aim_angle_deg = 0.0


func _fire() -> void:
	if not can_fire():
		fire_blocked.emit("no_ammo")
		return
	if _bullet_scene == null or _muzzle == null:
		return
	if not unlimited_ammo:
		ammo = maxi(0, ammo - ammo_per_shot)
		ammo_changed.emit(ammo, max_ammo)
	var bullet: LetterBullet = _bullet_scene.instantiate()
	bullet.player_shield = player_shield
	bullet.word_controller = word_controller
	bullet.z_index = 40
	var world := _find_world_node()
	if world:
		world.add_child(bullet)
	else:
		get_tree().current_scene.add_child(bullet)
	bullet.launch(_muzzle.global_position, player_shield != null and player_shield.is_active, _get_aim_direction())
	fired.emit()


func _update_aim_visuals() -> void:
	if _aim_line == null or _aim_arc == null or _muzzle == null:
		return
	if not _aiming or not can_fire():
		_aim_line.visible = false
		_aim_arc.visible = false
		return
	_aim_line.visible = true
	if _precision_aim_active:
		_aim_arc.visible = true
		var pivot := aim_pivot_offset
		_aim_arc.points = _build_arc_points(
			pivot,
			aim_arc_radius,
			-PRECISION_MAX_ANGLE_DEG,
			PRECISION_MAX_ANGLE_DEG,
			16,
		)
		var direction := _get_aim_direction()
		_aim_line.points = PackedVector2Array([pivot, pivot + direction * aim_line_length])
	else:
		_aim_arc.visible = false
		var start := _muzzle.position
		_aim_line.points = PackedVector2Array([start, start + Vector2(0.0, -aim_line_length)])


func _build_arc_points(
	center: Vector2,
	radius: float,
	min_deg: float,
	max_deg: float,
	segments: int,
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var count := maxi(segments, 2)
	for i in count + 1:
		var t := float(i) / float(count)
		var deg := lerpf(min_deg, max_deg, t)
		var dir := Vector2.UP.rotated(deg_to_rad(deg))
		pts.append(center + dir * radius)
	return pts


func _player_blocks_gun(body: CharacterBody2D) -> bool:
	for child in body.get_children():
		if child.has_method("is_rolling") and child.call("is_rolling"):
			return true
		if child.has_method("is_active") and child.call("is_active"):
			return true
	return false


func _find_world_node() -> Node2D:
	var n: Node = self
	while n != null:
		if n.name == "World" and n is Node2D:
			return n as Node2D
		n = n.get_parent()
	return null
