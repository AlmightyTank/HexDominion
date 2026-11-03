extends RefCounted
class_name CombatState
## Continuous DPS resolved simultaneously. Stable roster order breaks distance ties.

static func advance(delta: float, units: Array[UnitState], tiles: Dictionary = {}) -> Dictionary:
	var targets: Dictionary = {}
	var damage: Dictionary = {}
	if not is_finite(delta) or delta <= 0.0:
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
			var modifier: float = TerrainRules.attack_multiplier(tiles.get(attacker.hex, {}), attacker.kind) * TerrainRules.defense_multiplier(tiles.get(target.hex, {}), target.kind, target.path.is_empty())
			damage[target] = damage.get(target, 0.0) + attacker.damage_per_second * delta * modifier
	for target in damage:
		target.health = maxf(0.0, target.health - damage[target])
	return targets

static func attack_extractors(delta: float, units: Array[UnitState], economies: Array[EconomyState], unit_targets: Dictionary, tiles: Dictionary = {}) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	var damage: Dictionary = {}
	for attacker in units:
		# Unit fights take priority; one attack budget per tick, never double damage.
		if not attacker.is_alive() or not attacker.path.is_empty() or unit_targets.has(attacker):
			continue
		var target_economy: EconomyState = null
		var target_hex: Vector2i
		var best: int = attacker.attack_range + 1
		for economy in economies:
			if economy.faction == attacker.faction:
				continue
			for hex in economy.buildings:
				var building: Dictionary = economy.buildings[hex]
				var distance: int = HexMath.distance(attacker.hex, hex)
				if building.get("health", EconomyState.BUILD_HEALTH[building["kind"]]) > 0 and distance < best:
					best = distance
					target_economy = economy
					target_hex = hex
		if target_economy != null:
			if not damage.has(target_economy):
				damage[target_economy] = {}
			damage[target_economy][target_hex] = damage[target_economy].get(target_hex, 0.0) + attacker.damage_per_second * delta * TerrainRules.attack_multiplier(tiles.get(attacker.hex, {}), attacker.kind)
	for economy in damage:
		for hex in damage[economy]:
			economy.damage_building(hex, damage[economy][hex])
