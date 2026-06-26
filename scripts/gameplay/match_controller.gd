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

const MANUAL_CONTINUE_INPUT_LOCKOUT_SEC := 3.0

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
var _round_splash_started := false
var _ledger := RoundCombatLedger.new()
var _action_exchanges := ActionExchangeRegistry.new()
var _manual_continue_input_lockout := 0.0
var _round_end_wait_player_action := false
var _kill_cam_started_msec := -1


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
	_connect_enemy_action_signals()


func wire_round_ledger(damage_bridge: Node, player_action: Node, enemy_action: Node) -> void:
	if damage_bridge and damage_bridge.has_method("set_round_ledger"):
		damage_bridge.set_round_ledger(_ledger)
	if player_action and player_action.has_method("set_round_ledger"):
		player_action.set_round_ledger(_ledger)
	if enemy_action and enemy_action.has_method("set_round_ledger"):
		enemy_action.set_round_ledger(_ledger)


func wire_action_exchanges(combat_hud: Node, player_action: Node, enemy_action: Node) -> void:
	_action_exchanges.reset()
	if combat_hud and combat_hud.has_method("ensure_action_block_flash"):
		combat_hud.ensure_action_block_flash()
	if player_action:
		if player_action.has_method("set_exchange_registry"):
			player_action.set_exchange_registry(_action_exchanges)
		if combat_hud and player_action.has_method("set_block_feedback"):
			player_action.set_block_feedback(combat_hud)
	if enemy_action:
		if enemy_action.has_method("set_exchange_registry"):
			enemy_action.set_exchange_registry(_action_exchanges)
		if combat_hud and enemy_action.has_method("set_block_feedback"):
			enemy_action.set_block_feedback(combat_hud)


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
	_round_splash_started = false
	_ledger.reset()
	_action_exchanges.reset()
	FinisherKillCam.release(_ctx)
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
			if not config.use_inter_round_countdown and _manual_continue_input_lockout > 0.0:
				_manual_continue_input_lockout = maxf(_manual_continue_input_lockout - delta, 0.0)
			if _try_advance_from_round_result():
				return
			if config.use_inter_round_countdown:
				_tick_inter_round_countdown(delta)
		Phase.MATCH_VICTORY, Phase.MATCH_DEFEAT:
			if not config.use_inter_round_countdown:
				_manual_continue_input_lockout = maxf(_manual_continue_input_lockout - delta, 0.0)
				if _manual_continue_input_lockout > 0.0:
					return
				if Input.is_action_just_pressed("round_continue") \
						or Input.is_action_just_pressed("submit_word") \
						or Input.is_action_just_pressed("player_action"):
					_on_continue_requested()
				return
			if Input.is_action_just_pressed("round_continue"):
				_on_continue_requested()
				return
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
	if not _round_splash_started and _countdown_remaining <= config.round_splash_lead_before_land:
		_round_splash_started = true
		if _overlay:
			_overlay.show_round_start(_current_round, config.round_splash_duration)
	var after := int(ceilf(_countdown_remaining))
	if after != before and _overlay and after > 0 and not _round_splash_started:
		_overlay.show_countdown(after)
	if _countdown_remaining <= 0.0:
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
	_begin_finisher_kill_cam(false)
	if _is_any_action_blocking_round_end():
		_queue_round_end(false)
		return
	_end_round(false)


func on_enemy_death() -> void:
	if _phase != Phase.ROUND_ACTIVE:
		return
	_begin_finisher_kill_cam(true)
	if _is_any_action_blocking_round_end():
		_queue_round_end(true)
		return
	_end_round(true)


func _begin_finisher_kill_cam(player_won_round: bool) -> void:
	var victim: Node2D = _ctx.get("enemy") if player_won_round else _ctx.get("player")
	_kill_cam_started_msec = Time.get_ticks_msec()
	FinisherKillCam.arm(_ctx, victim, config)
	GameplayRoundReset.pause_after_round_end(_ctx)


func _finisher_kill_cam_elapsed() -> bool:
	if _kill_cam_started_msec < 0:
		return true
	var duration := 3.0
	if config != null:
		duration = config.finisher_kill_cam_duration_sec
	var elapsed := float(Time.get_ticks_msec() - _kill_cam_started_msec) / 1000.0
	return elapsed >= duration


