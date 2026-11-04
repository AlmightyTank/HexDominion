extends GridContainer
class_name MilitaryOrdersPanel
var status: Label
var rally_attack_move: CheckButton

func configure(command: Callable) -> void:
	columns = 2
	for action in {"attack_move": "Attack-Move (Z)", "guard": "Guard (V)", "patrol": "Patrol (O)"}:
		var button: Button = Button.new()
		button.text = {"attack_move": "Attack-Move (Z)", "guard": "Guard (V)", "patrol": "Patrol (O)"}[action]
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(command.bind(action))
		add_child(button)
	rally_attack_move = CheckButton.new()
	rally_attack_move.text = "Rally: attack-move"
	rally_attack_move.custom_minimum_size.y = 44
	rally_attack_move.tooltip_text = "Applies to the next rally point you set. Fighters retain strike/return missions."
	add_child(rally_attack_move)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)

func show_orders(selection: Array[UnitState]) -> void:
	var counts: Dictionary = {}
	for unit in selection:
		var order: String = unit.tactical_order.get("mode", "attack" if unit.attack_order else ("hold" if unit.holding else "move"))
		counts[order] = counts.get(order, 0) + 1
	var labels: PackedStringArray = []
	for order in counts:
		labels.append("%s: %d" % [order.replace("_", " "), counts[order]])
	status.text = "Orders: " + ", ".join(labels) if not labels.is_empty() else "Select units to issue orders."
