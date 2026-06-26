class_name YouWinSplashFx
extends Control

## Round-end YOU WIN / YOU LOSE graphic with ROUND N or FIGHT subtitle.

enum ResultKind {
	WIN,
	LOSE,
}

const WIN_TEXTURE_PATHS: Array[String] = [
	"res://assets/GFX_End_of_Round/YouWin.png",
	"res://assets/GFX_End_of_Round/YouWIN1.png",
]
const LOSE_TEXTURE_PATHS: Array[String] = [
	"res://assets/GFX_End_of_Round/YouLose.png",
]
const ROUND_GFX_DIR := "res://assets/GFX_Start_of_Rd"
const ROUND_GFX_PATTERN := "Round%d_GFX.png"
const FIGHT_TEXTURE_PATH := "res://assets/Fight_Announce1.png"

enum Mode {
	IDLE,
	INTRO,
	HOLD,
	ORBIT,
}

@export var display_width: float = 340.0
@export_range(0.55, 1.0, 0.01) var subtitle_width_ratio: float = 0.88
@export_range(0.2, 1.2, 0.01) var subtitle_max_height_ratio: float = 0.42
@export var subtitle_scale: float = 2.0
@export var subtitle_gap: float = 2.0
@export var intro_duration: float = 0.58
@export var start_scale: float = 0.06
@export var overshoot_scale: float = 1.14
@export var orbit_radius_x: float = 230.0
@export var orbit_radius_y: float = 175.0
@export var trail_ghost_count: int = 3
@export var trail_delays: Array[float] = [0.025, 0.05, 0.075]
@export var trail_opacities: Array[float] = [0.06, 0.10, 0.14]

const TRAIL_LOG_PAD_SEC := 0.03

@onready var _pivot: Control = $Pivot
@onready var _stack: VBoxContainer = $Pivot/Stack
@onready var _texture: TextureRect = $Pivot/Stack/MainTexture
@onready var _subtitle: TextureRect = $Pivot/Stack/SubtitleTexture

var _ghost_trail: Control
var _ghost_roots: Array[Control] = []
var _ghost_pivots: Array[Control] = []
var _ghost_mains: Array[TextureRect] = []
var _ghost_subtitles: Array[TextureRect] = []
var _trail_log: Array[Dictionary] = []

var _splash_texture: Texture2D
var _display_size := Vector2.ZERO
var _mode := Mode.IDLE
var _hold_time := 0.0
var _orbit_time := 0.0
var _orbit_angle := 0.0
var _orbit_center_local := Vector2.ZERO
var _intro_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation", int(subtitle_gap))
	_build_ghost_trail()
	visible = false


