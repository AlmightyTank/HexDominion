# Damage artwork integration

The approved faction-dominant overhead art now covers every runtime state.
No unit production, damage, movement or health thresholds were changed.

## Artwork and rendering

* Infantry retain the approved healthy/damaged/defeated art and brief defeat fade.
* All ten vehicle/aircraft/naval classes have regenerated wrecks derived from their
  current silhouette, with burnt panels, an exposed cavity and detached debris.
* All six buildings have three states in all three faction palettes. Roof cracks
  and scorch patches communicate damage without adding smoke or obscuring ownership.
* Expanded tanks/artillery use generated hull/turret/barrel textures, not the old
  procedural bodies. Independent aim and barrel recoil are preserved. Flash origins
  follow the authored turret pivot and moving barrel tip.
* Stack icons select damaged textures as soon as a member crosses its existing
  class threshold. Counts, health bars and selection remain screen-aligned.
* Unit wrecks draw at every zoom. Buildings destroyed through combat emit a cosmetic
  snapshot before their simulation entry disappears. Rubble lasts eight seconds,
  is bounded, cannot be selected, is not saved, and is cleared on save restoration.
  Building replacement hides old rubble. Demolition/cancellation do not create it.
* Textures remain lazily cached; healthy icons still alias their base texture.
  The generator and manifests include the new layers/states. All artwork is original
  project vector art, with no external asset licensing dependency.

## Verification

Godot 4.7.2, Compatibility renderer, Radeon RX 5500 XT:

* `tests/damage_art_checks.gd`: armor layer imports/cache, distinct building states,
  health-to-art selection, repair, player/rival destruction, noncombat removal,
  duplicate listener prevention and rubble expiry.
* Its rendered gallery covers 13 unit classes, six buildings, three factions,
  healthy/damaged/destroyed states, native stack icons and four independently aimed
  damaged tank/artillery turrets with recoil/flashes. Inspected visually.
* `tests/unit_art_checks.gd`: 784 checks, zero failures.
* `tests/run_smoke_tests.gd`: 1,190 passed, zero failed.
* Art cache, firing anchor, production and HUD suites passed.
* `tests/unit_art_runtime.gd`: mouse and synthetic touch selection at far/medium/close
  retained all 24 simulation units. Rendered damaged stack screenshot inspected.

Gallery output: `%LOCALAPPDATA%/Temp/opencode/damage-art.png`.
This is debug-rendered verification, not a release performance or physical-device test.

## Scoped delivery gate

* Hard gate PASS: requested assets only; engine import/run/tests clean; no new controls,
  text layout, themes, claims or input paths. Existing selection checks passed.
* Purpose gate PASS: faction color identifies ownership; cracks distinguish damaged
  from healthy; muted cavities/debris distinguish inactive wrecks from live units.
* Liveliness PASS: approved ENERGY 2 / RHYTHM 1 / MOTION 1 retained; existing short
  weapon recoil remains functional feedback, with no added camera or smoke effects.
* Craft PASS: rendered full-state gallery and actual-game stacks inspected; caches,
  repair and destruction lifecycle tested. No new gameplay classes were enabled.
