class_name MatchPhrases
extends RefCounted

const VICTORY_LINES: Array[String] = [
	"VICTORY IS YOURS!",
	"GLORY AWAITS!",
	"THE WORD IS YOURS!",
	"CHAMPION!",
	"DOMINION ACHIEVED!",
]

const DEFEAT_LINES: Array[String] = [
	"SUFFER IN DEFEAT!",
	"CRUSHED BY LETTERS!",
	"THE ENEMY TRIUMPHS!",
	"DEFEAT IS BITTER!",
	"OUTSPELLED!",
]


static func random_victory_line(rng: RandomNumberGenerator) -> String:
	return VICTORY_LINES[rng.randi_range(0, VICTORY_LINES.size() - 1)]


static func random_defeat_line(rng: RandomNumberGenerator) -> String:
	return DEFEAT_LINES[rng.randi_range(0, DEFEAT_LINES.size() - 1)]
