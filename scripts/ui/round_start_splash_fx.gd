class_name RoundStartSplashFx
extends Control

## Brief ROUND 1 / 2 / 3 splash during the intro drop.

const GFX_DIR := "res://assets/GFX_Start_of_Rd"
const GFX_PATTERN := "Round%d_GFX.png"

@export var display_width: float = 480.0
@export var hold_duration: float = 2.0
@export var intro_duration: float = 0.22
@export var outro_duration: float = 0.28

@onready var _pivot: Control = $Pivot
@onready var _texture: TextureRect = $Pivot/TextureRect

var _active := false
var _elapsed := 0.0
var _total_duration := 2.0
var _textures: Array[Texture2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preload_textures()
	visible = false
	set_process(false)


func _preload_textures() -> void:
	_textures.clear()
	for round_number in range(1, 4):
		var path := "%s/%s" % [GFX_DIR, GFX_PATTERN % round_number]
		var tex := _load_texture(path)
		if tex != null:
			_textures.append(tex)
		else:
			push_warning("RoundStartSplashFx: missing %s" % path)


func play_for_round(round_number: int) -> void:
	var index := clampi(round_number, 1, 3) - 1
	if index >= _textures.size() or _textures[index] == null:
		var path := "%s/%s" % [GFX_DIR, GFX_PATTERN % clampi(round_number, 1, 3)]
		var tex := _load_texture(path)
		if tex == null:
			push_warning("RoundStartSplashFx: missing %s" % path)
			return
		while _textures.size() <= index:
			_textures.append(null)
		_textures[index] = tex
	var tex := _textures[index]
	_layout(tex)
	visible = true
	_active = true
	_elapsed = 0.0
	_total_duration = hold_duration + intro_duration + outro_duration
	_pivot.scale = Vector2(0.82, 0.82)
	_pivot.modulate.a = 0.0
	set_process(true)


func stop_splash() -> void:
	_active = false
	_elapsed = 0.0
	visible = false
	set_process(false)
	if _pivot:
		_pivot.modulate.a = 1.0
		_pivot.scale = Vector2.ONE


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= _total_duration:
		stop_splash()
		return
	if _elapsed < intro_duration:
		var t := _elapsed / maxf(intro_duration, 0.001)
		t = 1.0 - pow(1.0 - t, 3.0)
		_pivot.modulate.a = t
		var scale_val := lerpf(0.82, 1.0, t)
		_pivot.scale = Vector2(scale_val, scale_val)
	elif _elapsed < intro_duration + hold_duration:
		_pivot.modulate.a = 1.0
		_pivot.scale = Vector2.ONE
	else:
		var out_t := (_elapsed - intro_duration - hold_duration) / maxf(outro_duration, 0.001)
		_pivot.modulate.a = 1.0 - out_t
		_pivot.scale = Vector2.ONE * lerpf(1.0, 1.06, out_t)


func _layout(tex: Texture2D) -> void:
	_texture.texture = tex
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0:
		return
	var scale_factor := display_width / tex_size.x
	var display_size := tex_size * scale_factor
	custom_minimum_size = display_size
	size = display_size
	_pivot.custom_minimum_size = display_size
	_pivot.size = display_size
	_texture.custom_minimum_size = display_size
	_texture.size = display_size
	_pivot.pivot_offset = display_size * 0.5


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
	var image := Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
	return null
