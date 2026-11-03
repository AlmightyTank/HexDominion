extends Node2D
## Entry point for v0.1 Slice A: world preview + input camera + HUD.

@onready var camera: StrategyCamera = $Camera2D
@onready var hud: StrategyHUD = $HUD/Overlay


func _ready() -> void:
	hud.bind_camera(camera)
