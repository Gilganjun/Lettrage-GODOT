class_name ShieldComponent
extends Node2D

## Reusable shield — impact area, visuals, audio. Used by Player and Enemy.

signal shield_activated
signal shield_deactivated
signal letter_broken(letter: Letter, character: String)
signal shield_impact(letter: Letter, character: String)

@export var owner_group: String = "player"
@export var impact_source: String = "player_shield"
@export var start_active := false
@export var shield_up_sound: AudioStream
@export var shield_down_sound: AudioStream
@export var shield_impact_sounds: Array[AudioStream] = []
@export_range(0.0, 1.0, 0.01) var shield_up_volume := 0.25
@export_range(0.0, 1.0, 0.01) var shield_down_volume := 0.25
@export_range(0.0, 1.0, 0.01) var impact_volume := 0.50

var is_active := false
var cooldown_remaining := 0.0
var active_duration_remaining := -1.0
var last_activation_reason := "none"

var _area: Area2D
var _visual: Node2D
var _audio: AudioStreamPlayer
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
	}


func _build_nodes() -> void:
	_area = Area2D.new()
	_area.name = "ShieldArea"
	_area.collision_layer = 0
	_area.collision_mask = 8
	_area.monitoring = true
	add_child(_area)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	shape.shape = circle
	_area.add_child(shape)
	_area.area_entered.connect(_on_area_entered)
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var ring := ColorRect.new()
	ring.name = "Ring"
	ring.size = Vector2(88, 88)
	ring.position = Vector2(-44, -44)
	ring.color = Color(0.35, 0.75, 1.0, 0.22)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(ring)
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
	if _visual:
		_visual.visible = on
	if _area:
		_area.monitoring = on


func _on_area_entered(area: Area2D) -> void:
	if not is_active or area == null:
		return
	if not area is Letter:
		return
	var letter := area as Letter
	var id := letter.get_instance_id()
	if _processed_this_frame.has(id):
		return
	_processed_this_frame[id] = true
	var outcome := (
		Letter.Resolution.PLAYER_SHIELD
		if owner_group == "player"
		else Letter.Resolution.ENEMY_SHIELD
	)
	if letter.try_resolve(outcome, impact_source):
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
