extends RefCounted
class_name UnitArt
## Visual-only roster. Adding art here does not authorize production or movement.
const CATEGORIES: Dictionary = {
	"rifle": "infantry", "rocket": "infantry", "gunner": "infantry",
	"tank": "vehicles", "scout": "vehicles", "apc": "vehicles",
	"anti_air": "vehicles", "artillery": "vehicles",
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

static func state_for(health: float, maximum: float) -> String:
	return "destroyed" if health <= 0 else ("damaged" if health < maximum else "base")

static func texture(kind: String, faction: int, state: String = "base") -> Texture2D:
	var path: String = asset_path(kind, faction, state)
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

static func draw(canvas: CanvasItem, kind: String, faction: int, state: String, point: Vector2, facing: float = 0.0, selected: bool = false, size: float = 28.0) -> void:
	if selected:
		canvas.draw_arc(point, size * 0.59, 0, TAU, 32, Color("131a17"), 4.0, true)
		canvas.draw_arc(point, size * 0.59, 0, TAU, 32, Color("fff0ad"), 2.0, true)
	var image: Texture2D = texture(kind, faction, state)
	canvas.draw_set_transform(point, 0.0 if CATEGORIES.get(kind, "") == "infantry" or state == "icon" else facing + PI / 2.0)
	if image != null:
		canvas.draw_texture_rect(image, Rect2(Vector2.ONE * -size / 2, Vector2.ONE * size), false)
	else:
		canvas.draw_rect(Rect2(-size / 2, -size / 2, size, size), Color("202a28"))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(-4, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO)
