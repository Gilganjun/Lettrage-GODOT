class_name WordDamageBridge
extends Node

## Routes confirmed word completions to combat damage (once per event).

signal word_damage_applied(event: Dictionary)

@export var player_combat: Node
@export var enemy_combat: Node

var last_damage_event: Dictionary = {}
var _event_seq := 0
var _processed_ids: Dictionary = {}


func _ready() -> void:
	pass


func bind_word_systems(
	player_words: WordGameController,
	enemy_words: EnemyWordController,
) -> void:
	if player_words and not player_words.valid_word_submitted.is_connected(_on_player_valid_word):
		player_words.valid_word_submitted.connect(_on_player_valid_word)
	if enemy_words and enemy_words.word_state:
		if not enemy_words.word_state.word_completed.is_connected(_on_enemy_word_completed):
			enemy_words.word_state.word_completed.connect(_on_enemy_word_completed)


func _on_player_valid_word(word: String, word_length: int, score_delta: int) -> void:
	if enemy_combat == null or enemy_combat.is_dead():
		return
	var damage := WordDamageCalculator.damage_for_word_length(word_length)
	if damage <= 0:
		return
	var event_id := _next_event_id("player_word:%s" % word)
	if _is_duplicate(event_id):
		return
	var applied: int = enemy_combat.apply_word_damage(damage, "player_valid_word")
	_record_event({
		"id": event_id,
		"attacker": "player",
		"defender": "enemy",
		"word": word,
		"word_length": word_length,
		"score_delta": score_delta,
		"damage": applied,
		"source": "player_valid_word",
	})


func _on_enemy_word_completed(word: String) -> void:
	if player_combat == null or player_combat.is_dead():
		return
	var word_length := word.length()
	var damage := WordDamageCalculator.damage_for_word_length(word_length)
	if damage <= 0:
		return
	var event_id := _next_event_id("enemy_word:%s" % word)
	if _is_duplicate(event_id):
		return
	var applied: int = player_combat.apply_word_damage(damage, "enemy_word_complete")
	_record_event({
		"id": event_id,
		"attacker": "enemy",
		"defender": "player",
		"word": word,
		"word_length": word_length,
		"score_delta": WordDamageCalculator.damage_for_word_length(word_length),
		"damage": applied,
		"source": "enemy_word_complete",
	})


func _next_event_id(prefix: String) -> String:
	_event_seq += 1
	return "%s#%d" % [prefix, _event_seq]


func _is_duplicate(event_id: String) -> bool:
	if _processed_ids.has(event_id):
		return true
	_processed_ids[event_id] = true
	return false


func _record_event(event: Dictionary) -> void:
	last_damage_event = event
	word_damage_applied.emit(event)
