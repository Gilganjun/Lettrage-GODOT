class_name Enemy
extends CharacterBody2D

## Phase 2B2A movement + Phase 2B2B word collection and shield.

const EnemyActionControllerScript := preload("res://scripts/enemy/enemy_action_controller.gd")

signal movement_state_changed(state: EnemyAnimation.MovementState)

@export var visual_profile: CharacterVisualProfile
@export var movement_config: EnemyMovementConfig
@export var obstacle_rng_seed: int = -1
@export var ambient_idle_enabled := false
@export var ambient_idle_min_interval := 55.0
@export var ambient_idle_max_interval := 65.0
@export var ambient_idle_duration := 5.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_controller: EnemyAnimation = $AnimationController
@onready var movement_controller: EnemyMovementController = $EnemyMovementController
@onready var obstacle_sensor: Node = $ObstacleSensor
@onready var obstacle_response: EnemyObstacleResponse = $ObstacleResponse
@onready var word_controller: EnemyWordController = $EnemyWordController
@onready var letter_targeting: EnemyLetterTargeting = $EnemyLetterTargeting
@onready var letter_collector: EnemyLetterCollector = $EnemyLetterCollector
@onready var shield_controller: EnemyShieldController = $EnemyShieldController
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
var _ambient_idle_remaining := 0.0
var _ambient_idle_deadline := 0.0
var _air_jumps_remaining := 0
var _letter_shooter: EnemyLetterShooter
var _action_sequence_targeted := false
var _action_strike_frozen := false
var _action_freeze_position := Vector2.ZERO
var movement_locked := false
var _idle_stuck_timer := 0.0
var _action_controller: Node
var _action_approach_stuck_time := 0.0
var _action_impact_sync: RefCounted
var _action_facing_locked := false
var _action_facing_target: Node2D
var _action_defender_facing_hold := false
var _finisher_survivor_active := false
var _finisher_victim: Node2D = null
var _finisher_arrived := false

const IDLE_STUCK_RESUME_SECONDS := 1.75
const IDLE_VELOCITY_EPSILON := 2.0
const EnemyActionImpactSyncScript := preload("res://scripts/enemy/enemy_action_impact_sync.gd")

const FLOOR_SNAP := 4.0
const MAX_AIR_JUMPS := 1
const CHASE_HOP_IMPULSE := 440.0
const ICON_HOP_IMPULSE := 500.0
const MAX_JUMP_IMPULSE := 920.0
const RECOVER_MIN_Y := -80.0
const RECOVER_MAX_Y := 620.0
const RECOVER_MIN_X := 40.0
const RECOVER_MAX_X := 2400.0
const RECOVER_CATASTROPHIC_MIN_Y := -520.0
const RECOVER_CATASTROPHIC_MAX_Y := 720.0
const RECOVER_CATASTROPHIC_X_MARGIN := 120.0


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
	if ambient_idle_enabled:
		_schedule_ambient_idle()
	_action_impact_sync = EnemyActionImpactSyncScript.new()


func _setup_word_and_shield() -> void:
	var shield_size := _shield_body_size()
	var collector_size := shield_size
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collector_size = (collision_shape.shape as RectangleShape2D).size
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
			shield_component.position = Vector2(_half_w, _foot_y - shield_size.y * 0.5)
		else:
			shield_component.position = Vector2(_half_w, _display_size.y * 0.45)
		shield_component.configure_body_shape(shield_size)
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
			rect.size = collector_size
			shape.shape = rect
			letter_collector.add_child(shape)
		elif shape.shape is RectangleShape2D:
			(shape.shape as RectangleShape2D).size = collector_size
		if not letter_collector.letter_collected.is_connected(_on_enemy_letter_collected):
			letter_collector.letter_collected.connect(_on_enemy_letter_collected)
	if word_controller:
		word_controller.collect_sound = load("res://assets/361334__spoonsandlessspoons__charge-up-shot.wav")
		if not word_controller.word_state.word_completed.is_connected(_on_enemy_word_completed):
			word_controller.word_state.word_completed.connect(_on_enemy_word_completed)
	_setup_letter_shooter()
	_setup_action_controller()


