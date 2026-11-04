# Top-down roster verification

Verified with Godot 4.7.2 on Windows using the Compatibility renderer.

## Automated evidence

* `tests/unit_art_checks.gd`: 784 checks, zero failures.
* `tests/run_smoke_tests.gd`: 1,190 checks passed.
* `tests/production_tests.gd`: passed production routing and capture cases.
* `tests/hud_tests.gd`: passed bounds, zoom, tabs, build signal, radar and pause cases.
* `tests/unit_art_runtime.gd`: mouse selection and synthetic touch selection at
  far, medium and close zoom; all 24 simulation objects preserved.
* `tests/infantry_visual_test.gd`: 27 units, nine role/faction combinations,
  three zoom tiers, changed attack/damage frames, movement and defeat; zero failures.

## Rendered evidence

`tests/top_down_gallery.gd` renders all 13 art classes and six building types in
all three palettes, enlarged and native-size, with damage, selection and counts.
The gallery was visually inspected, including four soldier facings. Actual
main-scene close screenshots were inspected: overhead HQ, soldiers, faction colors,
health, count and selection overlays render on the terrain with the existing HUD.
Captures are local review artifacts under the approved OpenCode temporary folder,
not shipped game assets. Set `HEX_FRONTLINES_ART_CAPTURE` for the gallery PNG,
`HEX_FRONTLINES_RUNTIME_CAPTURE` for runtime screenshots, or use
`tests/infantry_visual_test.gd -- --output=<directory>` to reproduce them.

## Delivery gate (scope: changed art and rendering)

* Hard Gate PASS: approved artwork only, no new controls or fabricated content;
  actual renderer and mouse/synthetic-touch selection exercised at all three tiers.
  Web-only semantics/media rules do not apply to these Godot draw calls.
* Purpose Gate PASS: faction dominance identifies ownership, dark edges separate
  terrain, weapon/roof silhouettes identify roles; reasons recorded in the art spec.
* Liveliness PASS: ENERGY 2 / RHYTHM 1 / MOTION 1 follows the approved preview;
  shared palette and overhead geometry unify the roster without added decoration.
* Craftsmanship PASS: transparent imports, faction/state variants and simulation
  invariants covered by art/smoke tests; rendered gallery and main scene inspected.

Physical touchscreen testing and an exhaustive manual playthrough are not claimed.
No gameplay roster, collision footprint, production cost or navigation rule changed.
