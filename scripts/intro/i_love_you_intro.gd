extends Node2D

## Standalone conversion of the I_Love_You cinematic intro from GAME25.json.
## Source layout: I_Love_You (baby / mother lab sequence + opening letter rain).

const MANIFEST_PATH := "res://resources/intro/i_love_you_intro_manifest.json"
const IntroCinematicSprite := preload("res://scripts/intro/intro_cinematic_sprite.gd")
const IntroViewport := preload("res://scripts/intro/intro_viewport.gd")

const BACKDROP_ROW := {
	"name": "BG1",
	"layer": "Base",
	"x": -136.0,
	"y": -214.0,
	"width": 2664.0,
	"height": 1024.0,
	"angle": 0.0,
	"z_order": -1,
	"texture": "res://assets/environment/out_18.jpg",
	"origin_x": 0.0,
	"origin_y": 0.0,
}

const LAYER_ORDER := [
	"Base",
	"BlackOverlay",
	"LabHall",
	"BabyScene2",
	"Doorway",
	"WomanBack",
	"BabyScene",
	"WomanFront",
	"CineOverlay",
	"WhiteFlash",
]

@export var auto_play := true
@export var time_scale := 0.8

@onready var camera_2d: Camera2D = $Camera2D
@onready var layer_root: Node2D = $LayerRoot
@onready var letter_root: Node2D = $LetterRoot
@onready var audio_main: AudioStreamPlayer = $Audio/MainMusic
@onready var audio_secondary: AudioStreamPlayer = $Audio/SecondaryMusic
@onready var audio_thunder: AudioStreamPlayer = $Audio/Thunder
@onready var audio_wind: AudioStreamPlayer = $Audio/Wind
@onready var audio_baby_cry: AudioStreamPlayer = $Audio/BabyCry
@onready var audio_door: AudioStreamPlayer = $Audio/DoorHiss

var _manifest: Dictionary = {}
var _layer_nodes: Dictionary = {}
var _sprites: Dictionary = {}
var _timer := 0.0
var _once: Dictionary = {}
var _finished := false

var baby_zoom := 11.0
var baby_zoom2 := 1.0
var doorway_zoom := 3.0
var woman_zoom := 3.0
var lab_crib_brightness := 1.0
var cam_switch := 0
var end_letters := 0
var _camera_angle_deg := 0.0
var _end_letters_timer := 0.0
var _white_flash_alpha := 0.0
var _iloveu_cam_zoom := 1.0


func _ready() -> void:
	_manifest = _load_manifest()
	_apply_manifest_defaults()
	_build_layers()
	_apply_initial_visibility()
	_wire_audio()
	camera_2d.make_current()
	if auto_play:
		_start_intro()


