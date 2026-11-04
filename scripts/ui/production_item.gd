extends Button
class_name ProductionItem

var item_title: String
var credit_cost: int
var duration: float

func configure(title: String, cost: int, seconds: float, image: Texture2D) -> void:
	item_title = title
	credit_cost = cost
	duration = seconds
	icon = image
	expand_icon = true
	add_theme_constant_override("icon_max_width", 36)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	custom_minimum_size = Vector2(0, 88)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	update_status("", "")

func update_status(requirement: String, status: String, blocked: bool = false) -> void:
	disabled = blocked
	text = "%s\n%d CR / %ds" % [item_title, credit_cost, duration]
	if not status.is_empty():
		text += "\n" + status
	tooltip_text = "%s\n%d credits, %d seconds\n%s" % [item_title, credit_cost, duration, requirement]
