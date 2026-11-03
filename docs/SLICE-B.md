# Godot v0.1 — Slice B: World Map

## Delivered

- Authored, Earth-inspired continental polygons for North America, South America, Eurasia, Africa, Australia and Antarctica, plus islands and archipelagos.
- Normalized continent/biome/site definitions stored in `data/world/earth_regions.json`. No external map image, proprietary tileset, or runtime download is needed.
- Deterministic hex-world generation with odd-r offset rows and axial `(q, r)` keys; 66 × 36 cells, coastlines, world bounds, and per-cell metadata.
- Terrain types: ocean, plains, forest, desert, mountain, city, and resource. City/resource markers reserve the nearest unique land cell to each authored site.
- Distinct colors, coast strokes, icons for terrain and points of interest, and selected-hex highlight drawn using Godot `Node2D` commands.
- Click/tap inspection shows terrain, region, city/resource site name and hex coordinates. Does not command units or claim territory.
- Camera zoom-to-fit and bounds clamp on desktop/mobile; responsive HUD positioning and existing Slice A navigation controls retained.
- Smoke-test coverage for continent presence, terrain categories, deterministic output, coordinate round-trips, tile lookup and map extents.

## Run

Open `project.godot` using **Godot 4.7.2 stable** and press **F5**.

- Pan: WASD/arrows or mouse drag, or one-finger touch drag.
- Zoom: mouse wheel, +/- controls, two-finger pinch.
- Reset to full world: HOME control or `R`.
- Inspect: click/tap a cell without dragging; cell outline and readout update.

## Map coordinate contract

`WorldMapData.offset_to_axial(column, row)` converts a rectangular, *odd-r* layout into stable axial tile keys. `HexMath.axial_to_world(...)` yields the center of a pointy-top hex; `WorldMap.world_to_hex(...)` converts a world point back to a key. Neighbor offsets are the six existing axial directions. This will be reused for pathfinding in Slice C.

The contour polygons and biome boundaries are artistic simplifications, deliberately **not** geographic or political reference data. The map's `continent` attribute is display metadata, not an economic or diplomatic ownership state. Cities/resources are visual sites without production values until later slices.

## Acceptance checklist

- [ ] Open and import project in Godot without parser warnings or errors.
- [ ] F5 shows an easily recognizable hex world, with land and ocean.
- [ ] Pan and zoom work, including HOME world-fit reset and camera boundary clamp.
- [ ] Forest, desert, mountain, city and resource symbols are legible.
- [ ] Mouse click and touch tap show the correct selected-hex information.
- [ ] Hexes in ocean cannot be assigned city/resource markers.
- [ ] Headless smoke tests pass.
- [ ] Existing main scene boots headlessly.

## Automated commands

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_smoke_tests.gd
godot --headless --path . --quit-after 5
```

## Out of scope

Unit selection, pathfinding, garrisons, capturing, factions, economy, AI, naval routes and combat remain future slices. The globe is a flat hex map, not a 3D projection; there is no east-west wraparound in Slice B.
