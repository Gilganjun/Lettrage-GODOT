class_name PlayerRoll
extends Node

## Ground roll from GDevelop GAME25 — Down+Left / Down+Right while on floor.

signal roll_started
signal roll_ended

const ANIM_ROLL := "Roll"
const ROLL_DISTANCE := 250.0
const ROLL_DURATION := 0.6
const ROLL_COOLDOWN := 0.35
const COLLISION_HEIGHT_SCALE := 0.58
const ROLL_SWISH := preload(
	"res://assets/misc._weapons_knife_swishes_military_battlefield_2022003807010269_12.wav"
)

@export var roll_distance: float = ROLL_DISTANCE
@export var roll_duration: float = ROLL_DURATION
@export var roll_cooldown: float = ROLL_COOLDOWN

var _rolling := false
var _cooldown_left := 0.0
var _elapsed := 0.0
var _direction := 0
var _start_x := 0.0
var _target_x := 0.0
var _saved_collision_size := Vector2.ZERO
var _saved_collision_position := Vector2.ZERO
var _collision_applied := false
var _saved_sprite_z := 0


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)


func is_rolling() -> bool:
	return _rolling


func process_roll(player: PlayerMovement, delta: float) -> bool:
	if not _rolling:
		if not _try_start_roll(player):
			return false
	if _tick_roll(player, delta):
		return true
	return _rolling


func _try_start_roll(player: PlayerMovement) -> bool:
	if _rolling or _cooldown_left > 0.0 or player == null:
		return false
	if _player_action_active(player):
		return false
	if not player.is_on_floor() or player.is_on_ladder:
		return false
	var dir := _read_roll_input()
	if dir == 0:
		return false
	_begin_roll(player, dir)
	return true


func _read_roll_input() -> int:
	if not Input.is_action_pressed("climb_down"):
		return 0
	var axis := Input.get_axis("move_left", "move_right")
	if absf(axis) < 0.45:
		return 0
	var edge := (
		Input.is_action_just_pressed("climb_down")
		or Input.is_action_just_pressed("move_left")
		or Input.is_action_just_pressed("move_right")
	)
	if not edge:
		return 0
	return 1 if axis > 0.0 else -1


func _begin_roll(player: PlayerMovement, dir: int) -> void:
	_direction = dir
	_rolling = true
	_elapsed = 0.0
	_cooldown_left = roll_cooldown
	_start_x = player.global_position.x
	_target_x = _start_x + float(dir) * roll_distance
	player.facing = dir
	player.velocity = Vector2.ZERO
	_cancel_player_aim(player)
	_play_roll_animation(player)
	var roll_layout := _apply_low_collision(player)
	_apply_roll_shield(player, roll_layout)
	if player.sprite:
		_saved_sprite_z = player.sprite.z_index
		player.sprite.z_index = 14
	_play_swish()
	roll_started.emit()


func _tick_roll(player: PlayerMovement, delta: float) -> bool:
	_elapsed += delta
	var t := clampf(_elapsed / maxf(roll_duration, 0.001), 0.0, 1.0)
	var eased := _ease_out_sine(t) if _direction > 0 else _ease_out_quad(t)
	var desired_x := lerpf(_start_x, _target_x, eased)
	var step := desired_x - player.global_position.x
	player.velocity = Vector2(step / maxf(delta, 0.0001), 0.0)
	player.facing = _direction
	if player.sprite:
		player.sprite.flip_h = _direction < 0
	if t >= 1.0:
		player.velocity = Vector2.ZERO
		_finish_roll()
	return true


func _finish_roll() -> void:
	if not _rolling:
		return
	_rolling = false
	_restore_roll_shield()
	_restore_collision()
	var player := get_parent() as PlayerMovement
	if player and player.sprite:
		player.sprite.z_index = _saved_sprite_z
	roll_ended.emit()


func _play_roll_animation(player: PlayerMovement) -> void:
	var sprite := player.sprite
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(ANIM_ROLL):
		return
	sprite.flip_h = _direction < 0
	sprite.play(ANIM_ROLL)


func _apply_low_collision(player: PlayerMovement) -> Dictionary:
	var shape_node := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is RectangleShape2D:
		return {}
	var rect := shape_node.shape as RectangleShape2D
	if not _collision_applied:
		_saved_collision_size = rect.size
		_saved_collision_position = shape_node.position
		_collision_applied = true
	var low_h := _saved_collision_size.y * COLLISION_HEIGHT_SCALE
	rect.size = Vector2(_saved_collision_size.x, low_h)
	shape_node.position = Vector2(
		_saved_collision_position.x,
		_saved_collision_position.y + (_saved_collision_size.y - low_h) * 0.5,
	)
	return {"size": rect.size, "position": shape_node.position}


func _apply_roll_shield(player: PlayerMovement, layout: Dictionary) -> void:
	if layout.is_empty():
		return
	var player_shield := PlayerShield.find_on_body(player)
	if player_shield:
		player_shield.apply_roll_presentation(layout["size"], layout["position"])


func _restore_roll_shield() -> void:
	var player := get_parent() as PlayerMovement
	if player == null:
		return
	var player_shield := PlayerShield.find_on_body(player)
	if player_shield:
		player_shield.clear_roll_presentation()


func _restore_collision() -> void:
	var player := get_parent() as PlayerMovement
	if player == null:
		_collision_applied = false
		return
	var shape_node := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is RectangleShape2D:
		_collision_applied = false
		return
	if not _collision_applied:
		return
	var rect := shape_node.shape as RectangleShape2D
	rect.size = _saved_collision_size
	shape_node.position = _saved_collision_position
	_collision_applied = false


func _play_swish() -> void:
	if ROLL_SWISH == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = ROLL_SWISH
	player.volume_db = -12.0
	player.pitch_scale = randf_range(1.0, 1.2)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _ease_out_sine(t: float) -> float:
	return sin(t * PI * 0.5)


func _ease_out_quad(t: float) -> float:
	var inv := 1.0 - t
	return 1.0 - inv * inv


func _cancel_player_aim(player: PlayerMovement) -> void:
	for child in player.get_children():
		if child is LetterShooter:
			(child as LetterShooter).cancel_aim()


func _player_action_active(player: PlayerMovement) -> bool:
	for child in player.get_children():
		if child.has_method("is_active") and child.call("is_active"):
			return true
	return false
