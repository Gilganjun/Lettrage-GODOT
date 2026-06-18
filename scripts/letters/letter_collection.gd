class_name LetterCollection
extends RefCounted

## Shared player letter resolution for body, bullet, and future collectors.


static func try_player_collect(
	letter: Letter,
	controller: WordGameController,
	player_shield: PlayerShield,
	source: String,
	resolution: Letter.Resolution = Letter.Resolution.PLAYER_COLLECT,
) -> bool:
	if letter == null or letter.is_resolved():
		return false
	if player_shield and player_shield.blocks_letter_collection():
		return letter.try_resolve(Letter.Resolution.PLAYER_SHIELD, source)
	if controller == null:
		return false
	if controller.has_method("is_garble_busy") and controller.is_garble_busy():
		return false
	if letter.try_resolve(resolution, source):
		controller.on_letter_collected(letter.character)
		return true
	return false