func _setup_action_controller() -> void:
	_action_controller = EnemyActionControllerScript.new()
	add_child(_action_controller)
	if _action_controller.has_signal("action_sequence_finished"):
		_action_controller.action_sequence_finished.connect(_on_enemy_action_sequence_finished)


func _on_enemy_action_sequence_finished() -> void:
	_action_approach_stuck_time = 0.0
	refresh_movement_animation()


func get_action_controller() -> Node:
	return _action_controller


func get_action_pickup_point() -> Vector2:
	return global_position + Vector2(_half_w, _foot_y * 0.55)


func tick_action_approach_movement(delta: float, direction: int, run_speed: float) -> void:
	var cfg := _cfg()
	if direction == 0:
		_stop_horizontal_on_floor(delta)
		if not is_on_floor():
			velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
		return
	facing = direction
	var sensor: Dictionary = obstacle_sensor.call("scan", direction)
	var blocked := (
		bool(sensor.get("blocked_wall", false))
		or bool(sensor.get("ahead_obstacle", false))
	)
	var jumpable := bool(sensor.get("jumpable", false))
	var obstacle_dist := float(sensor.get("distance_to_obstacle", INF))
	velocity.x = float(direction) * run_speed
	if is_on_floor():
		velocity.y = 0.0
		if blocked:
			_action_approach_stuck_time += delta
		else:
			_action_approach_stuck_time = 0.0
		var should_jump := blocked and (
			jumpable
			or obstacle_dist <= 96.0
			or _action_approach_stuck_time >= 0.3
		)
		if should_jump and movement_controller and movement_controller.request_jump():
			var step_h := maxf(float(sensor.get("obstacle_height", 0.0)), 22.0)
			_apply_jump_impulse(_compute_obstacle_hop_speed(step_h), false)
			_action_approach_stuck_time = 0.0
	else:
		velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)


func refresh_movement_animation() -> void:
	_update_movement_state()
	if animation_controller == null:
		return
	animation_controller.force_apply_state(movement_state, facing, _floor_distance)


func _shield_body_size() -> Vector2:
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var col := (collision_shape.shape as RectangleShape2D).size
		# Torso-only rect — same wrap style as player shield, not full physics padding.
		return Vector2(col.x * 0.72, col.y * 0.52)
	if _display_size.x <= 0.0 or _foot_y <= 0.0:
		return Vector2(36, 48)
	return Vector2(_display_size.x * 0.40, _foot_y * 0.45)


func _setup_letter_shooter() -> void:
	_letter_shooter = EnemyLetterShooter.new()
	_letter_shooter.word_controller = word_controller
	_letter_shooter.shield_component = shield_component
	_letter_shooter.letter_targeting = letter_targeting
	if collision_shape:
		_letter_shooter.sync_to_body(collision_shape.position)
	else:
		_letter_shooter.sync_to_body(Vector2(_half_w, _display_size.y * 0.45))
	add_child(_letter_shooter)


