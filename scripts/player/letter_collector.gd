class_name LetterCollector
extends Area2D

## Overlap-based letter pickup — attached to Player at runtime (does not modify movement script).

@export var controller: WordGameController

var _processed_this_frame: Dictionary = {}


func _ready() -> void:
	add_to_group("player_collector")
	collision_layer = 0
	collision_mask = 8
	monitoring = true
	area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	_processed_this_frame.clear()


func _on_area_entered(area: Area2D) -> void:
	if controller == null:
		return
	if area is Letter:
		var letter := area as Letter
		var id := letter.get_instance_id()
		if _processed_this_frame.has(id):
			return
		if letter.try_collect_by_player(get_parent()):
			_processed_this_frame[id] = true
			controller.on_letter_collected(letter.character)
