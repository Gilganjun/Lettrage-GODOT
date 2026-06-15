class_name ShieldComponent
extends Node2D

## Reusable shield — body-hugging hitbox, particle aura, audio. Used by Player and Enemy.

signal shield_activated
signal shield_deactivated
signal letter_broken(letter: Letter, character: String)
signal shield_impact(letter: Letter, character: String)

const ShieldVisualScript := preload("res://scripts/components/shield_visual.gd")

@export var owner_group: String = "player"
@export var impact_source: String = "player_shield"
@export var start_active := false
@export var shield_up_sound: AudioStream
@export var shield_down_sound: AudioStream
@export var shield_impact_sounds: Array[AudioStream] = []
@export_range(0.0, 1.0, 0.01) var shield_up_volume := 0.25
@export_range(0.0, 1.0, 0.01) var shield_down_volume := 0.25
@export_range(0.0, 1.0, 0.01) var impact_volume := 0.30

## GDevelop reference: player shield pop vol 50/100; enemy glass shatter vol 5–10/100.
const PLAYER_BREAK_VOLUME := 0.30
const ENEMY_BREAK_VOLUME := 0.08

var is_active := false
var cooldown_remaining := 0.0
var active_duration_remaining := -1.0
var last_activation_reason := "none"

var _area: Area2D
var _collision_shape: CollisionShape2D
var _shield_visual: ShieldVisual
var _audio: AudioStreamPlayer
var _hit_size := Vector2(40, 80)
var _processed_this_frame: Dictionary = {}


func _ready() -> void:
	_build_nodes()
	if start_active:
		activate("start_active")
	else:
		_set_active_visual(false)


func _physics_process(delta: float) -> void:
	_processed_this_frame.clear()
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if is_active and active_duration_remaining >= 0.0:
		active_duration_remaining -= delta
		if active_duration_remaining <= 0.0:
			deactivate("duration_expired")


func configure_body_shape(size: Vector2) -> void:
	_hit_size = size
	if _collision_shape and _collision_shape.shape is RectangleShape2D:
		(_collision_shape.shape as RectangleShape2D).size = size
	if _shield_visual:
		_shield_visual.configure(size, owner_group == "enemy")


func activate(reason: String = "manual", duration: float = -1.0) -> bool:
	if is_active:
		last_activation_reason = reason
		return true
	if cooldown_remaining > 0.0:
		return false
	is_active = true
	active_duration_remaining = duration
	last_activation_reason = reason
	_set_active_visual(true)
	_play_one_shot(shield_up_sound, shield_up_volume)
	shield_activated.emit()
	call_deferred("_break_overlapping_letters")
	return true


func deactivate(reason: String = "manual") -> void:
	if not is_active:
		return
	is_active = false
	active_duration_remaining = -1.0
	last_activation_reason = reason
	_set_active_visual(false)
	_play_one_shot(shield_down_sound, shield_down_volume)
	shield_deactivated.emit()


func set_cooldown(seconds: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining, seconds)


func blocks_letter_collection() -> bool:
	return is_active


func get_debug_info() -> Dictionary:
	return {
		"active": is_active,
		"cooldown": cooldown_remaining,
		"duration_remaining": active_duration_remaining,
		"last_reason": last_activation_reason,
		"hit_size": _hit_size,
	}


func _build_nodes() -> void:
	_area = Area2D.new()
	_area.name = "ShieldArea"
	_area.collision_layer = 0
	_area.collision_mask = 8
	_area.monitoring = false
	add_child(_area)
	_collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _hit_size
	_collision_shape.shape = rect
	_area.add_child(_collision_shape)
	_area.area_entered.connect(_on_area_entered)
	_shield_visual = ShieldVisualScript.new()
	_shield_visual.name = "ShieldVisual"
	_shield_visual.visible = false
	add_child(_shield_visual)
	_shield_visual.configure(_hit_size, owner_group == "enemy")
	_audio = AudioStreamPlayer.new()
	_audio.name = "ShieldAudio"
	add_child(_audio)
	if owner_group == "player":
		_area.collision_layer = 32
		_area.add_to_group("player_shield")
	elif owner_group == "enemy":
		_area.collision_layer = 128
		_area.add_to_group("enemy_shield")


func _set_active_visual(on: bool) -> void:
	if _shield_visual:
		_shield_visual.visible = on
		_shield_visual.set_active(on)
	if _area:
		_area.monitoring = on


func _on_area_entered(area: Area2D) -> void:
	if not is_active or area == null:
		return
	if area is Letter:
		_try_break_letter(area as Letter)


func _break_overlapping_letters() -> void:
	if not is_active or _area == null:
		return
	for area in _area.get_overlapping_areas():
		if area is Letter:
			_try_break_letter(area as Letter)


func _try_break_letter(letter: Letter) -> void:
	if letter == null or letter.is_resolved():
		return
	var id := letter.get_instance_id()
	if _processed_this_frame.has(id):
		return
	_processed_this_frame[id] = true
	var outcome := (
		Letter.Resolution.PLAYER_SHIELD
		if owner_group == "player"
		else Letter.Resolution.ENEMY_SHIELD
	)
	var burst_pos := (
		_shield_visual.to_local(letter.global_position)
		if _shield_visual
		else Vector2.ZERO
	)
	if letter.try_resolve(outcome, impact_source):
		if _shield_visual:
			_shield_visual.play_impact_burst(burst_pos)
		letter_broken.emit(letter, letter.character)
		shield_impact.emit(letter, letter.character)
		_play_impact_sound()


func _play_impact_sound() -> void:
	if shield_impact_sounds.is_empty():
		return
	var stream := shield_impact_sounds[randi() % shield_impact_sounds.size()]
	_play_one_shot(stream, impact_volume)


func _play_one_shot(stream: AudioStream, volume_linear: float) -> void:
	if stream == null or _audio == null:
		return
	_audio.volume_db = linear_to_db(volume_linear)
	_audio.stream = stream
	_audio.play()
