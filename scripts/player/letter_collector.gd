class_name LetterCollector
extends Area2D

## Overlap-based letter pickup — attached to Player at runtime.

@export var controller: WordGameController
@export var player_shield: PlayerShield

var _processed_this_frame: Dictionary = {}


func _ready() -> void:
	add_to_group("player_collector")
	collision_layer = 0
	collision_mask = 8
	monitoring = true
	area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	_processed_this_frame.clear()


func try_collect_letter(letter: Letter) -> bool:
	if letter == null or letter.is_resolved():
		return false
	if player_shield and player_shield.blocks_letter_collection():
		return false
	if controller == null:
		return false
	if letter.try_resolve(Letter.Resolution.PLAYER_COLLECT, "player_collector"):
		controller.on_letter_collected(letter.character)
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
