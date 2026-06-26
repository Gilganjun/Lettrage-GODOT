class_name ShieldVisual
extends Node2D

## GDevelop-style shield — FaceShield + Glow, scaled to collision body bounds.

const PATH_GLOW := "res://assets/shield/Glow.png"
const PATH_FACE_A := "res://assets/shield/faceshield.png"
const PATH_FACE_B := "res://assets/shield/faceshield2.png"
const PATH_FACE_ENEMY := "res://assets/shield/faceshield_red.png"

## Tight fit to collision rect (F3 debug box); keep character readable underneath.
const BODY_FIT := 0.94
const ENEMY_BODY_FIT := 0.94
const FACE_ALPHA := 0.28
const FACE_ALPHA_PULSE := 0.10
const GLOW_ALPHA := 0.10
const GLOW_ALPHA_PULSE := 0.06
const ENEMY_FACE_ALPHA := 0.12
const ENEMY_FACE_ALPHA_PULSE := 0.04
const ENEMY_GLOW_ALPHA := 0.04
const ENEMY_GLOW_ALPHA_PULSE := 0.02
const ENEMY_FIZZ_ALPHA := 0.18
const GLOW_SCALE_MUL := 0.82

const PLAYER_TINT := Color(0.72, 0.9, 1.0, 1.0)
const ENEMY_TINT := Color(1.0, 0.55, 0.28, 1.0)

var _size := Vector2(40, 80)
var _is_enemy := false
var _glow: Sprite2D
var _face: AnimatedSprite2D
var _fizz: CPUParticles2D
var _activate_burst: CPUParticles2D
var _impact_burst: CPUParticles2D
var _pulse_time := 0.0
var _add_material: CanvasItemMaterial


func _ready() -> void:
	z_index = 50
	_add_material = CanvasItemMaterial.new()
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_build_visuals()


func configure(size: Vector2, is_enemy: bool = false) -> void:
	_size = size
	_is_enemy = is_enemy
	if is_instance_valid(_face):
		_apply_layout()


func set_active(on: bool) -> void:
	if _face:
		if on:
			if _face.sprite_frames.has_animation("shield"):
				_face.play("shield")
		else:
			_face.stop()
	if _fizz:
		_fizz.emitting = on
	if on:
		_pulse_time = 0.0
		play_activate_burst()


func play_activate_burst() -> void:
	_emit_one_shot(_activate_burst)


func play_impact_burst(local_pos: Vector2) -> void:
	if _impact_burst == null:
		return
	_impact_burst.position = local_pos
	_emit_one_shot(_impact_burst)


func _build_visuals() -> void:
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.centered = true
	_glow.texture = _load_texture(PATH_GLOW)
	_glow.material = _add_material
	_glow.z_index = -1

	_face = AnimatedSprite2D.new()
	_face.name = "FaceShield"
	_face.centered = true
	_face.z_index = 0

	_fizz = _make_fizz_particles("Fizz")
	_activate_burst = _make_burst_particles("ActivateBurst", 14)
	_impact_burst = _make_burst_particles("ImpactBurst", 10)

	add_child(_glow)
	add_child(_face)
	add_child(_fizz)
	add_child(_activate_burst)
	add_child(_impact_burst)
	_apply_layout()


func _apply_layout() -> void:
	var tint := ENEMY_TINT if _is_enemy else PLAYER_TINT
	_face.sprite_frames = _build_face_frames()
	var face_tex := _face.sprite_frames.get_frame_texture("shield", 0)
	var fit_mul := ENEMY_BODY_FIT if _is_enemy else BODY_FIT
	var body_fit := _size * fit_mul
	_face.scale = _fit_texture_to_rect(face_tex, body_fit, _is_enemy)
	var face_c := tint
	face_c.a = _face_alpha_base()
	_face.modulate = face_c

	var glow_fit := body_fit * GLOW_SCALE_MUL
	_glow.scale = _fit_texture_to_rect(_glow.texture, glow_fit, _is_enemy)
	var glow_c := tint
	glow_c.a = _glow_alpha_base()
	_glow.modulate = glow_c

	var half := body_fit * 0.5
	_fizz.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_fizz.emission_points = _rect_edge_points(body_fit, 14)
	_fizz.color = tint
	_fizz.color.a = ENEMY_FIZZ_ALPHA if _is_enemy else 0.38

	var burst_half := half * 0.72
	for burst in [_activate_burst, _impact_burst]:
		burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		burst.emission_rect_extents = burst_half
		if _is_enemy:
			burst.initial_velocity_min = 8.0
			burst.initial_velocity_max = 22.0
			burst.scale_amount_min = 0.10
			burst.scale_amount_max = 0.20
		else:
			burst.initial_velocity_min = 12.0
			burst.initial_velocity_max = 40.0
			burst.scale_amount_min = 0.14
			burst.scale_amount_max = 0.32
	if _fizz:
		if _is_enemy:
			_fizz.initial_velocity_min = 6.0
			_fizz.initial_velocity_max = 18.0
			_fizz.scale_amount_min = 0.08
			_fizz.scale_amount_max = 0.18
		else:
			_fizz.initial_velocity_min = 8.0
			_fizz.initial_velocity_max = 28.0
			_fizz.scale_amount_min = 0.12
			_fizz.scale_amount_max = 0.28


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_pulse_time += delta
	var pulse := 0.5 + 0.5 * sin(_pulse_time * 3.2)
	var tint := ENEMY_TINT if _is_enemy else PLAYER_TINT
	if _glow:
		var glow_c := tint
		glow_c.a = _glow_alpha_base() + _glow_alpha_pulse() * pulse
		_glow.modulate = glow_c
	if _face:
		var face_c := tint
		face_c.a = _face_alpha_base() + _face_alpha_pulse() * pulse
		_face.modulate = face_c


