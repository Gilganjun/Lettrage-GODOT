class_name LetterReboundEffect
extends Node2D

## Shield-only alternate VFX — letter rebounds, spins, sometimes grows, then fades out.

const FLY_DURATION := 0.52
const FADE_DURATION := 0.16


static func spawn(
	parent: Node,
	global_pos: Vector2,
	texture: Texture2D,
	tint_color: Color,
	sprite_scale: Vector2,
	knockback_dir: Vector2,
) -> LetterReboundEffect:
	if parent == null or texture == null:
		return null
	var effect := LetterReboundEffect.new()
	effect.z_index = 80
	parent.add_child(effect)
	effect.global_position = global_pos
	effect.start(texture, tint_color, sprite_scale, knockback_dir)
	return effect


func start(texture: Texture2D, tint_color: Color, sprite_scale: Vector2, knockback_dir: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = sprite_scale
	LetterTint.apply(sprite, tint_color)
	add_child(sprite)

	var dir := knockback_dir
	if dir.length_squared() < 4.0:
		dir = Vector2(randf_range(-1.0, 1.0), randf_range(-0.65, -0.15))
	else:
		dir = dir.normalized()
		dir.y = clampf(dir.y + randf_range(-0.25, 0.05), -0.9, 0.35)

	var speed := randf_range(300.0, 540.0)
	var travel := dir * speed * FLY_DURATION
	var rot_speed := randf_range(8.0, 16.0) * (1.0 if randf() > 0.5 else -1.0)
	var grow_toward_camera := randf() < 0.55
	var scale_mult := randf_range(1.4, 2.0) if grow_toward_camera else randf_range(0.95, 1.2)
	var peak_scale := scale * scale_mult

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", global_position + travel, FLY_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", rot_speed * FLY_DURATION, FLY_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", peak_scale, FLY_DURATION * 0.72)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, FADE_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", peak_scale * 0.65, FADE_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain()
	tween.tween_callback(queue_free)
