extends RefCounted
class_name CommandTheme

const BACKGROUND: Color = Color("0b1825")
const PANEL: Color = Color("122434")
const BORDER: Color = Color("3e6980")
const TEXT: Color = Color("e9f4fc")
const MUTED: Color = Color("aac6d6")
const ACCENT: Color = Color("6dd5fa")
const POSITIVE: Color = Color("b9dfbe")
const WARNING: Color = Color("f5d39c")
const DANGER: Color = Color("ffd0ca")

static func box(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func create() -> Theme:
	var skin: Theme = Theme.new()
	skin.default_font_size = 14
	skin.set_color("font_color", "Label", TEXT)
	skin.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill: Color = {"normal": Color("1a3447"), "hover": Color("28465b"), "pressed": Color("315e80"), "disabled": Color("162c3d"), "focus": Color("28465b")}[state]
		var style: StyleBoxFlat = box(fill, ACCENT if state in ["hover", "focus", "pressed"] else BORDER)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
		skin.set_stylebox(state, "Button", style)
	skin.set_color("font_hover_color", "Button", TEXT)
	skin.set_color("font_pressed_color", "Button", TEXT)
	skin.set_color("font_color", "Button", TEXT)
	skin.set_color("font_disabled_color", "Button", MUTED)
	for container in ["VBoxContainer", "HBoxContainer", "GridContainer"]:
		skin.set_constant("separation", container, 6)
	skin.set_constant("h_separation", "GridContainer", 6)
	skin.set_constant("v_separation", "GridContainer", 6)
	skin.set_stylebox("background", "ProgressBar", box(BACKGROUND, BORDER))
	skin.set_stylebox("fill", "ProgressBar", box(Color("537d60"), POSITIVE))
	for tab_type in ["TabContainer", "TabBar"]:
		skin.set_font_size("font_size", tab_type, 11)
		skin.set_constant("h_separation", tab_type, 3)
		skin.set_stylebox("tab_selected", tab_type, box(Color("315e80"), BORDER))
		skin.set_stylebox("tab_unselected", tab_type, box(BACKGROUND, BORDER))
		skin.set_stylebox("tab_hovered", tab_type, box(Color("354f66"), ACCENT))
		for state in ["tab_selected", "tab_unselected", "tab_hovered"]:
			var tab_style: StyleBoxFlat = skin.get_stylebox(state, tab_type)
			tab_style.content_margin_top = 12
			tab_style.content_margin_bottom = 12
			tab_style.content_margin_left = 6
			tab_style.content_margin_right = 6
		skin.set_color("font_selected_color", tab_type, TEXT)
		skin.set_color("font_unselected_color", tab_type, MUTED)
	skin.set_stylebox("panel", "TabContainer", box(BACKGROUND, BORDER))
	return skin
