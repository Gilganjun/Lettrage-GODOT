class_name PlayerMovement
extends CharacterBody2D

## Basic platformer controller — independent from character artwork.

signal movement_state_changed(state: PlayerAnimation.MovementState)

@export var visual_profile: CharacterVisualProfile
@export var movement_config: PlayerMovementConfig

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_controller: PlayerAnimation = $AnimationController
@onready var camera: Camera2D = $Camera2D
@onready var camera_zoom: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var facing: int = 1
var movement_state: PlayerAnimation.MovementState = PlayerAnimation.MovementState.IDLE
var is_on_ladder: bool = false
var _ladder_areas: Array[Area2D] = []
var _jump_time: float = 0.0
var _jump_held: bool = false
var _display_size := Vector2(64, 97)
var _sprint_active := false
var _sprint_direction := 0
var _tap_clock := 0.0
var _last_press_time_left := -1.0
var _last_press_time_right := -1.0
var _pending_sprint_direction := 0
var _shift_sprint_hold := false
var movement_locked := false
var round_intro_fall_active := false

var _round_intro_land_position := Vector2.ZERO
var _round_intro_drop_start_y := 0.0
var _round_intro_fall_ease := 2.0
var _round_intro_was_airborne := false
var _round_intro_land_pose_active := false
var _round_intro_land_pose_timer := 0.0
var _action_sequence_targeted := false
var _action_strike_frozen := false
var _action_freeze_position := Vector2.ZERO

const FLOOR_SNAP := 4.0
const ROUND_INTRO_LAND_POSE_DURATION := 0.5
## death_031_.png — collapsed-on-impact pose shown briefly after intro landing.
const ROUND_INTRO_LAND_DEATH_FRAME := 30


func _ready() -> void:
	add_to_group("player")
	if camera_zoom and camera_zoom.has_method("reset_to_base"):
		camera_zoom.reset_to_base()
	else:
		camera.zoom = Vector2(1.0, 1.0)
	_apply_visual_profile()
	animation_controller.sprite = sprite
	activate_follow_camera()


func activate_follow_camera() -> void:
	var preserve_intro := round_intro_fall_active
	if camera_zoom and camera_zoom.has_method("is_round_intro_active"):
		preserve_intro = preserve_intro or camera_zoom.is_round_intro_active()
	if not preserve_intro:
		if camera_zoom and camera_zoom.has_method("reset_to_base"):
			camera_zoom.reset_to_base()
		else:
			camera.zoom = Vector2(1.0, 1.0)
	camera.enabled = true
	for fixed in get_tree().get_nodes_in_group("fixed_camera"):
		if fixed is Camera2D:
			(fixed as Camera2D).enabled = false
	call_deferred("_make_camera_current")


func _make_camera_current() -> void:
	if camera.enabled:
		camera.make_current()


func set_camera_follow_enabled(enabled: bool) -> void:
	if enabled:
		activate_follow_camera()


func begin_round_intro_fall(
	land_position: Vector2,
	drop_height: float,
	ease_power: float = 2.0,
	drop_top_y: float = NAN,
) -> void:
	round_intro_fall_active = true
	movement_locked = true
	_round_intro_land_position = land_position
	if is_nan(drop_top_y):
		_round_intro_drop_start_y = land_position.y - maxf(drop_height, 0.0)
	else:
		_round_intro_drop_start_y = drop_top_y
	_round_intro_fall_ease = maxf(ease_power, 0.1)
	global_position = Vector2(land_position.x, _round_intro_drop_start_y)
	velocity = Vector2.ZERO
	_round_intro_was_airborne = false
	_round_intro_land_pose_active = false
	_round_intro_land_pose_timer = 0.0


func cancel_round_intro_land_pose() -> void:
	_round_intro_land_pose_active = false
	_round_intro_land_pose_timer = 0.0
	_round_intro_was_airborne = false
	if sprite:
		sprite.speed_scale = 1.0


func tick_round_intro_fall(progress: float) -> void:
	if not round_intro_fall_active:
		return
	var p := clampf(progress, 0.0, 1.0)
	var t := 1.0 - pow(1.0 - p, _round_intro_fall_ease)
	global_position = Vector2(
		_round_intro_land_position.x,
		lerpf(_round_intro_drop_start_y, _round_intro_land_position.y, t),
	)
	velocity = Vector2.ZERO


