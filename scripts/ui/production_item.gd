extends Button
class_name ProductionItem

var item_title: String
var credit_cost: int
var duration: float
var portrait: TextureRect
var title_label: Label
var cost_label: Label
var status_label: Label
var progress_meter: ProgressBar

func configure(title: String, cost: int, seconds: float, image: Texture2D) -> void:
	item_title = title
	credit_cost = cost
	duration = seconds
	for state in ["font_color", "font_disabled_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	add_theme_font_size_override("font_size", 1)
	custom_minimum_size = Vector2(0, 66)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait = TextureRect.new()
	portrait.texture = image
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(portrait)
	title_label = Label.new()
	title_label.text = title.to_upper()
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(title_label)
	cost_label = Label.new()
	cost_label.text = "%d CR" % cost + (" / HEX" if seconds == 0 else "")
	cost_label.add_theme_color_override("font_color", CommandTheme.MUTED)
	add_child(cost_label)
	status_label = Label.new()
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.add_theme_color_override("font_color", CommandTheme.MUTED)
	add_child(status_label)
	progress_meter = ProgressBar.new()
	progress_meter.show_percentage = false
	add_child(progress_meter)
	for child in get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_content)
	update_status("", "")

func _layout_content() -> void:
	var scale: float = clampf(size.x / 188, 1, 1.5)
	portrait.position = Vector2(6, 7) * scale
	portrait.size = Vector2(34, 29) * scale
	title_label.position = Vector2(51, 5) * scale
	title_label.size = Vector2(size.x - 57 * scale, 17 * scale)
	cost_label.position = Vector2(51, 22) * scale
	cost_label.size = Vector2(size.x - 57 * scale, 16 * scale)
	status_label.position = Vector2(6, 40) * scale
	status_label.size = Vector2(size.x - 12 * scale, 15 * scale)
	status_label.hide()
	for label in [title_label, cost_label]:
		label.add_theme_font_size_override("font_size", roundi(11 * scale))
	status_label.add_theme_font_size_override("font_size", roundi(10 * scale))
	progress_meter.position = Vector2(1, size.y - 4)
	progress_meter.size = Vector2(size.x - 2, 3)

func update_status(requirement: String, status: String, blocked: bool = false, progress: float = -1) -> void:
	disabled = blocked
	text = "%s\n%d CR / %ds\n%s" % [item_title, credit_cost, duration, status]
	tooltip_text = "%s\n%d credits, %d seconds\n%s\n%s" % [item_title, credit_cost, duration, requirement, status]
	status_label.text = status
	portrait.modulate = Color("8998aa") if blocked else Color.WHITE
	title_label.add_theme_color_override("font_color", CommandTheme.MUTED if blocked else CommandTheme.TEXT)
	progress_meter.visible = progress >= 0
	progress_meter.value = clampf(progress, 0, 1) * 100
