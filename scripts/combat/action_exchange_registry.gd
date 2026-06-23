class_name ActionExchangeRegistry
extends RefCounted

## Tracks active ACTION sequences so defenders can block incoming strikes.

var _by_attacker: Dictionary = {}


func begin_exchange(attacker: String, defender: String) -> ActionExchange:
	finalize_exchange(attacker)
	var exchange := ActionExchange.new(attacker, defender)
	_by_attacker[attacker] = exchange
	return exchange


func get_exchange_for_attacker(attacker: String) -> ActionExchange:
	return _by_attacker.get(attacker) as ActionExchange


func get_incoming_exchange_for_defender(defender: String) -> ActionExchange:
	for exchange in _by_attacker.values():
		var ex := exchange as ActionExchange
		if ex != null and ex.defender == defender:
			return ex
	return null


func finalize_exchange(attacker: String) -> void:
	_by_attacker.erase(attacker)


func reset() -> void:
	_by_attacker.clear()