func configure_from_gdevelop(row: Dictionary) -> void:
	global_position = Vector2(float(row.get("source_x", 740)), float(row.get("source_y", 406)))
	_spawn_position = global_position
	_display_size = Vector2(float(row.get("display_width", 93)), float(row.get("display_height", 116)))
	if visual_profile and visual_profile.graphics_scale_multiplier > 0.0:
		_display_size *= visual_profile.graphics_scale_multiplier
	if visual_profile == null:
		visual_profile = load("res://resources/characters/enemy_visual.tres")
	if visual_profile == null:
		return
	sprite.sprite_frames = visual_profile.sprite_frames
	sprite.modulate = visual_profile.modulate
	sprite.play("Idle")
	var native_w := float(row.get("native_width", 145))
	var native_h := float(row.get("native_height", 191))
	if visual_profile.native_width_override > 0.0:
		native_w = visual_profile.native_width_override
	if visual_profile.native_height_override > 0.0:
		native_h = visual_profile.native_height_override
	GDevelopTransform.apply_to_animated_sprite(
		sprite,
		float(row["source_x"]),
		float(row["source_y"]),
		float(row.get("origin_x", 0)),
		float(row.get("origin_y", 0)),
		_display_size.x,
		_display_size.y,
		native_w,
		native_h,
		1.0,
		float(row.get("source_angle", 0)),
	)
	_apply_profile_sprite_scale(native_w, native_h)
	_align_collision_to_visual()
	_setup_word_and_shield()
	obstacle_sensor.call("setup", self, _foot_y, _half_w)
	if movement_controller:
		movement_controller.configure_patrol(300.0, 2000.0, global_position.x)
		if row.has("debug_initial_direction"):
			movement_controller.set_direction(int(row["debug_initial_direction"]))
		if row.has("debug_patrol_target_x"):
			movement_controller.target_x = float(row["debug_patrol_target_x"])


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
	if ambient_idle_enabled:
		info["ambient_idle_active"] = _is_ambient_idle_active()
		info["ambient_idle_remaining"] = _ambient_idle_remaining
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


func set_action_sequence_targeted(active: bool) -> void:
	_action_sequence_targeted = active
	if active:
		refresh_action_facing_lock()
	else:
		_action_defender_facing_hold = false
		unlock_action_facing()
		end_action_strike_freeze()
		_end_action_impact_sync_after_sequence()


func _end_action_impact_sync_after_sequence() -> void:
	if _combat_owns_sprite_presentation():
		end_action_impact_sync_for_finisher()
	else:
		end_action_impact_sync()


func _combat_owns_sprite_presentation() -> bool:
	var combat := get_node_or_null("CharacterCombat")
	if combat is CharacterCombat:
		return (combat as CharacterCombat).owns_action_sprite_presentation()
	return false


func is_action_sequence_targeted() -> bool:
	return _action_sequence_targeted


func lock_action_facing_toward(target: Node2D) -> void:
	_action_facing_locked = true
	_action_facing_target = target
	refresh_action_facing_lock()


func unlock_action_facing() -> void:
	_action_facing_locked = false
	_action_facing_target = null
	_action_defender_facing_hold = false


func set_action_defender_facing_hold(hold: bool) -> void:
	_action_defender_facing_hold = hold


func refresh_action_facing_lock() -> void:
	if not _action_facing_locked or _action_facing_target == null:
		return
	if _action_defender_facing_hold:
		return
	facing = 1 if _action_facing_target.global_position.x >= global_position.x else -1
	if sprite:
		sprite.flip_h = facing < 0


func _impact_sync() -> RefCounted:
	if _action_impact_sync == null:
		_action_impact_sync = EnemyActionImpactSyncScript.new()
	return _action_impact_sync


func begin_action_impact_sync(attack: ActionAttackDefinition) -> void:
	refresh_action_facing_lock()
	_impact_sync().begin(attack)
	if sprite:
		_impact_sync().tick(sprite, 1, facing)


func tick_action_impact_sync(player_attack_frame: int) -> void:
	if not _impact_sync().is_active() or sprite == null:
		return
	if _combat_owns_sprite_presentation():
		end_action_impact_sync_for_finisher()
		return
	refresh_action_facing_lock()
	_impact_sync().tick(sprite, player_attack_frame, facing)


func notify_action_impact_hit(hit_idx: int, total_hits: int) -> void:
	if sprite:
		_impact_sync().notify_hit_landed(sprite, hit_idx, total_hits)


func freeze_action_impact_after_block() -> void:
	_impact_sync().freeze_after_block()


