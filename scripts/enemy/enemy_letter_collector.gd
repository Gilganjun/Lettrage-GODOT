class_name EnemyLetterCollector
extends Area2D

## Enemy letter pickup — separate from body collision and shield.

signal letter_collected(letter: Letter, character: String)

@export var word_controller: Node
@export var shield_component: Node2D

var _processed_this_frame: Dictionary = {}


func _ready() -> void:
	add_to_group("enemy_collector")
	collision_layer = 64
	collision_mask = 8
	monitoring = true
	area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	_processed_this_frame.clear()


func try_collect_letter(letter: Letter) -> bool:
	if letter == null or letter.is_resolved():
		return false
	if shield_component and shield_component.blocks_letter_collection():
		return false
	if word_controller == null:
		return false
	var needed: String = word_controller.word_state.current_needed_letter()
	if needed.is_empty() or letter.character != needed:
		return false
	if letter.try_resolve(Letter.Resolution.ENEMY_COLLECT, "enemy_collector"):
		word_controller.on_letter_collected(letter.character)
		letter_collected.emit(letter, letter.character)
		return true
	return false


func _on_area_entered(area: Area2D) -> void:
	if area == null or not area is Letter:
		return
	var letter := area as Letter
	var id := letter.get_instance_id()
	if _processed_this_frame.has(id):
		return
	if try_collect_letter(letter):
		_processed_this_frame[id] = true
