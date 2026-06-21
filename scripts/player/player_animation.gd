class_name PlayerAnimation
extends Node

## Maps movement states to Phase 1/2A player animations.

enum MovementState { IDLE, RUN, SPRINT, JUMP, FALL, CLIMB }

const ANIM_IDLE := "Idle"
const ANIM_RUN := "Run"
const ANIM_SPRINT := "Sprint"
const ANIM_JUMP := "Jump"
const ANIM_FALL := "Fall"
const ANIM_CLIMB := "Climb"

@export var sprite: AnimatedSprite2D

var _current_anim: String = ""


func apply_state(state: MovementState, facing: int) -> void:
	if sprite == null:
		return
	sprite.flip_h = facing < 0
	var target := _anim_for_state(state)
	if target.is_empty():
		return
	if not sprite.sprite_frames.has_animation(target):
		return
	if target == _current_anim and sprite.animation == target and sprite.is_playing():
		return
	_current_anim = target
	sprite.play(target)


func force_apply_state(state: MovementState, facing: int) -> void:
	_current_anim = ""
	apply_state(state, facing)


func _anim_for_state(state: MovementState) -> String:
	match state:
		MovementState.IDLE:
			return ANIM_IDLE
		MovementState.RUN:
			return ANIM_RUN
		MovementState.SPRINT:
			return ANIM_SPRINT
		MovementState.JUMP:
			return ANIM_JUMP
		MovementState.FALL:
			return ANIM_FALL
		MovementState.CLIMB:
			return ANIM_CLIMB
	return ANIM_IDLE


func current_animation_name() -> String:
	return _current_anim if not _current_anim.is_empty() else ANIM_IDLE