func end_action_impact_sync() -> void:
	_impact_sync().end()
	if _combat_owns_sprite_presentation():
		return
	if animation_controller and sprite:
		animation_controller.force_apply_state(movement_state, facing, _floor_distance)


func end_action_impact_sync_for_finisher() -> void:
	## Stop Impact poses so Death / finisher reactions can own the sprite.
	_impact_sync().end()


func begin_action_strike_freeze() -> void:
	_action_strike_frozen = true
	_action_freeze_position = global_position
	velocity = Vector2.ZERO


func end_action_strike_freeze() -> void:
	_action_strike_frozen = false


func is_action_strike_frozen() -> bool:
	return _action_strike_frozen


func begin_finisher_survivor_pose(victim: Node2D) -> void:
	if not _is_defeated_fighter(victim):
		return
	_finisher_survivor_active = true
	_finisher_victim = victim
	_finisher_arrived = false
	movement_locked = true
	_action_strike_frozen = false
	_action_sequence_targeted = false
	_action_facing_locked = false
	_action_facing_target = null
	velocity = Vector2.ZERO
	if movement_controller:
		movement_controller.clear_letter_chase()


func end_finisher_survivor_pose() -> void:
	_finisher_survivor_active = false
	_finisher_victim = null
	_finisher_arrived = false
	velocity = Vector2.ZERO


func is_finisher_survivor_active() -> bool:
	return _finisher_survivor_active


func _physics_process(delta: float) -> void:
	var combat := get_node_or_null("CharacterCombat")
	if combat is CharacterCombat and (combat as CharacterCombat).is_dead():
		velocity = Vector2.ZERO
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		return
	# Finish an in-flight action even when round-end pause locks movement.
	if _action_controller and _action_controller.process_action(self, delta):
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		_update_movement_state()
		return
	if _finisher_survivor_active:
		_process_finisher_survivor(delta)
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		return
	if _action_strike_frozen:
		global_position = _action_freeze_position
		velocity = Vector2.ZERO
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		if not _combat_owns_sprite_presentation():
			_update_movement_state()
		return
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		_update_movement_state()
		return
	if combat and combat.blocks_ai():
		_process_combat_lock(delta)
		move_and_slide()
		floor_snap_length = FLOOR_SNAP
		_update_movement_state()
		return
	if _action_controller:
		_action_controller.process_action(self, delta)
	if movement_controller:
		movement_controller.tick(delta)
	_tick_ambient_idle(delta)
	_update_floor_probe()
	_tick_word_systems(delta)
	if is_on_ladder:
		_process_ladder(delta)
	else:
		_process_platformer(delta)
	move_and_slide()
	floor_snap_length = FLOOR_SNAP
	_recover_if_out_of_bounds()
	_tick_idle_resume_watchdog(delta)
	_update_movement_state()


func _tick_word_systems(delta: float) -> void:
	var combat := get_node_or_null("CharacterCombat")
	if combat and (combat.is_dead() or combat.blocks_ai()):
		return
	if _action_controller and _action_controller.blocks_ai():
		return
	if word_controller and letter_targeting:
		var needed: String = word_controller.word_state.current_needed_letter()
		var shield_blocks: bool = shield_component != null and shield_component.blocks_letter_collection()
		letter_targeting.tick(delta, global_position, needed, shield_blocks)
	if shield_controller:
		shield_controller.tick(delta, global_position)
	if _letter_shooter:
		var blocked: bool = combat is CharacterCombat and (
			(combat as CharacterCombat).is_dead()
			or (combat as CharacterCombat).blocks_ai()
			or (combat as CharacterCombat).blocks_collection()
		)
		_letter_shooter.tick(delta, global_position, facing, blocked)


