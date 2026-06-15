class_name WordDamageCalculator
extends RefCounted

## GDevelop active formula: (len/2) + len + len — same as score delta, not score itself.


static func damage_for_word_length(word_len: int) -> int:
	if word_len <= 0:
		return 0
	return (word_len >> 1) + word_len + word_len
