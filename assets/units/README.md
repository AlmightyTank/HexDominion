# Unit sprites

## Complete roster family

Runtime art now lives in `roster/<category>/<kind>/`, with 156 original SVGs:
13 classes, three faction slots, and base/damaged/destroyed/icon states. Selection
uses a shared overlay. See `docs/art/UNIT_VISUAL_SPEC.md` for integration, limitations,
and verification commands. Regenerate with `python tools/build_unit_art.py`.
The four root SVGs below remain the approved editable source inputs; their historical
48-64 pixel briefs are not the current runtime 25-28 pixel presentation size.

## Main battle tank

- File: `main_battle_tank.svg`
- Original vector artwork authored for Hex Frontlines; no external art assets used.
- Canvas: 128 × 128, transparent background, north-facing.
- Intended display size: 48–64 pixels. Test readability at the intended camera zoom.
- Center pivot: `(64, 64)`. Place in a Godot `Sprite2D` with `centered = true`.
- Teal faction panel: fill `#41b6a6`. Change this fill for alternate factions; do not tint the whole sprite.
- Single idle frame with hull and turret combined. Independent turret rotation requires separated layers.

Wide tracks and the long cannon identify the armored role without faction color. A dark outline separates the olive hull from forest and plains; pale upper edges preserve its shape over dark terrain. Detail is limited to tread bars, one hatch, and a rear vent to keep the sprite readable when reduced.

## Scout vehicle

- File: `scout_vehicle.svg`
- Original vector artwork authored for Hex Frontlines; no external art assets used.
- Canvas: 128 × 128, transparent background, north-facing, center pivot `(64, 64)`.
- Intended display size: 48–64 pixels; the vehicle occupies less of the canvas than the tank so it reads as a lighter unit at the same scale.
- Teal hood panel: fill `#41b6a6`, matching the tank's faction accent.
- Single idle frame with four exposed wheels, narrow hood, open two-seat cabin, and an offset pintle-mounted light gun. No tracks, enclosed turret, transport box, or anti-air weapon cluster.

The long gaps between the front and rear wheels preserve the wheeled silhouette when reduced. The open cabin and narrow chassis distinguish light reconnaissance from enclosed armored transport. Olive panels, charcoal outlines, and restrained edge highlights match the tank without borrowing its heavy silhouette.

## Armored personnel carrier

- File: `armored_personnel_carrier.svg`
- Original vector artwork authored for Hex Frontlines; no external art assets used.
- Canvas: 128 × 128, transparent background, north-facing, center pivot `(64, 64)`.
- Intended display size: 48–64 pixels.
- Eight exposed heavy wheels, enclosed rectangular troop compartment, roof access doors, rear ramp, and a small forward defensive turret.
- Teal compartment-side panels: fill `#41b6a6`, matching the other faction accents.
- Single idle frame with hull and weapon combined; no independent turret layer.

The long enclosed roof and rear ramp identify troop transport. Four separated wheel pairs contrast with the tank's continuous tracks and the scout's widely spaced four-wheel layout. A short gun and small turret leave the troop compartment dominant instead of suggesting a frontline battle tank. The olive, charcoal, and teal palette matches the existing sprites.

## Mobile anti-air vehicle

- File: `mobile_anti_air.svg`
- Original vector artwork authored for Hex Frontlines; no external art assets used.
- Canvas: 128 × 128, transparent background, north-facing, center pivot `(64, 64)`.
- Intended display size: 48–64 pixels.
- Medium six-wheel chassis, two wide three-missile launcher banks, and a central radar dish.
- Teal rear panel and launcher bands: `#41b6a6`, matching the other faction accents.
- Single idle frame, with chassis, radar, and launchers combined.

Twin launcher banks dominate the silhouette instead of a long tank or artillery barrel. The short parallel missiles and central radar identify air defense without relying on color. Six wheels and a medium hull distinguish it from the eight-wheel enclosed APC and four-wheel open scout. The palette and edge treatment match the existing vehicle sprites.
