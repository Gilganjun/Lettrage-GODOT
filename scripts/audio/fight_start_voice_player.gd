class_name FightStartVoicePlayer
extends Node

## Plays a random round-start fight vocal when the FIGHT splash appears.

const AUDIO_DIR := "res://assets/audio/Fight Vox Rd Start"
const FILE_PREFIX := "Fight_SFX"
const AUDIO_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]

@export var play_delay_seconds := 1.0
@export var volume_db := 0.0

var _voices: Array[AudioStream] = []
var _rng := RandomNumberGenerator.new()

@onready var _player: AudioStreamPlayer = $AudioStreamPlayer
@onready var _delay_timer: Timer = $DelayTimer


func _ready() -> void:
	_rng.randomize()
	_delay_timer.one_shot = true
	if not _delay_timer.timeout.is_connected(_play_random_voice):
		_delay_timer.timeout.connect(_play_random_voice)
	refresh_voices()


func refresh_voices() -> void:
	_voices.clear()
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		push_warning("FightStartVoicePlayer: cannot open %s" % AUDIO_DIR)
		return
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		if not file_name.begins_with(FILE_PREFIX):
			continue
		if file_name.get_extension().to_lower() not in AUDIO_EXTENSIONS:
			continue
		var path := "%s/%s" % [AUDIO_DIR, file_name]
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream != null:
			_voices.append(stream)


func schedule_play(delay_seconds: float = -1.0) -> void:
	cancel_scheduled_play()
	refresh_voices()
	if _voices.is_empty():
		return
	_delay_timer.wait_time = play_delay_seconds if delay_seconds < 0.0 else delay_seconds
	_delay_timer.start()


func cancel_scheduled_play() -> void:
	if _delay_timer:
		_delay_timer.stop()


func _play_random_voice() -> void:
	if _player == null or _voices.is_empty():
		return
	_player.stream = _voices[_rng.randi_range(0, _voices.size() - 1)]
	_player.volume_db = volume_db
	_player.play()