func end_round_intro_fall() -> void:
	if not round_intro_fall_active:
		return
	round_intro_fall_active = false
	global_position = _round_intro_land_position
	velocity = Vector2.ZERO
	if _round_intro_was_airborne and not _round_intro_land_pose_active:
		_begin_round_intro_land_pose()
	elif not _round_intro_land_pose_active:
		_restore_idle_after_intro_land()


func _begin_round_intro_land_pose() -> void:
	_round_intro_land_pose_active = true
	_round_intro_land_pose_timer = ROUND_INTRO_LAND_POSE_DURATION
	movement_state = PlayerAnimation.MovementState.IDLE
	_apply_intro_land_death_frame()


func _apply_intro_land_death_frame() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation("Death"):
		return
	var last_frame := sprite.sprite_frames.get_frame_count("Death") - 1
	var frame := clampi(ROUND_INTRO_LAND_DEATH_FRAME, 0, last_frame)
	sprite.play("Death")
	sprite.frame = frame
	sprite.pause()
	sprite.speed_scale = 1.0


func _tick_round_intro_land_pose(delta: float) -> void:
	if not _round_intro_land_pose_active:
		return
	_round_intro_land_pose_timer -= delta
	_apply_intro_land_death_frame()
	if _round_intro_land_pose_timer <= 0.0:
		_finish_round_intro_land_pose()


func _finish_round_intro_land_pose() -> void:
	_round_intro_land_pose_active = false
	_round_intro_land_pose_timer = 0.0
	if sprite:
		sprite.speed_scale = 1.0
	_restore_idle_after_intro_land()


func _restore_idle_after_intro_land() -> void:
	movement_state = PlayerAnimation.MovementState.IDLE
	animation_controller.force_apply_state(movement_state, facing)


func _apply_round_intro_animation() -> void:
	if _round_intro_land_pose_active:
		return
	var airborne := global_position.y < _round_intro_land_position.y - 2.0
	if airborne:
		_round_intro_was_airborne = true
		var fall_state := PlayerAnimation.MovementState.FALL
		if fall_state != movement_state:
			movement_state = fall_state
			movement_state_changed.emit(movement_state)
			animation_controller.apply_state(movement_state, facing)
		return
	if _round_intro_was_airborne:
		_begin_round_intro_land_pose()
		return
	var idle_state := PlayerAnimation.MovementState.IDLE
	if idle_state != movement_state:
		movement_state = idle_state
		movement_state_changed.emit(movement_state)
		animation_controller.apply_state(movement_state, facing)


func set_action_sequence_targeted(active: bool) -> void:
	_action_sequence_targeted = active
	if not active:
		end_action_strike_freeze()


func is_action_sequence_targeted() -> bool:
	return _action_sequence_targeted


func begin_action_strike_freeze() -> void:
	_action_strike_frozen = true
	_action_freeze_position = global_position
	velocity = Vector2.ZERO


func end_action_strike_freeze() -> void:
	_action_strike_frozen = false


func is_action_strike_frozen() -> bool:
	return _action_strike_frozen


func _physics_process(delta: float) -> void:
	if round_intro_fall_active:
		velocity = Vector2.ZERO
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		_apply_round_intro_animation()
		return
	if _round_intro_land_pose_active:
		velocity = Vector2.ZERO
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		_tick_round_intro_land_pose(delta)
		return
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		return
	if _action_strike_frozen:
		_poll_action_defender_block()
		global_position = _action_freeze_position
		velocity = Vector2.ZERO
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		_update_movement_state()
		return
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	if _process_action_sequence(delta):
		return
	if _process_roll(delta):
		return
	var combat := get_node_or_null("CharacterCombat")
	if combat and combat.blocks_movement():
		_process_combat_lock(delta, combat)
		move_and_slide()
		var word_stun: bool = combat is CharacterCombat and (combat as CharacterCombat).is_word_stun_active()
		floor_snap_length = 0.0 if word_stun else FLOOR_SNAP
		_update_movement_state()
		return
	_update_ladder_overlap()
	if is_on_ladder:
		_process_ladder(delta)
	else:
		_process_platformer(delta)
	move_and_slide()
	floor_snap_length = FLOOR_SNAP
	if not is_on_ladder and not movement_locked and not _action_strike_frozen:
		_try_apply_pending_sprint()
	_update_movement_state()


