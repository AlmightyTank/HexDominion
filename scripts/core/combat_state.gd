extends RefCounted
class_name CombatState
## Cooldown volleys resolved simultaneously. Stable roster order breaks distance ties.

static func _volley(attacker: UnitState, delta: float) -> float:
	attacker.weapon_elapsed += delta
	var shots: int = floori((attacker.weapon_elapsed + 0.000000001) / maxf(0.001, attacker.cooldown))
	if attacker.kind == "fighter":
		shots = mini(shots, 1)
	attacker.weapon_elapsed = maxf(0, attacker.weapon_elapsed - shots * attacker.cooldown)
	if shots > 0:
		attacker.shot_serial += shots
		attacker.attack_flash = 0.14
		if attacker.kind == "fighter":
			attacker.weapon_elapsed = 0.0
		AircraftRules.fired(attacker)
	return shots * attacker.damage

static func _face(attacker: UnitState, hex: Vector2i) -> void:
	attacker.last_shot_hex = hex
	if attacker.hex != hex:
		attacker.turret_facing = (HexMath.axial_to_world(hex, 1.0) - HexMath.axial_to_world(attacker.hex, 1.0)).angle()
		if attacker.kind not in ["tank", "artillery"]:
			attacker.facing = attacker.turret_facing

static func advance(delta: float, units: Array[UnitState], tiles: Dictionary = {}, protection: Dictionary = {}) -> Dictionary:
	var targets: Dictionary = {}
	var damage: Dictionary = {}
	if not is_finite(delta) or delta <= 0.0:
		return targets
	for attacker in units:
		if not attacker.is_deployed() or not attacker.path.is_empty():
			continue
		if attacker.kind == "fighter" and attacker.air_mission != "striking":
			continue
		# Explicit bombardment keeps its structure target even when defenders share the hex.
		if attacker.kind in ["artillery", "fighter", "destroyer"] and attacker.attack_order and attacker.attack_target == null:
			continue
		var target: UnitState = null
		var best: int = attacker.attack_range + 1
		var ordered: UnitState = attacker.attack_target.get_ref() if attacker.attack_target != null else null
		for candidate in units:
			if attacker.kind == "fighter" and candidate != ordered:
				continue
			if not candidate.is_deployed() or candidate.faction == attacker.faction or not UnitCatalog.can_target(attacker, candidate):
				continue
			var distance: int = HexMath.distance(attacker.hex, candidate.hex)
			var air_priority: bool = attacker.kind == "anti_air" and candidate.domain == "air" and (target == null or target.domain != "air")
			var keep_air: bool = attacker.kind == "anti_air" and target != null and target.domain == "air" and candidate.domain != "air"
			if distance <= attacker.attack_range and not keep_air and (air_priority or candidate == ordered or ((ordered == null or target != ordered) and distance < best)):
				best = distance
				target = candidate
		if target != null:
			targets[attacker] = target
			_face(attacker, target.hex)
			var modifier: float = TerrainRules.attack_multiplier(tiles.get(attacker.hex, {}), attacker.kind) * TerrainRules.defense_multiplier(tiles.get(target.hex, {}), target.kind, target.path.is_empty())
			if target.domain == "air":
				modifier = 1.0
			var counter: float = 3.0 if attacker.kind == "anti_air" and target.domain == "air" else UnitCatalog.counter(attacker.kind, target.kind)
			damage[target] = damage.get(target, 0.0) + _volley(attacker, delta) * counter * modifier * protection.get(target, 1.0)
	for target in damage:
		if damage[target] > 0:
			target.damage_flash = 0.18
		target.health = maxf(0.0, target.health - damage[target])
	return targets

static func attack_extractors(delta: float, units: Array[UnitState], economies: Array[EconomyState], unit_targets: Dictionary, tiles: Dictionary = {}) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	var damage: Dictionary = {}
	for attacker in units:
		# Unit fights take priority; one attack budget per tick, never double damage.
		if attacker.kind in ["patrol_boat", "landing_transport"]:
			continue
		if not attacker.is_deployed() or not attacker.path.is_empty() or unit_targets.has(attacker):
			continue
		if attacker.kind == "fighter" and attacker.air_mission != "striking":
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
				var focused: bool = attacker.attack_order and attacker.attack_target == null and hex == attacker.attack_hex
				var already_focused: bool = target_economy != null and attacker.attack_order and target_hex == attacker.attack_hex
				if building.get("health", EconomyState.BUILD_HEALTH[building["kind"]]) > 0 and distance <= attacker.attack_range and (focused or (not already_focused and distance < best)):
					best = distance
					target_economy = economy
					target_hex = hex
		if target_economy != null:
			_face(attacker, target_hex)
			if not damage.has(target_economy):
				damage[target_economy] = {}
			damage[target_economy][target_hex] = damage[target_economy].get(target_hex, 0.0) + _volley(attacker, delta) * TerrainRules.attack_multiplier(tiles.get(attacker.hex, {}), attacker.kind) * UnitCatalog.TYPES[attacker.kind].get("structure", 1.0)
	for economy in damage:
		for hex in damage[economy]:
			economy.damage_building(hex, damage[economy][hex])
