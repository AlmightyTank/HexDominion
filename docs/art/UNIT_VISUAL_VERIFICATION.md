# Unit visual verification

Verified locally with Godot 4.7.2, Compatibility renderer, Radeon RX 5500 XT.
Infantry badge refresh: both existing GitHub workflows were found and the validation
workflow now also runs the resource/badge checks and captures the faction/state gallery.
Remote CI results are reported separately after pushing; local results below are not
a claim of remote CI success.

## Executed checks

| Check | Result |
|---|---|
| `python tools/build_unit_art.py` | 156 SVGs plus manifest generated |
| `godot --headless --path . --editor --import` | Successful import, no parse errors |
| `godot --headless --path . --script tests/run_smoke_tests.gd` | 1,190 passed, zero failed |
| `godot --headless --path . --script tests/unit_art_checks.gd` | 724 passed, zero failed |
| `godot --headless --path . --script tests/hud_tests.gd` | Passed |
| `godot --headless --path . --script tests/production_tests.gd` | Primary/newest production, category routing, capture fallback and unfinished-site exclusion passed |
| `godot --headless --path . --script tests/americas_tests.gd` | Mexico City to Bogota connectivity passed |
| `godot --headless --path . --quit-after 10` | Booted without errors |
| `godot --path . --script tests/unit_art_gallery.gd` | Rendered full contact sheet, visually inspected |
| `godot --path . --script tests/unit_art_runtime.gd` | Mouse and touch selection at far/medium/close; 12 simulation objects unchanged |
| `godot --path . --script tests/infantry_visual_test.gd` | 27 units, all nine infantry combinations, three zoom tiers, attack/damage/movement/defeat captures; zero failures |
| `godot --path . --script tests/profile_map.gd` | Existing budget failure: 109 draw calls against budget 100, both before and after this change |

The resource suite covers every class/faction/state path, transparent corners,
dimensions, nonempty textures, distinct state/faction images, missing-art fallback,
mixed grouping, shared picking anchors, object identity, death removal and wreck expiry.
The gallery includes every class and faction, all four textures, native-size samples,
black silhouettes, count badges and selection over five terrain value swatches.
Visual review led to stronger forward anti-air pods, destroyer side sponsons and
wider close-view spacing. The infantry refresh replaces circles with metallic hexagonal
frames, helmeted weapon silhouettes and role insignia. All nine combinations were
inspected at native scale. No concept image was available for exact comparison.

The map benchmark measured 16.89 ms/frame for this change versus 17.22 ms/frame in
a separately imported clean archive of prior commit `32ed783` on the same machine.
Both averaged 109 draw calls over 180 samples and failed the old 100-call budget.
These are single debug runs, not a statistically supported speedup or proof of
unlimited-army performance. No terrain/render-budget changes were made to hide it.

Capture paths can be selected with `HEX_FRONTLINES_ART_CAPTURE` (PNG path) and
`HEX_FRONTLINES_RUNTIME_CAPTURE` (existing directory). Runtime captures are named
`unit-runtime-far.png`, `unit-runtime-medium.png`, `unit-runtime-close.png`.

## Delivery gate, scoped to the changed unit visuals

* Hard gate PASS: requested original assets only; no invented gameplay or claims,
  baked labels, dead controls, new menus or theme switch. Unknown art has a visible
  question-mark fallback. Counts come from actual group members.
* Interaction PASS: mouse selection and touch press/release select a real unit at
  each of the three rendered zoom tiers. Existing keyboard/HUD controls are unchanged.
  No new focusable UI elements were introduced.
* Readability PASS: dual-value selection outline inspected on light/dark, green, sand,
  ocean and gray swatches; native-size class icons and count text inspected in the
  rendered gallery. Count text uses the existing light-on-dark treatment.
* Purpose gate PASS: palette, panel motifs, hex frames, outlines, spacing and grouping
  have explicit reasons in `UNIT_VISUAL_SPEC.md` and `INFANTRY_BADGE_DESIGN.md`;
  defeat fade communicates actual removal without retaining dead simulation units.
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
