# Production-first sidebar

This supersedes the bottom command-bar layout described in the earlier UI review.

## Layout

- Credits and income remain in the slim top strip.
- The power gauge now fills the full height of its rail and resizes with the viewport. Supply fill and demand marker share a scale; LOW and numeric values supplement color.
- Objective, minimap and selection remain above Army / Production / Sites.
- Selection shows a compact roster summary, lead-unit HP and order state. Detailed mixed-roster and combat values remain in its tooltip. Its scroll area prevents long selections from pushing production off screen.
- Orders are selection-dependent: no orders without units, garrison for infantry, load when a stationary friendly APC in the same hex has capacity, and unload when a selected stationary APC has passengers. Existing order behavior and shortcuts are unchanged.
- Production contains Structures / Infantry / Vehicles. An independently refreshed queue summary includes every controlled, completed facility with active jobs, not just the inspected hex. Changing selection never changes either tab index, cancels a job, or clears this summary.
- Army contains the hex roster, Select all and Expand. Empty army context has an explicit prompt.
- Sites contains facility controls, the terrain/command inspector, supply and continent information. Terrain no longer permanently consumes map space.
- The bottom command bar is hidden. The camera reserves only the top strip and right sidebar/rail, restoring the map's full remaining height. The map's clear color matches its outer background at wider/taller view ratios.

## Visual decisions

The user chose the persistent-selection layout with production categories, prioritizing manufacturing during combat. The 340 px sidebar accommodates labeled category tabs; a shrinking minimap and scrolling content preserve access at shorter viewports. Original labeled monochrome tab symbols distinguish the six sections without competing with faction colors. See `assets/ui/tabs/README.md` for provenance and symbol meanings. Existing ENERGY 2 / RHYTHM 1 / MOTION 1 direction remains unchanged.

## Verification

Godot 4.7.2, Compatibility renderer:
- HUD tests exercise the six tab icons, relevant orders, reserved camera bounds, full-height power gauge, build requests, radar and pause/resume.
- A barracks queue remains visible after selecting a tank and inspecting another hex; it advances with the same management/category tabs active.
- Rendered UI review covers both tab levels, a selected rifle alongside an active 25% production queue, Army selection, power deficit/recovery, compact layout, pause, save validation and victory.
- Runtime mouse and synthetic touch selection pass at far, medium and close zoom with 24 units unchanged.
- Smoke assertions now target compact selection details, the separate power gauge and the two three-tab levels, rather than obsolete HUD placement.

## Scoped delivery gate

- Hard gate PASS: user-approved layout and original requested symbols; real queue/economy data; no new dead actions; tests cover tabs, army requests, build requests, camera navigation and modal actions. Physical gamepad/touch were not tested.
- Purpose gate PASS: fixed selection supports combat; persistent queues support manufacturing; symbol meanings and palette are documented above. Terrain and continent details move into the inspector instead of consuming a permanent map panel.
- Liveliness PASS: approved military palette, familiar overhead vehicle symbol and existing motion level retained; no decorative flashing added.
- Craftsmanship PASS: rendered normal, selected, production-active and compact states were inspected; empty army/queue states are explicit; selection changes preserve the active production category and running queue. Existing scaled text limitations on small windows are not claimed solved.
