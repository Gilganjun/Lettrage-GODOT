class_name LetterAmmoPickup
extends Area2D

## Restores letter-gun ammo on player contact.

@export var ammo_amount: int = 3
@export var fall_speed: float = 120.0
@export var lifetime: float = 16.0

var _age := 0.0
var _resolved := false


func _ready() -> void:
	add_to_group("ammo_pickup")
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	body_entered.connect(_on_body_entered)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	var label := Label.new()
	label.text = "AMMO"
	label.position = Vector2(-28, -10)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.4, 1.0, 1.0, 1.0))
	add_child(label)


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	position.y += fall_speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _resolved or body == null or not body.is_in_group("player"):
		return
	for child in (body as Node).get_children():
		if child is LetterShooter:
			(child as LetterShooter).add_ammo_clip(ammo_amount)
			_resolved = true
			queue_free()
			return
