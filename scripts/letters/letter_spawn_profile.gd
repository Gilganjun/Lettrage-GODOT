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
@export var delete_y: float = 648.0
@export var delete_x_min: float = -64.0
@export var delete_x_max: float = 2336.0
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
@export var letter_lifetime: float = 10.0
@export var letter_fade_start: float = 8.0
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
