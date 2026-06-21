class_name MatchController
extends Node

signal round_started(round_number: int)
signal round_ended(player_won_round: bool)
signal match_ended(player_won_match: bool)

enum Phase {
	IDLE,
	COUNTDOWN,
	FIGHT_FLASH,
	ROUND_ACTIVE,
	ROUND_END_PENDING,
	ROUND_RESULT,
	MATCH_VICTORY,
	MATCH_DEFEAT,
}

@export var config: LevelGameplayConfig

var _overlay: MatchOverlay
var _ctx: Dictionary = {}
var _phase := Phase.IDLE
var _countdown_remaining := 0.0
var _phase_timer := 0.0
var _player_round_wins := 0
var _enemy_round_wins := 0
var _current_round := 0
var _rng := RandomNumberGenerator.new()
var _round_result_player_won := false
var _pending_round_end := false
var _round_end_delay_timer := 0.0
var _waiting_for_action_finish := false


func setup(overlay: MatchOverlay, round_ctx: Dictionary) -> void:
	_overlay = overlay
	_ctx = round_ctx
	add_to_group("match_controller")
	if config == null:
		config = LevelGameplayConfig.new()
	_rng.randomize()
	if _overlay and not _overlay.continue_requested.is_connected(_on_continue_requested):
		_overlay.continue_requested.connect(_on_continue_requested)
	_connect_player_action_signals()


func is_round_active() -> bool:
	return _phase == Phase.ROUND_ACTIVE


func allows_action_start() -> bool:
	return _phase == Phase.ROUND_ACTIVE


func blocks_word_submit() -> bool:
	return _phase != Phase.ROUND_ACTIVE


func start_match() -> void:
	_player_round_wins = 0
	_enemy_round_wins = 0
	_current_round = 0
	_begin_next_round()


func _begin_next_round() -> void:
	_current_round += 1
	_clear_pending_round_end()
	GameplayRoundReset.reset_round(_ctx)
	_phase = Phase.COUNTDOWN
	_countdown_remaining = config.round_countdown_seconds
	_phase_timer = 0.0
	GameplayRoundReset.begin_round_intro(_ctx, config)
	_update_countdown_display()


func _process(delta: float) -> void:
	match _phase:
		Phase.COUNTDOWN:
			_tick_countdown(delta)
		Phase.FIGHT_FLASH:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_start_round_play()
		Phase.ROUND_END_PENDING:
			_tick_round_end_pending(delta)
		Phase.ROUND_RESULT:
			if Input.is_action_just_pressed("player_action"):
				_advance_from_round_result()
				return
			_tick_inter_round_countdown(delta)
		Phase.MATCH_VICTORY, Phase.MATCH_DEFEAT:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_phase = Phase.IDLE
				start_match()


func _tick_countdown(delta: float) -> void:
	var total := maxf(config.round_countdown_seconds, 0.001)
	var before := int(ceilf(_countdown_remaining))
	_countdown_remaining = maxf(_countdown_remaining - delta, 0.0)
	var elapsed := total - _countdown_remaining
	var progress := clampf(elapsed / total, 0.0, 1.0)
	GameplayRoundReset.tick_round_intro(_ctx, progress, config)
	var after := int(ceilf(_countdown_remaining))
	if after != before and _overlay:
		if after > 0:
			_overlay.show_countdown(after)
		else:
			GameplayRoundReset.tick_round_intro(_ctx, 1.0, config)
			GameplayRoundReset.end_round_intro(_ctx)
			_show_fight_flash()


func _show_fight_flash() -> void:
	_phase = Phase.FIGHT_FLASH
	_phase_timer = config.fight_flash_duration
	if _overlay:
		_overlay.show_fight()


func _start_round_play() -> void:
	_phase = Phase.ROUND_ACTIVE
	if _overlay:
		_overlay.hide_all()
	GameplayRoundReset.begin_round_play(_ctx)
	round_started.emit(_current_round)


func on_player_death() -> void:
	if _phase != Phase.ROUND_ACTIVE:
		return
	_end_round(false)


func on_enemy_death() -> void:
	if _phase != Phase.ROUND_ACTIVE:
		return
	if _should_delay_round_result_for_action():
		_queue_round_end(true)
		return
	_end_round(true)


