class_name FinisherSurvivorPose
extends RefCounted

## Scripted walk + idle beside the defeated fighter during finisher kill-cam.

const STAND_SPACING := 58.0
const ARRIVE_EPSILON := 8.0
const WALK_SPEED_SCALE := 0.48


static func arm(ctx: Dictionary, victim: Node2D) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	var player: Node = ctx.get("player")
	var enemy: Node = ctx.get("enemy")
	var survivor: Node2D = enemy if victim == player else player
	if survivor == null or not is_instance_valid(survivor):
		return
	_prepare_survivor(ctx, survivor, victim)
	_begin_survivor_pose_when_ready(ctx, survivor, victim)


static func release(ctx: Dictionary) -> void:
	for key in ["player", "enemy"]:
		var body: Node = ctx.get(key)
		if body and body.has_method("end_finisher_survivor_pose"):
			body.end_finisher_survivor_pose()


static func compute_motion(
	survivor: Node2D,
	victim: Node2D,
	delta: float,
	max_speed: float,
	gravity: float,
	max_fall_speed: float,
	is_on_floor: bool,
) -> Dictionary:
	var result := {
		"velocity": Vector2.ZERO,
		"facing": 1,
		"arrived": true,
	}
	if survivor == null or victim == null or not is_instance_valid(victim):
		return result
	var side := signf(survivor.global_position.x - victim.global_position.x)
	if side == 0.0:
		side = 1.0 if survivor.global_position.x <= victim.global_position.x else -1.0
	var target_x := victim.global_position.x + side * STAND_SPACING
	var dx := target_x - survivor.global_position.x
	var velocity := Vector2.ZERO
	var arrived := absf(dx) <= ARRIVE_EPSILON
	if arrived:
		velocity.x = 0.0
		result["facing"] = 1 if victim.global_position.x >= survivor.global_position.x else -1
	else:
		velocity.x = signf(dx) * maxf(max_speed * WALK_SPEED_SCALE, 24.0)
		result["facing"] = 1 if dx > 0.0 else -1
	if is_on_floor:
		velocity.y = 0.0
	else:
		velocity.y = minf(survivor.velocity.y + gravity * delta, max_fall_speed)
	result["velocity"] = velocity
	result["arrived"] = arrived
	return result


static func _prepare_survivor(ctx: Dictionary, survivor: Node2D, victim: Node2D) -> void:
	var player: Node = ctx.get("player")
	var enemy: Node = ctx.get("enemy")
	# Only stop the defeated fighter's action — never abort the survivor mid-strike.
	if victim == player:
		var player_action: Node = ctx.get("player_action")
		if player_action and player_action.has_method("abort_for_finisher_survivor"):
			player_action.abort_for_finisher_survivor()
	elif victim == enemy and enemy != null and enemy.has_method("get_action_controller"):
		var enemy_action: Node = enemy.get_action_controller()
		if enemy_action and enemy_action.has_method("abort_for_finisher_survivor"):
			enemy_action.abort_for_finisher_survivor()
	if victim == enemy and enemy != null:
		if enemy.has_method("set_action_sequence_targeted"):
			enemy.set_action_sequence_targeted(false)
		if enemy.has_method("end_action_strike_freeze"):
			enemy.end_action_strike_freeze()
	elif victim == player and player != null:
		if player.has_method("set_action_sequence_targeted"):
			player.set_action_sequence_targeted(false)
		if player.has_method("end_action_strike_freeze"):
			player.end_action_strike_freeze()


static func _begin_survivor_pose_when_ready(
	ctx: Dictionary,
	survivor: Node2D,
	victim: Node2D,
) -> void:
	var action: Node = _action_for_body(ctx, survivor)
	if action != null and action.has_method("is_active") and action.call("is_active"):
		if action.has_signal("action_sequence_finished"):
			var survivor_ref: WeakRef = weakref(survivor)
			var victim_ref: WeakRef = weakref(victim)
			var on_finished := func() -> void:
				var s: Node2D = survivor_ref.get_ref() as Node2D
				var v: Node2D = victim_ref.get_ref() as Node2D
				if s != null and is_instance_valid(s) and v != null and is_instance_valid(v):
					if s.has_method("begin_finisher_survivor_pose"):
						s.begin_finisher_survivor_pose(v)
			action.action_sequence_finished.connect(on_finished, CONNECT_ONE_SHOT)
			return
	if survivor.has_method("begin_finisher_survivor_pose"):
		survivor.begin_finisher_survivor_pose(victim)


static func _action_for_body(ctx: Dictionary, body: Node2D) -> Node:
	var player: Node = ctx.get("player")
	if body == player:
		return ctx.get("player_action")
	var enemy: Node = ctx.get("enemy")
	if body == enemy and enemy != null and enemy.has_method("get_action_controller"):
		return enemy.get_action_controller()
	return null
