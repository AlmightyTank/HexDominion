extends RefCounted
class_name CombatState
## Continuous DPS resolved simultaneously. Stable roster order breaks distance ties.

static func advance(delta: float, units: Array[UnitState]) -> Dictionary:
	var targets: Dictionary = {}
	var damage: Dictionary = {}
	if delta <= 0.0:
		return targets
	for attacker in units:
		if not attacker.is_alive() or not attacker.path.is_empty():
			continue
		var target: UnitState = null
		var best: int = attacker.attack_range + 1
		for candidate in units:
			if not candidate.is_alive() or candidate.faction == attacker.faction:
				continue
			var distance: int = HexMath.distance(attacker.hex, candidate.hex)
			if distance < best:
				best = distance
				target = candidate
		if target != null:
			targets[attacker] = target
			damage[target] = damage.get(target, 0.0) + attacker.damage_per_second * delta
	for target in damage:
		target.health = maxf(0.0, target.health - damage[target])
	return targets