func _should_delay_round_result_for_action() -> bool:
	var player_action: Node = _ctx.get("player_action")
	if player_action == null:
		return false
	if player_action.has_method("is_active"):
		return player_action.call("is_active")
	return false


func _queue_round_end(player_won: bool) -> void:
	_round_result_player_won = player_won
	if player_won:
		_player_round_wins += 1
	else:
		_enemy_round_wins += 1
	_pending_round_end = true
	_waiting_for_action_finish = true
	_round_end_delay_timer = 0.0
	_phase = Phase.ROUND_END_PENDING


func _tick_round_end_pending(delta: float) -> void:
	if _waiting_for_action_finish:
		return
	if _round_end_delay_timer > 0.0:
		_round_end_delay_timer -= delta
		if _round_end_delay_timer <= 0.0:
			_flush_pending_round_end()


func _on_action_sequence_finished_for_round_end() -> void:
	if not _pending_round_end or _phase != Phase.ROUND_END_PENDING:
		return
	_waiting_for_action_finish = false
	_round_end_delay_timer = config.post_action_round_result_delay


func _flush_pending_round_end() -> void:
	if not _pending_round_end:
		return
	var player_won := _round_result_player_won
	_clear_pending_round_end()
	_present_round_end(player_won)


func _clear_pending_round_end() -> void:
	_pending_round_end = false
	_waiting_for_action_finish = false
	_round_end_delay_timer = 0.0


func _connect_player_action_signals() -> void:
	var player_action: Node = _ctx.get("player_action")
	if player_action == null or not player_action.has_signal("action_sequence_finished"):
		return
	if not player_action.action_sequence_finished.is_connected(_on_action_sequence_finished_for_round_end):
		player_action.action_sequence_finished.connect(_on_action_sequence_finished_for_round_end)


func _end_round(player_won: bool) -> void:
	_round_result_player_won = player_won
	if player_won:
		_player_round_wins += 1
	else:
		_enemy_round_wins += 1
	_present_round_end(player_won)


func _present_round_end(player_won: bool) -> void:
	round_ended.emit(player_won)
	if player_won:
		var match_won := _player_round_wins >= config.rounds_to_win
		if match_won:
			match_ended.emit(true)
		_show_round_result(true, match_won)
	elif _enemy_round_wins >= config.rounds_to_win:
		match_ended.emit(false)
		_show_match_defeat()
	else:
		_show_round_result(false, false)


func _show_round_result(player_won: bool, match_won: bool = false) -> void:
	if match_won:
		_phase = Phase.MATCH_VICTORY
		_phase_timer = config.match_result_hold_seconds
	else:
		_phase = Phase.ROUND_RESULT
		_countdown_remaining = config.inter_round_countdown_seconds
	if _overlay:
		_overlay.show_round_result(
			player_won,
			_player_round_wins,
			_enemy_round_wins,
			_current_round,
			0 if match_won else maxi(int(ceilf(_countdown_remaining)), 1),
			match_won,
		)


func _tick_inter_round_countdown(delta: float) -> void:
	var before := int(ceilf(_countdown_remaining))
	_countdown_remaining = maxf(_countdown_remaining - delta, 0.0)
	var after := int(ceilf(_countdown_remaining))
	if after != before and _overlay:
		_overlay.update_inter_round_countdown(after)
	if _countdown_remaining <= 0.0:
		_advance_from_round_result()


func _advance_from_round_result() -> void:
	if _phase != Phase.ROUND_RESULT:
		return
	_phase = Phase.IDLE
	_begin_next_round()


func _show_match_defeat() -> void:
	_phase = Phase.MATCH_DEFEAT
	_phase_timer = config.match_result_hold_seconds
	if _overlay:
		_overlay.show_match_defeat(
			MatchPhrases.random_defeat_line(_rng),
			_player_round_wins,
			_enemy_round_wins,
		)


func _on_continue_requested() -> void:
	match _phase:
		Phase.ROUND_RESULT:
			_advance_from_round_result()
		Phase.MATCH_VICTORY, Phase.MATCH_DEFEAT:
			_phase = Phase.IDLE
			start_match()


func _update_countdown_display() -> void:
	if _overlay:
		_overlay.show_countdown(maxi(int(ceilf(_countdown_remaining)), 1))
