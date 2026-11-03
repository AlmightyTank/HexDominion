# v0.1 Slice C — Unit Selection and Movement

## Delivered

- Three selectable teal starter squads on the first three city hexes in map iteration order.
- Single-unit selection ring, remaining-route line and destination ring.
- Right-click movement orders, with acceptance/rejection feedback in the HUD.
- Touch: tap a squad to select; tap elsewhere to issue its movement order.
- Escape clears selection. Clicking empty terrain inspects it and clears selection.
- Mouse/touch drag still pans; movement and multi-finger gestures suppress taps.
- Uniform-cost breadth-first pathfinding over six axial neighbors. All land terrain is passable; ocean, off-map cells and disconnected destinations are rejected. No map wrapping.
- Scene-independent unit state advanced on fixed physics ticks, with smooth progress along each edge. New orders finish the in-flight edge before redirecting; invalid orders preserve the previous route.
- Route and unit drawing live in a separate overlay, leaving the terrain cache untouched.

## Deliberate limits

One selected unit at a time; no box selection, formations, collision avoidance or order queue. Squads can share and cross hexes. Each land step takes 0.45 seconds; terrain costs and differentiated unit stats are future tuning. Units are placeholders, without combat, capture, ownership or production. Routes are assumed static for this slice. Clearing selection does not cancel an existing order.

## Verification

Verified with Godot **4.7.2 stable**:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_smoke_tests.gd
godot --headless --path . --quit-after 5
```

The smoke suite checks shortest paths, ocean detours, disconnected/off-map destinations, adjacent steps, partial movement, retargeting, invalid-order preservation, large ticks, tick partitioning and starter placement, alongside existing geography regressions.

## Interactive acceptance (pending)

- [ ] F5: identify teal squads on city hexes; zoom in and select each.
- [ ] Right-click land: squad follows the yellow route and stops at its destination.
- [ ] Issue another order mid-edge: no jump or ocean crossing.
- [ ] Right-click ocean or another disconnected landmass: rejection leaves current order intact.
- [ ] Drag out and back with either mouse button: no selection or move order.
- [ ] Escape/empty click clears selection without stopping moving squads.
- [ ] Touch selection/orders work; drags and pinches never issue orders.
- [ ] Camera buttons, keyboard movement, zoom and HOME reset still work.
