extends RefCounted
class_name UnitArt
## Visual-only roster. Adding art here does not authorize production or movement.
const CATEGORIES: Dictionary = {
	"rifle": "infantry", "rocket": "infantry", "gunner": "infantry",
	"tank": "vehicles", "scout": "vehicles", "apc": "vehicles",
	"anti_air": "vehicles", "artillery": "vehicles", "supply_truck": "vehicles",
	"helicopter": "aircraft", "fighter": "aircraft",
	"patrol_boat": "naval", "destroyer": "naval", "landing_transport": "naval"
}
const ACCENTS: Array[Color] = [Color("55aff0"), Color("f08075"), Color("e5ba59")]
static var _textures: Dictionary = {}

static func faction_slot(faction: int) -> int:
	return clampi(faction - 1, 0, 2)

static func asset_path(kind: String, faction: int, state: String = "base") -> String:
	if not CATEGORIES.has(kind) or state not in ["base", "damaged", "destroyed", "icon"]:
		return ""
	return "res://assets/units/roster/%s/%s/%s_faction_%s_%s.svg" % [CATEGORIES[kind], kind, kind, ["a", "b", "c"][faction_slot(faction)], state]

static func state_for(health: float, maximum: float, kind: String = "") -> String:
	var threshold: float = maximum * 0.5 if CATEGORIES.get(kind, "") == "infantry" else maximum
	return "destroyed" if health <= 0 else ("damaged" if health < threshold else "base")

static func badge_outline(canvas: CanvasItem, point: Vector2, size: float, color: Color, width: float) -> void:
	var points: PackedVector2Array = []
	for index in range(7):
		points.append(point + Vector2.from_angle(-PI / 2 + index * TAU / 6) * size * 0.48)
	canvas.draw_polyline(points, color, width, true)

static func texture(kind: String, faction: int, state: String = "base") -> Texture2D:
	# The generated icon uses exactly the base geometry; share its imported texture.
	if state == "icon":
		state = "base"
	var path: String = asset_path(kind, faction, state)
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

static func layer_texture(kind: String, faction: int, state: String, part: String) -> Texture2D:
	if kind not in ["tank", "artillery"] or state not in ["base", "damaged"] or part not in ["hull", "turret", "barrel"]:
		return null
	var path: String = asset_path(kind, faction, state).trim_suffix(".svg") + "_" + part + ".svg"
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

static func oil_derrick_texture(faction: int, state: String = "base") -> Texture2D:
	if faction not in [0, 1, 2] or state not in ["base", "damaged", "destroyed", "selected", "icon"]:
		return null
	var path: String = "res://assets/buildings/oil_derrick_%s.svg" % state if state in ["selected", "icon"] else "res://assets/buildings/oil_derrick_%s_%s.svg" % [["neutral", "a", "b"][faction], state]
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


static func building_texture(kind: String, faction: int, state: String = "base") -> Texture2D:
	if kind in ["airfield", "shipyard"]:
		var air_path: String = "res://assets/buildings/%s.svg" % kind
		var faction_key: String = "%s:%d" % [air_path, faction_slot(faction)]
		if not _textures.has(faction_key):
			var source: Texture2D = load(air_path)
			var image: Image = source.get_image()
			var primary: Color = Color(["55aff0", "ef7770", "e8c768"][faction_slot(faction)])
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var pixel: Color = image.get_pixel(x, y)
					if pixel.a > 0 and (pixel.is_equal_approx(Color("b5b29b")) or pixel.is_equal_approx(Color("b3b39a")) or pixel.is_equal_approx(Color("92997a"))):
						image.set_pixel(x, y, Color(primary, pixel.a))
			_textures[faction_key] = ImageTexture.create_from_image(image)
		return _textures[faction_key]
	if state not in ["base", "damaged", "destroyed"]:
		return null
	var suffix: String = "" if state == "base" else "_" + state
	var path: String = "res://assets/buildings/%s_%s%s.svg" % [kind, ["a", "b", "c"][faction_slot(faction)], suffix]
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

static func draw(canvas: CanvasItem, kind: String, faction: int, state: String, point: Vector2, facing: float = 0.0, selected: bool = false, size: float = 28.0, opacity: float = 1.0) -> void:
	if selected:
		canvas.draw_arc(point, size * 0.59, 0, TAU, 32, Color("131a17"), 4.0, true)
		canvas.draw_arc(point, size * 0.59, 0, TAU, 32, Color("fff0ad"), 2.0, true)
	var image: Texture2D = texture(kind, faction, state)
	canvas.draw_set_transform(point, 0.0 if state == "icon" else facing + PI / 2.0)
	if image != null:
		canvas.draw_texture_rect(image, Rect2(Vector2.ONE * -size / 2, Vector2.ONE * size), false, Color(1, 1, 1, opacity))
	else:
		canvas.draw_rect(Rect2(-size / 2, -size / 2, size, size), Color("202a28"))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(-4, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO)