func _process_platformer(delta: float) -> void:
	var cfg := _cfg()
	if _is_ambient_idle_active():
		_stop_horizontal_on_floor(delta)
		if not is_on_floor():
			velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
		return
	var chase_dir: int = 0
	var icon_chase_active := false
	var icon_chase_jump := false
	var pickup_pt := get_action_pickup_point()
	if _action_controller:
		icon_chase_active = _action_controller.is_icon_chase_active(pickup_pt, cfg.max_speed)
		if icon_chase_active and _action_controller.should_jump_for_icon(pickup_pt):
			icon_chase_jump = true
		elif icon_chase_active:
			chase_dir = _action_controller.get_icon_chase_direction(pickup_pt, cfg.max_speed)
	if chase_dir == 0 and letter_targeting:
		chase_dir = letter_targeting.get_chase_direction(global_position)
	var patrol_dir := movement_controller.get_desired_direction(global_position.x) if movement_controller else 1
	var desired := patrol_dir
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
	var obstacle_busy := (
		obstacle_response.encounter_active
		or obstacle_response.is_paused()
		or obstacle_response.is_jump_in_progress()
	)
	if chase_dir != 0 and not obstacle_busy:
		movement_controller.set_letter_chase_direction(chase_dir)
		desired = chase_dir
	elif icon_chase_active and movement_controller:
		movement_controller.clear_letter_chase()
		patrol_dir = 0
		desired = 0
	else:
		if movement_controller:
			movement_controller.clear_letter_chase()
		patrol_dir = movement_controller.get_desired_direction(global_position.x) if movement_controller else 0
		desired = patrol_dir
	if obstacle_response.call("is_paused"):
		_stop_horizontal_on_floor(delta)
		if not is_on_floor():
			velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
		return
	var motion_dir := _compute_horizontal_motion_dir(chase_dir, patrol_dir, obstacle_busy)
	if icon_chase_jump:
		motion_dir = 0
	if (
		not obstacle_busy
		and not icon_chase_jump
		and chase_dir != 0
		and letter_targeting
		and letter_targeting.should_request_chase_jump(global_position, is_on_floor())
		and movement_controller.request_chase_jump()
	):
		_chase_hop_impulse = CHASE_HOP_IMPULSE
	if icon_chase_jump and is_on_floor() and movement_controller.request_chase_jump():
		_chase_hop_impulse = ICON_HOP_IMPULSE
	if motion_dir == 0 and is_on_floor():
		_stop_horizontal_on_floor(delta)
	elif motion_dir != 0:
		facing = motion_dir
		var target_speed := float(motion_dir) * cfg.max_speed
		var rate := cfg.acceleration if absf(target_speed) > absf(velocity.x) else cfg.deceleration
		velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
	else:
		_jump_time = 0.0
		_air_jumps_remaining = MAX_AIR_JUMPS
		var hop_impulse: float = obstacle_response.consume_jump_request()
		if hop_impulse <= 0.0 and _chase_hop_impulse > 0.0:
			hop_impulse = _chase_hop_impulse
			_chase_hop_impulse = 0.0
		if hop_impulse > 0.0:
			_apply_jump_impulse(hop_impulse, false)
	if _jump_held and _jump_time <= cfg.jump_sustain_time and velocity.y < 0.0:
		_jump_time += delta
		velocity.y = -minf(cfg.jump_speed, MAX_JUMP_IMPULSE)
	else:
		_jump_held = false
	_try_intelligent_double_jump(cfg)
	_try_mount_ladder()


func _compute_horizontal_motion_dir(chase_dir: int, patrol_dir: int, obstacle_busy: bool) -> int:
	if _is_ambient_idle_active() or obstacle_response.call("is_paused"):
		return 0
	if chase_dir != 0 and not obstacle_busy:
		return chase_dir
	return patrol_dir


func _stop_horizontal_on_floor(delta: float) -> void:
	if not is_on_floor():
		return
	var cfg := _cfg()
	velocity.x = move_toward(velocity.x, 0.0, cfg.deceleration * delta * 3.0)
	if absf(velocity.x) < IDLE_VELOCITY_EPSILON:
		velocity.x = 0.0


