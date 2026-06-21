class_name AlphabetCatalog
extends Resource

## Maps A–Z to letter textures and tint colors for reusable Letter instances.

const VOWELS := "AEIOU"
const GOLDEN_RATIO_CONJUGATE := 0.6180339887

enum ColorMode {
	LEGACY_RANDOM,
	PER_LETTER,
}

@export var texture_dir := "res://images/Alphabet/"
@export var legacy_naming := true
@export var color_mode := ColorMode.PER_LETTER
@export var vowel_modulate := Color(1.0, 0.71, 0.24, 1.0)
@export var consonant_modulate_min := Color(0.5, 0.5, 0.5, 1.0)
@export var consonant_modulate_max := Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var letter_hue_offset := 0.11
@export_range(0.55, 1.0, 0.01) var letter_saturation_min := 0.72
@export_range(0.55, 1.0, 0.01) var letter_saturation_max := 0.98
@export_range(0.65, 1.0, 0.01) var letter_value_min := 0.90
@export_range(0.65, 1.0, 0.01) var letter_value_max := 1.0
## Perceived brightness floor (0–1) so tints stay readable on dark level art.
@export_range(0.0, 0.8, 0.01) var readability_luminance_min := 0.52
## Optional override — set 26 colors in the inspector to hand-tune each letter.
@export var letter_colors: Array[Color] = []

var _font_set_id := "original"
var _export_files: Dictionary = {}
var _use_tint_shader := true
var _display_scale := 1.0
var _spawn_ref_size := 100.0


func apply_font_set(
	p_texture_dir: String,
	p_legacy_naming: bool,
	p_export_files: Dictionary,
	p_font_set_id: String,
	p_use_tint_shader: bool = true,
	p_display_scale: float = 1.0,
	p_spawn_ref_size: float = 100.0,
) -> void:
	texture_dir = p_texture_dir
	legacy_naming = p_legacy_naming
	_export_files = p_export_files.duplicate()
	_font_set_id = p_font_set_id
	_use_tint_shader = p_use_tint_shader
	_display_scale = maxf(p_display_scale, 0.01)
	_spawn_ref_size = maxf(p_spawn_ref_size, 1.0)


func get_display_scale() -> float:
	return _display_scale


func get_spawn_ref_size() -> float:
	return _spawn_ref_size


func compute_spawn_scale(target_world_size: float) -> float:
	return (target_world_size / _spawn_ref_size) * _display_scale


func get_font_set_id() -> String:
	return _font_set_id


func uses_tint_shader() -> bool:
	return _use_tint_shader


func get_texture_path(letter: String) -> String:
	var ch := letter.to_upper()
	if legacy_naming:
		if ch == "Q":
			return texture_dir + "q.png"
		return texture_dir + ch + ".png"
	var filename := str(_export_files.get(ch, ""))
	if filename.is_empty():
		return ""
	return texture_dir + filename


func is_vowel(letter: String) -> bool:
	return letter.to_upper() in VOWELS


func get_letter_modulate(letter: String, rng: RandomNumberGenerator = null) -> Color:
	var color: Color
	if color_mode == ColorMode.LEGACY_RANDOM:
		if rng == null:
			rng = RandomNumberGenerator.new()
			rng.randomize()
		color = random_modulate(is_vowel(letter), rng)
	else:
		color = _per_letter_color(letter)
	return _ensure_readability(color)


func random_modulate(is_vowel_letter: bool, rng: RandomNumberGenerator) -> Color:
	if is_vowel_letter:
		return vowel_modulate
	return Color(
		rng.randf_range(consonant_modulate_min.r, consonant_modulate_max.r),
		rng.randf_range(consonant_modulate_min.g, consonant_modulate_max.g),
		rng.randf_range(consonant_modulate_min.b, consonant_modulate_max.b),
		1.0,
	)


func all_letters() -> PackedStringArray:
	return all_letters_static()


static func all_letters_static() -> PackedStringArray:
	return PackedStringArray([
		"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
		"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
	])


func _letter_index(letter: String) -> int:
	return all_letters().find(letter.to_upper())


func _per_letter_color(letter: String) -> Color:
	var idx := _letter_index(letter)
	if idx < 0:
		return Color.WHITE
	if letter_colors.size() >= all_letters().size():
		return letter_colors[idx]
	return _generated_letter_color(idx)


func _generated_letter_color(index: int) -> Color:
	# Golden-ratio hue stepping avoids adjacent letters clustering in the same band.
	var hue := fmod(letter_hue_offset + float(index) * GOLDEN_RATIO_CONJUGATE, 1.0)
	var sat := lerpf(letter_saturation_min, letter_saturation_max, _letter_variation(index, 1))
	var val := lerpf(letter_value_min, letter_value_max, _letter_variation(index, 2))
	return Color.from_hsv(hue, sat, val)


func _ensure_readability(color: Color) -> Color:
	return ensure_readable_tint(color, readability_luminance_min, letter_value_min)


static func perceived_luminance(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114


static func hue_luminance_floor(hue: float, base_min: float) -> float:
	# Blue/violet hues look darker at the same measured luminance as greens/yellows.
	if hue >= 0.52 and hue <= 0.82:
		return base_min + 0.14
	if hue >= 0.42 and hue < 0.52:
		return base_min + 0.07
	return base_min
 

static func ensure_readable_tint(
	color: Color,
	min_luminance: float = 0.52,
	min_value: float = 0.92,
) -> Color:
	if min_luminance <= 0.0:
		return color
	var result := color
	if result.v < min_value:
		result = Color.from_hsv(result.h, result.s, min_value, result.a)
	var target_lum := maxf(min_luminance, hue_luminance_floor(result.h, min_luminance))
	var lum := perceived_luminance(result)
	if lum >= target_lum:
		return result
	return _boost_to_luminance(result, target_lum, min_value)


static func _boost_to_luminance(color: Color, target_lum: float, min_value: float) -> Color:
	var lum := perceived_luminance(color)
	if lum < 0.001:
		return Color(target_lum, target_lum, target_lum, color.a)
	var scale := target_lum / lum
	var boosted := Color(
		minf(color.r * scale, 1.0),
		minf(color.g * scale, 1.0),
		minf(color.b * scale, 1.0),
		color.a,
	)
	lum = perceived_luminance(boosted)
	var h := boosted.h
	var s := boosted.s
	var v := boosted.v
	var guard := 0
	while lum < target_lum and guard < 10:
		v = minf(v + 0.05, 1.0)
		s = maxf(s - 0.04, 0.58)
		boosted = Color.from_hsv(h, s, maxf(v, min_value), color.a)
		lum = perceived_luminance(boosted)
		guard += 1
	return boosted


func _letter_variation(index: int, channel: int) -> float:
	var n := index * 17 + channel * 31 + 5
	return float((n * 2654435761) % 997) / 996.0
