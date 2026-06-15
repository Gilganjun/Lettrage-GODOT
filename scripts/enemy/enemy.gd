class_name Enemy
extends CharacterBody2D

## Phase 2B2A movement + Phase 2B2B word collection and shield.

signal movement_state_changed(state: EnemyAnimation.MovementState)

@export var visual_profile: CharacterVisualProfile
@export var movement_config: EnemyMovementConfig
@export var obstacle_rng_seed: int = -1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_controller: EnemyAnimation = $AnimationController
@onready var movement_controller: EnemyMovementController = $EnemyMovementController
@onready var obstacle_sensor: Node = $ObstacleSensor
@onready var obstacle_response: EnemyObstacleResponse = $ObstacleResponse
@onready var word_controller: Node = $EnemyWordController
@onready var letter_targeting: Node = $EnemyLetterTargeting
@onready var letter_collector: Node = $EnemyLetterCollector
@onready var shield_controller: Node = $EnemyShieldController
@onready var shield_component: ShieldComponent = $ShieldComponent
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
var _spawn_position := Vector2(740.0, 406.0)
var _chase_hop_impulse := 0.0

const FLOOR_SNAP := 4.0
const RECOVER_MIN_Y := -80.0
const RECOVER_MAX_Y := 620.0
const RECOVER_MIN_X := 40.0
const RECOVER_MAX_X := 2400.0


func _ready() -> void:
	add_to_group("enemy")
	_apply_visual_profile()
	animation_controller.sprite = sprite
	_setup_rays()
	_setup_word_and_shield()
	obstacle_sensor.call("setup", self, _foot_y, _half_w)
	obstacle_response.setup(movement_controller, _cfg())
	if obstacle_rng_seed >= 0:
		obstacle_response.call("set_rng_seed", obstacle_rng_seed)
	ladder_detector.area_entered.connect(_on_ladder_area_entered)
	ladder_detector.area_exited.connect(_on_ladder_area_exited)
	if movement_controller:
		movement_controller.direction_changed.connect(func(_d): direction_changes += 1)


func _setup_word_and_shield() -> void:
	var hit_size := Vector2(36, 48)
	if collision_shape and collision_shape.shape is RectangleShape2D:
		hit_size = (collision_shape.shape as RectangleShape2D).size
	if shield_component:
		shield_component.owner_group = "enemy"
		shield_component.impact_source = "enemy_shield"
		var impact_sounds: Array[AudioStream] = [
			load("res://assets/463388__vilkas-sound__vs-pop-4.mp3") as AudioStream,
			load("res://assets/463389__vilkas-sound__vs-pop-3.mp3") as AudioStream,
		]
		shield_component.shield_impact_sounds = impact_sounds
		shield_component.impact_volume = ShieldComponent.PLAYER_BREAK_VOLUME
		if collision_shape:
			shield_component.position = collision_shape.position
		else:
			shield_component.position = Vector2(_half_w, _display_size.y * 0.45)
		shield_component.configure_body_shape(hit_size)
		shield_component.z_index = 20
	if shield_controller:
		shield_controller.setup(self, shield_component, letter_targeting)
	if letter_collector:
		letter_collector.word_controller = word_controller
		letter_collector.shield_component = shield_component
		if collision_shape:
			letter_collector.position = collision_shape.position
		else:
			letter_collector.position = Vector2(_half_w, _display_size.y * 0.45)
		var shape := letter_collector.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null:
			shape = CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = hit_size
			shape.shape = rect
			letter_collector.add_child(shape)
		elif collision_shape and collision_shape.shape is RectangleShape2D:
			var body_rect := collision_shape.shape as RectangleShape2D
			if shape.shape is RectangleShape2D:
				(shape.shape as RectangleShape2D).size = body_rect.size
		letter_collector.letter_collected.connect(_on_enemy_letter_collected)
	if word_controller:
		word_controller.collect_sound = load("res://assets/361334__spoonsandlessspoons__charge-up-shot.wav")
		word_controller.word_state.word_completed.connect(_on_enemy_word_completed)


func configure_from_gdevelop(row: Dictionary) -> void:
	global_position = Vector2(float(row.get("source_x", 740)), float(row.get("source_y", 406)))
	_spawn_position = global_position
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
	_setup_word_and_shield()
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


func get_word_controller() -> Node:
	return word_controller


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
	}
	if word_controller:
		info["enemy_word"] = word_controller.word_state.collected_letters
		info["enemy_target_word"] = word_controller.word_state.target_word
		info["enemy_score"] = word_controller.word_state.score
		info["enemy_needed_letter"] = word_controller.word_state.current_needed_letter()
		info["enemy_validation"] = word_controller.word_state.last_validation
	if shield_controller:
		info.merge(shield_controller.get_debug_info())
	if letter_targeting:
		info.merge(letter_targeting.get_debug_info(global_position))
	info.merge(obstacle_response.call("get_debug_info", _last_sensor) if obstacle_response else {})
	return info


func debug_force_shield(active: bool) -> void:
	if shield_controller:
		shield_controller.debug_force_shield(active)