func _refresh_patrol_direction() -> int:
	if movement_controller == null:
		return 0
	if movement_controller.letter_chase_active:
		movement_controller.clear_letter_chase()
	return movement_controller.get_desired_direction(global_position.x)


func _tick_idle_resume_watchdog(delta: float) -> void:
	if not is_on_floor() or _is_ambient_idle_active():
		_idle_stuck_timer = 0.0
		return
	if obstacle_response.call("is_paused") or obstacle_response.encounter_active:
		_idle_stuck_timer = 0.0
		return
	var combat := get_node_or_null("CharacterCombat")
	if combat and combat.blocks_ai():
		_idle_stuck_timer = 0.0
		return
	if movement_state != EnemyAnimation.MovementState.IDLE:
		_idle_stuck_timer = 0.0
		return
	if _compute_horizontal_motion_dir(
		letter_targeting.get_chase_direction(global_position) if letter_targeting else 0,
		_refresh_patrol_direction(),
		obstacle_response.encounter_active
		or obstacle_response.is_paused()
		or obstacle_response.is_jump_in_progress(),
	) != 0:
		_idle_stuck_timer = 0.0
		return
	_idle_stuck_timer += delta
	if _idle_stuck_timer < IDLE_STUCK_RESUME_SECONDS:
		return
	_idle_stuck_timer = 0.0
	if movement_controller:
		movement_controller.force_resume_patrol(global_position.x)


func _on_enemy_letter_collected(_letter: Letter, _character: String) -> void:
	if shield_controller:
		shield_controller.notify_letter_collected()
	if letter_targeting:
		letter_targeting.drop_target("collected")


func _on_enemy_word_completed(_word: String) -> void:
	if letter_targeting:
		letter_targeting.drop_target("word_complete")


func _try_intelligent_double_jump(cfg: EnemyMovementConfig) -> void:
	if is_on_floor() or _air_jumps_remaining <= 0:
		return
	if velocity.y < -cfg.jump_speed * 0.35:
		return
	if letter_targeting == null:
		return
	var target: Letter = letter_targeting.get_valid_target()
	if target == null:
		return
	var to_target: Vector2 = target.global_position - global_position
	if to_target.y >= -48.0 or absf(to_target.x) > 180.0:
		return
	_air_jumps_remaining -= 1
	_apply_jump_impulse(cfg.jump_speed * 0.72, false)


func _apply_jump_impulse(impulse: float, allow_sustain: bool) -> void:
	velocity.y = -minf(maxf(impulse, 0.0), MAX_JUMP_IMPULSE)
	_jump_held = allow_sustain
	_jump_time = 0.0


func _compute_obstacle_hop_speed(step_height: float) -> float:
	var cfg := _cfg()
	var target_height := maxf(step_height + 14.0, 26.0)
	var speed := sqrt(2.0 * cfg.gravity * target_height)
	return clampf(speed, 380.0, MAX_JUMP_IMPULSE)


func _process_ladder(_delta: float) -> void:
	var cfg := _cfg()
	velocity = Vector2.ZERO
	velocity.y = -cfg.ladder_climbing_speed
	if not _overlaps_any_ladder():
		is_on_ladder = false


func _process_combat_lock(delta: float) -> void:
	var cfg := _cfg()
	var combat := get_node_or_null("CharacterCombat")
	if combat and combat.has_method("is_stun_position_locked") and combat.is_stun_position_locked():
		global_position.x = combat.get_stun_locked_x()
		if combat.has_method("is_stun_grounded") and combat.is_stun_grounded():
			velocity = Vector2.ZERO
		else:
			velocity.x = 0.0
			velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_falling_speed)
		return
	var slide := Vector2.ZERO
	if combat and combat.has_method("compute_stun_slide_velocity"):
		slide = combat.compute_stun_slide_velocity()
	if combat and combat.has_method("is_enemy_stun_active") and combat.is_enemy_stun_active() and slide == Vector2.ZERO:
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


