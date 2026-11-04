# Weapon-tip firing effects

Flashes use the approved overhead roster rather than a generic light beside each unit.

- Rifle, machine gun and rocket origins match their offset SVG weapons.
- Scout and APC origins match their small defensive mounts.
- Anti-air uses the two forward launcher tips.
- Expanded tanks and artillery follow turret facing and the drawn barrel recoil.
- Upright stack icons use their own SVG origins, not simulation facing. A stack shows only its newest firing member, avoiding overlapping flashes.
- Orange directional bursts with pale cores distinguish discharge from damage feedback. Heavy guns have larger bursts; flashes fade within 65ms (light) or 90ms (heavy), inside the existing 140ms attack timer.
- No new textures, particle nodes, combat changes, camera shake or smoke changes.

## Verification

Godot 4.7.2 Compatibility renderer, Radeon RX 5500 XT:

- `tests/firing_effect_checks.gd`: all eight playable kinds have anchors, recoil endpoints and dual anti-air origins checked. Rendered and inspected four directions, independently rotated heavy turrets, native scale, stack scale and expired flashes.
- `tests/unit_art_checks.gd`: 784 checks passed.
- `tests/run_smoke_tests.gd`: 1,190 checks passed.

## Scoped delivery gate

- Hard gate PASS: user requested corrected unit flashes and vehicle flashes; no controls, text layout or input behavior changed. Rendered fixture and existing tests ran without errors.
- Purpose gate PASS: weapon-local origins communicate firing direction; pale core/orange edge reads as a brief discharge, not a selection glow.
- Liveliness PASS: existing ENERGY 2 / RHYTHM 1 / MOTION 1 retained, with short event-driven flashes only.
- Craft PASS: shared procedural renderer covers expanded units and upright stacks; no claims of physical-device or release-performance testing.
