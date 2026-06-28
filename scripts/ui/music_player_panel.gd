class_name MusicPlayerPanel
extends CanvasLayer

## Compact in-game music controller — open/close with M.

const FONT_PATH := "res://assets/Panton-BlackCaps.otf"

var _player: AudioStreamPlayer
var _root: Control
var _toggle_button: Button
var _panel: PanelContainer
var _track_label: Label
var _time_label: Label
var _progress: ProgressBar
var _mute_button: Button
var _prev_button: Button
var _stop_button: Button
var _next_button: Button
var _volume_slider: HSlider
var _volume_value: Label
var _open := false


func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_build_ui()
	_set_open(false)


func setup(player: AudioStreamPlayer) -> void:
	if _player == player:
		return
	_disconnect_player()
	_player = player
	if _player == null:
		_refresh_ui()
		return
	if not _player.track_changed.is_connected(_on_player_track_changed):
		_player.track_changed.connect(_on_player_track_changed)
	if not _player.muted_changed.is_connected(_on_player_muted_changed):
		_player.muted_changed.connect(_on_player_muted_changed)
	if not _player.volume_changed.is_connected(_on_player_volume_changed):
		_player.volume_changed.connect(_on_player_volume_changed)
	if not _player.playback_state_changed.is_connected(_on_player_playback_changed):
		_player.playback_state_changed.connect(_on_player_playback_changed)
	_refresh_ui()


func toggle_panel() -> void:
	_set_open(not _open)


func is_open() -> bool:
	return _open


func _process(_delta: float) -> void:
	if not _open or _player == null:
		return
	_progress.value = _player.get_playback_ratio() * 100.0
	_time_label.text = _player.get_playback_time_text()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action("toggle_music"):
		toggle_panel()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_open = open
	if _panel != null:
		_panel.visible = open
	if _toggle_button != null:
		_toggle_button.visible = not open
	if open:
		_refresh_ui()


func _disconnect_player() -> void:
	if _player == null:
		return
	if _player.track_changed.is_connected(_on_player_track_changed):
		_player.track_changed.disconnect(_on_player_track_changed)
	if _player.muted_changed.is_connected(_on_player_muted_changed):
		_player.muted_changed.disconnect(_on_player_muted_changed)
	if _player.volume_changed.is_connected(_on_player_volume_changed):
		_player.volume_changed.disconnect(_on_player_volume_changed)
	if _player.playback_state_changed.is_connected(_on_player_playback_changed):
		_player.playback_state_changed.disconnect(_on_player_playback_changed)


func _on_player_track_changed(_path: String, _name: String) -> void:
	_refresh_track_label()


func _on_player_muted_changed(_muted: bool) -> void:
	_refresh_mute_button()


func _on_player_volume_changed(percent: float) -> void:
	if _volume_slider != null and not _volume_slider.has_focus():
		_volume_slider.value = percent
	_refresh_volume_label(percent)


func _on_player_playback_changed() -> void:
	if _player != null:
		_progress.value = _player.get_playback_ratio() * 100.0
		_time_label.text = _player.get_playback_time_text()


func _refresh_ui() -> void:
	_refresh_track_label()
	_refresh_mute_button()
	if _player != null:
		var vol: float = _player.get_music_volume_percent()
		_volume_slider.value = vol
		_refresh_volume_label(vol)
		_progress.value = _player.get_playback_ratio() * 100.0
		_time_label.text = _player.get_playback_time_text()
	else:
		_track_label.text = "No music player"
		_volume_slider.value = 30.0
		_refresh_volume_label(30.0)
		_progress.value = 0.0
		_time_label.text = "0:00 / 0:00"


func _refresh_track_label() -> void:
	if _track_label == null:
		return
	if _player == null:
		_track_label.text = "No tracks"
		return
	var has_tracks: bool = _player.get_track_count() > 0
	if not has_tracks:
		_track_label.text = "Add tracks to Music/80sGaming"
	else:
		_track_label.text = _player.get_display_name()
	if _prev_button != null:
		_prev_button.disabled = not has_tracks
		_stop_button.disabled = not has_tracks
		_next_button.disabled = not has_tracks
		_mute_button.disabled = not has_tracks
		_volume_slider.editable = has_tracks


func _refresh_mute_button() -> void:
	if _mute_button == null or _player == null:
		return
	_mute_button.text = "UNMUTE" if _player.is_muted() else "MUTE"


func _refresh_volume_label(percent: float) -> void:
	if _volume_value != null:
		_volume_value.text = "%d%%" % int(roundf(percent))


func _on_prev_pressed() -> void:
	if _player != null:
		_player.play_previous()


func _on_stop_pressed() -> void:
	if _player != null:
		_player.stop_track()


func _on_next_pressed() -> void:
	if _player != null:
		_player.play_next()


func _on_mute_pressed() -> void:
	if _player != null:
		_player.toggle_mute()


func _on_volume_changed(value: float) -> void:
	if _player != null:
		_player.set_music_volume_percent(value)
	_refresh_volume_label(value)


