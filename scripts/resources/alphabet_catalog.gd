class_name AlphabetCatalog
extends Resource

## Maps A–Z to letter textures for reusable Letter instances.

const VOWELS := "AEIOU"

@export var texture_dir := "res://images/Alphabet/"
@export var vowel_modulate := Color(1.0, 0.71, 0.24, 1.0)
@export var consonant_modulate_min := Color(0.5, 0.5, 0.5, 1.0)
@export var consonant_modulate_max := Color(1.0, 1.0, 1.0, 1.0)


func get_texture_path(letter: String) -> String:
	var ch := letter.to_upper()
	if ch == "Q":
		return texture_dir + "q.png"
	return texture_dir + ch + ".png"


func is_vowel(letter: String) -> bool:
	return letter.to_upper() in VOWELS


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
