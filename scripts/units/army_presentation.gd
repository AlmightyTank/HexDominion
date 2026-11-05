extends RefCounted
class_name ArmyPresentation
## A single linear grouping pass shared by drawing and hit testing.
var batches: Array[Dictionary] = []
var offsets: Dictionary = {}
var _signature: Array = []

func refresh(roster: Array[UnitState]) -> void:
	var signature: Array = []
	for unit in roster:
		signature.append([unit, unit.hex, unit.kind, unit.faction, unit.is_deployed()])
	if signature == _signature:
		return
	_signature = signature
	batches = UnitVisuals.stacks(roster)
	var by_hex: Dictionary = {}
	offsets.clear()
	for unit in roster:
		if unit.is_deployed():
			if not by_hex.has(unit.hex):
				by_hex[unit.hex] = []
			by_hex[unit.hex].append(unit)
	for members in by_hex.values():
		for index in members.size():
			offsets[members[index]] = Vector2.ZERO if members.size() == 1 else Vector2.from_angle(index * TAU / mini(members.size(), 8)) * (26.0 + floorf(index / 8.0) * 26.0)