func configure_from_gdevelop(row: Dictionary) -> void:
	global_position = Vector2(float(row.get("source_x", 0)), float(row.get("source_y", 0)))
	_display_size = Vector2(float(row.get("display_width", 64)), float(row.get("display_height", 97)))
	if visual_profile == null:
		visual_profile = load("res://resources/characters/player_visual.tres")
	if visual_profile == null:
		return
	sprite.sprite_frames = visual_profile.sprite_frames
	sprite.modulate = visual_profile.modulate
	sprite.play("Idle")
	GDevelopTransform.apply_to_animated_sprite(
		sprite,
		float(row["source_x"]),
		float(row["source_y"]),
		float(row.get("origin_x", 0)),
		float(row.get("origin_y", 0)),
		_display_size.x,
		_display_size.y,
		float(row.get("native_width", 145)),
		float(row.get("native_height", 191)),
		1.0,
		float(row.get("source_angle", 0)),
	)
	var death_align := get_node_or_null("DeathFrameAlignment")
	if death_align and death_align.has_method("refresh_base_offset"):
		death_align.refresh_base_offset()
	_align_collision_to_visual()


func register_ladder(area: Area2D) -> void:
	if area not in _ladder_areas:
		_ladder_areas.append(area)


func get_debug_info() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"state": movement_state,
		"animation": animation_controller.current_animation_name(),
		"on_floor": is_on_floor(),
		"on_ladder": is_on_ladder,
		"facing": facing,
		"sprint": _sprint_active,
		"pending_sprint": _pending_sprint_direction,
		"camera_zoom_percent": camera_zoom.call("get_zoom_percent") if camera_zoom and camera_zoom.has_method("get_zoom_percent") else 100.0,
	}


func _apply_visual_profile() -> void:
	if visual_profile == null:
		visual_profile = load("res://resources/characters/player_visual.tres")
	if visual_profile == null:
		push_error("Player visual profile missing")
		return
	sprite.sprite_frames = visual_profile.sprite_frames
	sprite.modulate = visual_profile.modulate
	sprite.play("Idle")


func _align_collision_to_visual() -> void:
	var rect := collision_shape.shape as RectangleShape2D
	if rect == null:
		return
	rect.size = Vector2(_display_size.x * 0.56, _display_size.y * 0.86)
	collision_shape.position = Vector2(_display_size.x * 0.5, _display_size.y - rect.size.y * 0.5)


func _process_platformer(delta: float) -> void:
	var cfg := _cfg()
	var aim_mode := _is_aiming_letter_shot()
	_update_double_tap_sprint(delta)
	_update_shift_sprint()
	var input_x := 0.0 if aim_mode else Input.get_axis("move_left", "move_right")
	var air_fast_fall := not is_on_floor() and Input.is_action_pressed("climb_down")
	if not air_fast_fall:
		if input_x != 0.0:
			facing = 1 if input_x > 0.0 else -1
		var max_speed := cfg.sprint_max_speed if _sprint_active else cfg.max_speed
		var target_speed := input_x * max_speed
		var rate := cfg.acceleration if absf(target_speed) > absf(velocity.x) else cfg.deceleration
		velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if not is_on_floor():
		if air_fast_fall:
			_apply_air_fast_fall(cfg, input_x, delta)
		else:
			velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
	else:
		_jump_time = 0.0
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = -cfg.jump_speed
			_jump_held = true
			_jump_time = 0.0
		elif _can_mount_ladder() and Input.is_action_pressed("climb_up"):
			is_on_ladder = true
			velocity = Vector2.ZERO
	if Input.is_action_pressed("jump"):
		_jump_held = true
		_jump_time += delta
		if (
			not air_fast_fall
			and _jump_held
			and _jump_time <= cfg.jump_sustain_time
			and velocity.y < 0.0
		):
			velocity.y = -cfg.jump_speed
	else:
		_jump_held = false