func _load_manifest() -> Dictionary:
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	if text.is_empty():
		push_error("Missing intro manifest: %s" % MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _apply_manifest_defaults() -> void:
	var vars: Dictionary = _manifest.get("variables", {})
	baby_zoom = float(vars.get("BabyZoom", baby_zoom))
	baby_zoom2 = float(vars.get("BabyZoom2", baby_zoom2))
	doorway_zoom = float(vars.get("DoorwayZoom", doorway_zoom))
	woman_zoom = float(vars.get("WomanZoom", woman_zoom))
	lab_crib_brightness = float(vars.get("LabCribBrightness", lab_crib_brightness))
	cam_switch = int(vars.get("CamSwitch", cam_switch))


func _build_layers() -> void:
	for layer_name in LAYER_ORDER:
		var layer := Node2D.new()
		layer.name = layer_name if not layer_name.is_empty() else "Base"
		layer_root.add_child(layer)
		_layer_nodes[layer_name] = layer

	var backdrop_sprite := IntroCinematicSprite.new()
	backdrop_sprite.name = "BG1"
	backdrop_sprite.setup_from_manifest(BACKDROP_ROW)
	_layer_nodes["Base"].add_child(backdrop_sprite)
	_sprites["Base::BG1"] = backdrop_sprite

	var anims: Dictionary = _manifest.get("animations", {})
	for row in _manifest.get("instances", []):
		var layer_name: String = row.get("layer", "")
		if not _layer_nodes.has(layer_name):
			continue
		var inst_name: String = row.get("name", "Sprite")
		var node := IntroCinematicSprite.new()
		node.name = inst_name
		var anim_key := ""
		if inst_name == "Baby":
			anim_key = ""
		var frames: PackedStringArray
		if anims.has(anim_key):
			for path in anims[anim_key]:
				frames.append(str(path))
		node.setup_from_manifest(row, frames)
		_layer_nodes[layer_name].add_child(node)
		_sprites[_sprite_key(layer_name, inst_name)] = node


func _sprite_key(layer_name: String, inst_name: String) -> String:
	return "%s::%s" % [layer_name, inst_name]


func _apply_initial_visibility() -> void:
	for layer_name in _layer_nodes.keys():
		_set_layer_visible(layer_name, false)
	_set_layer_visible("Base", true)
	_set_layer_visible("CineOverlay", true)
	_set_cine_overlay_opacity(IntroViewport.gd_opacity_to_alpha(100.0))
	_set_white_flash_alpha(0.0)


func _wire_audio() -> void:
	var audio: Dictionary = _manifest.get("audio", {})
	_set_stream(audio_main, str(audio.get("music_main", "")))
	_set_stream(audio_secondary, str(audio.get("music_secondary", "")))
	_set_stream(audio_thunder, str(audio.get("ambient_thunder", "")))
	_set_stream(audio_wind, str(audio.get("ambient_wind", "")))
	_set_stream(audio_baby_cry, str(audio.get("baby_cry_1", "")))
	_set_stream(audio_door, str(audio.get("door_hiss", "")))


func _set_stream(player: AudioStreamPlayer, path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	player.stream = load(path)


func _start_intro() -> void:
	_timer = 0.0
	_once.clear()
	_finished = false
	end_letters = 0
	_end_letters_timer = 0.0
	_camera_angle_deg = 0.0
	_iloveu_cam_zoom = 1.0
	baby_zoom = float(_manifest.get("variables", {}).get("BabyZoom", 11.0))
	baby_zoom2 = float(_manifest.get("variables", {}).get("BabyZoom2", 1.0))
	doorway_zoom = float(_manifest.get("variables", {}).get("DoorwayZoom", 3.0))
	woman_zoom = float(_manifest.get("variables", {}).get("WomanZoom", 3.0))
	lab_crib_brightness = float(_manifest.get("variables", {}).get("LabCribBrightness", 1.0))
	cam_switch = 0
	_apply_initial_visibility()
	if audio_main.stream:
		audio_main.play()
	if audio_secondary.stream:
		audio_secondary.play()
	if audio_thunder.stream:
		audio_thunder.volume_db = -25.0
		audio_thunder.play()
	if audio_wind.stream:
		audio_wind.volume_db = -15.0
		audio_wind.play()


func _process(delta: float) -> void:
	if _finished:
		return
	var dt := delta * time_scale
	_timer += dt
	_update_continuous(dt)
	_run_timeline()
	_update_camera()


func _update_continuous(dt: float) -> void:
	if _timer < 12.0 and _is_layer_visible("Base") and not _is_layer_visible("BabyScene"):
		_iloveu_cam_zoom += 0.0005 * (dt / (1.0 / 60.0))

	if _timer >= 12.0 and _timer <= 16.0 and _is_layer_visible("BabyScene") and cam_switch == 0:
		baby_zoom = maxf(baby_zoom - 0.01 * (dt / (1.0 / 60.0)), 1.6)
		lab_crib_brightness = maxf(lab_crib_brightness - 0.0035 * (dt / (1.0 / 60.0)), 0.4)

	if _timer >= 21.0 and _timer <= 24.0 and _is_layer_visible("BabyScene2"):
		baby_zoom2 = maxf(baby_zoom2 - 0.002 * (dt / (1.0 / 60.0)), 0.5)
		woman_zoom = maxf(woman_zoom - 0.004 * (dt / (1.0 / 60.0)), 1.0)
		doorway_zoom = maxf(doorway_zoom - 0.002 * (dt / (1.0 / 60.0)), 1.0)
		lab_crib_brightness = maxf(lab_crib_brightness - 0.1 * dt, 0.2)

	if end_letters == 1:
		_end_letters_timer += dt
		if _end_letters_timer > 3.0:
			_camera_angle_deg += 0.5 * (dt / (1.0 / 60.0))

	if _timer >= 11.5 and _timer <= 12.0:
		_white_flash_alpha = clampf(_white_flash_alpha + 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 12.0 and _timer <= 14.0:
		_white_flash_alpha = clampf(_white_flash_alpha - 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 15.5 and _timer <= 16.0:
		_white_flash_alpha = clampf(_white_flash_alpha + 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 16.5 and _timer <= 18.0:
		_white_flash_alpha = clampf(_white_flash_alpha - 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 20.5 and _timer <= 21.0:
		_white_flash_alpha = clampf(_white_flash_alpha + 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 21.0 and _timer <= 23.0:
		_white_flash_alpha = clampf(_white_flash_alpha - 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 23.5 and _timer <= 24.0:
		_white_flash_alpha = clampf(_white_flash_alpha + 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 24.0 and _timer <= 26.0:
		_white_flash_alpha = clampf(_white_flash_alpha - 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 28.5 and _timer <= 29.0:
		_white_flash_alpha = clampf(_white_flash_alpha + 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 29.0 and _timer <= 31.0:
		_white_flash_alpha = clampf(_white_flash_alpha - 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 34.5 and _timer <= 35.0:
		_white_flash_alpha = clampf(_white_flash_alpha + 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 35.0 and _timer <= 37.0:
		_white_flash_alpha = clampf(_white_flash_alpha - 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 38.5 and _timer <= 39.0:
		_white_flash_alpha = clampf(_white_flash_alpha + 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 39.0 and _timer <= 41.0:
		_white_flash_alpha = clampf(_white_flash_alpha - 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 42.5 and _timer <= 43.0:
		_white_flash_alpha = clampf(_white_flash_alpha + 10.0 * dt, 0.0, 255.0) / 255.0
	elif _timer >= 43.0 and _timer <= 45.0:
		_white_flash_alpha = clampf(_white_flash_alpha - 10.0 * dt, 0.0, 255.0) / 255.0

	_set_white_flash_alpha(_white_flash_alpha)
	_apply_crib_brightness()


func _apply_crib_brightness() -> void:
	for key in ["BabyScene::LabCribBG", "BabyScene2::LabCribBG2"]:
		var node: IntroCinematicSprite = _sprites.get(key)
		if node:
			node.set_brightness(lab_crib_brightness)


func _run_timeline() -> void:
	_fire_once("letters_1", _timer >= 1.0, _spawn_letter.bind(9))
	_fire_once("letters_3", _timer >= 3.0, _spawn_letter.bind(12))
	_fire_once("letters_4", _timer >= 4.0, _spawn_letter.bind(15))

	_fire_once("white_flash_on_11", _timer >= 11.0, func() -> void:
		_set_layer_visible("WhiteFlash", true)
	)

	_fire_once("baby_scene_12", _timer >= 12.0, func() -> void:
		_set_layer_visible("Base", false)
		_set_layer_visible("CineOverlay", false)
		_set_layer_visible("BabyScene", true)
		lab_crib_brightness -= 0.1
		_play_baby_cry(audio_baby_cry)
		_start_baby_animation()
	)

	_fire_once("baby_scene_hide_16", _timer >= 16.0, func() -> void:
		_set_layer_visible("BabyScene", false)
		_set_layer_visible("Base", true)
		_set_layer_visible("CineOverlay", true)
	)

	_fire_once("cam_switch_17", _timer >= 17.0, func() -> void:
		cam_switch = 2
		doorway_zoom = 2.0
		woman_zoom = 2.5
	)

	_fire_once("lab_reveal_21", _timer >= 21.0, func() -> void:
		_set_layer_visible("Base", false)
		_set_layer_visible("CineOverlay", false)
		_set_layer_visible("BabyScene2", true)
		_set_layer_visible("Doorway", true)
		_set_layer_visible("WomanBack", true)
	)

	_fire_once("baby_cry_2_24", _timer >= 24.0 and _timer <= 25.0, func() -> void:
		_play_baby_cry(audio_baby_cry, "res://assets/intro/audio/BabyCry2.mp3")
		_set_layer_visible("BabyScene", true)
		_set_layer_visible("BabyScene2", false)
	)

	_fire_once("lab_full_29", _timer >= 29.0, func() -> void:
		_set_layer_visible("CineOverlay", false)
		_set_layer_visible("BabyScene2", true)
		_set_layer_visible("Doorway", true)
		_set_layer_visible("WomanBack", true)
		_set_layer_visible("LabHall", true)
		cam_switch = 1
	)

	_fire_once("door_hiss_31", _timer >= 31.0, func() -> void:
		if audio_door.stream:
			audio_door.play()
	)

	_fire_once("woman_front_39", _timer >= 39.0, func() -> void:
		for key in ["BabyScene", "BabyScene2", "Doorway", "WomanBack", "LabHall", "CineOverlay"]:
			_set_layer_visible(key, false)
		_set_layer_visible("WomanFront", true)
		_start_woman_face_animation()
	)

	_fire_once("end_letters_42", _timer >= 42.0, func() -> void:
		end_letters = 1
		_end_letters_timer = 0.0
	)

	_fire_once("intro_complete_45", _timer >= 45.0, func() -> void:
		_finished = true
		_set_layer_visible("WomanFront", false)
		_set_layer_visible("CineOverlay", true)
	)


func _fire_once(id: String, condition: bool, action: Callable) -> void:
	if not condition or _once.has(id):
		return
	_once[id] = true
	action.call()


func _spawn_letter(letter_index: int) -> void:
	var tex_path := "res://assets/intro/images/Alphabet2/%s2.png" % _letter_char(letter_index)
	if not ResourceLoader.exists(tex_path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(tex_path)
	sprite.position = Vector2(
		randf_range(IntroViewport.CENTER.x - 120.0, IntroViewport.CENTER.x + 120.0),
		-80.0,
	)
	sprite.scale = Vector2(randf_range(0.45, 0.85), randf_range(0.45, 0.85))
	sprite.modulate = Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0), 0.95)
	letter_root.add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "position:y", IntroViewport.SIZE.y + 80.0, randf_range(2.5, 4.0)).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sprite, "rotation", randf_range(-0.5, 0.5), randf_range(2.5, 4.0))
	tween.finished.connect(sprite.queue_free)


func _start_baby_animation() -> void:
	var row: Dictionary = {}
	for inst in _manifest.get("instances", []):
		if inst.get("name") == "Baby":
			row = inst
			break
	if row.is_empty():
		return
	var frames: PackedStringArray
	for path in _manifest.get("animations", {}).get("Baby_BabyAnim", []):
		var full := str(path)
		if not full.begins_with("res://"):
			full = "res://assets/intro/%s" % full
		frames.append(full)
	var baby: IntroCinematicSprite = _sprites.get("BabyScene::Baby")
	if baby:
		baby.setup_from_manifest(row, frames)
		baby.play_default_animation()


func _start_woman_face_animation() -> void:
	var row: Dictionary = {}
	for inst in _manifest.get("instances", []):
		if inst.get("name") == "WomanFront":
			row = inst
			break
	if row.is_empty():
		return
	var frames: PackedStringArray
	for path in _manifest.get("animations", {}).get("WomanFront_FaceMove", []):
		var full := str(path)
		if not full.begins_with("res://"):
			full = "res://assets/intro/%s" % full
		frames.append(full)
	var woman: IntroCinematicSprite = _sprites.get("WomanFront::WomanFront")
	if woman:
		woman.setup_from_manifest(row, frames)
		woman.play_default_animation()


func _letter_char(index: int) -> String:
	const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	if index < 1 or index > 26:
		return "A"
	return LETTERS[index - 1]


func _play_baby_cry(player: AudioStreamPlayer, path: String = "") -> void:
	if not path.is_empty() and ResourceLoader.exists(path):
		player.stream = load(path)
	if player.stream:
		player.play()


func _update_camera() -> void:
	var focus := IntroViewport.CENTER
	var zoom_factor := 1.0

	if _is_layer_visible("BabyScene"):
		focus = _sprite_focus("BabyScene::Baby")
		zoom_factor = baby_zoom
	elif _is_layer_visible("BabyScene2"):
		focus = _sprite_focus("BabyScene2::Baby2")
		zoom_factor = baby_zoom2
	elif _is_layer_visible("WomanFront"):
		focus = _sprite_focus("WomanFront::WomanFront")
		zoom_factor = woman_zoom
	elif _is_layer_visible("WomanBack"):
		focus = _sprite_focus("WomanBack::WomanBack")
		zoom_factor = woman_zoom
	elif _is_layer_visible("Doorway"):
		focus = _sprite_focus("Doorway::LabDoorway")
		zoom_factor = doorway_zoom
	elif _is_layer_visible("LabHall"):
		focus = _sprite_focus("LabHall::LabHall")
		zoom_factor = float(_manifest.get("variables", {}).get("LabHallZoom", 1.0))
	else:
		zoom_factor = _iloveu_cam_zoom

	camera_2d.global_position = focus
	camera_2d.zoom = IntroViewport.gd_zoom_to_godot(zoom_factor)
	camera_2d.rotation = deg_to_rad(_camera_angle_deg)


func _sprite_focus(key: String) -> Vector2:
	var node: IntroCinematicSprite = _sprites.get(key)
	if node:
		return node.get_focus_position()
	return Vector2(480, 270)


func _set_layer_visible(layer_name: String, visible: bool) -> void:
	var layer: Node2D = _layer_nodes.get(layer_name)
	if layer:
		layer.visible = visible


func _is_layer_visible(layer_name: String) -> bool:
	var layer: Node2D = _layer_nodes.get(layer_name)
	return layer != null and layer.visible


func _set_cine_overlay_opacity(alpha: float) -> void:
	var node: IntroCinematicSprite = _sprites.get("CineOverlay::CineOverlay")
	if node:
		node.set_opacity_alpha(alpha)


func _set_white_flash_alpha(alpha: float) -> void:
	_white_flash_alpha = alpha
	var node: IntroCinematicSprite = _sprites.get("WhiteFlash::WhiteFlash")
	if node:
		node.set_opacity_alpha(alpha)
	_set_layer_visible("WhiteFlash", alpha > 0.01)
