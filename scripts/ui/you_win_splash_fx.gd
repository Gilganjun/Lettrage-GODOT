class_name YouWinSplashFx
extends Control

## Centered zoom-in splash with ongoing shake / wobble for round-win impact.

const SPLASH_TEXTURE_PATHS: Array[String] = [
	"res://assets/GFX_End_of_Round/YouWin.png",
	"res://assets/GFX_End_of_Round/YouWIN1.png",
]

@export var display_width: float = 340.0
@export var intro_duration: float = 0.58
@export var start_scale: float = 0.06
@export var overshoot_scale: float = 1.14
@export var shake_strength: float = 9.0
@export var shake_falloff_seconds: float = 2.4

@onready var _pivot: Control = $Pivot
@onready var _texture: TextureRect = $Pivot/TextureRect

var _splash_texture: Texture2D
var _display_size := Vector2.ZERO
var _splash_active := false
var _intro_done := false
var _time := 0.0
var _intro_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_texture = _load_splash_texture()
	if _splash_texture == null:
		push_error("YouWinSplashFx: could not load splash texture")
		return
	_layout_texture()
	visible = false


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


func play_splash() -> void:
	if _splash_texture == null:
		return
	_layout_texture()
	visible = true
	_splash_active = true
	_intro_done = false
	_time = 0.0
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


func stop_splash() -> void:
	_splash_active = false
	_intro_done = false
	_time = 0.0
	visible = false
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_pivot.scale = Vector2.ONE
	_pivot.rotation = 0.0
	_pivot.position = Vector2.ZERO
	_pivot.modulate = Color.WHITE


func _on_intro_finished() -> void:
	_intro_done = true
	_pivot.scale = Vector2.ONE


func _process(delta: float) -> void:
	if not _splash_active or not _intro_done:
		return
	_time += delta
	var falloff := clampf(1.0 - (_time / maxf(shake_falloff_seconds, 0.01)), 0.22, 1.0)
	var strength := shake_strength * falloff
	var shake_x := (
		sin(_time * 47.3) * strength
		+ sin(_time * 23.1) * strength * 0.42
		+ sin(_time * 71.0) * strength * 0.18
	)
	var shake_y := (
		cos(_time * 39.7) * strength * 0.62
		+ cos(_time * 19.4) * strength * 0.34
		+ cos(_time * 58.2) * strength * 0.15
	)
	_pivot.position = Vector2(shake_x, shake_y)
	_pivot.rotation = (
		sin(_time * 8.6) * 0.045
		+ sin(_time * 13.4) * 0.022
		+ cos(_time * 5.1) * 0.012
	) * falloff
	var breathe := (
		1.0
		+ sin(_time * 5.8) * 0.028
		+ sin(_time * 11.3) * 0.014
		+ sin(_time * 2.7) * 0.008
	)
	_pivot.scale = Vector2.ONE * breathe


func _load_splash_texture() -> Texture2D:
	for path in SPLASH_TEXTURE_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null
