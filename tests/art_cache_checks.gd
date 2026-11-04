extends SceneTree

func check_stacks(layer: UnitLayer) -> void:
	assert(layer.visual_stacks() == UnitVisuals.stacks(layer.units))

func _initialize() -> void:
	var layer: UnitLayer = UnitLayer.new()
	var first: UnitState = UnitState.new()
	var second: UnitState = UnitState.new()
	layer.units.assign([first, second])
	check_stacks(layer)
	var cached: Array[Dictionary] = layer.visual_stacks()
	first.health -= 1
	first.facing = 1
	first.progress = 0.5
	check_stacks(layer)
	assert(is_same(cached, layer.visual_stacks()), "Cosmetic/interpolation changes must reuse batches")
	first.hex += Vector2i(1, 0)
	check_stacks(layer)
	first.faction = 2
	check_stacks(layer)
	first.configure_kind("tank")
	check_stacks(layer)
	first.health = 0
	check_stacks(layer)
	first.health = first.max_health
	check_stacks(layer)
	first.carrier = weakref(second)
	check_stacks(layer)
	first.carrier = null
	check_stacks(layer)
	layer.units.reverse()
	check_stacks(layer)
	layer.units[0] = UnitState.new(Vector2i(4, 4))
	check_stacks(layer)
	layer.units.pop_back()
	check_stacks(layer)
	layer.units.clear()
	check_stacks(layer)
	var title: RegEx = RegEx.new()
	title.compile("<title>.*?</title>")
	for kind in UnitArt.CATEGORIES:
		for faction in range(1, 4):
			var base: String = FileAccess.get_file_as_string(UnitArt.asset_path(kind, faction))
			var icon: String = FileAccess.get_file_as_string(UnitArt.asset_path(kind, faction, "icon"))
			assert(title.sub(base, "") == title.sub(icon, ""), "Icon alias must match source geometry")
			assert(UnitArt.texture(kind, faction) == UnitArt.texture(kind, faction, "icon"))
	layer.free()
	print("Art cache checks passed: exact stack invalidation, live member updates, 39 source-verified texture aliases")
	quit()
