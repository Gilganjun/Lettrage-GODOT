class_name GameKeyboardCommands
extends RefCounted

## Single source of truth for in-game keyboard shortcuts.
## Add new entries here whenever keyboard commands are introduced.

static func get_sections() -> Array[Dictionary]:
	return [
		{
			"title": "Movement",
			"entries": [
				{"keys": "Shift + A / Left", "desc": "Run left (hold)"},
				{"keys": "Shift + D / Right", "desc": "Run right (hold)"},
				{"keys": "A / Left (x2)", "desc": "Run left (double-tap)"},
				{"keys": "D / Right (x2)", "desc": "Run right (double-tap)"},
				{"keys": "A / Left", "desc": "Walk left"},
				{"keys": "D / Right", "desc": "Walk right"},
				{"keys": "W / Up", "desc": "Climb up / ladder"},
				{"keys": "S / Down", "desc": "Climb down / fast fall (air)"},
				{"keys": "Space", "desc": "Jump"},
				{"keys": "R", "desc": "Roll"},
			],
		},
		{
			"title": "Words & Combat",
			"entries": [
				{"keys": "C / Enter", "desc": "Submit word"},
				{"keys": "Backspace", "desc": "Delete last letter"},
				{"keys": "Ctrl", "desc": "Shield (tap latch / hold block)"},
				{"keys": "F", "desc": "Aim and fire letter bullet (release to shoot)"},
				{"keys": "J", "desc": "Action attack (with charge)"},
				{"keys": "J (while targeted)", "desc": "Spend ACTION charge to block further combo hits"},
			],
		},
		{
			"title": "Match Flow",
			"entries": [
				{"keys": "Enter / J / Space", "desc": "Continue after winning a round"},
			],
		},
		{
			"title": "Camera",
			"entries": [
				{"keys": "Shift + + / Numpad +", "desc": "Zoom in (hold)"},
				{"keys": "- / Numpad -", "desc": "Zoom out (hold)"},
			],
		},
		{
			"title": "Debug & Test",
			"entries": [
				{"keys": "V / F3", "desc": "Toggle collision debug overlay"},
				{"keys": "Shift + F2", "desc": "Toggle debug mode (⚙ panel)"},
				{"keys": "0", "desc": "Cycle font set (Original, Cyberpunk, Dinosaur1, …)"},
				{"keys": "9", "desc": "Cycle letter circle backdrop (BG1–BG4)"},
				{"keys": "F8", "desc": "Spawn test letter (Z)"},
				{"keys": "F9", "desc": "Clear player word"},
				{"keys": "F10", "desc": "Force enemy shield on"},
				{"keys": "F11", "desc": "Force enemy word validation"},
				{"keys": "F12", "desc": "Clear enemy word"},
				{"keys": "Alt + 1", "desc": "Damage player (10 HP)"},
				{"keys": "Alt + 2", "desc": "Cast random dictionary word at enemy (word damage + round log)"},
				{"keys": "Alt + 3", "desc": "Heal player fully"},
				{"keys": "Alt + 4", "desc": "Heal enemy fully"},
				{"keys": "Alt + 5", "desc": "Kill player"},
				{"keys": "Alt + 6", "desc": "Kill enemy"},
				{"keys": "Alt + 0", "desc": "Reset combat (both sides)"},
				{"keys": "Esc", "desc": "Quit game"},
			],
		},
	]


static func format_as_text() -> String:
	var lines: PackedStringArray = []
	for section in get_sections():
		lines.append(str(section.get("title", "")))
		for entry in section.get("entries", []):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			lines.append("  %s — %s" % [str(entry.get("keys", "")), str(entry.get("desc", ""))])
		lines.append("")
	return "\n".join(lines)
