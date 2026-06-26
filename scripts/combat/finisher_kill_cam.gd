class_name FinisherKillCam
extends RefCounted

## Cut-zoom + slow-mo on the defeated fighter before round-result UI.


static func arm(
	ctx: Dictionary,
	victim: Node2D,
	level_config: LevelGameplayConfig,
) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	var cam := _resolve_camera(ctx)
	if cam == null:
		return
	var survivor := _resolve_survivor(ctx, victim)
	_end_action_strike_cameras(ctx)
	ActionStrikeCameraDirector.clear_strike_presentation(cam)
	var slow_scale := 0.22
	var screen_fill := 0.52
	if level_config != null:
		slow_scale = level_config.finisher_kill_cam_slow_scale
		screen_fill = level_config.finisher_kill_cam_screen_fill
	var zoom_percent := compute_zoom_percent(victim, survivor, cam, screen_fill)
	cam.call_deferred("begin_finisher_kill_cam", victim, survivor, zoom_percent, slow_scale)
	FinisherSurvivorPose.arm(ctx, victim)


static func release(ctx: Dictionary) -> void:
	FinisherSurvivorPose.release(ctx)
	var cam := _resolve_camera(ctx)
	if cam != null:
		cam.end_finisher_kill_cam()


static func compute_zoom_percent(
	victim: Node2D,
	survivor: Node2D,
	cam: CameraZoomController,
	screen_fill: float,
) -> float:
	if victim == null or cam == null:
		return cam.base_zoom_percent if cam != null else 120.0
	var vp := cam.get_viewport().get_visible_rect().size
	if vp.y <= 1.0:
		return cam.base_zoom_percent
	var fill := clampf(screen_fill, 0.35, 0.95)
	var fighters := _collect_fighters(victim, survivor)
	var min_x := fighters[0].x
	var max_x := fighters[0].x
	var min_y := fighters[0].y
	var max_y := fighters[0].y
	for pos in fighters:
		min_x = minf(min_x, pos.x)
		max_x = maxf(max_x, pos.x)
		min_y = minf(min_y, pos.y)
		max_y = maxf(max_y, pos.y)
	var frame_w := maxf(max_x - min_x + _estimate_frame_width(victim), 120.0)
	var frame_h := maxf(
		max_y - min_y + _estimate_frame_height(victim) * 0.55,
		_estimate_frame_height(victim),
	)
	var zoom_factor := maxf(vp.y / (frame_h * fill), vp.x / (frame_w * fill))
	return clampf(zoom_factor * 100.0, cam.min_zoom_percent, cam.max_zoom_percent)


static func _resolve_survivor(ctx: Dictionary, victim: Node2D) -> Node2D:
	var player: Node2D = ctx.get("player") as Node2D
	var enemy: Node2D = ctx.get("enemy") as Node2D
	if victim == player:
		return enemy
	if victim == enemy:
		return player
	return null


static func _fighter_visual_center(body: Node2D) -> Vector2:
	if body == null:
		return Vector2.ZERO
	var sprite := body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return body.global_position
	var local_visual := sprite.position + Vector2(
		sprite.offset.x * sprite.scale.x,
		sprite.offset.y * sprite.scale.y,
	)
	return body.global_position + local_visual


static func _collect_fighters(victim: Node2D, survivor: Node2D) -> Array[Vector2]:
	var points: Array[Vector2] = [_fighter_visual_center(victim)]
	if survivor != null and is_instance_valid(survivor):
		points.append(_fighter_visual_center(survivor))
	return points


static func _resolve_camera(ctx: Dictionary) -> CameraZoomController:
	var player: Node = ctx.get("player")
	if player == null:
		return null
	var cam := player.get_node_or_null("Camera2D")
	if cam is CameraZoomController:
		return cam as CameraZoomController
	return null


static func _end_action_strike_cameras(ctx: Dictionary) -> void:
	var player_action: Node = ctx.get("player_action")
	if player_action and player_action.has_method("end_strike_camera_for_finisher"):
		player_action.call("end_strike_camera_for_finisher")
	elif player_action and player_action.has_method("end_strike_camera_presentation"):
		player_action.end_strike_camera_presentation()
	var enemy: Node = ctx.get("enemy")
	if enemy and enemy.has_method("get_action_controller"):
		var enemy_action = enemy.get_action_controller()
		if enemy_action and enemy_action.has_method("end_strike_camera_for_finisher"):
			enemy_action.call("end_strike_camera_for_finisher")
		elif enemy_action and enemy_action.has_method("end_strike_camera_presentation"):
			enemy_action.end_strike_camera_presentation()


static func _estimate_frame_height(victim: Node2D) -> float:
	var sprite := victim.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames:
		var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if tex:
			return maxf(float(tex.get_height()) * absf(sprite.scale.y), 96.0)
	return 140.0


static func _estimate_frame_width(victim: Node2D) -> float:
	var sprite := victim.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames:
		var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if tex:
			return maxf(float(tex.get_width()) * absf(sprite.scale.x), 72.0)
	return 100.0
