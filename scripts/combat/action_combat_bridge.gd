class_name ActionCombatBridge
extends RefCounted

## Shared ACTION hit + block resolution for player and enemy controllers.


static func resolve_action_hit(
	exchange: ActionExchange,
	hit_idx: int,
	damage: int,
	defender_combat: CharacterCombat,
	apply_damage: Callable,
) -> Dictionary:
	if exchange != null and exchange.is_hit_blocked(hit_idx):
		exchange.notify_hit_blocked(hit_idx)
		if defender_combat != null:
			ActionBlockImpactSfx.play(defender_combat)
		return {"blocked": true, "dealt": 0}
	if defender_combat == null or not _can_apply_action_hit(defender_combat):
		return {"blocked": false, "dealt": 0}
	var dealt: int = int(apply_damage.call())
	if exchange != null and hit_idx == 0 and dealt > 0:
		exchange.notify_hit_landed(hit_idx)
	return {"blocked": false, "dealt": dealt}


static func _can_apply_action_hit(combat: CharacterCombat) -> bool:
	if combat == null:
		return false
	if combat.has_pending_action_death():
		return true
	return not combat.is_dead()
