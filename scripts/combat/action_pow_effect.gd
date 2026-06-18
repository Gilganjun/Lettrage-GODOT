class_name ActionPowEffect
extends Node2D

## Placeholder POW burst for ACTION hits (enemy stun anim later).


static func spawn_at(world_parent: Node, global_pos: Vector2) -> void:
	if world_parent == null:
		return
	var fx := ActionPowEffect.new()
	world_parent.add_child(fx)
	fx.global_position = global_pos
	fx._play()


func _play() -> void:
	z_index = 120
	var label := Label.new()
	label.text = "POW!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.2, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.85, 0.15, 0.05, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(-36, -18)
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 28.0, 0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.45)
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.2)
	tween.chain().tween_callback(queue_free)
