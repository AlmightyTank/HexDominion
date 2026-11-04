extends SceneTree

var output: String = "user://artillery-visuals"
var failures: int = 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("run")

func capture(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(name + ".png")) != OK:
		failures += 1
	return image

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1440, 900)
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	game.camera.set_process(false)
	game.units.match_state.ai_countdown = 10000
	var home: Vector2i = game.units.units[0].hex
	var route: Array[Vector2i] = HexPathfinding.find_path(game.world_map.map_data["tiles"], home, game.units.match_state.rival_hq)
	var target: Vector2i = route[3]
	game.units.units.clear()
	for kind in ["artillery", "artillery", "artillery", "tank", "apc"]:
		var unit: UnitState = UnitState.new(home, UnitCatalog.TYPES[kind]["name"])
		unit.configure_kind(kind)
		unit.turret_facing = -PI / 3
		game.units.units.append(unit)
	var rival: UnitState = UnitState.new(target, "Defender")
	rival.faction = 2
	game.units.units.append(rival)
	game.units.match_state.rival_economy.add_building(target, "bunker")
	game.units.territory.set_owner(target, 2)
	var gun: UnitState = game.units.units[0]
	game.units.select_one(gun)
	game.hud.command_tabs.current_tab = 2
	game._process(0)
	for entry in [["artillery-far", 0.45], ["artillery-medium", 1.0], ["artillery-close", 2.3]]:
		game.camera.restore_view(game.world_map.hex_to_world(home), Vector2.ONE * entry[1])
		game.units.queue_redraw()
		await capture(entry[0])
	game.units.expanded_hex = home
	game.camera.restore_view(game.world_map.hex_to_world(home), Vector2.ONE)
	game.units.queue_redraw()
	await capture("artillery-medium-expanded")
	game.camera.restore_view(game.world_map.hex_to_world(home), Vector2.ONE * 2.3)
	game.units.queue_redraw()
	var idle: Image = await capture("artillery-expanded-idle")
	for unit in game.units.units:
		if unit.kind == "artillery":
			UnitOrders.attack(unit, game.world_map.map_data["tiles"], target)
	game.units._physics_process(3.0)
	game._process(0)
	var fired: Image = await capture("artillery-recoil")
	if idle.get_data() == fired.get_data() or game.units.shell_effects.size() != 3:
		failures += 1
	for effect in game.units.shell_effects:
		effect["age"] = 0.22
	game.units.queue_redraw()
	var shell: Image = await capture("artillery-shell-flight")
	for effect in game.units.shell_effects:
		effect["age"] = 0.55
	game.units.queue_redraw()
	var impact: Image = await capture("artillery-impact")
	if shell.get_data() == impact.get_data():
		failures += 1
	print("Artillery rendered fixture: %d failures. Images: %s" % [failures, ProjectSettings.globalize_path(output)])
	game.free()
	quit(1 if failures else 0)