func debug_clear_word() -> void:
	if word_controller:
		word_controller.debug_clear_word()
		letter_targeting.drop_target("debug_clear")


func debug_force_validation() -> void:
	if word_controller:
		word_controller.debug_force_validation()


func _physics_process(delta: float) -> void:
	var combat := get_node_or_null("CharacterCombat")
	if combat and combat.is_dead():
		velocity = Vector2.ZERO
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		return
	if combat and combat.blocks_ai():
		_process_combat_lock(delta)
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		_update_movement_state()
		return
	if movement_controller:
		movement_controller.tick(delta)
	_update_floor_probe()
	_tick_word_systems(delta)
	if is_on_ladder:
		_process_ladder(delta)
	else:
		_process_platformer(delta)
	move_and_slide()
	floor_snap_length = FLOOR_SNAP
	_recover_if_out_of_bounds()
	_update_movement_state()


func _tick_word_systems(delta: float) -> void:
	var combat := get_node_or_null("CharacterCombat")
	if combat and (combat.is_dead() or combat.blocks_ai()):
		return
	if shield_controller:
		shield_controller.tick(delta, global_position)
	if word_controller and letter_targeting:
		var needed: String = word_controller.word_state.current_needed_letter()
		var shield_blocks: bool = shield_component != null and shield_component.blocks_letter_collection()
		letter_targeting.tick(delta, global_position, needed, shield_blocks)


func _process_platformer(delta: float) -> void:
	var cfg := _cfg()
	var patrol_dir := movement_controller.get_desired_direction(global_position.x) if movement_controller else 1
	var chase_dir: int = letter_targeting.get_chase_direction(global_position) if letter_targeting else 0
	var desired := patrol_dir
	var obstacle_busy := (
		obstacle_response.encounter_active
		or obstacle_response.is_paused()
		or obstacle_response.is_jump_in_progress()
	)
	if chase_dir != 0 and not obstacle_busy:
		movement_controller.set_letter_chase_direction(chase_dir)
		desired = chase_dir
	elif not obstacle_busy:
		movement_controller.clear_letter_chase()
	if movement_controller and movement_controller.direction != 0 and chase_dir == 0:
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
	if (
		not obstacle_busy
		and chase_dir != 0
		and letter_targeting
		and letter_targeting.should_request_chase_jump(global_position, is_on_floor())
		and movement_controller.request_jump()
	):
		_chase_hop_impulse = 380.0
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
		var hop_impulse: float = obstacle_response.consume_jump_request()
		if hop_impulse <= 0.0 and _chase_hop_impulse > 0.0:
			hop_impulse = _chase_hop_impulse
			_chase_hop_impulse = 0.0
		if hop_impulse > 0.0:
			velocity.y = -hop_impulse
			_jump_held = false
			_jump_time = 0.0
	if _jump_held and _jump_time <= cfg.jump_sustain_time and velocity.y < 0.0:
		_jump_time += delta
		velocity.y = -cfg.jump_speed
	else:
		_jump_held = false
	_try_mount_ladder()


func _on_enemy_letter_collected(_letter: Letter, _character: String) -> void:
	if shield_controller:
		shield_controller.notify_letter_collected()
	if letter_targeting:
		letter_targeting.drop_target("collected")


func _on_enemy_word_completed(_word: String) -> void:
	if letter_targeting:
		letter_targeting.drop_target("word_complete")


func _process_ladder(_delta: float) -> void:
	var cfg := _cfg()
	velocity = Vector2.ZERO
	velocity.y = -cfg.ladder_climbing_speed
	if not _overlaps_any_ladder():
		is_on_ladder = false


func _process_combat_lock(delta: float) -> void:
	var cfg := _cfg()
	if not is_on_floor():
		velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
	else:
		velocity.y = 0.0
	velocity.x = move_toward(velocity.x, 0.0, cfg.deceleration * delta)


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
		get_node_or_null("LookAheadWallRay"),
		get_node_or_null("LookAheadFloorRay"),
		get_node_or_null("StepLandingRay"),
	]:
		if ray:
			ray.enabled = true
			ray.collision_mask = 1
			if ray is RayCast2D and (
				ray.name.begins_with("Wall")
				or ray.name.begins_with("LookAhead")
				or ray.name in ["FloorBeyondRay", "HeadClearanceRay", "StepLandingRay"]
			):
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


func _recover_if_out_of_bounds() -> void:
	var out_of_bounds := (
		global_position.y < RECOVER_MIN_Y
		or global_position.y > RECOVER_MAX_Y
		or global_position.x < RECOVER_MIN_X
		or global_position.x > RECOVER_MAX_X
	)
	if not out_of_bounds:
		return
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_jump_held = false
	is_on_ladder = false
	if movement_controller:
		movement_controller.configure_patrol(
			movement_controller.patrol_min_x,
			movement_controller.patrol_max_x,
			global_position.x,
		)
	if obstacle_response:
		obstacle_response.reset_after_recovery()


func _cfg() -> EnemyMovementConfig:
	if movement_config == null:
		movement_config = load("res://resources/enemy/enemy_movement_config.tres")
	return movement_config