func _process_combat_lock(delta: float, combat: Node) -> void:
	var cfg := _cfg()
	if combat.is_dead():
		velocity = Vector2.ZERO
		return
	if combat.has_method("is_stun_position_locked") and combat.is_stun_position_locked():
		global_position.x = combat.get_stun_locked_x()
		if combat.has_method("is_stun_grounded") and combat.is_stun_grounded():
			velocity = Vector2.ZERO
		else:
			velocity.x = 0.0
			velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
		return
	var slide := Vector2.ZERO
	if combat.has_method("compute_stun_slide_velocity"):
		slide = combat.compute_stun_slide_velocity()
	if combat.has_method("is_word_stun_active") and combat.is_word_stun_active() and slide == Vector2.ZERO:
		velocity = Vector2.ZERO
		if not is_on_floor():
			velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
	else:
		velocity.y = 0.0
	if slide.x != 0.0:
		velocity.x = slide.x
	else:
		velocity.x = move_toward(velocity.x, 0.0, cfg.deceleration * delta)


func _process_ladder(_delta: float) -> void:
	var cfg := _cfg()
	velocity = Vector2.ZERO
	var input_x := Input.get_axis("move_left", "move_right")
	var input_y := Input.get_axis("climb_up", "climb_down")
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
		velocity.x = input_x * cfg.max_speed * 0.5
	if input_y != 0.0:
		velocity.y = input_y * cfg.ladder_climbing_speed
	if Input.is_action_just_pressed("jump"):
		is_on_ladder = false
		velocity.y = -cfg.jump_speed
		return
	if not _overlaps_any_ladder():
		is_on_ladder = false


func _update_ladder_overlap() -> void:
	if is_on_ladder:
		return
	if _can_mount_ladder():
		var input_y := Input.get_axis("climb_up", "climb_down")
		if input_y != 0.0:
			is_on_ladder = true
			velocity = Vector2.ZERO


func _can_mount_ladder() -> bool:
	if not _overlaps_any_ladder():
		return false
	var input_y := Input.get_axis("climb_up", "climb_down")
	return input_y != 0.0 or (not is_on_floor() and Input.is_action_pressed("climb_up"))


func _overlaps_any_ladder() -> bool:
	for area in _ladder_areas:
		if area == null or not is_instance_valid(area):
			continue
		if area.overlaps_body(self):
			return true
	return false


func _update_movement_state() -> void:
	var combat := get_node_or_null("CharacterCombat")
	if combat and combat.has_method("is_word_stun_active") and combat.is_word_stun_active():
		return
	var action := _get_action_controller()
	if action and action.is_active() and action.locks_movement_animation():
		return
	var new_state: PlayerAnimation.MovementState
	if is_on_ladder:
		new_state = PlayerAnimation.MovementState.CLIMB
	elif not is_on_floor():
		new_state = (
			PlayerAnimation.MovementState.JUMP
			if velocity.y < 0.0
			else PlayerAnimation.MovementState.FALL
		)
	elif absf(velocity.x) > 8.0:
		if _sprint_active and is_on_floor():
			new_state = PlayerAnimation.MovementState.SPRINT
		else:
			new_state = PlayerAnimation.MovementState.RUN
	else:
		new_state = PlayerAnimation.MovementState.IDLE
	if new_state != movement_state:
		movement_state = new_state
		movement_state_changed.emit(movement_state)
	animation_controller.apply_state(movement_state, facing)


func _update_double_tap_sprint(delta: float) -> void:
	if _is_aiming_letter_shot():
		return
	var cfg := _cfg()
	var window := cfg.double_tap_window
	_tap_clock += delta
	_update_direction_double_tap(1, "move_right", window)
	_update_direction_double_tap(-1, "move_left", window)
	if _sprint_active and not is_on_floor():
		_end_sprint()


func _update_direction_double_tap(direction: int, action: String, window: float) -> void:
	var is_sprint_dir := _sprint_active and _sprint_direction == direction

	if Input.is_action_just_pressed(action):
		if is_sprint_dir:
			return
		if _pending_sprint_direction != 0 and _pending_sprint_direction != direction:
			_pending_sprint_direction = 0
		var last_time := _last_press_time_right if direction > 0 else _last_press_time_left
		if last_time >= 0.0 and (_tap_clock - last_time) <= window:
			_set_last_press_time(direction, -1.0)
			_request_sprint(direction)
		else:
			_set_last_press_time(direction, _tap_clock)

	if Input.is_action_just_released(action):
		if is_sprint_dir and not Input.is_physical_key_pressed(KEY_SHIFT):
			_end_sprint()


