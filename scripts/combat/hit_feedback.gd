class_name HitFeedback
extends Node

const OVERLAP_SFX_SLOTS := 2

@export var flash_color := Color(1.0, 0.35, 0.35, 1.0)
@export var flash_duration := 0.18
@export_range(0.0, 1.0, 0.01) var impact_volume := 0.35

var _sprite: CanvasItem
var _impact_sound: AudioStream
var _audio: AudioStreamPlayer
var _overlap_audio: Array[AudioStreamPlayer] = []
var _overlap_cursor := 0
var _base_modulate := Color.WHITE
var _flash_remaining := 0.0


func setup(sprite: CanvasItem, impact_sound: AudioStream = null) -> void:
	_sprite = sprite
	_impact_sound = impact_sound
	if _sprite:
		_base_modulate = _sprite.modulate
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	for _i in OVERLAP_SFX_SLOTS:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_overlap_audio.append(player)


func play_hit(allow_overlap: bool = false) -> void:
	if _sprite:
		_flash_remaining = flash_duration
		_sprite.modulate = flash_color
	if _impact_sound == null or not is_inside_tree():
		return
	if allow_overlap:
		_play_impact_overlapping()
	elif _audio:
		_audio.volume_db = linear_to_db(impact_volume)
		_audio.stream = _impact_sound
		_audio.play()


func _play_impact_overlapping() -> void:
	if _overlap_audio.is_empty():
		return
	var player := _overlap_audio[_overlap_cursor]
	if player.playing:
		player.stop()
	player.volume_db = linear_to_db(impact_volume)
	player.stream = _impact_sound
	player.play()
	_overlap_cursor = (_overlap_cursor + 1) % OVERLAP_SFX_SLOTS


func _process(delta: float) -> void:
	if _flash_remaining <= 0.0 or _sprite == null:
		return
	_flash_remaining -= delta
	if _flash_remaining <= 0.0:
		_sprite.modulate = _base_modulate
