class_name PlayerShield
extends Node

## Player shield — hybrid tap-latch + hold-to-block (default), or legacy toggle/hold-only.

signal shield_toggled(active: bool)
signal latch_changed(latched: bool)
signal hold_session_changed(holding: bool)

enum InputMode {
	## Tap LCtrl toggles shield on/off; hold LCtrl blocks only while held.
	HYBRID,
	TOGGLE,
	HOLD,
}

enum _HybridPhase { IDLE, PRESSING, HOLDING }

const ShieldComponentScript := preload("res://scripts/components/shield_component.gd")

@export var shield_scene: PackedScene
@export var input_mode: InputMode = InputMode.HYBRID
@export var hold_threshold: float = 0.18

var shield: ShieldComponent
var is_active := false
var is_latched := false
var is_hold_blocking := false

var _hold_session := false
var _hybrid_phase := _HybridPhase.IDLE
var _press_start_msec := 0


func _ready() -> void:
	set_process_unhandled_input(true)
	if shield_scene == null:
		shield_scene = load("res://scenes/components/shield_component.tscn")
	shield = shield_scene.instantiate() as ShieldComponent
	if shield == null:
		return
	shield.owner_group = "player"
	shield.impact_source = "player_shield"
	shield.shield_up_sound = load("res://assets/ShieldUp1.mp3")
	shield.shield_down_sound = load("res://assets/ShieldDown1.mp3")
	shield.shield_impact_sounds = [
		load("res://assets/463388__vilkas-sound__vs-pop-4.mp3") as AudioStream,
		load("res://assets/463389__vilkas-sound__vs-pop-3.mp3") as AudioStream,
	]
	shield.impact_volume = ShieldComponent.PLAYER_BREAK_VOLUME
	shield.shield_activated.connect(func(): _sync_active(true))
	shield.shield_deactivated.connect(func(): _sync_active(false))


func _process(_delta: float) -> void:
	match input_mode:
		InputMode.TOGGLE:
			if Input.is_action_just_pressed("player_shield"):
				toggle()
		InputMode.HOLD:
			_update_hold_only_shield()
		InputMode.HYBRID:
			_update_hybrid_hold_tick()


func _unhandled_input(event: InputEvent) -> void:
	if input_mode != InputMode.HYBRID or shield == null:
		return
	if not event.is_action("player_shield") or event.is_echo():
		return
	if _is_input_blocked():
		_cancel_hybrid_gesture()
		return
	if event.is_pressed():
		_on_hybrid_press_started()
	else:
		_on_hybrid_press_ended()


func attach_to_body(body: Node2D, local_position: Vector2 = Vector2.ZERO) -> void:
	if shield == null or body == null:
		return
	var parent := shield.get_parent()
	if parent != body:
		if parent:
			parent.remove_child(shield)
		body.add_child(shield)
	shield.position = local_position


func toggle() -> void:
	if shield == null or _is_input_blocked():
		return
	if shield.is_active:
		shield.deactivate("player_toggle")
		_set_latched(false)
	else:
		shield.activate("player_toggle")
		_set_latched(true)


func set_active(active: bool) -> void:
	if shield == null:
		return
	if active:
		shield.activate("external")
	else:
		shield.deactivate("external")
		_set_latched(false)


func blocks_letter_collection() -> bool:
	return shield != null and shield.blocks_letter_collection()


func get_debug_info() -> Dictionary:
	if shield == null:
		return {
			"active": false,
			"cooldown": 0.0,
			"input_mode": input_mode,
			"latched": is_latched,
			"hold_session": _hold_session,
		}
	var info := shield.get_debug_info()
	info["input_mode"] = input_mode
	info["latched"] = is_latched
	info["hold_session"] = _hold_session
	info["hybrid_phase"] = _hybrid_phase
	return info


func _update_hold_only_shield() -> void:
	if shield == null:
		return
	if _is_input_blocked():
		_end_hold_session()
		return
	var want_active := Input.is_action_pressed("player_shield")
	if want_active and not shield.is_active:
		shield.activate("player_hold")
		_set_hold_session(true)
	elif not want_active and shield.is_active:
		shield.deactivate("player_hold")
		_set_hold_session(false)
	elif not want_active:
		_set_hold_session(false)


func _on_hybrid_press_started() -> void:
	if _hybrid_phase != _HybridPhase.IDLE:
		return
	_hybrid_phase = _HybridPhase.PRESSING
	_press_start_msec = Time.get_ticks_msec()


func _on_hybrid_press_ended() -> void:
	if _hybrid_phase == _HybridPhase.IDLE:
		return
	var held_sec := float(Time.get_ticks_msec() - _press_start_msec) / 1000.0
	if held_sec < hold_threshold:
		_on_hybrid_tap()
	else:
		_on_hybrid_hold_release()
	_hybrid_phase = _HybridPhase.IDLE


func _update_hybrid_hold_tick() -> void:
	if shield == null:
		return
	if _is_input_blocked():
		_cancel_hybrid_gesture()
		return
	if _hybrid_phase != _HybridPhase.PRESSING:
		return
	if not Input.is_action_pressed("player_shield"):
		return
	var held_sec := float(Time.get_ticks_msec() - _press_start_msec) / 1000.0
	if held_sec >= hold_threshold:
		_begin_hybrid_hold()


func _on_hybrid_tap() -> void:
	if is_latched:
		shield.deactivate("player_toggle_latch")
		_set_latched(false)
	else:
		shield.activate("player_toggle_latch")
		_set_latched(true)


func _on_hybrid_hold_release() -> void:
	_set_hold_session(false)
	if shield.is_active:
		shield.deactivate("player_hold")
	_set_latched(false)


func _begin_hybrid_hold() -> void:
	if _hybrid_phase == _HybridPhase.HOLDING:
		return
	_hybrid_phase = _HybridPhase.HOLDING
	_set_hold_session(true)
	if not shield.is_active:
		shield.activate("player_hold")


func _cancel_hybrid_gesture() -> void:
	if _hybrid_phase == _HybridPhase.HOLDING:
		_on_hybrid_hold_release()
	_hybrid_phase = _HybridPhase.IDLE


func _end_hold_session() -> void:
	if not _hold_session:
		return
	_set_hold_session(false)
	if not is_latched and shield != null and shield.is_active:
		shield.deactivate("player_hold")


func _set_hold_session(active: bool) -> void:
	if _hold_session == active:
		return
	_hold_session = active
	is_hold_blocking = active
	hold_session_changed.emit(active)


func _set_latched(latched: bool) -> void:
	if is_latched == latched:
		return
	is_latched = latched
	latch_changed.emit(is_latched)


func _is_input_blocked() -> bool:
	var body := get_parent() as Node
	if body:
		var combat := body.get_node_or_null("CharacterCombat")
		if combat and combat.has_method("is_dead") and (
			combat.is_dead() or combat.blocks_movement()
		):
			return true
	return false


func _sync_active(active: bool) -> void:
	is_active = active
	if not active:
		_set_hold_session(false)
		_set_latched(false)
	shield_toggled.emit(active)
