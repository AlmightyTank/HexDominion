extends RefCounted
class_name UnitVisuals
## Presentation-only batches. Members always remain independent simulation objects.
const FAR_ZOOM: float = 0.65
const CLOSE_ZOOM: float = 1.5
## Sprite boxes in world pixels. A hex is 31.2 wide, so a close-zoom sprite fills
## most of its hex and the medium tier stays large enough to read the unit type.
const UNIT_BOX: float = 42.0
const STACK_BOX: float = 34.0
## Far tier markers stay a constant screen size so a hex reads at a glance.
const ICON_BOX: float = 25.0

static func badge_scale(zoom_factor: float) -> float:
	return clampf(zoom_factor / FAR_ZOOM, 1.0, 1.8)

## Sprite box for the drawn unit art, in world pixels.
static func sprite_box(zoom_factor: float) -> float:
	if zoom_factor >= CLOSE_ZOOM:
		return UNIT_BOX
	if zoom_factor <= FAR_ZOOM:
		return STACK_BOX
	return lerpf(STACK_BOX, UNIT_BOX, (zoom_factor - FAR_ZOOM) / (CLOSE_ZOOM - FAR_ZOOM))

## Hit radius in world pixels around a unit marker.
static func pick_radius(zoom_factor: float) -> float:
	if zoom_factor < FAR_ZOOM:
		return 18.0 / maxf(zoom_factor, 0.15)
	return sprite_box(zoom_factor) * 0.55

static func tier(zoom_factor: float) -> String:
	return "far" if zoom_factor < FAR_ZOOM else ("medium" if zoom_factor < CLOSE_ZOOM else "close")

static func groups(units: Array[UnitState]) -> Array[Dictionary]:
	var batches: Dictionary = {}
	for unit in units:
		if not unit.is_deployed():
			continue
		var key: String = "%s:%s:%s" % [unit.hex, unit.faction, unit.kind]
		if not batches.has(key):
			batches[key] = {"kind": unit.kind, "faction": unit.faction, "hex": unit.hex, "members": []}
		batches[key]["members"].append(unit)
	var result: Array[Dictionary] = []
	for batch in batches.values():
		result.append(batch)
	return result

static func stacks(units: Array[UnitState]) -> Array[Dictionary]:
	var by_hex: Dictionary = {}
	for unit in units:
		if not unit.is_deployed():
			continue
		var key: String = "%s:%s" % [unit.hex, unit.faction]
		if not by_hex.has(key):
			by_hex[key] = {"hex": unit.hex, "faction": unit.faction, "kind": unit.kind, "domain": unit.domain, "members": [], "counts": {}}
		var stack: Dictionary = by_hex[key]
		stack["members"].append(unit)
		stack["counts"][unit.kind] = stack["counts"].get(unit.kind, 0) + 1
	var result: Array[Dictionary] = []
	for stack in by_hex.values():
		var most: int = 0
		# Catalog order resolves ties independently of roster insertion or selection.
		for kind in UnitCatalog.TYPES:
			if stack["counts"].get(kind, 0) > most:
				most = stack["counts"][kind]
				stack["kind"] = kind
		for member in stack["members"]:
			if member.kind == stack["kind"]:
				stack["domain"] = member.domain
				break
		result.append(stack)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["faction"] != b["faction"]:
			return a["faction"] < b["faction"]
		if a["hex"].y != b["hex"].y:
			return a["hex"].y < b["hex"].y
		return a["hex"].x < b["hex"].x)
	return result

static func offset(unit: UnitState, units: Array[UnitState]) -> Vector2:
	var peers: Array[UnitState] = []
	for candidate in units:
		if candidate.is_deployed() and candidate.hex == unit.hex:
			peers.append(candidate)
	var slot: int = peers.find(unit)
	if peers.size() < 2 or slot < 0:
		return Vector2.ZERO
	return Vector2.from_angle(slot * TAU / mini(peers.size(), 6)) * (28.0 + floorf(slot / 6.0) * 30.0)

static func group_offset(batch: Dictionary, batches: Array[Dictionary]) -> Vector2:
	var peers: Array[Dictionary] = []
	for candidate in batches:
		if candidate["hex"] == batch["hex"]:
			peers.append(candidate)
	if peers.size() < 2:
		return Vector2.ZERO
	var slot: int = peers.find(batch)
	return Vector2((slot % 3 - (mini(peers.size(), 3) - 1) * 0.5) * 42.0, (slot / 3 - (ceili(peers.size() / 3.0) - 1) * 0.5) * 42.0)
