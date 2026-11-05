extends SceneTree

func _init() -> void:
	var roster: Array[UnitState] = []
	var kinds: Array[String] = ["rifle", "tank", "artillery", "anti_air", "fighter"]
	for index in range(80):
		var unit: UnitState = UnitState.new(Vector2i((index * 13) % 17 - 8, (index * 7) % 15 - 7))
		unit.configure_kind(kinds[index % kinds.size()])
		unit.faction = 1 if index % 3 == 0 else 2
		unit.air_mission = "striking" if unit.kind == "fighter" else "ready"
		roster.append(unit)
	for index in range(0, roster.size(), 9):
		roster[index].attack_target = weakref(roster[(index + 1) % roster.size()])
	var expected: Dictionary = {}
	for attacker in roster:
		if attacker.kind == "fighter" and attacker.air_mission != "striking":
			continue
		var target: UnitState = null
		var best: int = attacker.attack_range + 1
		var ordered: UnitState = attacker.attack_target.get_ref() if attacker.attack_target != null else null
		for candidate in roster:
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
			expected[attacker] = target
	var actual: Dictionary = CombatState.advance(0.001, roster)
	if actual != expected:
		push_error("Spatial combat selection changed target priority")
		quit(1)
	else:
		print("Spatial combat selection matches roster-order reference (%d units)" % roster.size())
		quit()
