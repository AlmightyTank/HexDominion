# Overhead infantry (replaces military badges)

The user approved `top-down-style-preview.svg` after refining the uniform palette,
strict overhead view and natural rifle grip. `tools/top_down_art.py` reuses that
soldier geometry; `tools/build_unit_art.py` writes the complete faction/state family.
These are original SVGs, with no traced or third-party artwork.

## Direction and reasons

ENERGY 2 / RHYTHM 1 / MOTION 1.

* Faction blue, red or gold dominates the uniform so ownership reads at native size.
* Olive backpack/equipment ties infantry to the vehicle and building trim.
* Helmet, shoulders and backpack top establish a strict overhead view, with no legs.
* Offset rifle and separate grip/support hands avoid a symmetrical hugging pose.
* Rocket launcher and heavy gun/ammunition/bipod distinguish the other two roles.
* Dark outlines separate the small silhouette from terrain without a badge backing.
* Circular two-tone selection remains separate from the rotating soldier artwork.

## Technical frame

Transparent 128x128 SVG, center pivot (64,64), north-facing source, linear filtering.
Normal unit rendering uses 42 world pixels (34-42 in the medium army tier); strategic
rendering uses the existing stack scale and real counts. Current stack/expansion rules
remain unchanged.
Only artwork rotates; health, counts and selection remain upright.

Infantry below 50% health use damaged art; exactly 50% remains normal. Existing
attack/damage flashes, movement, selection, combat and production are unchanged.
Defeat removes the simulation object; its cosmetic snapshot expires after 0.65
simulation seconds. No new animation rig or gameplay class is introduced.

## Verification

See `TOP_DOWN_VERIFICATION.md` for rendered and interaction evidence. The historical
filename is retained for existing links; hex badges are no longer the active design.
