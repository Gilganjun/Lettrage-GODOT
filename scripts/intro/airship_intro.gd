extends Node2D

## Standalone conversion of Intro_1 (airship cinematic) from GAME25.json.

const MANIFEST_PATH := "res://resources/intro/airship_intro_manifest.json"
const IntroCinematicSprite := preload("res://scripts/intro/intro_cinematic_sprite.gd")
const IntroViewport := preload("res://scripts/intro/intro_viewport.gd")

const LAYER_ORDER := [
	"RedBGFlyBy",
	"Passenger1",
	"JetFlyByAlien",
	"Passenger2",
]

@export var auto_play := true

@onready var camera_2d: Camera2D = $Camera2D
@onready var layer_root: Node2D = $LayerRoot
@onready var audio_main: AudioStreamPlayer = $Audio/MainMusic
@onready var audio_convoy: AudioStreamPlayer = $Audio/ConvoySfx

var _manifest: Dictionary = {}
var _layer_nodes: Dictionary = {}
var _sprites: Dictionary = {}
var _timer := 0.0
var _once: Dictionary = {}
var _finished := false

var cam_zoom_alien := 1.5
var cam_zoom_alien2 := 3.0
var _jet: IntroCinematicSprite
var _jet_phase := 0
var _passengers1_base := Vector2.ZERO
var _sky_base_x := 0.0
var _sky_scroll := 0.0
var _black_alpha := 1.0
var _passenger_shake_timer := 0.0


func _ready() -> void:
	_manifest = _load_manifest()
	_apply_manifest_defaults()
	_build_layers()
	_apply_initial_state()
	_wire_audio()
	camera_2d.make_current()
	if auto_play:
		_start_intro()