func play_splash_centered(
	kind: ResultKind = ResultKind.WIN,
	round_number: int = 0,
	fight_subtitle: bool = false,
) -> void:
	_splash_texture = _load_main_texture(kind)
	if _splash_texture == null:
		push_error("YouWinSplashFx: could not load splash texture for %s" % str(kind))
		return
	_layout_stack(round_number, fight_subtitle)
	_mode = Mode.INTRO
	_hold_time = 0.0
	_orbit_time = 0.0
	visible = true
	_center_on_parent()
	_pivot.scale = Vector2(start_scale, start_scale)
	_pivot.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_pivot.rotation = 0.0
	_pivot.position = Vector2.ZERO
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(
		_pivot,
		"scale",
		Vector2(overshoot_scale, overshoot_scale),
		intro_duration * 0.62,
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(
		_pivot,
		"modulate:a",
		1.0,
		intro_duration * 0.28,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.chain().tween_property(
		_pivot,
		"scale",
		Vector2.ONE,
		intro_duration * 0.38,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)


func begin_orbit(orbit_center_global: Vector2) -> void:
	if not visible:
		return
	_mode = Mode.ORBIT
	_orbit_time = 0.0
	_orbit_angle = randf() * TAU
	_orbit_center_local = _global_to_local(orbit_center_global)
	_pivot.rotation = 0.0
	_pivot.position = Vector2.ZERO
	_trail_log.clear()
	_set_ghost_trail_visible(true)
	_tick_orbit(0.0)
	_push_trail_sample()
	_update_ghost_trail()


func stop_splash() -> void:
	_mode = Mode.IDLE
	_hold_time = 0.0
	_orbit_time = 0.0
	_trail_log.clear()
	_set_ghost_trail_visible(false)
	visible = false
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_pivot.scale = Vector2.ONE
	_pivot.rotation = 0.0
	_pivot.position = Vector2.ZERO
	_pivot.modulate = Color.WHITE
	if _subtitle:
		_subtitle.visible = false


func _on_intro_finished() -> void:
	_mode = Mode.HOLD
	_pivot.scale = Vector2.ONE
	_hold_time = 0.0


func _process(delta: float) -> void:
	match _mode:
		Mode.HOLD:
			_tick_hold(delta)
		Mode.ORBIT:
			_tick_orbit(delta)


func _tick_hold(delta: float) -> void:
	_hold_time += delta
	var breathe := 1.0 + sin(_hold_time * 4.2) * 0.018
	_pivot.scale = Vector2.ONE * breathe
	_pivot.rotation = 0.0


func _tick_orbit(delta: float) -> void:
	_orbit_time += delta
	var speed := (
		0.82
		+ sin(_orbit_time * 2.05) * 0.34
		+ sin(_orbit_time * 5.15) * 0.16
		+ cos(_orbit_time * 8.4) * 0.09
	)
	_orbit_angle += speed * delta
	var rx := (
		orbit_radius_x
		+ sin(_orbit_time * 3.05) * 42.0
		+ sin(_orbit_time * 7.25) * 16.0
	)
	var ry := (
		orbit_radius_y
		+ cos(_orbit_time * 2.65) * 34.0
		+ cos(_orbit_time * 6.05) * 13.0
	)
	var offset := Vector2(cos(_orbit_angle) * rx, sin(_orbit_angle) * ry)
	var jitter := Vector2(
		sin(_orbit_time * 19.3) * 5.5,
		cos(_orbit_time * 14.7) * 4.5,
	)
	position = _orbit_center_local - _display_size * 0.5 + offset + jitter
	_pivot.rotation = 0.0
	_pivot.position = Vector2.ZERO
	var breathe := 1.0 + sin(_orbit_time * 6.1) * 0.022 + sin(_orbit_time * 11.8) * 0.011
	_pivot.scale = Vector2.ONE * breathe
	_push_trail_sample()
	_update_ghost_trail()


func _layout_stack(round_number: int, fight_subtitle: bool) -> void:
	if _splash_texture == null:
		return
	_stack.add_theme_constant_override("separation", int(subtitle_gap))
	var main_size := _layout_texture_rect(_texture, _splash_texture, display_width)
	var subtitle_size := Vector2.ZERO
	var subtitle_tex: Texture2D = null
	if fight_subtitle:
		subtitle_tex = _load_texture_path(FIGHT_TEXTURE_PATH)
	elif round_number > 0:
		subtitle_tex = _load_round_texture(round_number)
	if subtitle_tex != null:
		_subtitle.visible = true
		subtitle_size = _layout_subtitle_texture(_subtitle, subtitle_tex, main_size)
	else:
		_subtitle.visible = false
		_clear_texture_region(_subtitle)
	_display_size = Vector2(
		main_size.x,
		main_size.y + (subtitle_size.y + subtitle_gap if subtitle_size.y > 0.0 else 0.0),
	)
	custom_minimum_size = _display_size
	size = _display_size
	_pivot.custom_minimum_size = _display_size
	_pivot.size = _display_size
	_stack.custom_minimum_size = _display_size
	_stack.size = _display_size
	_pivot.pivot_offset = _display_size * 0.5
	_pivot.position = Vector2.ZERO
	_sync_ghost_visuals()


func _layout_subtitle_texture(rect: TextureRect, tex: Texture2D, main_size: Vector2) -> Vector2:
	if rect == null or tex == null:
		return Vector2.ZERO
	var region := _opaque_region(tex)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		_clear_texture_region(rect)
		return Vector2.ZERO
	var max_width := main_size.x * subtitle_width_ratio
	var max_height := main_size.y * subtitle_max_height_ratio
	var scale_factor := (
		minf(max_width / region.size.x, max_height / region.size.y) * subtitle_scale
	)
	return _apply_cropped_texture_rect(rect, tex, scale_factor)


func _layout_texture_rect(rect: TextureRect, tex: Texture2D, target_width: float) -> Vector2:
	if rect == null or tex == null:
		return Vector2.ZERO
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0:
		_clear_texture_region(rect)
		return Vector2.ZERO
	var scale_factor := target_width / tex_size.x
	return _apply_cropped_texture_rect(rect, tex, scale_factor)


func _opaque_region(tex: Texture2D) -> Rect2:
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2(Vector2.ZERO, tex_size)
	var image := tex.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, tex_size)
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return Rect2(Vector2.ZERO, tex_size)
	return Rect2(used)


func _apply_cropped_texture_rect(rect: TextureRect, tex: Texture2D, scale_factor: float) -> Vector2:
	var region := _opaque_region(tex)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	rect.texture = atlas
	var display_size := region.size * scale_factor
	rect.custom_minimum_size = display_size
	rect.size = display_size
	return display_size


func _clear_texture_region(rect: TextureRect) -> void:
	if rect == null:
		return
	rect.texture = null


func _build_ghost_trail() -> void:
	_ghost_trail = Control.new()
	_ghost_trail.name = "GhostTrail"
	_ghost_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost_trail)
	move_child(_ghost_trail, 0)
	var count := maxi(trail_ghost_count, 0)
	for i in count:
		var root := Control.new()
		root.name = "Ghost%d" % i
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.visible = false
		var pivot := Control.new()
		pivot.name = "Pivot"
		pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stack := VBoxContainer.new()
		stack.name = "Stack"
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", int(subtitle_gap))
		var main_tex := TextureRect.new()
		main_tex.name = "MainTexture"
		main_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		main_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		main_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sub_tex := TextureRect.new()
		sub_tex.name = "SubtitleTexture"
		sub_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sub_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sub_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(main_tex)
		stack.add_child(sub_tex)
		pivot.add_child(stack)
		root.add_child(pivot)
		_ghost_trail.add_child(root)
		_ghost_roots.append(root)
		_ghost_pivots.append(pivot)
		_ghost_mains.append(main_tex)
		_ghost_subtitles.append(sub_tex)
	_set_ghost_trail_visible(false)


