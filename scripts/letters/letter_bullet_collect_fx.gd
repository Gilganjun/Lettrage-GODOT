class_name LetterBulletCollectFx
extends Node2D

## Bullet collect (shield off) — pause, cyber frame, glide letter into the HUD word row.

const LetterTint := preload("res://scripts/letters/letter_tint.gd")

const PAUSE_SEC := 0.14
const FRAME_IN_SEC := 0.16
const FLY_SEC := 0.42


static func play(
	letter: Letter,
	controller: WordGameController,
	combat_hud: Control,
) -> void:
	_play_collect(letter, controller, combat_hud, true)


static func play_for_enemy(
	letter: Letter,
	controller: EnemyWordController,
	combat_hud: Control,
) -> void:
	_play_collect(letter, controller, combat_hud, false)


static func _play_collect(
	letter: Letter,
	controller: Node,
	combat_hud: Control,
	for_player: bool,
) -> void:
	if letter == null or controller == null:
		return
	var sprite := letter.get_sprite()
	if sprite == null or sprite.texture == null:
		_fallback_collect(letter, controller, for_player)
		return
	var source_tag := "letter_bullet" if for_player else "enemy_letter_bullet"
	var outcome := Letter.Resolution.BULLET_COLLECT if for_player else Letter.Resolution.ENEMY_COLLECT
	letter.begin_pending_resolve(outcome, source_tag)
	sprite.visible = false
	var parent := letter.get_parent()
	if parent == null:
		parent = letter.get_tree().current_scene
	var fx: Node2D = LetterBulletCollectFx.new()
	fx.z_index = 150
	parent.add_child(fx)
	fx.global_position = letter.global_position
	fx._run(letter, sprite, controller, combat_hud, for_player)


static func _fallback_collect(letter: Letter, controller: Node, for_player: bool) -> void:
	if controller and controller.has_method("on_letter_collected"):
		controller.call("on_letter_collected", letter.character)
	letter.shatter_on_resolve = false
	var outcome := Letter.Resolution.BULLET_COLLECT if for_player else Letter.Resolution.ENEMY_COLLECT
	var source_tag := "letter_bullet" if for_player else "enemy_letter_bullet"
	letter.try_resolve(outcome, source_tag)


func _run(
	letter: Letter,
	source_sprite: Sprite2D,
	controller: Node,
	combat_hud: Control,
	for_player: bool,
) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = source_sprite.texture
	ghost.centered = true
	ghost.scale = letter.get_display_scale()
	LetterTint.apply(ghost, letter.tint_color)
	add_child(ghost)
	var frame := LetterBulletCyberFrame.new()
	frame.z_index = 2
	var letter_half := maxf(22.0, ghost.texture.get_size().x * ghost.scale.x * 0.5)
	frame.set_frame_size(letter_half + 6.0)
	add_child(frame)
	var target := _resolve_target(combat_hud, controller, for_player)
	var tween := create_tween()
	tween.tween_interval(PAUSE_SEC)
	tween.tween_callback(func(): frame.animate_in(FRAME_IN_SEC))
	tween.tween_interval(FRAME_IN_SEC)
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target, FLY_SEC)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ghost, "scale", ghost.scale * 0.72, FLY_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(frame, "modulate:a", 0.0, FLY_SEC * 0.65)\
		.set_delay(FLY_SEC * 0.35)
	tween.chain()
	tween.tween_callback(func():
		if controller and controller.has_method("on_letter_collected"):
			controller.call("on_letter_collected", letter.character)
		letter.finish_pending_resolve()
		queue_free()
	)


func _resolve_target(combat_hud: Control, controller: Node, for_player: bool) -> Vector2:
	if for_player and combat_hud and combat_hud.has_method("get_player_word_insert_position"):
		var word := ""
		if controller is WordGameController:
			word = (controller as WordGameController).word_state.current_word
		return combat_hud.get_player_word_insert_position(word)
	if combat_hud and combat_hud.has_method("get_word_anchor_center"):
		return combat_hud.get_word_anchor_center(for_player)
	var viewport := get_viewport().get_visible_rect()
	return viewport.position + Vector2(viewport.size.x * 0.12, 72.0)