func _load_manifest() -> Dictionary:
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	if text.is_empty():
		push_error("Missing airship intro manifest: %s" % MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _apply_manifest_defaults() -> void:
	var vars: Dictionary = _manifest.get("variables", {})
	cam_zoom_alien = float(vars.get("CamZoomAlien", cam_zoom_alien))
	if cam_zoom_alien <= 0.0:
		cam_zoom_alien = 1.5


func _build_layers() -> void:
	for layer_name in LAYER_ORDER:
		var layer := Node2D.new()
		layer.name = layer_name
		layer_root.add_child(layer)
		_layer_nodes[layer_name] = layer

	for row in _manifest.get("instances", []):
		var layer_name: String = row.get("layer", "")
		if not _layer_nodes.has(layer_name):
			continue
		var node := IntroCinematicSprite.new()
		node.name = str(row.get("id", row.get("name", "Sprite"))).replace("::", "_")
		node.setup_from_manifest(row)
		_layer_nodes[layer_name].add_child(node)
		_sprites[str(row.get("id"))] = node


func _apply_initial_state() -> void:
	_set_layer_visible("Passenger1", true)
	_set_layer_visible("Passenger2", false)
	_set_layer_visible("JetFlyByAlien", false)
	_set_layer_visible("RedBGFlyBy", false)

	_set_sprite_opacity_gd("Passenger2::Passenger2", 0)
	_set_sprite_opacity_gd("Passenger1::Sky", 125)
	_set_sprite_opacity_gd("Passenger2::BG2", 255)

	var passengers: IntroCinematicSprite = _sprites.get("Passenger1::Passengers1")
	if passengers:
		_passengers1_base = passengers.position
	var sky: IntroCinematicSprite = _sprites.get("Passenger1::Sky")
	if sky:
		_sky_base_x = sky.position.x

	var black: IntroCinematicSprite = _sprites.get("Passenger1::black")
	if black:
		black.z_index = 50
		black.set_opacity_alpha(1.0)


func _wire_audio() -> void:
	var audio: Dictionary = _manifest.get("audio", {})
	if ResourceLoader.exists(str(audio.get("music_main", ""))):
		audio_main.stream = load(str(audio.get("music_main")))
	if ResourceLoader.exists(str(audio.get("sfx_convoy", ""))):
		audio_convoy.stream = load(str(audio.get("sfx_convoy")))


func _start_intro() -> void:
	_timer = 0.0
	_once.clear()
	_finished = false
	cam_zoom_alien = 1.5
	cam_zoom_alien2 = 3.0
	_jet_phase = 0
	_black_alpha = 1.0
	_sky_scroll = 0.0
	_passenger_shake_timer = 0.0
	_apply_initial_state()
	_spawn_jet_phase_one()
	if audio_main.stream:
		audio_main.play()


func _process(delta: float) -> void:
	if _finished:
		return
	_timer += delta
	_update_continuous(delta)
	_run_timeline()
	_update_camera()


func _update_continuous(delta: float) -> void:
	var frame_scale := delta * 60.0

	var sky: IntroCinematicSprite = _sprites.get("Passenger1::Sky")
	if sky and _is_layer_visible("Passenger1"):
		_sky_scroll += 0.1 * frame_scale
		sky.position.x = _sky_base_x + _sky_scroll

	if _is_layer_visible("Passenger1"):
		_passenger_shake_timer += delta
		if _passenger_shake_timer >= 1.0 / 60.0:
			_passenger_shake_timer = 0.0
			var passengers: IntroCinematicSprite = _sprites.get("Passenger1::Passengers1")
			if passengers:
				passengers.position = _passengers1_base + Vector2(
					randf_range(-5.0, 5.0),
					randf_range(-5.0, 5.0),
				)

	if _timer >= 5.0:
		_black_alpha = maxf(_black_alpha - (0.6 / 255.0) * frame_scale, 0.0)
		var black: IntroCinematicSprite = _sprites.get("Passenger1::black")
		if black:
			black.set_opacity_alpha(_black_alpha)

	if _jet and _jet_phase == 1 and _timer >= 10.0:
		_jet.position.x -= 2.0 * frame_scale
		if cam_zoom_alien >= 1.2:
			cam_zoom_alien = maxf(cam_zoom_alien - 0.001 * frame_scale, 1.2)

	if _jet and _jet_phase == 2 and _timer >= 27.2:
		_jet.position.x -= 0.01 * frame_scale
		_jet.position.y += 0.5 * frame_scale
		cam_zoom_alien2 = maxf(cam_zoom_alien2 - 0.003 * frame_scale, 1.0)

	if _timer >= 19.0 and _is_layer_visible("Passenger2"):
		var bg2: IntroCinematicSprite = _sprites.get("Passenger2::BG2")
		if bg2:
			bg2.position.x += 0.2 * frame_scale
		_passenger_shake_timer += delta
		if _passenger_shake_timer >= 1.0 / 60.0:
			_passenger_shake_timer = 0.0
			var pass2: IntroCinematicSprite = _sprites.get("Passenger2::Passenger2")
			if pass2:
				pass2.position += Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))


func _run_timeline() -> void:
	_fire_once("convoy_sfx", _timer >= 5.0, func() -> void:
		if audio_convoy.stream:
			audio_convoy.volume_db = -6.0
			audio_convoy.play()
	)

	_fire_once("show_jet_layer", _timer >= 12.5, func() -> void:
		_set_layer_visible("Passenger1", false)
		_set_layer_visible("JetFlyByAlien", true)
	)

	_fire_once("show_passenger2", _timer >= 20.0, func() -> void:
		_set_layer_visible("Passenger2", true)
		_set_layer_visible("JetFlyByAlien", false)
		_set_layer_visible("Passenger1", false)
		_set_sprite_opacity_gd("Passenger2::Passenger2", 255)
		_set_sprite_opacity_gd("Passenger2::BG2", 255)
		var pass2: IntroCinematicSprite = _sprites.get("Passenger2::Passenger2")
		if pass2:
			pass2.position += Vector2(randf_range(-5, 5), randf_range(-5, 5))
	)

	_fire_once("red_phase", _timer >= 27.0, func() -> void:
		if _jet:
			_jet.queue_free()
			_jet = null
		_set_layer_visible("Passenger2", false)
		_set_layer_visible("RedBGFlyBy", true)
		var red2: IntroCinematicSprite = _sprites.get("RedBGFlyBy::RedBGFlyBy2")
		if red2:
			red2.set_flip_x(true)
		_spawn_jet_phase_two()
	)

	_fire_once("intro_complete", _timer >= 40.0, func() -> void:
		_finished = true
	)


