class_name ActionCollectible
extends Area2D

## Falling ACTION pickup — grants one special attack charge.

signal collected

@export var fall_speed: float = 140.0
@export var lifetime: float = 18.0

var _age := 0.0
var _resolved := false


func _ready() -> void:
	add_to_group("action_collectible")
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	_build_visual()


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	position.y += fall_speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _build_visual() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)
	var icon := Label.new()
	icon.name = "Icon"
	icon.text = "ACTION"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.position = Vector2(-34, -12)
	icon.add_theme_font_size_override("font_size", 11)
	icon.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2, 1.0))
	icon.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0, 1.0))
	icon.add_theme_constant_override("outline_size", 3)
	add_child(icon)


func _on_body_entered(body: Node) -> void:
	if _resolved or body == null:
		return
	if not body is CharacterBody2D or not body.is_in_group("player"):
		return
	var controller := _find_action_controller(body as CharacterBody2D)
	if controller == null:
		return
	if controller.get_charges() >= controller.max_action_charges:
		return
	controller.add_charge(1)
	_resolved = true
	collected.emit()
	queue_free()


func _find_action_controller(player: CharacterBody2D) -> Node:
	for child in player.get_children():
		if child.has_method("add_charge"):
			return child
	return null
