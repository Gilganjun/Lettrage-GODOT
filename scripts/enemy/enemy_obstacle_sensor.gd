class_name EnemyObstacleSensor
extends Node

## Look-ahead + contact raycasts for jump vs reverse decisions.

@export var max_jump_height := 100.0
@export var min_step_height := 8.0
@export var look_ahead_wall_range := 130.0
@export var look_ahead_floor_forward := 72.0
@export var head_clearance_forward := 48.0

var _body: CharacterBody2D
var _foot_y_local := 116.0
var _half_w := 46.0

var _floor_left: RayCast2D
var _floor_right: RayCast2D
var _wall_left: RayCast2D
var _wall_right: RayCast2D
var _floor_beyond: RayCast2D
var _head_clearance: RayCast2D
var _look_ahead_wall: RayCast2D
var _look_ahead_floor: RayCast2D
var _step_landing: RayCast2D


func setup(body: CharacterBody2D, foot_y: float, half_width: float) -> void:
	_body = body
	_foot_y_local = foot_y
	_half_w = half_width
	_floor_left = body.get_node("FloorRayLeft") as RayCast2D
	_floor_right = body.get_node("FloorRayRight") as RayCast2D
	_wall_left = body.get_node("WallRayLeft") as RayCast2D
	_wall_right = body.get_node("WallRayRight") as RayCast2D
	_floor_beyond = body.get_node("FloorBeyondRay") as RayCast2D
	_head_clearance = body.get_node("HeadClearanceRay") as RayCast2D
	_look_ahead_wall = body.get_node("LookAheadWallRay") as RayCast2D
	_look_ahead_floor = body.get_node("LookAheadFloorRay") as RayCast2D
	_step_landing = body.get_node("StepLandingRay") as RayCast2D


func scan(direction: int) -> Dictionary:
	var result := {
		"direction": direction,
		"blocked_wall": false,
		"geometry_snag": false,
		"ahead_obstacle": false,
		"ledge_ahead": false,
		"wall_point": Vector2.ZERO,
		"obstacle_height": 0.0,
		"distance_to_obstacle": INF,
		"floor_beyond": false,
		"floor_beyond_point": Vector2.ZERO,
		"head_blocked": false,
		"jumpable": false,
		"early_approach": false,
		"on_ground": _body.is_on_floor() if _body else false,
	}
	if _body == null or direction == 0:
		return result
	var wall_ray := _wall_right if direction > 0 else _wall_left
	var ledge_ray := _floor_right if direction > 0 else _floor_left
	var body_wall: Vector2 = _probe_contact_wall(wall_ray, direction, 20.0)
	var foot_wall: Vector2 = _probe_contact_wall(wall_ray, direction, 5.0)
	_position_look_ahead_rays(direction)
	if _wall_probe_hit(body_wall):
		result.blocked_wall = true
		result.wall_point = body_wall
		result.distance_to_obstacle = _ray_origin_global(wall_ray).distance_to(result.wall_point)
	elif _wall_probe_hit(foot_wall):
		result.geometry_snag = true
		result.blocked_wall = true
		result.wall_point = foot_wall
		result.distance_to_obstacle = _ray_origin_global(wall_ray).distance_to(result.wall_point)
	elif _look_ahead_wall and _look_ahead_wall.is_colliding():
		result.ahead_obstacle = true
		result.wall_point = _look_ahead_wall.get_collision_point()
		result.distance_to_obstacle = _ray_origin_global(_look_ahead_wall).distance_to(result.wall_point)
	if result.ahead_obstacle or result.blocked_wall:
		_analyze_step_geometry(direction, result)
	elif _body.is_on_floor() and ledge_ray and not ledge_ray.is_colliding():
		result.ledge_ahead = true
		if _look_ahead_floor and not _look_ahead_floor.is_colliding():
			result.ahead_obstacle = true
			result.distance_to_obstacle = look_ahead_floor_forward
	return result


