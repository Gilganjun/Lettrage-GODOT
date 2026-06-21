class_name YouWinVoicePlayer
extends Node

## Plays voiced "You Win" samples when a round is won.

enum PickMode { ROTATE, RANDOM }

const VOICES: Array[AudioStream] = [
	preload("res://assets/audio/YouWin/You_Win1.mp3"),
	preload("res://assets/audio/YouWin/You_Win2.mp3"),
	preload("res://assets/audio/YouWin/You_Win3.mp3"),
	preload("res://assets/audio/YouWin/You_Win4.mp3"),
	preload("res://assets/audio/YouWin/You_Win5.mp3"),
	preload("res://assets/audio/YouWin/You_Win6.mp3"),
	preload("res://assets/audio/YouWin/You_Win7.mp3"),
]

@export var pick_mode: PickMode = PickMode.RANDOM
@export var volume_db: float = 0.0

var _rotate_index := 0
var _rng := RandomNumberGenerator.new()

@onready var _player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	_rng.randomize()


func play_you_win() -> void:
	if _player == null or VOICES.is_empty():
		return
	_player.stream = _pick_next_voice()
	_player.volume_db = volume_db
	_player.play()


func _pick_next_voice() -> AudioStream:
	match pick_mode:
		PickMode.RANDOM:
			return VOICES[_rng.randi_range(0, VOICES.size() - 1)]
		_:
			var voice := VOICES[_rotate_index]
			_rotate_index = (_rotate_index + 1) % VOICES.size()
			return voice
