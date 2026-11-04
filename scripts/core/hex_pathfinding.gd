extends RefCounted
class_name HexPathfinding
## A* with a conservative heuristic and stable insertion-order tie breaks.

static func find_path(tiles: Dictionary, start: Vector2i, goal: Vector2i, kind: String = "rifle") -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	var airborne: bool = UnitCatalog.is_air(kind)
	if not tiles.has(start) or not tiles.has(goal) or (not airborne and (not is_walkable(tiles, start) or not is_walkable(tiles, goal))):
		return empty
	var frontier: Array = [[0.0, 0, start, 0.0]]
	var previous: Dictionary = {start: start}
	var distances: Dictionary = {start: 0.0}
	var serial: int = 0
	while not frontier.is_empty():
		var entry: Array = _pop(frontier)
		var current: Vector2i = entry[2]
		if entry[3] > distances[current]:
			continue
		if current == goal:
			var path: Array[Vector2i] = [goal]
			while path[-1] != start:
				path.append(previous[path[-1]])
			path.reverse()
			return path
		for neighbor in HexMath.neighbors(current):
			if tiles.has(neighbor) and (airborne or is_walkable(tiles, neighbor)):
				var cost: float = distances[current] + (1.0 if airborne else TerrainRules.movement_cost(tiles, current, neighbor, kind))
				if cost >= distances.get(neighbor, INF):
					continue
				distances[neighbor] = cost
				previous[neighbor] = current
				serial += 1
				_push(frontier, [cost + (0.8 / RoadRules.SPEED) * HexMath.distance(neighbor, goal), serial, neighbor, cost])
	return empty

static func _less(a: Array, b: Array) -> bool:
	return a[0] < b[0] if a[0] != b[0] else a[1] < b[1]

static func _push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var index: int = heap.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if not _less(heap[index], heap[parent]):
			break
		var swap: Array = heap[parent]
		heap[parent] = heap[index]
		heap[index] = swap
		index = parent

static func _pop(heap: Array) -> Array:
	var result: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return result
	heap[0] = last
	var index: int = 0
	while index * 2 + 1 < heap.size():
		var child: int = index * 2 + 1
		if child + 1 < heap.size() and _less(heap[child + 1], heap[child]):
			child += 1
		if not _less(heap[child], heap[index]):
			break
		var swap: Array = heap[index]
		heap[index] = heap[child]
		heap[child] = swap
		index = child
	return result


static func is_walkable(tiles: Dictionary, hex: Vector2i) -> bool:
	return tiles.has(hex) and bool(tiles[hex].get("is_land", false))
