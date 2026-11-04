# Command HUD review

## Direction

ENERGY 1 / RHYTHM 2 / MOTION 1. The battlefield remains the focal point.

- The supplied `download (1).svg` supersedes the earlier Allied direction: navy/teal surfaces, a full-width resource header, right-hand production lists, and a bottom command deck.
- Existing unit and building art identifies actual production choices; infantry badges are unchanged.
- The engine's readable default font avoids introducing an unrelated display face.
- Header values come from the simulation; the bottom-left minimap and selection orders stay off the production palette. Terrain now uses the supplied muted greens and cyan selection treatment, while retaining the real world geography and approved unit art.
- The deck is 88 reference pixels tall (reduced from 125); the header is 42 (reduced from 54), with a 52px physical minimum. Pause fills an 82x34 reference-pixel target, with proportional text and a 44px minimum height. Credits display two decimal places; simulation precision is unchanged.
- The production sidebar is 180 reference pixels wide (reduced from 220), giving the battlefield the remaining 80% of the desktop width. The Vehicles tab tooltip also identifies its real aircraft production entries.
- One accent marks focus and selected tabs; no decorative glow or animation competes with combat.
- Phone production becomes a bottom sheet instead of shrinking desktop controls.

## Implemented surfaces

A. Shared reference-driven theme, fixed production sidebar, full-width resource header and compact command deck. Detailed contextual controls open above the deck.
B. Structures, defenses, infantry and vehicles reuse actual costs, requirements, queues and progress. A selected compatible producer takes precedence over the primary/newest fallback. The sidebar is production-only: no Army/Sites navigation. Bunkers live under Defenses; no unsupported weapons are invented.
C. Selected armies expose existing orders plus explicit destination picking for Move. Building controls retain rally, primary, repair, sell and construction cancellation. Territory reports ownership, supply, roads and income per minute.
D. Radar shares cached terrain, overlays ownership and camera footprint, and supports mouse/touch navigation. Ownership redraws and production/construction/attack alerts use state signals. A bounded five-second alert locates its event when pressed and suppresses repeated identical messages. Economy rebinding disconnects old saves' event sources.
E. Narrow screens use bottom sheets, 44px buttons and larger tab targets. Escape dismisses mobile production. Camera keyboard polling yields to focused UI; touch releases over UI clear camera gesture tracking.
F. Rendered desktop and phone review verified all four text tabs fit. Repair/Sell remain available in selection details; old sidebar proxies are hidden. Duplicate phone Options/objective blocks are hidden.

## Validation evidence

Local engine: Godot 4.4.1, Windows OpenGL Compatibility (Radeon RX 5500 XT). CI remains configured for 4.7.2.

- `tests/run_smoke_tests.gd`: 1,235 passed, zero failed, including the concurrent aircraft additions.
- `tests/hud_tests.gd`: passed, including selected producer, persistent queue display, orders, build signal, minimap navigation, pause/resume, real completion alert, stale economy disconnection, synthetic touch and 390x844 sheet bounds.
- `tests/ui_review.gd`: rendered successfully at 1280x720, 760x640 and 390x844, no console errors. Re-run after the deck-height and Pause-size changes.
- Captures here: desktop production, selected army and phone production. All are actual runtime renders, not mockups.

Recorded interaction evidence (automated signal/input execution, not manual mouse testing):

| Control | Observed result |
| --- | --- |
| Production sidebar | Single production surface; no Army/Sites navigation on desktop or phone |
| Build / Defenses / Army / Vehicles and aircraft | Four real build/train lists selected and rendered as single-column rows |
| Build item | Emits construction request without spending until placement |
| Facility / Train / Primary | Correct selected producer queues prepaid unit; independent rally retained |
| Rally / Repair / Sell / Cancel construction | Existing smoke suite verifies state mutation and stale selection protection |
| Sidebar Repair / Sell | Damaged-building fixture enables both controls; button activation emits repair and sell actions |
| Attack / Hold / Garrison / transport | Existing selection and simulation tests retained |
| Radar | Camera navigation; synthetic touch press/release tracked |
| Build toggle / context toggle | Phone sheet opens within viewport; context expands |
| Pause / Resume | Simulation and camera pause/resume |
| Save / Load | Empty list and blank name disabled states rendered |
| Completion alert | Actual recruitment emits visible ready message; old save source disconnected |

## Delivery gate and boundaries

- Hard gate PASS (automated scope): controls and disabled states covered above; real simulation numbers; native Godot focus/buttons retained; 390x844 render and bounds checks show no horizontal overflow. New shield icon identifies the real Defenses category.
- Purpose gate PASS: visual decisions documented above; teal boundaries separate command surfaces, blue marks active controls, existing silhouettes identify actual units. Larger Pause text improves visibility without crowding resource values.
- Liveliness PASS: ENERGY 1 / RHYTHM 2 / MOTION 1; battlefield remains focal, with reference-matched navy/teal framing and no distracting animation.
- Craft PASS (automated scope): headless and rendered evidence recorded, including empty/disabled states. Physical touchscreen and exhaustive manual keyboard/controller traversal are **not verified**.

This HUD pass does not add simulation features. Concurrent aircraft gameplay changes are preserved and remain exposed by existing production logic; unsupported naval production is not fabricated. Attack-move, guard, patrol, game speed and prepaid queue cancellation have no pretend controls. Alerts currently cover production, completed construction and building attacks, not every territory/continent/supply transition. Performance has not been profiled. The supplied illustration's fictional unit counts, costs and queues are replaced by real data; the result is not claimed to be a pixel-identical battlefield illustration.
