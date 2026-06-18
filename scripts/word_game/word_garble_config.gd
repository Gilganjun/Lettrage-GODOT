class_name WordGarbleConfig
extends RefCounted

## Rules for purging long gibberish words at the 20-letter checkpoint.

const CHECK_AT_LETTER_COUNT := 20
const REQUIRED_PREFIX_LENGTH := 15

const MESSAGES: PackedStringArray = [
	"Are you trying to invent a new word??",
	"So you invented a new word? Tell that to the judge!",
	"This doesn't make any sense!",
	"What are you doing??",
	"That's not a word. That's a keyboard sneeze.",
	"The dictionary filed a restraining order.",
	"Even autocorrect gave up on you.",
	"Nice try, Shakespeare.",
	"That's not spelling. That's jazz.",
	"My letters deserve better than this.",
	"Did your cat walk on the keyboard?",
	"Congratulations! You invented gibberish.",
	"Spell check left the chat.",
	"That's a word in no known language.",
	"The alphabet is not a drum kit.",
	"You're collecting letters, not building chaos.",
	"Somewhere, a librarian just cried.",
	"Nope. Nope. Nope.",
	"That's not a word — that's a cry for help.",
	"Try again with actual English this time.",
]


static func random_message() -> String:
	return MESSAGES[randi() % MESSAGES.size()]