func _set_ghost_trail_visible(show_trail: bool) -> void:
	if _ghost_trail:
		_ghost_trail.visible = show_trail
	for root in _ghost_roots:
		root.visible = show_trail


func _sync_ghost_visuals() -> void:
	if _ghost_roots.is_empty():
		return
	for i in _ghost_roots.size():
		var root := _ghost_roots[i]
		var pivot := _ghost_pivots[i]
		var stack := pivot.get_child(0) as VBoxContainer
		var main_tex := _ghost_mains[i]
		var sub_tex := _ghost_subtitles[i]
		root.custom_minimum_size = _display_size
		root.size = _display_size
		pivot.custom_minimum_size = _display_size
		pivot.size = _display_size
		pivot.pivot_offset = _display_size * 0.5
		pivot.position = Vector2.ZERO
		if stack:
			stack.custom_minimum_size = _display_size
			stack.size = _display_size
			stack.add_theme_constant_override("separation", int(subtitle_gap))
		_mirror_texture_rect(main_tex, _texture)
		_mirror_texture_rect(sub_tex, _subtitle)
		sub_tex.visible = _subtitle.visible


func _mirror_texture_rect(target: TextureRect, source: TextureRect) -> void:
	if target == null or source == null:
		return
	target.texture = source.texture
	target.visible = source.visible
	target.custom_minimum_size = source.custom_minimum_size
	target.size = source.size


