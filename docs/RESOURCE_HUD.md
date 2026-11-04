# Resource HUD

The subsequent full-height gauge and production-first layout are documented in [PRODUCTION_SIDEBAR.md](PRODUCTION_SIDEBAR.md).

Credits and current income occupy a 28 px top strip. Power occupies a 44 px rail beside the production sidebar. The map camera excludes both regions so clicks, centering and zoom remain aligned with the visible map.

The RA2-inspired gauge fills upward with supplied power; the white marker shows consumption on the same scale. Supply and usage have numeric labels. A deficit changes the fill to red and displays LOW, so the warning does not rely on color alone. The tooltip explains the existing production penalties. The scale grows in 40-power increments to accommodate larger bases; zero supply and demand remain valid.

These choices keep resources visible while switching production tabs, without retaining duplicate resource text in the bottom command bar. Existing olive panels and pale text preserve the approved military art direction. No economy rules changed, and the remaining sidebar redesign is not part of this change.

## Verification

Godot 4.7.2, Compatibility renderer:
- HUD tests passed, including resource/map bounds and deficit, recovery and zero-power values.
- Rendered UI review passed: four tabs, pause/resume, empty saves, name validation and victory banner. Inspected normal, low-power and compact screenshots.
- Runtime selection passed with mouse and synthetic touch at all three zoom tiers, with 24 simulation units unchanged.
- `git diff --check` passed (existing line-ending notices only).

## Scoped delivery gate

- Hard gate PASS: explicitly requested resource elements; real economy values; existing controls remain functional in HUD/runtime tests; no new interactive controls or fabricated claims.
- Purpose gate PASS: top strip provides persistent financial information; vertical fill and demand marker compare supply against consumption; LOW adds a non-color deficit cue.
- Liveliness PASS: existing ENERGY 2 / RHYTHM 1 / MOTION 1 direction retained; no flashing or decorative motion added.
- Craftsmanship PASS: inspected 1280x720 and compact 960x540 renders, tested resource states and reserved camera bounds. Physical touch and gamepad were not tested; existing small-screen text limitations are unchanged.
