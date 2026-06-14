class_name Enemy
extends CharacterBody2D

## Phase 2B2A enemy foundation — movement, patrol, animation only.

signal movement_state_changed(state: EnemyAnimation.MovementState)

@export var visual_profile: CharacterVisualProfile
@export var movement_config: EnemyMovementConfig

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_controller: EnemyAnimation = $AnimationController
@onready var movement_controller: EnemyMovementController = $EnemyMovementController
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var floor_ray_left: RayCast2D = $FloorRayLeft
@onready var floor_ray_right: RayCast2D = $FloorRayRight
@onready var wall_ray_left: RayCast2D = $WallRayLeft
@onready var wall_ray_right: RayCast2D = $WallRayRight
@onready var ladder_detector: Area2D = $LadderDetector
@onready var floor_probe: RayCast2D = $FloorProbe

var facing: int = 1
var movement_state: EnemyAnimation.MovementState = EnemyAnimation.MovementState.IDLE
var is_on_ladder: bool = false
var direction_changes: int = 0

var _display_size := Vector2(93, 116)
var _ladder_areas: Array[Area2D] = []
var _jump_time: float = 0.0
var _jump_held: bool = false
var _floor_distance: float = INF

const FLOOR_SNAP := 4.0


func _ready() -> void:
	add_to_group("enemy")
	_apply_visual_profile()
	animation_controller.sprite = sprite
	_setup_rays()
	ladder_detector.area_entered.connect(_on_ladder_area_entered)
	ladder_detector.area_exited.connect(_on_ladder_area_exited)
	if movement_controller:
		movement_controller.direction_changed.connect(func(_d): direction_changes += 1)


func configure_from_gdevelop(row: Dictionary) -> void:
	global_position = Vector2(float(row.get("source_x", 740)), float(row.get("source_y", 406)))
	_display_size = Vector2(float(row.get("display_width", 93)), float(row.get("display_height", 116)))
	if visual_profile == null:
		visual_profile = load("res://resources/characters/enemy_visual.tres")
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
	if movement_controller:
		movement_controller.configure_patrol(300.0, 2000.0, global_position.x)


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
		"direction": movement_controller.direction if movement_controller else facing,
		"target_x": movement_controller.target_x if movement_controller else 0.0,
		"patrol_min_x": movement_controller.patrol_min_x if movement_controller else 0.0,
		"patrol_max_x": movement_controller.patrol_max_x if movement_controller else 0.0,
		"jump_cooldown": movement_controller.jump_cooldown if movement_controller else 0.0,
		"direction_changes": direction_changes,
		"floor_distance": _floor_distance,
	}


func _physics_process(delta: float) -> void:
	if movement_controller:
		movement_controller.tick(delta)
	_update_floor_probe()
	if is_on_ladder:
		_process_ladder(delta)
	else:
		_process_platformer(delta)
	move_and_slide()
	floor_snap_length = FLOOR_SNAP
	_update_movement_state()


func _process_platformer(delta: float) -> void:
	var cfg := _cfg()
	var desired := movement_controller.get_desired_direction(global_position.x) if movement_controller else 1
	var blocked := _is_blocked(desired)
	if _should_reverse(desired, blocked):
		desired = -desired
		if movement_controller:
			movement_controller.set_direction(desired)
		blocked = _is_blocked(desired)
	if movement_controller:
		movement_controller.set_direction(desired)
	facing = desired
	var target_speed := float(desired) * cfg.max_speed
	var rate := cfg.acceleration if absf(target_speed) > absf(velocity.x) else cfg.deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
	else:
		_jump_time = 0.0
		if blocked and movement_controller and movement_controller.request_jump():
			velocity.y = -cfg.jump_speed
			_jump_held = true
			_jump_time = 0.0
		elif movement_controller and movement_controller.update_stuck_timer(
			delta, true, absf(velocity.x), blocked
		) and movement_controller.request_jump():
			velocity.y = -cfg.jump_speed
			_jump_held = true
			_jump_time = 0.0
	if _jump_held and _jump_time <= cfg.jump_sustain_time and velocity.y < 0.0:
		_jump_time += delta
		velocity.y = -cfg.jump_speed
	else:
		_jump_held = false
	_try_mount_ladder()


