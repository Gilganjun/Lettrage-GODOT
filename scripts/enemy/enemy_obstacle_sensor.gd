class_name EnemyObstacleSensor
extends Node

## Raycast-based obstacle analysis for jump vs reverse decisions.

@export var max_jump_height := 220.0
@export var floor_beyond_forward := 34.0
@export var floor_beyond_probe_drop := 72.0
@export var floor_beyond_down := 110.0
@export var head_clearance_forward := 42.0

var _body: CharacterBody2D
var _foot_y_local := 116.0
var _half_w := 46.0

var _floor_left: RayCast2D
var _floor_right: RayCast2D
var _wall_left: RayCast2D
var _wall_right: RayCast2D
var _floor_beyond: RayCast2D
var _head_clearance: RayCast2D


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


func scan(direction: int) -> Dictionary:
	var result := {
		"direction": direction,
		"blocked_wall": false,
		"ledge_ahead": false,
		"wall_point": Vector2.ZERO,
		"obstacle_height": 0.0,
		"floor_beyond": false,
		"floor_beyond_point": Vector2.ZERO,
		"head_blocked": false,
		"jumpable": false,
		"on_ground": _body.is_on_floor() if _body else false,
	}
	if _body == null or direction == 0:
		return result
	var wall_ray := _wall_right if direction > 0 else _wall_left
	var ledge_ray := _floor_right if direction > 0 else _floor_left
	_position_wall_ray(wall_ray, direction)
	if wall_ray and wall_ray.is_colliding():
		result.blocked_wall = true
		result.wall_point = wall_ray.get_collision_point()
		var feet_global_y := _body.global_position.y + _foot_y_local
		result.obstacle_height = maxf(0.0, feet_global_y - result.wall_point.y)
		_update_floor_beyond_ray(direction, result.wall_point)
		if _floor_beyond.is_colliding():
			result.floor_beyond = true
			result.floor_beyond_point = _floor_beyond.get_collision_point()
		_update_head_clearance_ray(direction)
		result.head_blocked = _head_clearance.is_colliding()
		result.jumpable = (
			result.obstacle_height <= max_jump_height
			and result.floor_beyond
			and not result.head_blocked
		)
	elif _body.is_on_floor() and ledge_ray and not ledge_ray.is_colliding():
		result.ledge_ahead = true
	return result


func _position_wall_ray(wall_ray: RayCast2D, direction: int) -> void:
	if wall_ray == null or _body == null:
		return
	var lead := Vector2(_half_w + float(direction) * 6.0, _foot_y_local - 24.0)
	wall_ray.position = lead
	wall_ray.target_position = Vector2(float(direction) * 30.0, 0.0)
	wall_ray.force_raycast_update()


func _update_floor_beyond_ray(direction: int, wall_point: Vector2) -> void:
	var origin := wall_point + Vector2(float(direction) * floor_beyond_forward, -floor_beyond_probe_drop)
	_floor_beyond.global_position = origin
	_floor_beyond.target_position = Vector2(0.0, floor_beyond_down)
	_floor_beyond.force_raycast_update()


func _update_head_clearance_ray(direction: int) -> void:
	var local_y := _foot_y_local - max_jump_height * 0.55
	var local_x := _half_w + float(direction) * 8.0
	_head_clearance.position = Vector2(local_x, local_y)
	_head_clearance.target_position = Vector2(float(direction) * head_clearance_forward, 0.0)
	_head_clearance.force_raycast_update()