func _process_finisher_survivor(delta: float) -> void:
	if not _is_defeated_fighter(_finisher_victim):
		end_finisher_survivor_pose()
		return
	var cfg := _cfg()
	var motion := FinisherSurvivorPose.compute_motion(
		self,
		_finisher_victim,
		delta,
		cfg.max_speed,
		cfg.gravity,
		cfg.max_falling_speed,
		is_on_floor(),
	)
	velocity = motion.get("velocity", Vector2.ZERO)
	facing = int(motion.get("facing", facing))
	_finisher_arrived = bool(motion.get("arrived", true))
	if sprite:
		sprite.flip_h = facing < 0
	_update_finisher_survivor_animation()


func _update_finisher_survivor_animation() -> void:
	var new_state := EnemyAnimation.MovementState.IDLE
	if not _finisher_arrived and absf(velocity.x) > 8.0:
		new_state = EnemyAnimation.MovementState.RUN
	elif not is_on_floor():
		new_state = (
			EnemyAnimation.MovementState.JUMP
			if velocity.y < -40.0
			else EnemyAnimation.MovementState.FALL
		)
	if new_state != movement_state:
		movement_state = new_state
		movement_state_changed.emit(movement_state)
	animation_controller.force_apply_state(movement_state, facing, _floor_distance)


