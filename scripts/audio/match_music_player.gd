class_name MatchMusicPlayer
extends AudioStreamPlayer

## Round/match music from assets/Music/80sGaming — YouWIN stingers between player round wins.

signal track_changed(track_path: String, display_name: String)
signal muted_changed(is_muted: bool)
signal volume_changed(volume_percent: float)
signal playback_state_changed()

const MUSIC_DIR := "res://assets/Music/80sGaming"
const YOU_WIN_DIR := "res://assets/Music/80sGaming/YouWIN"
const MUSIC_BUS := "Music"
const AUDIO_EXTENSIONS: PackedStringArray = ["mp3", "ogg", "wav"]
const DEFAULT_MUSIC_VOLUME_PERCENT := 30.0

@export_range(0.0, 1.0, 0.01) var music_level := 0.3
@export var stop_scene_ambient := true

var _all_tracks: PackedStringArray = PackedStringArray()
var _you_win_tracks: PackedStringArray = PackedStringArray()
var _match_round_pool: Array[String] = []
var _current_track_path := ""
var _muted := false
var _music_volume_percent := DEFAULT_MUSIC_VOLUME_PERCENT
var _auto_advance := true
var _in_you_win_mode := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_music_volume_percent = music_level * 100.0
	_ensure_music_bus()
	bus = MUSIC_BUS
	volume_db = 0.0
	_apply_bus_volume()
	_apply_bus_mute()
	finished.connect(_on_track_finished)
	_discover_tracks()
	_discover_you_win_tracks()
	if _all_tracks.is_empty():
		push_warning("MatchMusicPlayer: no gameplay tracks in %s" % MUSIC_DIR)
	if _you_win_tracks.is_empty():
		push_warning("MatchMusicPlayer: no YouWIN tracks in %s" % YOU_WIN_DIR)


func setup(match_controller: MatchController, scene_ambient: AudioStreamPlayer = null) -> void:
	if match_controller != null:
		if not match_controller.round_countdown_started.is_connected(_on_round_countdown_started):
			match_controller.round_countdown_started.connect(_on_round_countdown_started)
		if not match_controller.round_started.is_connected(_on_round_started):
			match_controller.round_started.connect(_on_round_started)
		if not match_controller.round_ended.is_connected(_on_round_ended):
			match_controller.round_ended.connect(_on_round_ended)
	if stop_scene_ambient and scene_ambient != null:
		scene_ambient.stop()
	reset_default_volume()


func get_track_count() -> int:
	return _all_tracks.size()


func get_current_track_path() -> String:
	return _current_track_path


func get_display_name(path: String = "") -> String:
	var resolved := path if not path.is_empty() else _current_track_path
	if resolved.is_empty():
		return "No track loaded"
	return resolved.get_file().get_basename().replace("_", " ")


func is_muted() -> bool:
	return _muted


func get_music_volume_percent() -> float:
	return _music_volume_percent


func reset_default_volume() -> void:
	set_music_volume_percent(DEFAULT_MUSIC_VOLUME_PERCENT)


func set_music_volume_percent(percent: float) -> void:
	_music_volume_percent = clampf(percent, 0.0, 100.0)
	_apply_bus_volume()
	volume_changed.emit(_music_volume_percent)


func toggle_mute() -> void:
	set_muted(not _muted)


func set_muted(muted: bool) -> void:
	if _muted == muted:
		return
	_muted = muted
	_apply_bus_mute()
	if not _muted and not playing and not _all_tracks.is_empty() and not _in_you_win_mode:
		var resume_path := _current_track_path
		if resume_path.is_empty() or not _is_gameplay_track(resume_path):
			resume_path = _all_tracks[0]
		_play_track(resume_path)
	muted_changed.emit(_muted)


func stop_track() -> void:
	_auto_advance = false
	stop()
	playback_state_changed.emit()


func play_you_win_track() -> void:
	stop_track()
	if _you_win_tracks.is_empty():
		_discover_you_win_tracks()
	if _you_win_tracks.is_empty():
		return
	_in_you_win_mode = true
	_auto_advance = false
	var path: String = _you_win_tracks[_rng.randi_range(0, _you_win_tracks.size() - 1)]
	_play_track(path)


func play_next(manual := true) -> void:
	if _in_you_win_mode or _all_tracks.is_empty():
		return
	if manual:
		_auto_advance = true
	var idx := _track_index_for(_current_track_path)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + 1) % _all_tracks.size()
	_play_track(_all_tracks[idx])


