class_name CharacterPreviewSlot
extends VBoxContainer

signal control_action(action: String)

const ACTION_PREV := "prev"
const ACTION_NEXT := "next"
const ACTION_PLAY := "play"
const ACTION_PAUSE := "pause"
const ACTION_RESTART := "restart"

@export var profile: CharacterVisualProfile

@onready var role_label: Label = $Header/RoleLabel
@onready var sprite: AnimatedSprite2D = $ViewportPanel/SubViewportContainer/SubViewport/AnimatedSprite2D
@onready var info_label: Label = $InfoPanel/InfoLabel
@onready var resource_label: Label = $InfoPanel/ResourceLabel
@onready var effect_label: Label = $InfoPanel/EffectLabel

var _anim_index: int = 0
var _playing: bool = true


func _ready() -> void:
	if profile == null:
		info_label.text = "ERROR: CharacterVisualProfile not assigned"
		return
	_apply_profile()
	_play_current(false)


func _process(_delta: float) -> void:
	_update_info()


func set_profile(new_profile: CharacterVisualProfile) -> void:
	profile = new_profile
	if is_node_ready():
		_apply_profile()
		_play_current(false)


func perform_action(action: String) -> void:
	match action:
		ACTION_PREV:
			_anim_index = (_anim_index - 1 + profile.animation_order.size()) % profile.animation_order.size()
			_play_current(true)
		ACTION_NEXT:
			_anim_index = (_anim_index + 1) % profile.animation_order.size()
			_play_current(true)
		ACTION_PLAY:
			_playing = true
			sprite.play(_current_anim_name())
		ACTION_PAUSE:
			_playing = false
			sprite.stop()
		ACTION_RESTART:
			_play_current(true)
	_update_info()


func _apply_profile() -> void:
	role_label.text = profile.role_label
	sprite.sprite_frames = profile.sprite_frames
	sprite.modulate = profile.modulate
	sprite.scale = Vector2.ONE * profile.display_scale
	resource_label.text = "Profile: %s" % profile.resource_path
	effect_label.text = "Effects: %s" % profile.get_effect_summary()
	_anim_index = 0


func _current_anim_name() -> String:
	if profile.animation_order.is_empty():
		return ""
	return profile.animation_order[_anim_index]


func _play_current(from_start: bool) -> void:
	var anim := _current_anim_name()
	if anim.is_empty():
		return
	if not profile.sprite_frames.has_animation(anim):
		info_label.text = "Missing animation: %s" % anim
		return
	sprite.animation = anim
	if from_start:
		sprite.frame = 0
		sprite.frame_progress = 0.0
	if _playing:
		sprite.play(anim)
	else:
		sprite.stop()
	_update_info()


func _update_info() -> void:
	if profile == null:
		return
	var anim := _current_anim_name()
	if anim.is_empty():
		return
	var fc := profile.sprite_frames.get_frame_count(anim)
	var fps := profile.sprite_frames.get_animation_speed(anim)
	var loops := profile.sprite_frames.get_animation_loop(anim)
	var frame_idx := sprite.frame if fc > 0 else 0
	var state := "playing" if _playing and sprite.is_playing() else "paused"
	info_label.text = (
		"Animation: %s  (%d/%d in sequence)\n"
		% [anim, _anim_index + 1, profile.animation_order.size()]
	)
	info_label.text += "Frame: %d / %d  |  FPS: %.2f  |  Loop: %s  |  %s" % [
		frame_idx + 1,
		fc,
		fps,
		str(loops).to_lower(),
		state,
	]


func _on_prev_pressed() -> void:
	perform_action(ACTION_PREV)
	control_action.emit(ACTION_PREV)


func _on_next_pressed() -> void:
	perform_action(ACTION_NEXT)
	control_action.emit(ACTION_NEXT)


func _on_play_pressed() -> void:
	perform_action(ACTION_PLAY)
	control_action.emit(ACTION_PLAY)


func _on_pause_pressed() -> void:
	perform_action(ACTION_PAUSE)
	control_action.emit(ACTION_PAUSE)


func _on_restart_pressed() -> void:
	perform_action(ACTION_RESTART)
	control_action.emit(ACTION_RESTART)
