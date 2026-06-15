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
@export var color_mode := ColorMode.PER_LETTER
@export var vowel_modulate := Color(1.0, 0.71, 0.24, 1.0)
@export var consonant_modulate_min := Color(0.5, 0.5, 0.5, 1.0)
@export var consonant_modulate_max := Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var letter_hue_offset := 0.11
@export_range(0.55, 1.0, 0.01) var letter_saturation_min := 0.72
@export_range(0.55, 1.0, 0.01) var letter_saturation_max := 0.98
@export_range(0.65, 1.0, 0.01) var letter_value_min := 0.78
@export_range(0.65, 1.0, 0.01) var letter_value_max := 1.0
## Optional override — set 26 colors in the inspector to hand-tune each letter.
@export var letter_colors: Array[Color] = []


func get_texture_path(letter: String) -> String:
	var ch := letter.to_upper()
	if ch == "Q":
		return texture_dir + "q.png"
	return texture_dir + ch + ".png"


func is_vowel(letter: String) -> bool:
	return letter.to_upper() in VOWELS


func get_letter_modulate(letter: String, rng: RandomNumberGenerator = null) -> Color:
	if color_mode == ColorMode.LEGACY_RANDOM:
		if rng == null:
			rng = RandomNumberGenerator.new()
			rng.randomize()
		return random_modulate(is_vowel(letter), rng)
	return _per_letter_color(letter)


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


func _letter_variation(index: int, channel: int) -> float:
	var n := index * 17 + channel * 31 + 5
	return float((n * 2654435761) % 997) / 996.0
