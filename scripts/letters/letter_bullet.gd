class_name LetterBullet
extends Area2D

## Upward player shot — first letter hit is collected or shield-destroyed.

const SPEED := 720.0
const MAX_TRAVEL := 900.0

@export var player_shield: PlayerShield
@export var word_controller: WordGameController

var _traveled := 0.0
var _resolved := false


func _ready() -> void:
	collision_layer = 256
	collision_mask = 9
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func launch(from_global: Vector2) -> void:
	global_position = from_global
	_traveled = 0.0
	_resolved = false


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	var step := SPEED * delta
	position.y -= step
	_traveled += step
	if _traveled >= MAX_TRAVEL:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.45, 0.95, 1.0, 0.9))


func _on_area_entered(area: Area2D) -> void:
	if _resolved or area == null or not area is Letter:
		return
	_hit_letter(area as Letter)


func _on_body_entered(body: Node) -> void:
	if _resolved:
		return
	if body is StaticBody2D:
		queue_free()


func _hit_letter(letter: Letter) -> void:
	if letter.is_resolved():
		return
	_resolved = true
	LetterCollection.try_player_collect(
		letter,
		word_controller,
		player_shield,
		"letter_bullet",
		Letter.Resolution.BULLET_COLLECT,
	)
	queue_free()
