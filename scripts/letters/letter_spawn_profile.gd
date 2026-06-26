class_name LetterSpawnProfile
extends Resource

## Tunable spawn settings shared by LetterSpawnDirector profiles.

enum ProfileKind {
	RAIN,
	LANE_RAIN,
}

@export var kind: ProfileKind = ProfileKind.RAIN
@export var spawn_interval: float = 0.25
## Extra vowel-only drops (A→E→I→O→U cycle). Slower = more consonants from main stream.
@export var vowel_spawn_interval: float = 0.75
@export var spawn_x_min: float = 100.0
@export var spawn_x_max: float = 2000.0
@export var spawn_y: float = -256.0
## Visible playfield edges — letters begin fading after crossing these bounds.
@export var fade_x_min: float = 0.0
@export var fade_x_max: float = 2272.0
@export var fade_y_max: float = 648.0
## Extra travel past fade edges before boundary cleanup (safety distance).
@export var off_screen_grace_sec: float = 3.0
@export var off_screen_grace_horizontal_speed: float = 150.0
@export var off_screen_fade_duration_sec: float = 2.5
## Extra off-screen lifetime while that letter is the active claw target.
@export var claw_selected_decay_bonus_sec: float = 3.0
@export var size_min: float = 25.0
@export var size_max: float = 50.0
@export var fall_speed_min: float = 120.0
@export var fall_speed_max: float = 210.0
@export var max_active_letters: int = 24
@export var min_spawn_spacing_x: float = 80.0
@export var spawn_spacing_retries: int = 3
## Minimum gap between horizontally scrolling letters (same lane / direction).
@export var min_horizontal_spacing_x: float = 200.0
@export var horizontal_lane_y_tolerance: float = 72.0
@export var horizontal_spacing_retries: int = 8
## Safety cap only — boundary cleanup removes letters first.
@export var letter_lifetime: float = 120.0
@export var letter_fade_start: float = 115.0
@export var throttle_count_low: int = 10
@export var throttle_count_high: int = 20
@export var throttle_multiplier_mid: float = 2.0
@export var throttle_multiplier_high: float = 4.0

## Lane rain: optional reroll chance (0 = use sequence / vowel-cycle letter as-is).
@export_range(0.0, 1.0, 0.01) var lane_rain_vowel_reroll_chance: float = 0.0
@export_range(0.0, 1.0, 0.01) var lane_rain_consonant_reroll_chance: float = 0.0

## Lane rain: three horizontal bands (fractions of spawn width).
@export var lane_vowel_end: float = 0.33
@export var lane_common_end: float = 0.66

const RARE_CONSONANTS := "QZXJK"


func get_off_screen_grace_x() -> float:
	return off_screen_grace_sec * off_screen_grace_horizontal_speed


func get_off_screen_grace_y() -> float:
	return off_screen_grace_sec * fall_speed_max


func get_delete_x_min() -> float:
	return fade_x_min - get_off_screen_grace_x()


func get_delete_x_max() -> float:
	return fade_x_max + get_off_screen_grace_x()


func get_delete_y() -> float:
	return fade_y_max + get_off_screen_grace_y()