func _spawn_jet_phase_one() -> void:
	_jet = _create_jet(2, 0.25, 10.0, 9)
	var markers: Dictionary = _manifest.get("jet", {}).get("start_markers", {})
	var start: Dictionary = markers.get("jet_start_1", {"x": 899, "y": 113})
	_jet.position = Vector2(float(start.get("x", 899)), float(start.get("y", 113)))
	_layer_nodes["JetFlyByAlien"].add_child(_jet)
	_jet_phase = 1
	cam_zoom_alien = 1.5


func _spawn_jet_phase_two() -> void:
	_jet = _create_jet(0, 0.3, 12.0, 12)
	var markers: Dictionary = _manifest.get("jet", {}).get("start_markers", {})
	var start: Dictionary = markers.get("jet_start_2", {"x": 825, "y": 26})
	_jet.position = Vector2(float(start.get("x", 825)), float(start.get("y", 26)))
	_jet.rotation = deg_to_rad(12.0)
	_layer_nodes["RedBGFlyBy"].add_child(_jet)
	_jet_phase = 2
	cam_zoom_alien2 = 3.0


func _create_jet(anim_index: int, scale_factor: float, angle_deg: float, z_order: int) -> IntroCinematicSprite:
	var jet_cfg: Dictionary = _manifest.get("jet", {})
	var textures: Array = jet_cfg.get("animation_textures", [])
	var origins: Array = jet_cfg.get("origins", [])
	var tex_path := str(textures[anim_index]) if anim_index < textures.size() else ""
	var origin := {"x": 0.0, "y": 0.0}
	if anim_index < origins.size():
		origin = origins[anim_index]

	var row := {
		"name": "Jet",
		"layer": "",
		"x": 0,
		"y": 0,
		"width": 206,
		"height": 155,
		"angle": angle_deg,
		"z_order": z_order,
		"texture": tex_path,
		"origin_x": float(origin.get("x", 0.0)),
		"origin_y": float(origin.get("y", 0.0)),
	}
	var jet := IntroCinematicSprite.new()
	jet.name = "Jet"
	jet.setup_from_manifest(row)
	jet.set_display_scale(scale_factor)
	jet.z_index = z_order
	jet.rotation = deg_to_rad(angle_deg)
	return jet


func _update_camera() -> void:
	var zoom_factor := 1.0
	if _is_layer_visible("RedBGFlyBy"):
		zoom_factor = cam_zoom_alien2
	elif _is_layer_visible("JetFlyByAlien"):
		zoom_factor = cam_zoom_alien

	camera_2d.global_position = IntroViewport.CENTER
	camera_2d.zoom = IntroViewport.gd_zoom_to_godot(zoom_factor)


func _fire_once(id: String, condition: bool, action: Callable) -> void:
	if not condition or _once.has(id):
		return
	_once[id] = true
	action.call()


func _set_layer_visible(layer_name: String, show_layer: bool) -> void:
	var layer: Node2D = _layer_nodes.get(layer_name)
	if layer:
		layer.visible = show_layer


func _is_layer_visible(layer_name: String) -> bool:
	var layer: Node2D = _layer_nodes.get(layer_name)
	return layer != null and layer.visible


func _set_sprite_opacity_gd(sprite_id: String, gd_value: float) -> void:
	var node: IntroCinematicSprite = _sprites.get(sprite_id)
	if node:
		node.set_opacity_gd(gd_value)