func _is_defeated_fighter(body: Node2D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	var combat := body.get_node_or_null("CharacterCombat")
	if combat is CharacterCombat:
		var cc := combat as CharacterCombat
		return cc.is_dead() or cc.has_pending_action_death()
	return false


func _update_movement_state() -> void:
	if _finisher_survivor_active:
		_update_finisher_survivor_animation()
		return
	if _combat_owns_sprite_presentation():
		return
	if _action_controller and _action_controller.is_active():
		return
	if _impact_sync().is_active():
		return
	if _action_strike_frozen or _action_sequence_targeted:
		return
	var combat := get_node_or_null("CharacterCombat")
	if combat and combat.has_method("is_enemy_stun_active") and combat.is_enemy_stun_active():
		return
	var patrol_dir := _refresh_patrol_direction()
	var chase_dir := letter_targeting.get_chase_direction(global_position) if letter_targeting else 0
	var obstacle_busy := (
		obstacle_response.encounter_active
		or obstacle_response.is_paused()
		or obstacle_response.is_jump_in_progress()
	)
	var move_intent := _compute_horizontal_motion_dir(chase_dir, patrol_dir, obstacle_busy)
	var new_state: EnemyAnimation.MovementState
	if is_on_ladder:
		new_state = EnemyAnimation.MovementState.CLIMB
	elif not is_on_floor():
		new_state = (
			EnemyAnimation.MovementState.JUMP
			if velocity.y < -40.0
			else EnemyAnimation.MovementState.FALL
		)
	elif _is_ambient_idle_active() or obstacle_response.call("is_paused"):
		new_state = EnemyAnimation.MovementState.IDLE
	elif move_intent != 0 or absf(velocity.x) > IDLE_VELOCITY_EPSILON:
		new_state = EnemyAnimation.MovementState.RUN
	else:
		new_state = EnemyAnimation.MovementState.IDLE
	if new_state == EnemyAnimation.MovementState.IDLE and is_on_floor() and move_intent == 0:
		velocity.x = 0.0
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


func _apply_profile_sprite_scale(native_w: float, native_h: float) -> void:
	if visual_profile == null or sprite == null or native_h <= 0.0 or native_w <= 0.0:
		return
	if visual_profile.use_proportional_sprite_scale:
		var uniform := _display_size.y / native_h
		sprite.scale = Vector2(uniform, uniform)
	else:
		sprite.scale = GDevelopTransform.compute_scale(
			_display_size.x,
			_display_size.y,
			native_w,
			native_h,
		)
	if visual_profile.sprite_width_scale_multiplier != 1.0:
		sprite.scale.x *= visual_profile.sprite_width_scale_multiplier
	_display_size = Vector2(native_w * sprite.scale.x, native_h * sprite.scale.y)


func _align_collision_to_visual() -> void:
	var rect := collision_shape.shape as RectangleShape2D
	if rect == null:
		return
	_half_w = _display_size.x * 0.5
	_foot_y = _resolve_foot_y()
	rect.size = Vector2(_display_size.x * 0.56, _foot_y * 0.86)
	collision_shape.position = Vector2(_half_w, _foot_y - rect.size.y * 0.5)
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
	ladder_detector.position = Vector2(_half_w, _foot_y * 0.5)
	var ladder_shape := ladder_detector.get_node("CollisionShape2D").shape as RectangleShape2D
	if ladder_shape:
		ladder_shape.size = Vector2(_display_size.x * 0.45, _foot_y * 0.75)
	var beyond := get_node_or_null("FloorBeyondRay") as RayCast2D
	if beyond:
		beyond.position = Vector2(_half_w, _foot_y)
		beyond.target_position = Vector2(0, 110)
	var look_floor := get_node_or_null("LookAheadFloorRay") as RayCast2D
	if look_floor:
		look_floor.position = Vector2(_half_w + 72.0, _foot_y)
	var step := get_node_or_null("StepLandingRay") as RayCast2D
	if step:
		step.position = Vector2(_half_w, _foot_y)
	var head := get_node_or_null("HeadClearanceRay") as RayCast2D
	if head:
		head.position = Vector2(_half_w, _foot_y - 120.0)
		head.target_position = Vector2(42, 0)


func _resolve_foot_y() -> float:
	if visual_profile == null:
		return _display_size.y
	var native_h := visual_profile.native_height_override
	if native_h <= 0.0:
		return _display_size.y
	if visual_profile.native_foot_y > 0.0:
		return _display_size.y * clampf(visual_profile.native_foot_y / native_h, 0.1, 1.0)
	return _display_size.y


func _on_ladder_area_entered(_area: Area2D) -> void:
	pass


func _on_ladder_area_exited(_area: Area2D) -> void:
	pass


func _recover_if_out_of_bounds() -> void:
	var mildly_out := (
		global_position.y < RECOVER_MIN_Y
		or global_position.y > RECOVER_MAX_Y
		or global_position.x < RECOVER_MIN_X
		or global_position.x > RECOVER_MAX_X
	)
	var catastrophically_out := (
		global_position.y < RECOVER_CATASTROPHIC_MIN_Y
		or global_position.y > RECOVER_CATASTROPHIC_MAX_Y
		or global_position.x < RECOVER_MIN_X - RECOVER_CATASTROPHIC_X_MARGIN
		or global_position.x > RECOVER_MAX_X + RECOVER_CATASTROPHIC_X_MARGIN
	)
	if not mildly_out and not catastrophically_out:
		return
	# High jumps are valid — do not teleport mid-air back to spawn.
	if not catastrophically_out and not is_on_floor():
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


func _schedule_ambient_idle() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_ambient_idle_deadline = now + randf_range(ambient_idle_min_interval, ambient_idle_max_interval)


func _tick_ambient_idle(delta: float) -> void:
	if not ambient_idle_enabled:
		return
	if _ambient_idle_remaining > 0.0:
		_ambient_idle_remaining = maxf(0.0, _ambient_idle_remaining - delta)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _ambient_idle_deadline:
		_ambient_idle_remaining = ambient_idle_duration
		_schedule_ambient_idle()


func _is_ambient_idle_active() -> bool:
	return ambient_idle_enabled and _ambient_idle_remaining > 0.0
