extends Button

var _expires: float = 0.0
var _last_message: String = ""
var _hex: Vector2i
var _camera: StrategyCamera
var _world: WorldMap
var _economy: EconomyState


func configure(camera: StrategyCamera, world: WorldMap) -> void:
	_camera = camera
	_world = world
	custom_minimum_size = Vector2(0, 44)
	position = Vector2(8, 94)
	size = Vector2(300, 44)
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pressed.connect(func() -> void: _camera.restore_view(_world.hex_to_world(_hex), _camera.zoom))
	hide()


func bind_economy(economy: EconomyState) -> void:
	if _economy == economy:
		return
	if _economy != null:
		_economy.command_event.disconnect(_receive)
	_economy = economy
	_economy.command_event.connect(_receive)
	hide()
	_last_message = ""


func _receive(message: String, hex: Vector2i) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if message == _last_message and now < _expires:
		return
	_last_message = message
	_hex = hex
	text = message
	tooltip_text = "%s at %s. Select to locate." % [message, hex]
	_expires = now + 5.0
	show()


func _process(_delta: float) -> void:
	if visible and Time.get_ticks_msec() / 1000.0 >= _expires:
		hide()