func play_previous(manual := true) -> void:
	if _in_you_win_mode or _all_tracks.is_empty():
		return
	if manual:
		_auto_advance = true
	var idx := _track_index_for(_current_track_path)
	if idx < 0:
		idx = _all_tracks.size() - 1
	else:
		idx = (idx - 1 + _all_tracks.size()) % _all_tracks.size()
	_play_track(_all_tracks[idx])


func get_playback_ratio() -> float:
	if stream == null:
		return 0.0
	var length := stream.get_length()
	if length <= 0.0:
		return 0.0
	return clampf(get_playback_position() / length, 0.0, 1.0)


func get_playback_time_text() -> String:
	if stream == null:
		return "0:00 / 0:00"
	var pos := int(get_playback_position())
	var len := int(stream.get_length())
	return "%d:%02d / %d:%02d" % [pos / 60, pos % 60, len / 60, len % 60]


func _on_round_ended(player_won_round: bool) -> void:
	if not player_won_round:
		return
	play_you_win_track()


func _on_round_countdown_started(_round_number: int) -> void:
	if not _in_you_win_mode:
		return
	_in_you_win_mode = false
	stop_track()


func _on_round_started(round_number: int) -> void:
	_in_you_win_mode = false
	if playing:
		stop_track()
	reset_default_volume()
	if _all_tracks.is_empty():
		return
	if round_number == 1:
		_reset_match_round_pool()
	_auto_advance = true
	_play_round_start_track()


func _is_gameplay_track(path: String) -> bool:
	return _all_tracks.has(path)


func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) >= 0:
		return
	var bus_idx := AudioServer.bus_count
	AudioServer.add_bus(bus_idx)
	AudioServer.set_bus_name(bus_idx, MUSIC_BUS)
	AudioServer.set_bus_send(bus_idx, "Master")


func _apply_bus_volume() -> void:
	var bus_idx := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_idx < 0:
		return
	var linear := _music_volume_percent / 100.0
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear) if linear > 0.0 else -80.0)


func _apply_bus_mute() -> void:
	var bus_idx := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_idx < 0:
		return
	AudioServer.set_bus_mute(bus_idx, _muted)


func _discover_tracks() -> void:
	_all_tracks = _discover_audio_files_in(MUSIC_DIR, false)


func _discover_you_win_tracks() -> void:
	_you_win_tracks = _discover_audio_files_in(YOU_WIN_DIR, true)


func _discover_audio_files_in(dir_path: String, include_subdirs: bool) -> PackedStringArray:
	var tracks := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return tracks
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if include_subdirs:
				for sub_track in _discover_audio_files_in(full_path, true):
					tracks.append(sub_track)
		else:
			var ext := entry.get_extension().to_lower()
			if ext in AUDIO_EXTENSIONS:
				tracks.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	tracks.sort()
	return tracks


func _track_index_for(path: String) -> int:
	if path.is_empty():
		return -1
	return _all_tracks.find(path)


func _reset_match_round_pool() -> void:
	_match_round_pool.clear()
	for path in _all_tracks:
		_match_round_pool.append(path)
	_match_round_pool.shuffle()


func _pick_round_start_track() -> String:
	if _match_round_pool.is_empty():
		_reset_match_round_pool()
	if _match_round_pool.is_empty():
		return ""
	return _match_round_pool.pop_back()


func _play_round_start_track() -> void:
	var path := _pick_round_start_track()
	if path.is_empty():
		return
	_play_track(path)


func _on_track_finished() -> void:
	if _muted or not _auto_advance or _in_you_win_mode:
		playback_state_changed.emit()
		return
	play_next(false)


func _play_track(path: String) -> void:
	var playable := _load_stream(path)
	if playable == null:
		push_warning("MatchMusicPlayer: failed to load %s" % path)
		return
	_current_track_path = path
	stream = playable
	track_changed.emit(path, get_display_name(path))
	if not _muted:
		play()
	playback_state_changed.emit()


func _load_stream(path: String) -> AudioStream:
	var res := load(path) as AudioStream
	if res == null:
		return null
	var playable := res.duplicate() as AudioStream
	if playable is AudioStreamMP3:
		(playable as AudioStreamMP3).loop = false
	elif playable is AudioStreamOggVorbis:
		(playable as AudioStreamOggVorbis).loop = false
	return playable
