class_name LetterBulletCyberFrame
extends Node2D

## Animated cyberpunk bracket frame around a bullet-collected letter.

var _pulse := 0.0
var _size := 18.0
var _target_size := 34.0
var _line_w := 2.0


func set_frame_size(half_extent: float) -> void:
	_size = half_extent * 0.55
	_target_size = half_extent + 8.0
	queue_redraw()


func _ready() -> void:
	set_process(true)


func animate_in(duration: float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_size, _size, _target_size, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_size(value: float) -> void:
	_size = value
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta * 9.0
	queue_redraw()


func _draw() -> void:
	var half := _size
	var corner := half * 0.42
	var pulse := 0.65 + 0.35 * sin(_pulse)
	var core := Color(0.25, 0.95, 1.0, 0.92 * pulse)
	var glow := Color(0.55, 0.35, 1.0, 0.35 * pulse)
	_draw_bracket(Vector2(-half, -half), Vector2(corner, 0.0), Vector2(0.0, corner), core, glow)
	_draw_bracket(Vector2(half, -half), Vector2(-corner, 0.0), Vector2(0.0, corner), core, glow)
	_draw_bracket(Vector2(-half, half), Vector2(corner, 0.0), Vector2(0.0, -corner), core, glow)
	_draw_bracket(Vector2(half, half), Vector2(-corner, 0.0), Vector2(0.0, -corner), core, glow)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.15, 0.85, 1.0, 0.08 * pulse), false, 1.0)


func _draw_bracket(origin: Vector2, arm_a: Vector2, arm_b: Vector2, core: Color, glow: Color) -> void:
	draw_line(origin, origin + arm_a, glow, _line_w + 2.0, true)
	draw_line(origin, origin + arm_b, glow, _line_w + 2.0, true)
	draw_line(origin, origin + arm_a, core, _line_w, true)
	draw_line(origin, origin + arm_b, core, _line_w, true)
