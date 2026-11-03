# Godot v0.1 — Slice A: Foundation and camera controls

## Scope

Slice A creates the *runnable foundation*, not the world strategy game.

- Godot 4.7.2-compatible GDScript project with main scene
- Camera2D and cross-platform mouse, keyboard and touchscreen controls
- Panning using WASD or arrow keys, plus left/middle/right mouse dragging
- Zoom toward the mouse cursor with the scroll wheel
- Single-touch panning, two-touch pinch zoom and two-finger panning
- On-screen zoom +, zoom -, HOME buttons; keyboard R to reset
- Camera position and zoom readout
- Temporary hex preview to test movement, not the final Earth-shaped map
- Pure hex-grid coordinate methods, with headless smoke-test script
- No external assets, extensions, fonts, or add-ons required

## Controls

| Input | Action |
|---|---|
| WASD / arrow keys | Pan camera |
| Left, middle or right mouse drag | Pan camera |
| Mouse wheel | Zoom at pointer |
| R | Reset view |
| One-finger drag | Pan camera |
| Two-finger pinch | Zoom at finger midpoint |
| Two-finger drag | Pan camera |
| + / - / HOME buttons | Adjust or reset camera |

**Note:** Left-mouse dragging moves the camera only in Slice A. When unit selection is added, the main selection action will take precedence, and panning can use middle/right drag.

## Manual acceptance checks

- [ ] Godot 4.7.2 opens `project.godot` without parse/import errors
- [ ] F5 starts the main scene
- [ ] The visible test hex grid renders behind the HUD
- [ ] Arrow keys and WASD scroll in the expected directions
- [ ] Drag panning is smooth
- [ ] Mouse wheel zooms toward the cursor without jumping
- [ ] Zoom stays within 40%–230%
- [ ] HUD buttons work with mouse and touch
- [ ] R and HOME recenter the camera
- [ ] Touch drag and pinch do not double-apply mouse input
- [ ] Test runner passes with the command below

## Automated checks

```bash
# Import and parse all resources
# Do this once before the runtime smoke tests.
godot --headless --path . --editor --quit

# Test axial hex geometry
godot --headless --path . --script res://tests/run_smoke_tests.gd

# Check that the scene starts and runs for a few frames
godot --headless --path . --quit-after 5
```

The tests must be run on a machine with Godot installed. A ZIP download is not proof that the engine tests passed.

## Explicitly deferred to Slice B and later

- Earth-shaped continental hex map and oceans (B)
- Unit selection, pathfinding, move orders (C)
- Capture progress, factions, territory borders, garrisons (D)
- Units and combat (E)
- Buildings, production, economy (F)
- AI, win condition, saving/loading (G)
