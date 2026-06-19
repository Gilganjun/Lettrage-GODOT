class_name GameKeyboardCommands
extends RefCounted

## Single source of truth for in-game keyboard shortcuts.
## Add new entries here whenever keyboard commands are introduced.

static func get_sections() -> Array[Dictionary]:
	return [
		{
			"title": "Movement",
			"entries": [
				{"keys": "A / Left", "desc": "Move left"},
				{"keys": "D / Right", "desc": "Move right"},
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
				{"keys": "Left Shift", "desc": "Shield (tap latch / hold block)"},
				{"keys": "F", "desc": "Aim and fire letter bullet (release to shoot)"},
				{"keys": "J", "desc": "Action attack"},
			],
		},
		{
			"title": "Camera",
			"entries": [
				{"keys": "+ / Numpad +", "desc": "Zoom in (hold)"},
				{"keys": "- / Numpad -", "desc": "Zoom out (hold)"},
			],
		},
		{
			"title": "Debug & Test",
			"entries": [
				{"keys": "V / F3", "desc": "Toggle collision debug overlay"},
				{"keys": "Shift + F2", "desc": "Toggle word / combat HUD debug"},
				{"keys": "0", "desc": "Cycle font set: Original → Cyberpunk (tint) → Cyberpunk Original"},
				{"keys": "F8", "desc": "Spawn test letter (Z)"},
				{"keys": "F9", "desc": "Clear player word"},
				{"keys": "F10", "desc": "Force enemy shield on"},
				{"keys": "F11", "desc": "Force enemy word validation"},
				{"keys": "F12", "desc": "Clear enemy word"},
				{"keys": "Alt + 1", "desc": "Damage player (10 HP)"},
				{"keys": "Alt + 2", "desc": "Damage enemy (10 HP)"},
				{"keys": "Alt + 3", "desc": "Heal player fully"},
				{"keys": "Alt + 4", "desc": "Heal enemy fully"},
				{"keys": "Alt + 5", "desc": "Kill player"},
				{"keys": "Alt + 6", "desc": "Kill enemy"},
				{"keys": "Alt + 0", "desc": "Reset combat (both sides)"},
				{"keys": "Esc", "desc": "Quit game"},
			],
		},
	]
