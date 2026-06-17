extends Control

## Phase 1 dual-character animation validation.
## Player and Enemy use independent CharacterVisualProfile resources.

@onready var player_slot: CharacterPreviewSlot = $Root/Characters/PlayerSlot
@onready var enemy_slot: CharacterPreviewSlot = $Root/Characters/EnemySlot
@onready var independence_label: Label = $Root/Footer/IndependenceLabel
@onready var controls_help: Label = $Root/Footer/ControlsHelp

var _player_profile: CharacterVisualProfile
var _enemy_profile: CharacterVisualProfile
var _both_playing: bool = true


func _ready() -> void:
	_player_profile = load("res://resources/characters/player_visual.tres") as CharacterVisualProfile
	_enemy_profile = load("res://resources/characters/enemy_visual.tres") as CharacterVisualProfile
	if _player_profile == null or _enemy_profile == null:
		push_error("CharacterVisualProfile resources missing")
		return
	player_slot.set_profile(_player_profile)
	enemy_slot.set_profile(_enemy_profile)
	_update_independence_label()
	controls_help.text = (
		"Keyboard: A/D = Player prev/next | ←/→ = Enemy prev/next | Space = play/pause both | R = restart both"
	)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_A:
			player_slot.perform_action(CharacterPreviewSlot.ACTION_PREV)
		KEY_D:
			player_slot.perform_action(CharacterPreviewSlot.ACTION_NEXT)
		KEY_LEFT:
			enemy_slot.perform_action(CharacterPreviewSlot.ACTION_PREV)
		KEY_RIGHT:
			enemy_slot.perform_action(CharacterPreviewSlot.ACTION_NEXT)
		KEY_SPACE:
			_toggle_play_pause_both()
		KEY_R:
			player_slot.perform_action(CharacterPreviewSlot.ACTION_RESTART)
			enemy_slot.perform_action(CharacterPreviewSlot.ACTION_RESTART)


func _toggle_play_pause_both() -> void:
	_both_playing = not _both_playing
	var action := (
		CharacterPreviewSlot.ACTION_PLAY
		if _both_playing
		else CharacterPreviewSlot.ACTION_PAUSE
	)
	player_slot.perform_action(action)
	enemy_slot.perform_action(action)


func _update_independence_label() -> void:
	var same_frames_resource := _player_profile.sprite_frames == _enemy_profile.sprite_frames
	var same_instance := _player_profile == _enemy_profile
	independence_label.text = (
		"Resource independence: profiles are %s | SpriteFrames resources are %s. "
		% [
			"DIFFERENT instances" if not same_instance else "SAME instance (ERROR)",
			"shared" if same_frames_resource else "separate",
		]
	)
	independence_label.text += (
		"Both reference PNGs under res://characters/. "
		+ "player_visual.tres → player_frames.tres | enemy_visual.tres → enemy_frames.tres. "
		+ "Changing enemy profile SpriteFrames does not alter player profile."
	)
