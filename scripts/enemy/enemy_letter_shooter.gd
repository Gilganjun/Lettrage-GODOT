class_name EnemyLetterShooter
extends Node2D

## AI letter gun — fires at needed letters; occasional manic upward bursts.

signal fired

@export var fire_cooldown := 0.38
@export var logical_max_range := 560.0
@export var logical_max_horizontal := 200.0
@export var manic_fire_chance_per_sec := 0.14
@export var manic_burst_cooldown_min := 1.8
@export var manic_burst_cooldown_max := 4.2
@export var manic_aim_jitter := 0.42

var word_controller: EnemyWordController
var shield_component: ShieldComponent
var letter_targeting: EnemyLetterTargeting

var _cooldown := 0.0
var _manic_cooldown := 0.0
var _muzzle: Marker2D
var _bullet_scene: PackedScene
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 24
	_rng.randomize()
	_bullet_scene = load("res://scenes/letters/letter_bullet.tscn")
	_muzzle = Marker2D.new()
	_muzzle.name = "BulletMuzzle"
	_muzzle.position = Vector2(0, -14)
	add_child(_muzzle)


func sync_to_body(center: Vector2 = Vector2.ZERO) -> void:
	position = center


func tick(
	delta: float,
	body_pos: Vector2,
	facing: int,
	actions_blocked: bool,
) -> void:
	if actions_blocked:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_manic_cooldown = maxf(0.0, _manic_cooldown - delta)
	if _cooldown <= 0.0 and _try_logical_shot(body_pos, facing):
		return
	_try_manic_shot(delta, facing)


func _try_logical_shot(body_pos: Vector2, facing: int) -> bool:
	if letter_targeting == null or word_controller == null:
		return false
	var target: Letter = letter_targeting.get_valid_target()
	if target == null:
		return false
	var needed: String = word_controller.word_state.current_needed_letter()
	if needed.is_empty() or target.character != needed:
		return false
	var to_target: Vector2 = target.global_position - body_pos
	if to_target.y > -logical_max_horizontal * 0.15:
		return false
	if absf(to_target.x) > logical_max_horizontal:
		return false
	if to_target.length() > logical_max_range:
		return false
	var aim: Vector2 = to_target.normalized()
	if aim.y > -0.25:
		aim = Vector2(signf(aim.x) if aim.x != 0.0 else float(facing), -1.0).normalized()
	return _fire(aim, facing)


func _try_manic_shot(delta: float, facing: int) -> void:
	if _manic_cooldown > 0.0:
		return
	if _rng.randf() > manic_fire_chance_per_sec * delta:
		return
	var jitter: float = _rng.randf_range(-manic_aim_jitter, manic_aim_jitter)
	var aim: Vector2 = Vector2(jitter + float(facing) * 0.08, -1.0).normalized()
	if _fire(aim, facing):
		_manic_cooldown = _rng.randf_range(manic_burst_cooldown_min, manic_burst_cooldown_max)


func _fire(aim: Vector2, _facing: int) -> bool:
	if _bullet_scene == null or _muzzle == null:
		return false
	var bullet: LetterBullet = _bullet_scene.instantiate()
	bullet.owner_kind = "enemy"
	bullet.fire_direction = aim
	bullet.enemy_word_controller = word_controller
	bullet.enemy_shield = shield_component
	bullet.z_index = 38
	var world: Node2D = _find_world_node()
	if world:
		world.add_child(bullet)
	else:
		get_tree().current_scene.add_child(bullet)
	var shield_on: bool = shield_component != null and shield_component.is_active
	bullet.launch(_muzzle.global_position, shield_on, aim)
	_cooldown = fire_cooldown
	fired.emit()
	return true


func _find_world_node() -> Node2D:
	var n: Node = self
	while n != null:
		if n.name == "World" and n is Node2D:
			return n as Node2D
		n = n.get_parent()
	return null