func _analyze_step_geometry(direction: int, result: Dictionary) -> void:
	var feet_y := _body.global_position.y + _foot_y_local
	var wall_pt: Vector2 = result.wall_point
	var dir_f := float(direction)
	# Step-up landing: probe downward from above/ahead of the vertical face.
	for forward in [14.0, 24.0, 36.0]:
		for drop in [-32.0, -64.0, -96.0, -128.0]:
			if _step_landing == null:
				break
			_step_landing.global_position = wall_pt + Vector2(dir_f * forward, drop)
			_step_landing.target_position = Vector2(0.0, 170.0)
			_step_landing.force_raycast_update()
			if not _step_landing.is_colliding():
				continue
			var land_pt := _step_landing.get_collision_point()
			var step_h := feet_y - land_pt.y
			if step_h < min_step_height or step_h > max_jump_height:
				continue
			result.floor_beyond = true
			result.floor_beyond_point = land_pt
			result.obstacle_height = step_h
			break
		if result.floor_beyond:
			break
	# Fallback: horizontal floor-beyond probe (walkable flat past wall).
	if not result.floor_beyond and _floor_beyond:
		_floor_beyond.global_position = wall_pt + Vector2(dir_f * 28.0, -48.0)
		_floor_beyond.target_position = Vector2(0.0, 120.0)
		_floor_beyond.force_raycast_update()
		if _floor_beyond.is_colliding():
			result.floor_beyond = true
			result.floor_beyond_point = _floor_beyond.get_collision_point()
			result.obstacle_height = maxf(min_step_height, feet_y - result.floor_beyond_point.y)
	_position_head_clearance(direction, result.distance_to_obstacle)
	result.head_blocked = _head_clearance.is_colliding() if _head_clearance else false
	result.jumpable = (
		result.obstacle_height >= min_step_height
		and result.obstacle_height <= max_jump_height
		and result.floor_beyond
		and not result.head_blocked
	)
	result.early_approach = (
		result.ahead_obstacle
		and not result.blocked_wall
		and result.distance_to_obstacle < INF
		and result.jumpable
	)


func _probe_contact_wall(wall_ray: RayCast2D, direction: int, height_from_foot: float) -> Vector2:
	if wall_ray == null:
		return Vector2(INF, INF)
	var lead := Vector2(_half_w + float(direction) * 4.0, _foot_y_local - height_from_foot)
	wall_ray.position = lead
	wall_ray.target_position = Vector2(float(direction) * 28.0, 0.0)
	wall_ray.force_raycast_update()
	if wall_ray.is_colliding():
		return wall_ray.get_collision_point()
	return Vector2(INF, INF)


func _wall_probe_hit(point: Vector2) -> bool:
	return point.is_finite()


func _position_look_ahead_rays(direction: int) -> void:
	var dir_f := float(direction)
	if _look_ahead_wall:
		_look_ahead_wall.position = Vector2(_half_w + dir_f * 4.0, _foot_y_local - 36.0)
		_look_ahead_wall.target_position = Vector2(dir_f * look_ahead_wall_range, 0.0)
		_look_ahead_wall.force_raycast_update()
	if _look_ahead_floor:
		_look_ahead_floor.position = Vector2(_half_w + dir_f * look_ahead_floor_forward, _foot_y_local)
		_look_ahead_floor.target_position = Vector2(0.0, 56.0)
		_look_ahead_floor.force_raycast_update()


func _position_head_clearance(direction: int, distance: float) -> void:
	if _head_clearance == null:
		return
	var reach := clampf(distance - 8.0, 16.0, head_clearance_forward)
	var local_y := _foot_y_local - max_jump_height * 0.5
	var local_x := _half_w + float(direction) * 6.0
	_head_clearance.position = Vector2(local_x, local_y)
	_head_clearance.target_position = Vector2(float(direction) * reach, 0.0)
	_head_clearance.force_raycast_update()


func _ray_origin_global(ray: RayCast2D) -> Vector2:
	return ray.global_position if ray else Vector2.ZERO
