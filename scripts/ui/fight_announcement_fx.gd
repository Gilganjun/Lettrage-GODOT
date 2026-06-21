class_name FightAnnouncementFx
extends Control

## Round-start FIGHT splash: zoom from far, maniacal shake, quick fade (2s total).

const TEXTURE_PATH := "res://assets/Fight_Announce1.png"

@export var total_duration: float = 2.0
@export var zoom_in_duration: float = 0.48
@export var fade_out_duration: float = 0.38
@export var display_width: float = 320.0
@export var start_scale: float = 0.06
@export var peak_scale: float = 1.1
@export var shake_strength: float = 15.4

@onready var _pivot: Control = $Pivot
@onready var _texture: TextureRect = $Pivot/TextureRect

var _splash_texture: Texture2D
var _display_size := Vector2.ZERO
var _active := false
var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_texture = _load_texture()
	if _splash_texture == null:
		push_error("FightAnnouncementFx: could not load %s" % TEXTURE_PATH)
		return
	_layout_texture()
	visible = false
	set_process(false)


func play_announcement() -> void:
	if _splash_texture == null:
		return
	_layout_texture()
	visible = true
	_active = true
	_elapsed = 0.0
	_pivot.scale = Vector2(start_scale, start_scale)
	_pivot.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_pivot.rotation = 0.0
	_pivot.position = Vector2.ZERO
	set_process(true)


func stop_announcement() -> void:
	_active = false
	_elapsed = 0.0
	visible = false
	set_process(false)
	if _pivot:
		_pivot.scale = Vector2.ONE
		_pivot.rotation = 0.0
		_pivot.position = Vector2.ZERO
		_pivot.modulate = Color.WHITE


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= total_duration:
		stop_announcement()
		return

	var shake_start := zoom_in_duration
	var fade_start := maxf(total_duration - fade_out_duration, shake_start)

	if _elapsed < zoom_in_duration:
		var t := _elapsed / maxf(zoom_in_duration, 0.001)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		var scale_val := lerpf(start_scale, peak_scale, eased)
		_pivot.scale = Vector2(scale_val, scale_val)
		_pivot.modulate.a = clampf(t * 1.35, 0.0, 1.0)
		_pivot.position = Vector2.ZERO
		_pivot.rotation = 0.0
	elif _elapsed < fade_start:
		_apply_maniacal_shake(_elapsed - shake_start)
	elif _elapsed < total_duration:
		var fade_t := (_elapsed - fade_start) / maxf(fade_out_duration, 0.001)
		_pivot.modulate.a = 1.0 - fade_t
		var scale_val := lerpf(peak_scale, peak_scale * 1.08, fade_t)
		_pivot.scale = Vector2(scale_val, scale_val)
		_apply_maniacal_shake(_elapsed - shake_start, fade_t)


func _apply_maniacal_shake(shake_time: float, fade: float = 0.0) -> void:
	var intensity := shake_strength * (1.0 - fade * 0.65)
	var shake_x := (
		sin(shake_time * 62.0) * intensity
		+ sin(shake_time * 41.3) * intensity * 0.55
		+ sin(shake_time * 97.0) * intensity * 0.28
	)
	var shake_y := (
		cos(shake_time * 54.7) * intensity * 0.72
		+ cos(shake_time * 33.8) * intensity * 0.46
		+ cos(shake_time * 81.5) * intensity * 0.22
	)
	_pivot.position = Vector2(shake_x, shake_y)
	_pivot.rotation = (
		sin(shake_time * 19.4) * 0.09
		+ sin(shake_time * 31.2) * 0.045
		+ cos(shake_time * 11.7) * 0.028
	) * (1.0 - fade * 0.5)
	var wobble := 1.0 + sin(shake_time * 24.0) * 0.035 + sin(shake_time * 47.0) * 0.018
	_pivot.scale = Vector2(peak_scale, peak_scale) * wobble


func _layout_texture() -> void:
	_texture.texture = _splash_texture
	var tex_size := _splash_texture.get_size()
	if tex_size.x <= 0.0:
		return
	var scale_factor := display_width / tex_size.x
	_display_size = tex_size * scale_factor
	custom_minimum_size = _display_size
	size = _display_size
	_pivot.custom_minimum_size = _display_size
	_pivot.size = _display_size
	_texture.custom_minimum_size = _display_size
	_texture.size = _display_size
	_pivot.pivot_offset = _display_size * 0.5
	_pivot.position = Vector2.ZERO


func _load_texture() -> Texture2D:
	if ResourceLoader.exists(TEXTURE_PATH):
		var imported := load(TEXTURE_PATH) as Texture2D
		if imported != null:
			return imported
	var image := Image.new()
	if image.load(TEXTURE_PATH) == OK:
		return ImageTexture.create_from_image(image)
	return null
