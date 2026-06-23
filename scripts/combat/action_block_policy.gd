class_name ActionBlockPolicy
extends RefCounted

## Extensible defender block AI — testing mode always blocks when charged.

enum Mode {
	ALWAYS_WHEN_CHARGED,
	NEVER,
	CUSTOM,
}

@export var mode: Mode = Mode.ALWAYS_WHEN_CHARGED
## When defender HP ratio is at or below this, prefer taking hits (future counter play).
@export_range(0.0, 1.0, 0.01) var prefer_counter_below_hp_ratio := 0.0
## Reserved: minimum attacker HP ratio before choosing to absorb hits for a counter.
@export_range(0.0, 1.0, 0.01) var counter_when_attacker_hp_below_ratio := 0.35


func should_defender_block(
	defender_side: String,
	exchange: ActionExchange,
	defender_charges: int,
	defender_combat: CharacterCombat = null,
	attacker_combat: CharacterCombat = null,
) -> bool:
	if defender_charges <= 0 or exchange == null:
		return false
	if not exchange.can_offer_block():
		return false
	match mode:
		Mode.NEVER:
			return false
		Mode.ALWAYS_WHEN_CHARGED:
			return true
		Mode.CUSTOM:
			return _evaluate_custom(
				defender_side,
				exchange,
				defender_charges,
				defender_combat,
				attacker_combat,
			)
	return false


func _evaluate_custom(
	_defender_side: String,
	_exchange: ActionExchange,
	_defender_charges: int,
	defender_combat: CharacterCombat,
	attacker_combat: CharacterCombat,
) -> bool:
	if defender_combat and defender_combat.health:
		var hp_ratio: float = defender_combat.health.get_ratio()
		if prefer_counter_below_hp_ratio > 0.0 and hp_ratio <= prefer_counter_below_hp_ratio:
			if attacker_combat == null or attacker_combat.health == null:
				return false
			var attacker_ratio: float = attacker_combat.health.get_ratio()
			if attacker_ratio <= counter_when_attacker_hp_below_ratio:
				return false
	return true
