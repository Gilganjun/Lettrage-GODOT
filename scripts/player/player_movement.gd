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
var _tap_tracking_right := false
var _tap_tracking_left := false
var _tap_armed_right := false
var _tap_armed_left := false
var _tap_elapsed_right := 0.0
var _tap_elapsed_left := 0.0

const FLOOR_SNAP := 4.0


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


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
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
	_update_double_tap_sprint(delta)
	var input_x := Input.get_axis("move_left", "move_right")
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	var max_speed := cfg.sprint_max_speed if _sprint_active else cfg.max_speed
	var target_speed := input_x * max_speed
	var rate := cfg.acceleration if absf(target_speed) > absf(velocity.x) else cfg.deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if not is_on_floor():
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
		if _jump_held and _jump_time <= cfg.jump_sustain_time and velocity.y < 0.0:
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
		velocity = Vector2.ZERO
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
	var cfg := _cfg()
	var window := cfg.double_tap_window
	_update_direction_double_tap(1, "move_right", delta, window)
	_update_direction_double_tap(-1, "move_left", delta, window)
	if _sprint_active and not is_on_floor():
		_end_sprint()


func _update_direction_double_tap(direction: int, action: String, delta: float, window: float) -> void:
	var is_sprint_dir := _sprint_active and _sprint_direction == direction
	var tracking := _tap_tracking_right if direction > 0 else _tap_tracking_left
	var armed := _tap_armed_right if direction > 0 else _tap_armed_left

	if Input.is_action_just_pressed(action):
		if is_sprint_dir:
			return
		if armed and (_tap_elapsed_right if direction > 0 else _tap_elapsed_left) <= window and is_on_floor():
			_start_sprint(direction)
			return
		if direction > 0:
			_tap_tracking_right = true
			_tap_elapsed_right = 0.0
			_tap_armed_right = false
		else:
			_tap_tracking_left = true
			_tap_elapsed_left = 0.0
			_tap_armed_left = false

	if Input.is_action_just_released(action):
		if is_sprint_dir:
			_end_sprint()
			return
		if tracking and not armed:
			if direction > 0:
				_tap_armed_right = true
			else:
				_tap_armed_left = true

	if tracking and not _sprint_active:
		if direction > 0:
			_tap_elapsed_right += delta
			if _tap_elapsed_right > window:
				_tap_tracking_right = false
				_tap_armed_right = false
		else:
			_tap_elapsed_left += delta
			if _tap_elapsed_left > window:
				_tap_tracking_left = false
				_tap_armed_left = false


func _start_sprint(direction: int) -> void:
	if not is_on_floor():
		return
	_sprint_active = true
	_sprint_direction = direction
	facing = direction
	_reset_tap_state()
	movement_state = PlayerAnimation.MovementState.SPRINT
	movement_state_changed.emit(movement_state)
	animation_controller.apply_state(movement_state, facing)


func _end_sprint() -> void:
	if not _sprint_active:
		return
	_sprint_active = false
	_sprint_direction = 0
	_reset_tap_state()


func _reset_tap_state() -> void:
	_tap_tracking_right = false
	_tap_tracking_left = false
	_tap_armed_right = false
	_tap_armed_left = false
	_tap_elapsed_right = 0.0
	_tap_elapsed_left = 0.0


func _cfg() -> PlayerMovementConfig:
	if movement_config == null:
		movement_config = load("res://resources/player/movement_config.tres")
	return movement_config
