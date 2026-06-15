class_name HitFeedback
extends Node

@export var flash_color := Color(1.0, 0.35, 0.35, 1.0)
@export var flash_duration := 0.18
@export_range(0.0, 1.0, 0.01) var impact_volume := 0.35

var _sprite: CanvasItem
var _audio: AudioStreamPlayer
var _base_modulate := Color.WHITE
var _flash_remaining := 0.0
var _impact_sound: AudioStream


func setup(sprite: CanvasItem, impact_sound: AudioStream = null) -> void:
	_sprite = sprite
	_impact_sound = impact_sound
	if _sprite:
		_base_modulate = _sprite.modulate
	_audio = AudioStreamPlayer.new()
	add_child(_audio)


func play_hit() -> void:
	if _sprite:
		_flash_remaining = flash_duration
		_sprite.modulate = flash_color
	if _impact_sound and _audio and is_inside_tree():
		_audio.volume_db = linear_to_db(impact_volume)
		_audio.stream = _impact_sound
		_audio.play()


func _process(delta: float) -> void:
	if _flash_remaining <= 0.0 or _sprite == null:
		return
	_flash_remaining -= delta
	if _flash_remaining <= 0.0:
		_sprite.modulate = _base_modulate