func _push_trail_sample() -> void:
	_trail_log.append({
		"pos": position,
		"pivot_scale": _pivot.scale.x,
		"time": _orbit_time,
	})
	var max_delay := 0.0
	for delay in trail_delays:
		max_delay = maxf(max_delay, delay)
	var cutoff := _orbit_time - max_delay - TRAIL_LOG_PAD_SEC
	while _trail_log.size() > 2 and float(_trail_log[0].get("time", 0.0)) < cutoff:
		_trail_log.pop_front()


func _sample_trail_at(lookback_sec: float) -> Dictionary:
	var target_time := _orbit_time - lookback_sec
	if _trail_log.is_empty():
		return {"pos": position, "pivot_scale": _pivot.scale.x}
	var oldest: Dictionary = _trail_log[0]
	if target_time <= float(oldest.get("time", 0.0)):
		return oldest
	for i in range(_trail_log.size() - 1, -1, -1):
		var sample: Dictionary = _trail_log[i]
		var sample_time := float(sample.get("time", 0.0))
		if sample_time <= target_time:
			if i + 1 < _trail_log.size():
				var newer: Dictionary = _trail_log[i + 1]
				var newer_time := float(newer.get("time", sample_time))
				var span: float = newer_time - sample_time
				var t: float = (target_time - sample_time) / maxf(span, 0.0001)
				var sample_pos := sample.get("pos", position) as Vector2
				var newer_pos := newer.get("pos", position) as Vector2
				return {
					"pos": sample_pos.lerp(newer_pos, t),
					"pivot_scale": lerpf(
						float(sample.get("pivot_scale", 1.0)),
						float(newer.get("pivot_scale", 1.0)),
						t,
					),
				}
			return sample
	return _trail_log[_trail_log.size() - 1]


func _update_ghost_trail() -> void:
	if _mode != Mode.ORBIT or _ghost_roots.is_empty():
		return
	for i in _ghost_roots.size():
		var delay: float = trail_delays[i] if i < trail_delays.size() else 0.025 * float(i + 1)
		var alpha: float = trail_opacities[i] if i < trail_opacities.size() else 0.05 + 0.04 * float(i)
		var sample: Dictionary = _sample_trail_at(delay)
		var root := _ghost_roots[i]
		var pivot := _ghost_pivots[i]
		root.position = (sample.get("pos", position) as Vector2) - position
		root.modulate = Color(1.0, 1.0, 1.0, alpha)
		var ghost_scale: float = float(sample.get("pivot_scale", 1.0))
		pivot.scale = Vector2(ghost_scale, ghost_scale)
		pivot.rotation = 0.0
		root.visible = true


func _center_on_parent() -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl:
		var area := parent_ctrl.get_rect()
		position = area.position + (area.size - _display_size) * 0.5
		return
	var vp := get_viewport().get_visible_rect()
	position = (vp.size - _display_size) * 0.5


func _global_to_local(global_pos: Vector2) -> Vector2:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl:
		return parent_ctrl.get_global_transform_with_canvas().affine_inverse() * global_pos
	return global_pos


func _load_round_texture(round_number: int) -> Texture2D:
	var path := "%s/%s" % [ROUND_GFX_DIR, ROUND_GFX_PATTERN % maxi(round_number, 1)]
	return _load_texture_path(path)


func _load_texture_path(path: String) -> Texture2D:
	var imported := load(path) as Texture2D
	if imported != null:
		return imported
	if ResourceLoader.exists(path):
		imported = ResourceLoader.load(path) as Texture2D
		if imported != null:
			return imported
	var filesystem_path := ProjectSettings.globalize_path(path)
	if filesystem_path.is_empty() or not FileAccess.file_exists(filesystem_path):
		push_warning("YouWinSplashFx: missing %s" % path)
		return null
	var image := Image.new()
	if image.load(filesystem_path) != OK:
		push_warning("YouWinSplashFx: could not load %s" % path)
		return null
	return ImageTexture.create_from_image(image)


func _load_main_texture(kind: ResultKind) -> Texture2D:
	var paths := WIN_TEXTURE_PATHS if kind == ResultKind.WIN else LOSE_TEXTURE_PATHS
	for path in paths:
		var tex := _load_texture_path(path)
		if tex != null:
			return tex
	return null
