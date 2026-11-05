extends SceneTree

var failures: int = 0
var checks: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(UnitArt.CATEGORIES.size() == UnitCatalog.TYPES.size(), "Full visual roster including supply scaffold")
	for kind in UnitArt.CATEGORIES:
		var faction_images: Array[PackedByteArray] = []
		for faction in range(1, 4):
			var states: Array[PackedByteArray] = []
			for state in ["base", "damaged", "destroyed", "icon"]:
				var path: String = UnitArt.asset_path(kind, faction, state)
				var texture: Texture2D = UnitArt.texture(kind, faction, state)
				check(texture != null, "Load " + path)
				if texture == null:
					continue
				var image: Image = texture.get_image()
				check(image.get_size() == Vector2i(128, 128), "Dimensions " + path)
				check(image.get_pixel(0, 0).a == 0 and image.get_pixel(127, 127).a == 0, "Transparent corners " + path)
				check(image.get_used_rect().has_area(), "Nonempty " + path)
				states.append(image.get_data())
			check(states[0] != states[1] and states[1] != states[2], "Distinct damage states " + kind)
			faction_images.append(states[0])
		check(faction_images[0] != faction_images[1] and faction_images[1] != faction_images[2], "Distinct factions " + kind)
	check(UnitArt.state_for(100, 100) == "base", "Healthy query")
	check(UnitArt.state_for(99, 100) == "damaged", "Damaged query")
	check(UnitArt.state_for(0, 100) == "destroyed", "Destroyed query")
	for kind in ["rifle", "rocket", "gunner"]:
		check(UnitArt.state_for(51, 100, kind) == "base", "Above half healthy " + kind)
		check(UnitArt.state_for(50, 100, kind) == "base", "Exactly half healthy " + kind)
		check(UnitArt.state_for(49, 100, kind) == "damaged", "Below half damaged " + kind)
		check(UnitArt.state_for(0, 100, kind) == "destroyed", "Infantry defeated " + kind)
		for faction in range(1, 4):
			var image: Image = UnitArt.texture(kind, faction).get_image()
			check(image.get_pixel(64, 105).a == 0 and image.get_pixel(64, 63).a > 0.9, "Overhead helmet with no visible legs")
			check(UnitArt.texture(kind, faction, "icon").get_image().get_used_rect().has_area(), "Overhead strategic silhouette")
	for kind in ["headquarters", "barracks", "factory", "supply_center", "extractor", "power_plant", "bunker"]:
		var images: Array[PackedByteArray] = []
		for faction in range(1, 4):
			var texture: Texture2D = UnitArt.building_texture(kind, faction)
			check(texture != null, "Building art " + kind)
			if texture != null:
				var image: Image = texture.get_image()
				check(image.get_size() == Vector2i(128, 128), "Building dimensions " + kind)
				check(image.get_pixel(0, 0).a == 0, "Building transparent corner " + kind)
				images.append(image.get_data())
		check(images.size() == 3 and images[0] != images[1] and images[1] != images[2], "Building faction colors " + kind)
	check(UnitArt.asset_path("supply_truck", 1) != UnitArt.asset_path("scout", 1), "Supply truck has dedicated art")
	check(UnitArt.building_texture("supply_center", 1).get_image().get_data() != UnitArt.building_texture("factory", 1).get_image().get_data(), "Supply center has dedicated art")
	for faction in range(1, 4):
		var supply_center_states: Array[PackedByteArray] = []
		for state in ["base", "damaged", "destroyed"]:
			supply_center_states.append(UnitArt.building_texture("supply_center", faction, state).get_image().get_data())
		check(supply_center_states[0] != supply_center_states[1] and supply_center_states[1] != supply_center_states[2], "Supply center has distinct damage states")
	check(UnitArt.texture("unknown", 1) == null, "Unknown placeholder support")
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	var home: Vector2i = game.units.units[0].hex
	game.units.units.clear()
	for kind in UnitCatalog.TYPES:
		for faction in [1, 2, 3]:
			for index in range(2):
				var unit: UnitState = UnitState.new(home)
				unit.configure_kind(kind)
				unit.faction = faction
				game.units.units.append(unit)
	var before: Array[UnitState] = game.units.units.duplicate()
	for zoom_factor in [0.45, 1.0, 2.3]:
		game.camera.restore_view(game.world_map.hex_to_world(home), Vector2.ONE * zoom_factor)
		var batches: Array[Dictionary] = UnitVisuals.groups(game.units.units)
		var count: int = 0
		for batch in batches:
			count += batch["members"].size()
		check(batches.size() == UnitCatalog.TYPES.size() * 3 and count == UnitCatalog.TYPES.size() * 6, "Mixed army exact counts at " + str(zoom_factor))
		check(game.units.units == before, "Zoom preserves identities and roster")
		var stacks: Array[Dictionary] = game.units.military_batches()
		var point: Vector2 = game.units.group_position(stacks[0], stacks, zoom_factor)
		check(game.units.pick_faction(game.units.to_global(point), zoom_factor, 1) != null, "Mouse/touch shared pick anchor")
	var lost: UnitState = before[0]
	lost.health = 0
	game.units._physics_process(0.01)
	check(not game.units.units.has(lost) and game.units.wrecks.size() == 1, "Death produces cosmetic snapshot only")
	check(game.units.wrecks[0]["remaining"] <= 0.65, "Infantry defeat is brief")
	check(game.units.pick_faction(game.units.to_global(game.units.wrecks[0]["position"]), 2.3, 1) != lost, "Defeated badge cannot be picked")
	game.units.match_state.result = "victory"
	game.units._physics_process(0.7)
	check(game.units.wrecks.is_empty(), "Wreck expires")
	game.free()
	print("Unit art: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
