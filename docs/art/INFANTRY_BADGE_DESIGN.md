# Infantry military badges

## Reference and direction

The concept image was not attached or available in the repository. This implementation
uses the written specification, not an exact reference-image match. Original programmatic
SVG artwork is used; no external image generation, emoji, traced artwork or infographic
texture is involved. Direction: ENERGY 2 / RHYTHM 1 / MOTION 1, military insignia with
predictable class grouping and short combat feedback. This supersedes circular infantry.

## Assets and palettes

`tools/infantry_badges.py` authors reusable metallic bevel, inset dark field, helmeted
soldier, weapon, bottom role insignia and wear layers. `tools/build_unit_art.py` writes
36 infantry SVGs to the established `assets/units/roster/infantry/<kind>/` folders.
All are transparent 128x128 sources; Godot caches Texture2D imports and scales them at
render time. Separate compact icons omit the torso to enlarge the weapon at far zoom.
No per-frame texture generation or new dependencies are introduced.

| Existing ID | Pose and weapon | Bottom role |
|---|---|---|
| rifle | Helmeted soldier aiming compact assault rifle right | Chevron |
| rocket | Helmeted soldier with broad shoulder launcher and projecting round | Rocket |
| gunner | Supported heavy receiver, extended barrel, ammunition box and bipod | Three rounds |

Palette definitions are centralized in `PALETTES` in the badge generator. A uses
blue/navy, B red/gunmetal, C gold/olive. Existing player/rival IDs remain 1/2; slot 3
is artwork support only. The runtime selection accent uses the shared UnitArt palette.
Weapons and role symbols identify classes without relying on faction color.

## Runtime integration

* Normal: silver soldier, metallic frame, faction edge and shaded inset.
* Selected: dark-backed pale **hexagonal** outer outline plus a brighter faction edge.
  Every selected member is outlined in close view; any selected group member highlights
  its class group. No human sprites or animation rigs are used.
* Damaged: infantry health **strictly below 50%** selects the darker/worn SVG. Exactly
  50% remains normal. The health bar still updates for any health loss. Non-infantry
  health thresholds and artwork are unchanged.
* Taking damage: brief red hexagonal impact outline from existing damage_flash.
* Attacking: existing short weapon flash, driven by actual attack_flash.
* Defeated: normal death removes the simulation object immediately; an unselectable
  cracked desaturated snapshot fades over 0.65 simulation seconds at close zoom.
  Existing non-infantry wreck lifetime remains eight seconds. Pause freezes effects.
* Movement: existing interpolated movement is retained, with no cosmetic gameplay offset
  changes, new orders or altered attack targeting.

Far (<0.65) shows separate class/faction/hex icons and real counts. Medium (<1.5) shows
one larger full badge per class group with exact count. Close shows each real unit.
The established shared input anchors handle mouse and touch. Zoom never changes the
roster. Existing spacing separates mixed classes; extremely crowded neighboring hexes
can still overlap and there is no new obstacle-aware screen-space decluttering.

## Design reasons

* Hex frame repeats the game's territory geometry, replacing the old circular tokens.
* Metallic bevel distinguishes a military insignia from a flat UI button.
* Dark field and silver figure maximize weapon contrast over varied terrain.
* Shared pose plus different weapon mass/bipod keeps a cohesive but distinct roster.
* Bottom insignia reinforces class when the torso is omitted at strategic scale.
* Cached SVG imports and bounded cosmetic snapshots avoid dynamic texture allocations.
* Brief defeat fade avoids accumulating dead infantry or changing gameplay death rules.

## Verification

Use the commands in `UNIT_VISUAL_VERIFICATION.md`. The expanded art checks include all
nine class/faction combinations, 50% threshold boundaries, compact icons, hex footprint,
nonselectable defeat and 0.65-second expiry. Existing smoke tests cover infantry combat,
capture, production, garrisons, movement and saves. Rendered gallery and actual main-scene
screenshots cover all three zoom tiers. No reference-image comparison is claimed.
