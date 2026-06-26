class_name LetterClawCollectFx
extends Node2D

## Claw grab — extend rope, then glide letter into the HUD word row.

const ROPE_EXTEND_SEC := 0.18
const PAUSE_SEC := 0.08
const FLY_SEC := 0.42


static func play(
	letter: Letter,
	controller: WordGameController,
	combat_hud: Control,
	claw_origin: Vector2,
	on_finished: Callable,
) -> void:
	if letter == null or not is_instance_valid(letter) or letter.is_resolved():
		if on_finished.is_valid():
			on_finished.call(false)
		return
	if controller == null:
		if on_finished.is_valid():
			on_finished.call(false)
		return
	var sprite := letter.get_sprite()
	if sprite == null or sprite.texture == null:
		_fallback_collect(letter, controller, on_finished)
		return
	letter.begin_pending_resolve(Letter.Resolution.CLAW_COLLECT, "player_claw")
	sprite.visible = false
	var parent := letter.get_parent()
	if parent == null:
		parent = letter.get_tree().current_scene
	var fx: Node2D = LetterClawCollectFx.new()
	fx.z_index = 150
	parent.add_child(fx)
	fx.global_position = claw_origin
	fx._run(letter, sprite, controller, combat_hud, on_finished)


static func _fallback_collect(
	letter: Letter,
	controller: WordGameController,
	on_finished: Callable,
) -> void:
	if controller:
		controller.on_letter_collected(letter.character)
	letter.shatter_on_resolve = false
	letter.try_resolve(Letter.Resolution.CLAW_COLLECT, "player_claw")
	if on_finished.is_valid():
		on_finished.call(true)


func _run(
	letter: Letter,
	source_sprite: Sprite2D,
	controller: WordGameController,
	combat_hud: Control,
	on_finished: Callable,
) -> void:
	var rope := Line2D.new()
	rope.width = 3.0
	rope.default_color = Color(0.45, 0.95, 1.0, 0.9)
	rope.z_index = 1
	add_child(rope)
	var ghost := Sprite2D.new()
	ghost.texture = source_sprite.texture
	ghost.centered = true
	ghost.scale = letter.get_display_scale()
	LetterTint.apply(ghost, letter.tint_color)
	ghost.visible = false
	ghost.z_index = 2
	add_child(ghost)
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(letter):
				return
			var end := to_local(letter.global_position)
			rope.clear_points()
			rope.add_point(Vector2.ZERO)
			rope.add_point(end * t),
		0.0,
		1.0,
		ROPE_EXTEND_SEC,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(letter):
			_finish_fizzle(on_finished)
			return
		global_position = letter.global_position
		ghost.visible = true
		ghost.position = Vector2.ZERO
		rope.queue_free()
	)
	tween.tween_interval(PAUSE_SEC)
	var fly_target := _resolve_target(combat_hud, controller)
	tween.tween_property(self, "global_position", fly_target, FLY_SEC)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.72, FLY_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain()
	tween.tween_callback(func() -> void:
		if controller:
			controller.on_letter_collected(letter.character)
		if is_instance_valid(letter):
			letter.finish_pending_resolve()
		if on_finished.is_valid():
			on_finished.call(true)
		queue_free()
	)


func _finish_fizzle(on_finished: Callable) -> void:
	if on_finished.is_valid():
		on_finished.call(false)
	queue_free()


func _resolve_target(combat_hud: Control, controller: WordGameController) -> Vector2:
	if combat_hud and combat_hud.has_method("get_player_word_insert_position"):
		var word := ""
		if controller:
			word = controller.word_state.current_word
		return combat_hud.get_player_word_insert_position(word)
	if combat_hud and combat_hud.has_method("get_word_anchor_center"):
		return combat_hud.get_word_anchor_center(true)
	var viewport := get_viewport().get_visible_rect()
	return viewport.position + Vector2(viewport.size.x * 0.12, 72.0)