func _is_any_action_blocking_round_end() -> bool:
	return _is_player_action_blocking_round_end() or _is_enemy_action_blocking_round_end()


func _is_player_action_blocking_round_end() -> bool:
	var player_action: Node = _ctx.get("player_action")
	return player_action != null \
		and player_action.has_method("is_active") \
		and player_action.call("is_active")


func _is_enemy_action_blocking_round_end() -> bool:
	var enemy: Node = _ctx.get("enemy")
	if enemy == null:
		return false
	var enemy_combat: Node = enemy.get_node_or_null("CharacterCombat")
	if enemy_combat and enemy_combat.has_method("is_dead") and enemy_combat.call("is_dead"):
		return false
	if not enemy.has_method("get_action_controller"):
		return false
	var enemy_action = enemy.get_action_controller()
	return enemy_action != null \
		and enemy_action.has_method("is_active") \
		and enemy_action.call("is_active")


func _queue_round_end(player_won: bool) -> void:
	_round_result_player_won = player_won
	if player_won:
		_player_round_wins += 1
	else:
		_enemy_round_wins += 1
	_pending_round_end = true
	_round_end_wait_player_action = _is_player_action_blocking_round_end()
	_waiting_for_action_finish = _round_end_wait_player_action \
		or _is_enemy_action_blocking_round_end()
	_round_end_delay_timer = 0.0
	_phase = Phase.ROUND_END_PENDING


func _tick_round_end_pending(delta: float) -> void:
	_round_end_delay_timer += delta
	if _waiting_for_action_finish:
		if _round_end_wait_player_action:
			var player_action: Node = _ctx.get("player_action")
			if player_action == null \
					or not player_action.has_method("is_active") \
					or not player_action.call("is_active"):
				_waiting_for_action_finish = false
		else:
			var enemy: Node = _ctx.get("enemy")
			var enemy_action: Node = null
			if enemy and enemy.has_method("get_action_controller"):
				enemy_action = enemy.get_action_controller()
			if enemy_action == null \
					or not enemy_action.has_method("is_active") \
					or not enemy_action.call("is_active"):
				_waiting_for_action_finish = false
		if _waiting_for_action_finish and _round_end_delay_timer >= 6.0:
			_force_finish_blocking_actions()
			_waiting_for_action_finish = false
		if _waiting_for_action_finish:
			return
	if not _finisher_kill_cam_elapsed():
		return
	_flush_pending_round_end()


func _force_finish_blocking_actions() -> void:
	var player_action: Node = _ctx.get("player_action")
	if player_action and player_action.has_method("abort_for_finisher_survivor"):
		player_action.call("abort_for_finisher_survivor")
	var enemy: Node = _ctx.get("enemy")
	if enemy and enemy.has_method("get_action_controller"):
		var enemy_action = enemy.get_action_controller()
		if enemy_action and enemy_action.has_method("abort_for_finisher_survivor"):
			enemy_action.call("abort_for_finisher_survivor")


func _on_action_sequence_finished_for_round_end() -> void:
	if not _pending_round_end or _phase != Phase.ROUND_END_PENDING:
		return
	_waiting_for_action_finish = false


func _flush_pending_round_end() -> void:
	if not _pending_round_end:
		return
	var player_won := _round_result_player_won
	_clear_pending_round_end()
	_present_round_end(player_won)


func _clear_pending_round_end() -> void:
	_pending_round_end = false
	_waiting_for_action_finish = false
	_round_end_wait_player_action = false
	_round_end_delay_timer = 0.0
	_kill_cam_started_msec = -1


func _connect_player_action_signals() -> void:
	var player_action: Node = _ctx.get("player_action")
	if player_action == null or not player_action.has_signal("action_sequence_finished"):
		return
	if not player_action.action_sequence_finished.is_connected(_on_action_sequence_finished_for_round_end):
		player_action.action_sequence_finished.connect(_on_action_sequence_finished_for_round_end)


func _connect_enemy_action_signals() -> void:
	var enemy: Node = _ctx.get("enemy")
	if enemy == null or not enemy.has_method("get_action_controller"):
		return
	var enemy_action = enemy.get_action_controller()
	if enemy_action == null or not enemy_action.has_signal("action_sequence_finished"):
		return
	if not enemy_action.action_sequence_finished.is_connected(_on_action_sequence_finished_for_round_end):
		enemy_action.action_sequence_finished.connect(_on_action_sequence_finished_for_round_end)


