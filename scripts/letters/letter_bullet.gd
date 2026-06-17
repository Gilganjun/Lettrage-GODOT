class_name LetterBullet
extends Area2D

## Vertical letter shot — player or enemy; collects or shield-destroys on first letter hit.

const SPEED := 720.0
const MAX_TRAVEL := 900.0
const ExplosionFx := preload("res://scripts/letters/letter_bullet_explosion_effect.gd")
const CollectFx := preload("res://scripts/letters/letter_bullet_collect_fx.gd")

@export var owner_kind := "player"
@export var fire_direction := Vector2.UP

@export var player_shield: PlayerShield
@export var word_controller: WordGameController
@export var enemy_word_controller: EnemyWordController
@export var enemy_shield: ShieldComponent

var fired_with_shield := false

var _traveled := 0.0
var _resolved := false


func _ready() -> void:
	collision_layer = 256
	collision_mask = 9
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func launch(
	from_global: Vector2,
	shield_active_at_fire: bool = false,
	direction: Vector2 = Vector2.ZERO,
) -> void:
	global_position = from_global
	top_level = true
	_traveled = 0.0
	_resolved = false
	fired_with_shield = shield_active_at_fire
	if direction != Vector2.ZERO:
		fire_direction = direction.normalized()
	elif fire_direction == Vector2.ZERO:
		fire_direction = Vector2.UP


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	var step := SPEED * delta
	var motion := fire_direction.normalized() * step
	position += motion
	_traveled += step
	if _traveled >= MAX_TRAVEL:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var core := Color(1.0, 0.45, 0.35, 0.95) if owner_kind == "enemy" else Color(0.35, 1.0, 1.0, 0.95)
	draw_circle(Vector2.ZERO, 8.0, core)
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 1.0, 0.9))


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
	if fired_with_shield:
		_resolve_shield_hit(letter)
	else:
		_resolve_collect_hit(letter)
	queue_free()


func _resolve_shield_hit(letter: Letter) -> void:
	var parent := letter.get_parent()
	if parent == null:
		parent = get_tree().current_scene
	var sprite := letter.get_sprite()
	ExplosionFx.spawn(
		parent,
		letter.global_position,
		letter.tint_color,
		sprite.texture if sprite else null,
		letter.get_display_scale(),
	)
	letter.shatter_on_resolve = false
	if owner_kind == "enemy":
		letter.try_resolve(Letter.Resolution.ENEMY_SHIELD, "enemy_letter_bullet", global_position)
	else:
		letter.try_resolve(Letter.Resolution.PLAYER_SHIELD, "letter_bullet", global_position)


func _resolve_collect_hit(letter: Letter) -> void:
	var combat_hud := _find_combat_hud()
	if owner_kind == "enemy":
		CollectFx.play_for_enemy(letter, enemy_word_controller, combat_hud)
		return
	CollectFx.play(letter, word_controller, combat_hud)


func _find_combat_hud() -> Control:
	var scene := get_tree().current_scene
	if scene:
		var hud := scene.get_node_or_null("UI/CombatHud") as Control
		if hud:
			return hud
	return null
