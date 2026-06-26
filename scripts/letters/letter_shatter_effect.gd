class_name LetterShatterEffect
extends Node2D

## Letter destroy VFX using the live alphabet texture — independent of shield FX.

enum Style {
	GRID_SHATTER,
	PIXEL_BURST,
	SOFT_DISSOLVE,
}

const DEFAULT_STYLE := Style.GRID_SHATTER
const SHARD_LIFETIME := 0.42

## Active style for gameplay; test scene can override via keys 1–3.
static var active_style: Style = DEFAULT_STYLE

var _elapsed := 0.0
var _lifetime := SHARD_LIFETIME
var _shards: Array[Dictionary] = []
var _style := DEFAULT_STYLE


static func spawn(
	parent: Node,
	global_pos: Vector2,
	texture: Texture2D,
	tint_color: Color,
	sprite_scale: Vector2,
	style: Style = active_style,
) -> LetterShatterEffect:
	if parent == null or texture == null:
		return null
	var effect := LetterShatterEffect.new()
	parent.add_child(effect)
	effect.global_position = global_pos
	effect.start(texture, tint_color, sprite_scale, style)
	return effect


func start(texture: Texture2D, tint_color: Color, sprite_scale: Vector2, style: Style) -> void:
	_style = style
	_lifetime = SHARD_LIFETIME
	match style:
		Style.GRID_SHATTER:
			_lifetime = SHARD_LIFETIME
			_build_grid_shatter(texture, tint_color, sprite_scale, 4, 4)
		Style.PIXEL_BURST:
			_lifetime = 0.55
			_build_pixel_burst(texture, tint_color, sprite_scale)
		Style.SOFT_DISSOLVE:
			_lifetime = 0.35
			_build_soft_dissolve(texture, tint_color, sprite_scale)
	if _shards.is_empty() and get_child_count() == 0:
		queue_free()
		return
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime + 0.05:
		queue_free()
		return
	if _shards.is_empty():
		return
	var t := clampf(_elapsed / _lifetime, 0.0, 1.0)
	var fade := 1.0 - t
	for data in _shards:
		var sprite: Sprite2D = data["sprite"]
		if not is_instance_valid(sprite):
			continue
		var start_pos: Vector2 = data["start_pos"]
		var velocity: Vector2 = data["velocity"]
		var start_rot: float = data["start_rot"]
		var rot_speed: float = data["rot_speed"]
		var start_mod: Color = data["start_modulate"]
		sprite.position = start_pos + velocity * _elapsed
		sprite.rotation = start_rot + rot_speed * _elapsed
		var c := start_mod
		c.a = start_mod.a * fade
		sprite.modulate = Color(1.0, 1.0, 1.0, c.a)
		var shrink := lerpf(1.0, 0.55, t)
		var base_scale: Vector2 = data["base_scale"]
		sprite.scale = base_scale * shrink


func _build_grid_shatter(
	texture: Texture2D,
	tint_color: Color,
	sprite_scale: Vector2,
	cols: int,
	rows: int,
) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var cell := Vector2(tex_size.x / float(cols), tex_size.y / float(rows))
	for row in rows:
		for col in cols:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * cell.x, row * cell.y, cell.x, cell.y)
			var shard := Sprite2D.new()
			shard.texture = atlas
			shard.centered = true
			var local := Vector2(
				(col - (cols - 1) * 0.5) * cell.x * sprite_scale.x,
				(row - (rows - 1) * 0.5) * cell.y * sprite_scale.y,
			)
			shard.position = local
			shard.scale = sprite_scale
			LetterTint.apply(shard, tint_color)
			add_child(shard)
			var dir := local.normalized() if local.length_squared() > 1.0 else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var speed := randf_range(95.0, 210.0) * maxf(scale.x, 0.35)
			_shards.append({
				"sprite": shard,
				"start_pos": local,
				"velocity": dir * speed + Vector2(randf_range(-20, 20), randf_range(-40, 10)),
				"start_rot": randf_range(-0.4, 0.4),
				"rot_speed": randf_range(-9.0, 9.0),
				"start_modulate": tint_color,
				"base_scale": sprite_scale,
			})


func _build_pixel_burst(texture: Texture2D, tint_color: Color, sprite_scale: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.texture = texture
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 1.0
	particles.amount = 28
	particles.lifetime = 0.48
	particles.lifetime_randomness = 0.35
	particles.randomness = 0.55
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 220.0)
	particles.initial_velocity_min = 70.0 * sprite_scale.x
	particles.initial_velocity_max = 170.0 * sprite_scale.x
	particles.angular_velocity_min = -280.0
	particles.angular_velocity_max = 280.0
	particles.scale_amount_min = sprite_scale.x * 0.18
	particles.scale_amount_max = sprite_scale.x * 0.42
	LetterTint.apply_particles(particles, tint_color)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 8.0 * sprite_scale.x
	particles.local_coords = true
	add_child(particles)


func _build_soft_dissolve(texture: Texture2D, tint_color: Color, sprite_scale: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = sprite_scale
	LetterTint.apply(sprite, tint_color)
	add_child(sprite)
	_shards.append({
		"sprite": sprite,
		"start_pos": Vector2.ZERO,
		"velocity": Vector2(randf_range(-12, 12), randf_range(-30, -8)),
		"start_rot": 0.0,
		"rot_speed": randf_range(-4.0, 4.0),
		"start_modulate": tint_color,
		"base_scale": sprite_scale * 1.08,
	})


static func style_name(style: Style) -> String:
	match style:
		Style.GRID_SHATTER:
			return "Grid shatter"
		Style.PIXEL_BURST:
			return "Pixel burst"
		Style.SOFT_DISSOLVE:
			return "Soft dissolve"
		_:
			return "Unknown"