func _end_round(player_won: bool) -> void:
	_round_result_player_won = player_won
	if player_won:
		_player_round_wins += 1
	else:
		_enemy_round_wins += 1
	_pending_round_end = true
	_waiting_for_action_finish = false
	_round_end_wait_player_action = false
	_phase = Phase.ROUND_END_PENDING


func _present_round_end(player_won: bool) -> void:
	FinisherKillCam.release(_ctx)
	GameplayRoundReset.pause_after_round_end(_ctx)
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
		if not config.use_inter_round_countdown:
			_manual_continue_input_lockout = MANUAL_CONTINUE_INPUT_LOCKOUT_SEC
	else:
		_phase = Phase.ROUND_RESULT
		if config.use_inter_round_countdown:
			_countdown_remaining = config.inter_round_countdown_seconds
			_manual_continue_input_lockout = 0.0
		else:
			_countdown_remaining = 0.0
			_manual_continue_input_lockout = MANUAL_CONTINUE_INPUT_LOCKOUT_SEC
	if _overlay:
		var player_report := _ledger.build_report_for("player")
		var enemy_report := _ledger.build_report_for("enemy")
		_overlay.show_round_result(
			player_won,
			_player_round_wins,
			_enemy_round_wins,
			_current_round,
			0 if match_won else maxi(int(ceilf(_countdown_remaining)), 1),
			match_won,
			player_report,
			enemy_report,
			not config.use_inter_round_countdown,
		)


func _tick_inter_round_countdown(delta: float) -> void:
	var before := int(ceilf(_countdown_remaining))
	_countdown_remaining = maxf(_countdown_remaining - delta, 0.0)
	var after := int(ceilf(_countdown_remaining))
	if after != before and _overlay:
		_overlay.update_inter_round_countdown(after)
	if _countdown_remaining <= 0.0:
		_advance_from_round_result()


func _try_advance_from_round_result() -> bool:
	if config.use_inter_round_countdown:
		if Input.is_action_just_pressed("player_action"):
			_advance_from_round_result()
			return true
		return false
	if _manual_continue_input_lockout > 0.0:
		return false
	if Input.is_action_just_pressed("round_continue") \
			or Input.is_action_just_pressed("submit_word") \
			or Input.is_action_just_pressed("player_action"):
		_advance_from_round_result()
		return true
	return false


func _advance_from_round_result() -> void:
	if _phase != Phase.ROUND_RESULT:
		return
	if _overlay:
		_overlay.dismiss_round_result_ui()
	_phase = Phase.IDLE
	_begin_next_round()


func _show_match_defeat() -> void:
	GameplayRoundReset.pause_after_round_end(_ctx)
	_phase = Phase.MATCH_DEFEAT
	_phase_timer = config.match_result_hold_seconds
	if not config.use_inter_round_countdown:
		_manual_continue_input_lockout = MANUAL_CONTINUE_INPUT_LOCKOUT_SEC
	if _overlay:
		_overlay.show_match_defeat(
			MatchPhrases.random_defeat_line(_rng),
			_player_round_wins,
			_enemy_round_wins,
			_ledger.build_report_for("player"),
			_ledger.build_report_for("enemy"),
			not config.use_inter_round_countdown,
		)


func is_manual_continue_active() -> bool:
	return not config.use_inter_round_countdown \
		and (_phase == Phase.ROUND_RESULT \
			or _phase == Phase.MATCH_VICTORY \
			or _phase == Phase.MATCH_DEFEAT)


func _on_continue_requested() -> void:
	match _phase:
		Phase.ROUND_RESULT:
			_manual_continue_input_lockout = 0.0
			_advance_from_round_result()
		Phase.MATCH_VICTORY, Phase.MATCH_DEFEAT:
			_manual_continue_input_lockout = 0.0
			if _overlay:
				_overlay.dismiss_round_result_ui()
			_phase = Phase.IDLE
			start_match()


func _update_countdown_display() -> void:
	if _overlay:
		_overlay.show_countdown(maxi(int(ceilf(_countdown_remaining)), 1))
