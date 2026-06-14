class_name PlayerShield
extends Node

## Player shield input — LControl toggle wrapping ShieldComponent.

signal shield_toggled(active: bool)

const ShieldComponentScript := preload("res://scripts/components/shield_component.gd")

@export var shield_scene: PackedScene

var shield: Node2D
var is_active := false

var _toggle_armed := true


func _ready() -> void:
	if shield_scene == null:
		shield_scene = load("res://scenes/components/shield_component.tscn")
	shield = shield_scene.instantiate() as Node2D
	if shield:
		shield.owner_group = "player"
		shield.impact_source = "player_shield"
		shield.shield_up_sound = load("res://assets/ShieldUp1.mp3")
		shield.shield_down_sound = load("res://assets/ShieldDown1.mp3")
		shield.shield_impact_sounds = [
			load("res://assets/463388__vilkas-sound__vs-pop-4.mp3"),
			load("res://assets/463389__vilkas-sound__vs-pop-3.mp3"),
		]
		shield.shield_activated.connect(func(): _sync_active(true))
		shield.shield_deactivated.connect(func(): _sync_active(false))
		add_child(shield)


func attach_to_body(body: Node2D, local_position: Vector2 = Vector2.ZERO) -> void:
	if shield == null or body == null:
		return
	body.add_child(shield)
	shield.position = local_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("player_shield"):
		toggle()


func toggle() -> void:
	if shield == null:
		return
	if shield.is_active:
		shield.deactivate("player_toggle")
	else:
		shield.activate("player_toggle")


func set_active(active: bool) -> void:
	if shield == null:
		return
	if active:
		shield.activate("external")
	else:
		shield.deactivate("external")


func blocks_letter_collection() -> bool:
	return shield != null and shield.blocks_letter_collection()


func get_debug_info() -> Dictionary:
	if shield == null:
		return {"active": false, "cooldown": 0.0}
	return shield.get_debug_info()


func _sync_active(active: bool) -> void:
	is_active = active
	shield_toggled.emit(active)