func _update_shift_sprint() -> void:
	if _is_aiming_letter_shot():
		return
	var shift_held := Input.is_physical_key_pressed(KEY_SHIFT)
	var input_x := Input.get_axis("move_left", "move_right")
	if shift_held and absf(input_x) > 0.1:
		var direction := 1 if input_x > 0.0 else -1
		_shift_sprint_hold = true
		if _pending_sprint_direction != 0 and _pending_sprint_direction != direction:
			_pending_sprint_direction = 0
		if is_on_floor():
			if not _sprint_active or _sprint_direction != direction:
				_start_sprint(direction)
		else:
			_pending_sprint_direction = direction
	elif _shift_sprint_hold:
		_shift_sprint_hold = false
		if not is_on_floor():
			_pending_sprint_direction = 0
		if _sprint_active:
			_end_sprint()


func _request_sprint(direction: int) -> void:
	if is_on_floor():
		_start_sprint(direction)
	else:
		_pending_sprint_direction = direction


func _try_apply_pending_sprint() -> void:
	if _pending_sprint_direction == 0 or not is_on_floor():
		return
	var direction := _pending_sprint_direction
	_pending_sprint_direction = 0
	_start_sprint(direction)
	if _is_aiming_letter_shot():
		return
	var cfg := _cfg()
	velocity.x = float(direction) * cfg.sprint_max_speed


func _set_last_press_time(direction: int, time: float) -> void:
	if direction > 0:
		_last_press_time_right = time
	else:
		_last_press_time_left = time


func _start_sprint(direction: int) -> void:
	if not is_on_floor():
		return
	_sprint_active = true
	_sprint_direction = direction
	facing = direction
	_pending_sprint_direction = 0
	_clear_tap_press_times()
	movement_state = PlayerAnimation.MovementState.SPRINT
	movement_state_changed.emit(movement_state)
	animation_controller.apply_state(movement_state, facing)


func _end_sprint() -> void:
	if not _sprint_active:
		return
	_sprint_active = false
	_sprint_direction = 0
	_shift_sprint_hold = false
	_clear_tap_press_times()


func _clear_tap_press_times() -> void:
	_last_press_time_left = -1.0
	_last_press_time_right = -1.0


func _cfg() -> PlayerMovementConfig:
	if movement_config == null:
		movement_config = load("res://resources/player/movement_config.tres")
	return movement_config


func get_action_pickup_point() -> Vector2:
	if collision_shape:
		return collision_shape.global_position
	return global_position + Vector2(_display_size.x * 0.5, _display_size.y * 0.55)


func _is_aiming_letter_shot() -> bool:
	for child in get_children():
		if child is LetterShooter and (child as LetterShooter).is_aim_mode_active():
			return true
	return false


func _apply_air_fast_fall(cfg: PlayerMovementConfig, input_x: float, delta: float) -> void:
	_jump_held = false
	var speed := cfg.fast_fall_speed
	if absf(input_x) > 0.1:
		var dir := Vector2(signf(input_x), 1.0).normalized()
		velocity = dir * speed
		facing = 1 if input_x > 0.0 else -1
	else:
		velocity.y = speed
		velocity.x = move_toward(velocity.x, 0.0, cfg.deceleration * 2.0 * delta)


func _process_action_sequence(delta: float) -> bool:
	var action := _get_action_controller()
	if action == null:
		return false
	if action.process_action(self, delta):
		var kinematic: bool = (
			action.has_method("uses_side_slide_strike") and action.uses_side_slide_strike()
		)
		if not kinematic:
			move_and_slide()
		else:
			velocity = Vector2.ZERO
			if action.has_method("finalize_strike_physics"):
				action.finalize_strike_physics()
		floor_snap_length = FLOOR_SNAP
		_update_movement_state()
		return true
	return false


func _process_roll(delta: float) -> bool:
	var roll := _get_roll()
	if roll == null:
		return false
	if roll.process_roll(self, delta):
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		_update_movement_state()
		return true
	return false


func _get_action_controller() -> Node:
	for child in get_children():
		if child.has_method("process_action"):
			return child
	return null


func _poll_action_defender_block() -> void:
	var action := _get_action_controller()
	if action and action.has_method("process_defender_block_input"):
		action.process_defender_block_input(self)


func _get_roll() -> Node:
	for child in get_children():
		if child.has_method("process_roll"):
			return child
	return null
