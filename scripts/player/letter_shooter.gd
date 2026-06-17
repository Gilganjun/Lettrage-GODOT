class_name LetterShooter
extends Node

## Vertical letter shot — hold fire to aim, release to shoot.

signal fired

@export var word_controller: WordGameController
@export var player_shield: PlayerShield
@export var fire_cooldown: float = 1.0
@export var aim_line_length: float = 220.0

var _cooldown_remaining := 0.0
var _aiming := false
var _active_bullet: LetterBullet
var _muzzle: Marker2D
var _aim_line: Line2D
var _bullet_scene: PackedScene


func _ready() -> void:
	_bullet_scene = load("res://scenes/letters/letter_bullet.tscn")
	_muzzle = Marker2D.new()
	_muzzle.name = "BulletMuzzle"
	_muzzle.position = Vector2(18, -8)
	add_child(_muzzle)
	_aim_line = Line2D.new()
	_aim_line.name = "AimLine"
	_aim_line.width = 2.0
	_aim_line.default_color = Color(0.45, 0.95, 1.0, 0.65)
	_aim_line.visible = false
	_aim_line.z_index = 30
	add_child(_aim_line)


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _active_bullet != null and not is_instance_valid(_active_bullet):
		_active_bullet = null
	_update_aim_line()
	_handle_input()


func attach_to_body(body: Node2D) -> void:
	if body == null:
		return
	if get_parent() != body:
		if get_parent():
			get_parent().remove_child(self)
		body.add_child(self)


func can_fire() -> bool:
	return _cooldown_remaining <= 0.0 and _active_bullet == null


func get_debug_info() -> Dictionary:
	return {
		"aiming": _aiming,
		"cooldown": _cooldown_remaining,
		"has_bullet": _active_bullet != null,
	}


func _handle_input() -> void:
	var body := get_parent() as CharacterBody2D
	if body:
		var combat := body.get_node_or_null("CharacterCombat")
		if combat and combat.has_method("blocks_collection") and combat.blocks_collection():
			_aiming = false
			return
	if Input.is_action_just_released("player_fire"):
		if _aiming and can_fire():
			_fire()
		_aiming = false
	elif Input.is_action_pressed("player_fire") and can_fire():
		_aiming = true
	else:
		_aiming = false


func _fire() -> void:
	if _bullet_scene == null or _muzzle == null:
		return
	var bullet: LetterBullet = _bullet_scene.instantiate()
	bullet.player_shield = player_shield
	bullet.word_controller = word_controller
	get_tree().current_scene.add_child(bullet)
	bullet.launch(_muzzle.global_position)
	_active_bullet = bullet
	_cooldown_remaining = fire_cooldown
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
