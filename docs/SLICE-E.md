# Slice E — Real-time combat

Stationary units automatically attack the nearest living enemy within one hex (including their own hex). Equal-distance ties use roster order. Damage is continuous and simultaneous: mutual destruction is possible, with no first-attacker advantage. Friendly fire is disabled. Moving units can take damage but cannot fire; range uses their last reached hex, not their interpolated marker position.

| Unit | Health | Damage/second | Seconds/hex |
| --- | ---: | ---: | ---: |
| Rifle squad | 100 | 20 | 0.45 |
| Main battle tank | 250 | 45 | 0.65 |

The second starter unit is a tank (rectangular hull and barrel). All units display health bars; lines indicate active attacks. The rival rifle garrison starts three hexes from the third player squad, on reachable land, so combat does not begin automatically at startup. Move a squad within one hex and let it stop to engage.

Combat resolves before capture and movement each physics tick. Dead units are removed, selection clears if needed, and dead defenders no longer block capture. Garrisoned units fire normally but cannot move until released with G. Ownership survives unit death; occupy the defeated defender's hex for three seconds to capture it.

No pursuit AI, explicit attack orders, projectiles, armor modifiers, line-of-sight, terrain bonuses, healing or production yet. Continuous DPS is a prototype rule, not a weapon cooldown system. Coarse manual simulation steps can over-apply damage after a lethal instant; normal gameplay runs fixed physics ticks.

## Verification

Headless tests cover simultaneous damage/death, range, friendly fire, distinct tank stats, moving-unit restrictions, dead-unit orders/capture, removal and selection cleanup, and capture following a defender's death, alongside prior regressions.

Manual checks pending: rifle/tank silhouettes and bars at zoom extremes; attack lines and health depletion; mutual destruction; moving away from range; garrison combat; capture after defeating the rival.
