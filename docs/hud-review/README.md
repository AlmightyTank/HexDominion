# Command HUD review

## Direction

ENERGY 1 / RHYTHM 2 / MOTION 1. The battlefield remains the focal point.

- Navy panels separate command surfaces from terrain without imitating map tiles.
- Existing unit and building art identifies actual production choices; infantry badges are unchanged.
- The engine's readable default font avoids introducing an unrelated display face.
- Compact top resources, full-width production rows and a bottom inspector serve different information densities.
- One accent marks focus and selected tabs; no decorative glow or animation competes with combat.
- Phone production becomes a bottom sheet instead of shrinking desktop controls.

## Implemented surfaces

A. Shared theme, persistent resource strip and collapsible production/context/radar surfaces.
B. Structures, infantry and vehicles reuse actual costs, requirements, queues and progress. A selected compatible producer takes precedence over the primary/newest fallback.
C. Selected armies expose existing orders plus explicit destination picking for Move. Building controls retain rally, primary, repair, sell and construction cancellation. Territory reports ownership, supply, roads and income per minute.
D. Radar shares cached terrain, overlays ownership and camera footprint, and supports mouse/touch navigation. Ownership redraws and production/construction/attack alerts use state signals. A bounded five-second alert locates its event when pressed and suppresses repeated identical messages. Economy rebinding disconnects old saves' event sources.
E. Narrow screens use bottom sheets, 44px buttons and larger tab targets. Escape dismisses mobile production. Camera keyboard polling yields to focused UI; touch releases over UI clear camera gesture tracking.
F. Rendered desktop and phone review corrected narrow cards, hidden category tabs and truncated phone income.

## Validation evidence

Local engine: Godot 4.4.1, Windows OpenGL Compatibility (Radeon RX 5500 XT). CI remains configured for 4.7.2.

- `tests/run_smoke_tests.gd`: 1,190 passed, zero failed.
- `tests/hud_tests.gd`: passed, including selected producer, persistent queue display, orders, build signal, minimap navigation, pause/resume, real completion alert, stale economy disconnection, synthetic touch and 390x844 sheet bounds.
- `tests/ui_review.gd`: rendered successfully at 1280x720, 960x640 and 390x844, no console errors.
- Captures here: desktop production, selected army and phone production. All are actual runtime renders, not mockups.

Recorded interaction evidence (automated signal/input execution, not manual mouse testing):

| Control | Observed result |
| --- | --- |
| Army / Production / Sites | Selected content changes; six category icons retained |
| Structures / Infantry / Vehicles | Real build/train lists selected and rendered |
| Build item | Emits construction request without spending until placement |
| Facility / Train / Primary | Correct selected producer queues prepaid unit; independent rally retained |
| Rally / Repair / Sell / Cancel construction | Existing smoke suite verifies state mutation and stale selection protection |
| Attack / Hold / Garrison / transport | Existing selection and simulation tests retained |
| Radar | Camera navigation; synthetic touch press/release tracked |
| Build toggle / context toggle | Phone sheet opens within viewport; context expands |
| Pause / Resume | Simulation and camera pause/resume |
| Save / Load | Empty list and blank name disabled states rendered |
| Completion alert | Actual recruitment emits visible ready message; old save source disconnected |

## Delivery gate and boundaries

- Hard-gate checks: functional controls covered above; real simulation numbers; no invented assets, testimonials, claims or unsupported production. Focus style and native Godot buttons retained. Phone renders show no horizontal overflow.
- Purpose-gate checks: visual decisions documented above; no gradients, glass, decorative arrows or new illustrations.
- Liveliness checks: declared dials; terrain is focal point; military palette and existing unit silhouettes provide identity.
- Craft checks: headless and rendered evidence recorded, including empty/disabled states. Physical touchscreen and exhaustive manual keyboard/controller traversal are **not verified**.

This is not a new simulation feature release. Aircraft/naval artwork has no playable production backend, so those categories are not offered. Attack-move, guard, patrol, game speed and prepaid queue cancellation are not implemented and have no pretend controls. Alerts currently cover production, completed construction and building attacks, not every territory/continent/supply transition. Performance has not been profiled; no frame-rate claim is made.
