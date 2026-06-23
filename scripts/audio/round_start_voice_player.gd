class_name RoundStartVoicePlayer
extends Node

## Random round-start vocal from Rd1 / Rd2 / Rd3 subfolders.

const AUDIO_BASE := "res://assets/audio/Fight Vox Rd Start/Round Start"
const AUDIO_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]

@export var volume_db: float = 0.0

var _cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()

@onready var _player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	_rng.randomize()


func play_for_round(round_number: int) -> void:
	if _player == null:
		return
	var voices := _voices_for_round(round_number)
	if voices.is_empty():
		push_warning("RoundStartVoicePlayer: no clips for round %d" % round_number)
		return
	_player.stream = voices[_rng.randi_range(0, voices.size() - 1)]
	_player.volume_db = volume_db
	_player.play()


func stop() -> void:
	if _player:
		_player.stop()


func _voices_for_round(round_number: int) -> Array[AudioStream]:
	var key := clampi(round_number, 1, 3)
	if _cache.has(key):
		return _cache[key]
	var voices: Array[AudioStream] = []
	var dir_path := "%s/Rd%d" % [AUDIO_BASE, key]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_cache[key] = voices
		return voices
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		if file_name.get_extension().to_lower() not in AUDIO_EXTENSIONS:
			continue
		var path := "%s/%s" % [dir_path, file_name]
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream != null:
			voices.append(stream)
	_cache[key] = voices
	return voices
