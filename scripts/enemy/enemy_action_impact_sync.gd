class_name EnemyActionImpactSync
extends RefCounted

## Syncs Alien01 Impact animation to player ACTION hits - impact poses land on hit frames.

const ANIM_NAME := "Impact"
const IMPACT_POSE_FRAMES := [8, 23, 36, 54]
const IMPACT_FRAME_COUNT := 61
## Player attack frames to wait after each hit frame before the impact pose lands.
const IMPACT_PLAYER_FRAME_DELAY := 5

var _active := false
var _block_frozen := false
var _hold_frame := 1
var _segments: Array[Dictionary] = []


func is_active() -> bool:
	return _active


func begin(attack: ActionAttackDefinition) -> void:
	_active = true
	_block_frozen = false
	_hold_frame = 1
	_segments.clear()
	if attack == null or attack.hit_frames.is_empty():
		_segments.append(_make_segment(1, 1, 1, IMPACT_FRAME_COUNT))
		return
	var total_hits := attack.hit_frames.size()
	var prev_player_frame := 1
	var prev_impact_frame := 1
	for i in range(total_hits):
		var hit_arrival_frame: int = attack.hit_frames[i] + IMPACT_PLAYER_FRAME_DELAY
		hit_arrival_frame = mini(hit_arrival_frame, attack.frame_count)
		var hit_impact_frame: int = _pose_frame_for_hit(i, total_hits)
		_segments.append(_make_segment(
			prev_player_frame,
			hit_arrival_frame,
			prev_impact_frame,
			hit_impact_frame,
		))
		prev_player_frame = hit_arrival_frame
		prev_impact_frame = hit_impact_frame
	var tail_player_end := maxi(attack.frame_count, attack.hit_frames[-1] + IMPACT_PLAYER_FRAME_DELAY + 1)
	_segments.append(_make_segment(
		prev_player_frame,
		tail_player_end,
		prev_impact_frame,
		IMPACT_FRAME_COUNT,
	))


func end() -> void:
	_active = false
	_block_frozen = false
	_segments.clear()


func freeze_after_block() -> void:
	if not _active:
		return
	_block_frozen = true


func notify_hit_landed(_sprite: AnimatedSprite2D, _hit_idx: int, _total_hits: int) -> void:
	if not _active:
		return
	# Timing is driven by tick() segment playback; avoid snapping early on hit frame.


func tick(sprite: AnimatedSprite2D, player_frame: int, facing: int) -> void:
	if not _active or sprite == null:
		return
	sprite.flip_h = facing < 0
	if _block_frozen:
		_set_impact_frame(sprite, _hold_frame)
		return
	var impact_frame := _sample_impact_frame(player_frame)
	_hold_frame = impact_frame
	_set_impact_frame(sprite, impact_frame)


static func _make_segment(
	player_start: int,
	player_end: int,
	impact_start: int,
	impact_end: int,
) -> Dictionary:
	return {
		"player_start": player_start,
		"player_end": maxi(player_end, player_start),
		"impact_start": impact_start,
		"impact_end": impact_end,
	}


static func _pose_frame_for_hit(hit_idx: int, total_hits: int) -> int:
	if hit_idx < IMPACT_POSE_FRAMES.size():
		return IMPACT_POSE_FRAMES[hit_idx]
	var extra_hits := total_hits - IMPACT_POSE_FRAMES.size()
	var extra_idx := hit_idx - (IMPACT_POSE_FRAMES.size() - 1)
	var tail_start := IMPACT_POSE_FRAMES[-1]
	if extra_hits <= 0:
		return tail_start
	var tail_span := IMPACT_FRAME_COUNT - tail_start
	var step := int(round(float(extra_idx) / float(extra_hits) * float(tail_span)))
	return clampi(tail_start + step, tail_start, IMPACT_FRAME_COUNT)


func _sample_impact_frame(player_frame: int) -> int:
	if _segments.is_empty():
		return 1
	for segment in _segments:
		var player_start: int = int(segment.get("player_start", 1))
		var player_end: int = int(segment.get("player_end", player_start))
		if player_frame < player_start:
			continue
		if player_frame <= player_end:
			var impact_start: int = int(segment.get("impact_start", 1))
			var impact_end: int = int(segment.get("impact_end", impact_start))
			if player_end <= player_start:
				return impact_end
			var t := inverse_lerp(float(player_start), float(player_end), float(player_frame))
			return int(round(lerpf(float(impact_start), float(impact_end), t)))
	return int(_segments[-1].get("impact_end", IMPACT_FRAME_COUNT))


func _set_impact_frame(sprite: AnimatedSprite2D, frame_1_based: int) -> void:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(ANIM_NAME):
		return
	if sprite.animation != ANIM_NAME:
		sprite.sprite_frames.set_animation_loop(ANIM_NAME, false)
		sprite.play(ANIM_NAME)
		sprite.pause()
	var frame_count := frames.get_frame_count(ANIM_NAME)
	sprite.frame = clampi(frame_1_based - 1, 0, maxi(frame_count - 1, 0))
