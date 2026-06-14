class_name Enemy
extends CharacterBody2D

## Phase 2B2A enemy foundation — patrol, obstacle escape, animation.

signal movement_state_changed(state: EnemyAnimation.MovementState)

@export var visual_profile: CharacterVisualProfile
@export var movement_config: EnemyMovementConfig
@export var obstacle_rng_seed: int = -1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_controller: EnemyAnimation = $AnimationController
@onready var movement_controller: EnemyMovementController = $EnemyMovementController
@onready var obstacle_sensor: Node = $ObstacleSensor
@onready var obstacle_response: Node = $ObstacleResponse
@onready var shield: Node = $Shield
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
var _foot_y := 116.0
var _half_w := 46.0
var _ladder_areas: Array[Area2D] = []
var _jump_time: float = 0.0
var _jump_held: bool = false
var _floor_distance: float = INF
var _last_sensor: Dictionary = {}

const FLOOR_SNAP := 4.0


func _ready() -> void:
	add_to_group("enemy")
	_apply_visual_profile()
	animation_controller.sprite = sprite
	_setup_rays()
	obstacle_sensor.call("setup", self, _foot_y, _half_w)
	obstacle_response.call("setup", movement_controller)
	if obstacle_rng_seed >= 0:
		obstacle_response.call("set_rng_seed", obstacle_rng_seed)
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
	obstacle_sensor.call("setup", self, _foot_y, _half_w)
	if movement_controller:
		movement_controller.configure_patrol(300.0, 2000.0, global_position.x)


func set_obstacle_rng_seed(seed_value: int) -> void:
	obstacle_rng_seed = seed_value
	if obstacle_response:
		obstacle_response.call("set_rng_seed", seed_value)


func register_ladder(area: Area2D) -> void:
	if area not in _ladder_areas:
		_ladder_areas.append(area)


func get_debug_info() -> Dictionary:
	var info := {
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
		"direction_changes": direction_changes,
		"floor_distance": _floor_distance,
		"shield_active": shield.get("is_active") if shield else false,
	}
	info.merge(obstacle_response.call("get_debug_info", _last_sensor) if obstacle_response else {})
	return info


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
	if movement_controller and movement_controller.direction != 0:
		desired = movement_controller.direction
	_last_sensor = obstacle_sensor.call("scan", desired)
	obstacle_response.call(
		"tick",
		delta,
		_last_sensor,
		global_position,
		is_on_floor(),
		not is_on_floor(),
		absf(velocity.x),
		desired,
	)
	if obstacle_response.call("is_paused"):
		velocity.x = move_toward(velocity.x, 0.0, cfg.deceleration * delta)
		if not is_on_floor():
			velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
		return
	var motion_dir := desired
	if movement_controller and movement_controller.direction != 0:
		motion_dir = movement_controller.direction
	facing = motion_dir if motion_dir != 0 else facing
	var target_speed := float(motion_dir) * cfg.max_speed
	var rate := cfg.acceleration if absf(target_speed) > absf(velocity.x) else cfg.deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
	else:
		_jump_time = 0.0
		if obstacle_response.call("consume_jump_request"):
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
	elif obstacle_response.call("is_paused"):
		new_state = EnemyAnimation.MovementState.IDLE
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
	for ray in [
		floor_ray_left,
		floor_ray_right,
		wall_ray_left,
		wall_ray_right,
		floor_probe,
		get_node_or_null("FloorBeyondRay"),
		get_node_or_null("HeadClearanceRay"),
	]:
		if ray:
			ray.enabled = true
			ray.collision_mask = 1
			if ray is RayCast2D and ray.name.begins_with("Wall") or ray.name == "FloorBeyondRay" or ray.name == "HeadClearanceRay":
				ray.hit_from_inside = true


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
	_half_w = _display_size.x * 0.5
	_foot_y = _display_size.y
	rect.size = Vector2(_display_size.x * 0.56, _display_size.y * 0.86)
	collision_shape.position = Vector2(_half_w, _display_size.y - rect.size.y * 0.5)
	floor_ray_left.position = Vector2(_half_w - 14.0, _foot_y)
	floor_ray_right.position = Vector2(_half_w + 14.0, _foot_y)
	floor_ray_left.target_position = Vector2(0, 36)
	floor_ray_right.target_position = Vector2(0, 36)
	wall_ray_left.position = Vector2(_half_w - 10.0, _foot_y - 24.0)
	wall_ray_right.position = Vector2(_half_w + 10.0, _foot_y - 24.0)
	wall_ray_left.target_position = Vector2(-22, 0)
	wall_ray_right.target_position = Vector2(22, 0)
	floor_probe.position = Vector2(_half_w, _foot_y)
	floor_probe.target_position = Vector2(0, 64)
	ladder_detector.position = Vector2(_half_w, _display_size.y * 0.5)
	var ladder_shape := ladder_detector.get_node("CollisionShape2D").shape as RectangleShape2D
	if ladder_shape:
		ladder_shape.size = Vector2(_display_size.x * 0.45, _display_size.y * 0.75)
	var beyond := get_node_or_null("FloorBeyondRay") as RayCast2D
	if beyond:
		beyond.target_position = Vector2(0, 110)
	var head := get_node_or_null("HeadClearanceRay") as RayCast2D
	if head:
		head.position = Vector2(_half_w, _foot_y - 120.0)
		head.target_position = Vector2(42, 0)


func _on_ladder_area_entered(_area: Area2D) -> void:
	pass


func _on_ladder_area_exited(_area: Area2D) -> void:
	pass


func _cfg() -> EnemyMovementConfig:
	if movement_config == null:
		movement_config = load("res://resources/enemy/enemy_movement_config.tres")
	return movement_config
