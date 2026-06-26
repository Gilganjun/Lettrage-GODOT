class_name EnemyAnimation
extends Node

## Maps enemy movement states to SpriteFrames animations (group #14 baseline).

enum MovementState { IDLE, RUN, JUMP, FALL, CLIMB }

const ANIM_IDLE := "Idle"
const ANIM_RUN := "Run"
const ANIM_JUMP := "Jump"
const ANIM_FALL := "Fall"
const ANIM_CLIMB := "Climb"
const ANIM_IMPACT := "Impact"

@export var sprite: AnimatedSprite2D
@export var near_floor_run_distance: float = 60.0

var _current_anim: String = ""


func apply_state(state: MovementState, facing: int, floor_distance: float = INF) -> void:
	if sprite == null:
		return
	sprite.flip_h = facing < 0
	var target := _anim_for_state(state, floor_distance)
	if target.is_empty():
		return
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(target):
		return
	if target == _current_anim and sprite.animation == target and sprite.is_playing():
		return
	_current_anim = target
	sprite.play(target)


func force_apply_state(state: MovementState, facing: int, floor_distance: float = INF) -> void:
	_current_anim = ""
	apply_state(state, facing, floor_distance)


func _anim_for_state(state: MovementState, floor_distance: float) -> String:
	match state:
		MovementState.IDLE:
			return ANIM_IDLE
		MovementState.RUN:
			return ANIM_RUN
		MovementState.JUMP:
			return ANIM_JUMP
		MovementState.FALL:
			if floor_distance <= near_floor_run_distance:
				return ANIM_RUN
			return ANIM_FALL
		MovementState.CLIMB:
			return ANIM_CLIMB
	return ANIM_IDLE


func current_animation_name() -> String:
	return _current_anim if not _current_anim.is_empty() else ANIM_IDLE