func _face_alpha_base() -> float:
	return ENEMY_FACE_ALPHA if _is_enemy else FACE_ALPHA


func _face_alpha_pulse() -> float:
	return ENEMY_FACE_ALPHA_PULSE if _is_enemy else FACE_ALPHA_PULSE


func _glow_alpha_base() -> float:
	return ENEMY_GLOW_ALPHA if _is_enemy else GLOW_ALPHA


func _glow_alpha_pulse() -> float:
	return ENEMY_GLOW_ALPHA_PULSE if _is_enemy else GLOW_ALPHA_PULSE


func _build_face_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("shield")
	frames.set_animation_loop("shield", true)
	frames.set_animation_speed("shield", 12.5)
	var paths: PackedStringArray
	if _is_enemy:
		paths = PackedStringArray([PATH_FACE_ENEMY, PATH_FACE_B])
	else:
		paths = PackedStringArray([PATH_FACE_A, PATH_FACE_B])
	for path in paths:
		var tex := _load_texture(path)
		if tex:
			frames.add_frame("shield", tex)
	return frames


func _make_fizz_particles(particle_name: String) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = particle_name
	particles.texture = _load_texture(PATH_GLOW)
	particles.material = _add_material
	particles.emitting = false
	particles.amount = 22
	particles.lifetime = 0.55
	particles.lifetime_randomness = 0.35
	particles.preprocess = 0.35
	particles.explosiveness = 0.0
	particles.randomness = 0.45
	particles.direction = Vector2(0, -1)
	particles.spread = 18.0
	particles.gravity = Vector2(0, -90.0)
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 28.0
	particles.angular_velocity_min = -40.0
	particles.angular_velocity_max = 40.0
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.28
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	particles.local_coords = true
	particles.z_index = 1
	return particles


func _make_burst_particles(particle_name: String, amount: int) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = particle_name
	particles.texture = _load_texture(PATH_GLOW)
	particles.material = _add_material
	particles.emitting = false
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = 0.35
	particles.lifetime_randomness = 0.2
	particles.explosiveness = 0.9
	particles.randomness = 0.4
	particles.direction = Vector2(0, -1)
	particles.spread = 140.0
	particles.gravity = Vector2(0, -60.0)
	particles.initial_velocity_min = 12.0
	particles.initial_velocity_max = 40.0
	particles.scale_amount_min = 0.14
	particles.scale_amount_max = 0.32
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.local_coords = true
	particles.z_index = 2
	return particles


func _emit_one_shot(particles: CPUParticles2D) -> void:
	if particles == null:
		return
	particles.emitting = false
	particles.emitting = true


func _fit_texture_to_rect(tex: Texture2D, target: Vector2, uniform: bool = false) -> Vector2:
	if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0:
		return Vector2(0.2, 0.2)
	var sx := target.x / tex.get_width()
	var sy := target.y / tex.get_height()
	if uniform:
		var s := minf(sx, sy)
		return Vector2(s, s)
	return Vector2(sx, sy)


func _rect_edge_points(size: Vector2, segments_per_edge: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var n := maxi(segments_per_edge, 2)
	for i in n:
		var t := float(i) / float(n - 1)
		pts.append(Vector2(-hw + t * size.x, -hh))
	for i in range(1, n):
		var t := float(i) / float(n - 1)
		pts.append(Vector2(hw, -hh + t * size.y))
	for i in range(1, n):
		var t := float(i) / float(n - 1)
		pts.append(Vector2(hw - t * size.x, hh))
	for i in range(1, n - 1):
		var t := float(i) / float(n - 1)
		pts.append(Vector2(-hw, hh - t * size.y))
	return pts


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("ShieldVisual: missing texture %s" % path)
		return null
	return load(path) as Texture2D
