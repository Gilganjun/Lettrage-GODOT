class_name WordGameFeatures
extends RefCounted

const ProfanityReactionPlayerScript := preload("res://scripts/ui/profanity_reaction_player.gd")
const DefinitionPopupPlayerScript := preload("res://scripts/ui/definition_popup_player.gd")


## Attaches profanity reaction UI under parent (typically UI CanvasLayer).
static func attach_profanity_reactions(
	parent: Node,
	word_controller: WordGameController,
	enemy: Enemy = null,
) -> CanvasLayer:
	var reaction: CanvasLayer = ProfanityReactionPlayerScript.new()
	parent.add_child(reaction)
	reaction.bind_player_words(word_controller)
	if enemy:
		reaction.bind_enemy_words(enemy)
	return reaction


## Attaches definition popup UI for player valid-word submissions.
static func attach_definition_popups(
	parent: Node,
	word_controller: WordGameController,
) -> CanvasLayer:
	var popup: DefinitionPopupPlayer = DefinitionPopupPlayerScript.new()
	parent.add_child(popup)
	popup.bind_player_words(word_controller)
	return popup