func _process_ladder(delta: float) -> void:
	var cfg := _cfg()
	velocity = Vector2.ZERO
	velocity.y = -cfg.ladder_climbing_speed
	if not _overlaps_any_ladder():
		is_on_ladder = false


func _try_mount_ladder() -> void:
	if is_on_ladder:
		return
	if _overlaps_any_ladder():
		is_on_ladder = true
		velocity = Vector2.ZERO


func _overlaps_any_ladder() -> bool:
	for area in _ladder_areas:
		if area == null or not is_instance_valid(area):
			continue
		if area.overlaps_area(ladder_detector) or area.overlaps_body(self):
			return true
	return false


func _should_reverse(desired: int, blocked: bool) -> bool:
	if blocked:
		return true
	if desired > 0 and not floor_ray_right.is_colliding() and is_on_floor():
		return true
	if desired < 0 and not floor_ray_left.is_colliding() and is_on_floor():
		return true
	return false


func _is_blocked(desired: int) -> bool:
	if desired > 0:
		return wall_ray_right.is_colliding()
	if desired < 0:
		return wall_ray_left.is_colliding()
	return false


func _update_movement_state() -> void:
	var new_state: EnemyAnimation.MovementState
	if is_on_ladder:
		new_state = EnemyAnimation.MovementState.CLIMB
	elif not is_on_floor():
		new_state = (
			EnemyAnimation.MovementState.JUMP
			if velocity.y < 0.0
			else EnemyAnimation.MovementState.FALL
		)
	elif absf(velocity.x) > 8.0:
		new_state = EnemyAnimation.MovementState.RUN
	else:
		new_state = EnemyAnimation.MovementState.IDLE
	if new_state != movement_state:
		movement_state = new_state
		movement_state_changed.emit(movement_state)
	animation_controller.apply_state(movement_state, facing, _floor_distance)


func _update_floor_probe() -> void:
	if floor_probe.is_colliding():
		_floor_distance = global_position.distance_to(floor_probe.get_collision_point())
	else:
		_floor_distance = INF


func _setup_rays() -> void:
	for ray in [floor_ray_left, floor_ray_right, wall_ray_left, wall_ray_right, floor_probe]:
		if ray:
			ray.enabled = true
			ray.collision_mask = 1


func _apply_visual_profile() -> void:
	if visual_profile == null:
		visual_profile = load("res://resources/characters/enemy_visual.tres")
	if visual_profile == null:
		push_error("Enemy visual profile missing")
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
	var half_w := _display_size.x * 0.5
	var foot_y := _display_size.y
	floor_ray_left.position = Vector2(half_w - 14.0, foot_y)
	floor_ray_right.position = Vector2(half_w + 14.0, foot_y)
	floor_ray_left.target_position = Vector2(0, 36)
	floor_ray_right.target_position = Vector2(0, 36)
	wall_ray_left.position = Vector2(half_w - 10.0, foot_y - 24.0)
	wall_ray_right.position = Vector2(half_w + 10.0, foot_y - 24.0)
	wall_ray_left.target_position = Vector2(-22, 0)
	wall_ray_right.target_position = Vector2(22, 0)
	floor_probe.position = Vector2(half_w, foot_y)
	floor_probe.target_position = Vector2(0, 64)
	ladder_detector.position = Vector2(half_w, _display_size.y * 0.5)
	var ladder_shape := ladder_detector.get_node("CollisionShape2D").shape as RectangleShape2D
	if ladder_shape:
		ladder_shape.size = Vector2(_display_size.x * 0.45, _display_size.y * 0.75)


func _on_ladder_area_entered(_area: Area2D) -> void:
	pass


func _on_ladder_area_exited(_area: Area2D) -> void:
	pass


func _cfg() -> EnemyMovementConfig:
	if movement_config == null:
		movement_config = load("res://resources/enemy/enemy_movement_config.tres")
	return movement_config
