# Unit visual verification

Verified locally with Godot 4.7.2, Compatibility renderer, Radeon RX 5500 XT.
No CI configuration was present; remote CI was not run. No commit or push was made.

## Executed checks

| Check | Result |
|---|---|
| `python tools/build_unit_art.py` | 156 SVGs plus manifest generated |
| `godot --headless --path . --editor --import` | Successful import, no parse errors |
| `godot --headless --path . --script tests/run_smoke_tests.gd` | 1,190 passed, zero failed |
| `godot --headless --path . --script tests/unit_art_checks.gd` | 692 passed, zero failed |
| `godot --path . --script tests/unit_art_gallery.gd` | Rendered full contact sheet, visually inspected |
| `godot --path . --script tests/unit_art_runtime.gd` | Mouse and touch selection at far/medium/close; 12 simulation objects unchanged |

The resource suite covers every class/faction/state path, transparent corners,
dimensions, nonempty textures, distinct state/faction images, missing-art fallback,
mixed grouping, shared picking anchors, object identity, death removal and wreck expiry.
The gallery includes every class and faction, all four textures, native-size samples,
black silhouettes, count badges and selection over five terrain value swatches.
Visual review led to stronger forward anti-air pods, destroyer side sponsons and
wider close-view spacing. Infantry black silhouettes deliberately remain circles;
their center symbols, rather than an external silhouette, identify the role.

Capture paths can be selected with `HEX_DOMINION_ART_CAPTURE` (PNG path) and
`HEX_DOMINION_RUNTIME_CAPTURE` (existing directory). Runtime captures are named
`unit-runtime-far.png`, `unit-runtime-medium.png`, `unit-runtime-close.png`.

## Delivery gate, scoped to the changed unit visuals

* Hard gate PASS: requested original assets only; no invented gameplay or claims,
  baked labels, dead controls, new menus or theme switch. Unknown art has a visible
  question-mark fallback. Counts come from actual group members.
* Interaction PASS: mouse selection and touch press/release select a real unit at
  each of the three rendered zoom tiers. Existing keyboard/HUD controls are unchanged.
  No new focusable UI elements were introduced.
* Readability PASS: dual-value selection ring inspected on light/dark, green, sand,
  ocean and gray swatches; native-size class icons and count text inspected in the
  rendered gallery. Count text uses the existing light-on-dark treatment.
* Purpose gate PASS: palette, panel motifs, circles, outlines, spacing and grouping
  have explicit reasons in `UNIT_VISUAL_SPEC.md`; no decorative glow or motion added.
* Liveliness PASS: ENERGY 2 / RHYTHM 1 / MOTION 1, class-specific original geometry,
  fixed faction panel language and existing short combat feedback.
* Craftsmanship PASS: actual import, resource checks, smoke tests and rendered runs
  completed; pre-existing gameplay/HUD work preserved. Browser-only semantics,
  web performance and page-layout checks do not apply to these Godot map visuals.

## Boundaries

Nine roster classes and faction C are visual support only, not new playable content.
State treatments are simplified vectors; no animated smoke, crash or sinking cycle.
Very crowded neighboring hexes may overlap; unlimited army-scale performance and
automatic cross-hex decluttering were not measured or implemented. Portrait cards
were unnecessary for the existing text selection panel. Terrain rendering is unchanged.

Next: approve the family at native size, then separately design gameplay definitions
and movement/production rules before enabling the additional classes.