func _on_close_pressed() -> void:
	_set_open(false)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_toggle_button = _make_chip_button("MUSIC", toggle_panel)
	_toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toggle_button.offset_left = -92.0
	_toggle_button.offset_top = 10.0
	_toggle_button.offset_right = -10.0
	_toggle_button.offset_bottom = 38.0
	_toggle_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_toggle_button)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 10.0
	_panel.offset_top = 46.0
	_panel.custom_minimum_size = Vector2(292.0, 0.0)
	_root.add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.14, 0.94)
	style.border_color = Color(0.92, 0.76, 0.28, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "MUSIC"
	title.add_theme_font_override("font", load(FONT_PATH))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := _make_button("X", _on_close_pressed)
	close_btn.custom_minimum_size = Vector2(28.0, 24.0)
	header.add_child(close_btn)

	_track_label = Label.new()
	_track_label.text = "—"
	_track_label.clip_text = true
	_track_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_track_label.add_theme_font_override("font", load(FONT_PATH))
	_track_label.add_theme_font_size_override("font_size", 13)
	_track_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	vbox.add_child(_track_label)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	vbox.add_child(progress_row)

	_progress = ProgressBar.new()
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.custom_minimum_size = Vector2(120.0, 14.0)
	_progress.max_value = 100.0
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var progress_style := StyleBoxFlat.new()
	progress_style.bg_color = Color(0.12, 0.15, 0.22, 1.0)
	progress_style.set_corner_radius_all(3)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.95, 0.78, 0.28, 0.95)
	progress_fill.set_corner_radius_all(3)
	_progress.add_theme_stylebox_override("background", progress_style)
	_progress.add_theme_stylebox_override("fill", progress_fill)
	progress_row.add_child(_progress)

	_time_label = Label.new()
	_time_label.text = "0:00 / 0:00"
	_time_label.custom_minimum_size = Vector2(84.0, 0.0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.add_theme_font_size_override("font_size", 11)
	_time_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9, 1.0))
	progress_row.add_child(_time_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(controls)

	controls.add_child(_make_button("◀", _on_prev_pressed))
	_prev_button = controls.get_child(controls.get_child_count() - 1) as Button
	controls.add_child(_make_button("STOP", _on_stop_pressed))
	_stop_button = controls.get_child(controls.get_child_count() - 1) as Button
	controls.add_child(_make_button("▶", _on_next_pressed))
	_next_button = controls.get_child(controls.get_child_count() - 1) as Button
	_mute_button = _make_button("MUTE", _on_mute_pressed)
	_mute_button.custom_minimum_size = Vector2(72.0, 28.0)
	controls.add_child(_mute_button)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 8)
	vbox.add_child(volume_row)

	var vol_caption := Label.new()
	vol_caption.text = "VOL"
	vol_caption.add_theme_font_override("font", load(FONT_PATH))
	vol_caption.add_theme_font_size_override("font_size", 12)
	vol_caption.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95, 1.0))
	volume_row.add_child(vol_caption)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.value = 30.0
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.custom_minimum_size = Vector2(140.0, 0.0)
	_volume_slider.value_changed.connect(_on_volume_changed)
	volume_row.add_child(_volume_slider)

	_volume_value = Label.new()
	_volume_value.text = "30%"
	_volume_value.custom_minimum_size = Vector2(38.0, 0.0)
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_value.add_theme_font_size_override("font_size", 11)
	_volume_value.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9, 1.0))
	volume_row.add_child(_volume_value)


func _make_chip_button(caption: String, callback: Callable) -> Button:
	var button := _make_button(caption, callback)
	button.add_theme_font_size_override("font_size", 14)
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.08, 0.1, 0.16, 0.82)
	chip_style.border_color = Color(0.92, 0.76, 0.28, 0.85)
	chip_style.set_border_width_all(2)
	chip_style.set_corner_radius_all(6)
	chip_style.content_margin_left = 10.0
	chip_style.content_margin_right = 10.0
	chip_style.content_margin_top = 4.0
	chip_style.content_margin_bottom = 4.0
	button.add_theme_stylebox_override("normal", chip_style)
	button.add_theme_stylebox_override("hover", chip_style)
	button.add_theme_stylebox_override("pressed", chip_style)
	button.custom_minimum_size = Vector2(72.0, 28.0)
	return button


func _make_button(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(52.0, 28.0)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.11, 0.14, 0.22, 1.0)
	btn_style.border_color = Color(0.45, 0.58, 0.82, 0.85)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.content_margin_left = 6.0
	btn_style.content_margin_right = 6.0
	btn_style.content_margin_top = 2.0
	btn_style.content_margin_bottom = 2.0
	button.add_theme_stylebox_override("normal", btn_style)
	button.add_theme_stylebox_override("hover", btn_style)
	button.add_theme_stylebox_override("pressed", btn_style)
	button.add_theme_font_override("font", load(FONT_PATH))
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(func() -> void:
		callback.call()
	)
	return button
