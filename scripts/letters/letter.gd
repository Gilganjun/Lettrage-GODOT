class_name Letter
extends Area2D

## Single falling collectible letter (A–Z).

signal collected(letter_node: Letter, character: String)

@export var catalog: AlphabetCatalog

var character: String = "A"
var spawn_id: int = -1
var is_vowel: bool = false
var fall_speed: float = 180.0
var _collected := false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 4
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func configure(
	p_character: String,
	p_spawn_id: int,
	p_scale_factor: float,
	p_modulate: Color,
	p_fall_speed: float,
) -> void:
	character = p_character.to_upper()
	spawn_id = p_spawn_id
	is_vowel = catalog.is_vowel(character) if catalog else false
	fall_speed = p_fall_speed
	var sprite := $Sprite2D as Sprite2D
	var path := catalog.get_texture_path(character) if catalog else ""
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	sprite.modulate = p_modulate
	sprite.scale = Vector2.ONE * p_scale_factor
	var shape := $CollisionShape2D.shape as RectangleShape2D
	if shape and sprite.texture:
		var tex_size := sprite.texture.get_size() * sprite.scale
		shape.size = tex_size * 0.55


func _physics_process(delta: float) -> void:
	if _collected:
		return
	position.y += fall_speed * delta


func try_collect_by_player(body: Node) -> bool:
	if _collected:
		return false
	if body == null or not body.is_in_group("player"):
		return false
	_collect()
	return true


func _on_body_entered(body: Node2D) -> void:
	try_collect_by_player(body)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_collector"):
		var player := area.get_parent()
		try_collect_by_player(player)


func _collect() -> void:
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)
	collected.emit(self, character)
	queue_free()
