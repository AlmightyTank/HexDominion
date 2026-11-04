# Hex Dominion unit visual specification

## Direction and scope

Infantry use overhead soldiers, not framed badges. Buildings use overhead structures.
The user-approved source target is `top-down-style-preview.svg`.
Top-down, original silhouette-first military vectors. ENERGY 2 / RHYTHM 1 /
MOTION 1: tactical clarity, predictable map grouping, short combat feedback only.
The existing four approved vehicle SVGs are source art, not discarded experiments.
`tools/build_unit_art.py` creates the related family deterministically with no
dependencies or remote services. `assets/units/roster/manifest.json` records every
source path and silhouette. No traced or third-party military artwork is used.

Playable classes are defined by `UnitCatalog.TYPES`, not this art manifest.
Generating artwork does not enable additional gameplay classes. Naval
pathfinding, flight, transports and additional production rules are outside this task.
Existing faction IDs 1/2 are player/rival, not formal faction names. Visual slots
A/B/C map to IDs 1/2/3; unknown IDs clamp to the nearest supported slot.

## Roster and silhouettes

| Stable visual ID | Name | Silhouette |
|---|---|---|
| rifle | Rifleman | Overhead helmet, shoulders, offset shouldered rifle |
| rocket | Rocket Soldier | Overhead soldier, broad shoulder launcher |
| gunner | Machine Gunner | Overhead soldier, heavy gun, ammunition box, bipod |
| tank | Main Battle Tank | Wide tracks, turret, long cannon |
| scout | Scout Vehicle | Narrow light hull, four exposed wheels |
| apc | APC | Boxy enclosed troop compartment, eight wheels |
| anti_air | Mobile Anti-Air | Paired forward-projecting missile banks, central radar |
| artillery | Self-Propelled Artillery | Extended chassis, very long barrel |
| helicopter | Attack Helicopter | Cross rotor, thin tail boom, side weapon pods |
| fighter | Fighter Jet | Pointed nose, swept wings, split tail |
| patrol_boat | Patrol Boat | Small narrow pointed hull, light fore gun |
| destroyer | Destroyer | Longer hull, fore/aft guns, side sponsons, central superstructure |
| landing_transport | Landing Transport | Broad squared hull, open cargo deck, ramp |

Infantry show helmet, shoulders and the top of the backpack, never visible legs.
Role recognition comes from the weapon silhouette, not a surrounding badge.
Ship scale and deck details complement hull shape; recognition must also be judged
at native 25-28 pixel display sizes, not only at source resolution.

## Factions

* A: dominant blue `#55aff0`, pointed chevron rear panel.
* B: dominant red `#f08075`, broad rectangular armor panel and two bright rivets.
* C: dominant gold `#e5ba59`, twin utilitarian rails.

Panels provide grayscale identification without changing the class footprint. These
are deliberately modest panel variants, not independent redesigns. The accent on
the unit itself differs from the existing teal player ownership/HUD accent, which is
preserved to avoid changing established game interaction semantics.
Faction color dominates uniforms, hulls and roofs. Olive is secondary equipment/trim;
dark outlines, weapons and tracks separate the artwork from terrain.

## States

Each class/faction has base, damaged, destroyed and icon SVGs (156 files total).
Tank/artillery additionally have 36 healthy/damaged hull, turret and barrel layers.
Each of the six buildings has healthy, damaged and destroyed art for three factions
(54 files). Building damage starts below maximum HP and repairs restore healthy art.
Selected is a reusable dark-backed pale circular outline for every class,
not another texture copy. Its double
stroke remains legible on ocean, forest, desert, snow and city terrain.
Non-infantry health below maximum queries damaged; infantry require below 50%.
Zero queries destroyed. Damaged art uses
a dark scorch patch and angular crack. Destroyed art uses muted burnt tones and a
broad structural fracture with debris; infantry use the same cracked inactive marker,
not corpses. These are simplified vector state treatments, not animated wreck art.
Attack flashes, movement facing and gameplay health bars remain separate layers.
Strategic stacks use damaged artwork and a notch when at least one member crosses
its damage threshold; the health
bar shows the lowest member fraction, not an invented combined simulation health.

Dead simulation objects are removed normally. Wreck snapshots at every zoom last eight
simulation seconds for vehicles, or fade over 0.65 seconds for infantry, capped at
128, never selected or counted. They are cosmetic and
are not saved. Successful save restoration clears cosmetic snapshots atomically.
Combat-destroyed buildings leave eight-second cosmetic rubble, separately capped
at 128. Demolition does not produce rubble; a replacement building hides old rubble.

## Files and imports

`assets/units/roster/<category>/<kind>/<kind>_faction_<a|b|c>_<state>.svg`
is the canonical generated path; state is base/damaged/destroyed/icon.
Categories are infantry, vehicles, aircraft, naval. Icons live with their source
class rather than in a duplicate icon tree. The four original root SVGs remain
editable source inputs. All sources have transparent 128x128 canvases, center pivot
(64,64), north-facing units, no baked text or environment.
Godot imports SVGs as Texture2D. Runtime scales them to 28 world pixels, with linear
filtering inherited from the project. This is vector-style art, not pixel art.
Strategic icons retain the shared overhead silhouette and remain independent files.
Portraits are not added: the current text selection panel does not need them.

## Godot integration

`UnitArt` provides roster/category/path lookup, health-state query, cached Texture2D
lookup, faction mapping and modular selection drawing. Unknown/missing textures
draw a visible question-mark placeholder rather than silently drawing another class.
Definitions do not extend UnitCatalog and cannot accidentally enable production.
`UnitAppearance` retains existing health/hold/garrison and attack feedback.
Expanded tanks/artillery draw the generated armor layers instead of procedural
bodies. Turrets rotate about authored pivots (64,76) and (64,85); only barrels
recoil. Muzzle flashes use those same pivots and recoil distances. Strategic stacks
use the full composited state texture. See `DAMAGE_ARTWORK.md` for verification.

`UnitVisuals` remains authoritative for zoom thresholds: far <0.65, medium <1.5,
close >=1.5. Current hex/faction stacks retain exact counts and the existing
expansion behavior. Expanded units use interpolated movement and facing
(+X simulation to north-facing texture). Infantry rotate with their weapons;
health, selection and count overlays remain upright.
No zoom path creates, deletes, merges or duplicates simulation objects.
Existing mouse/touch picking and group cycling use the same presentation anchors.
Very crowded neighboring hex groups can still overlap; there is no screen-space
cross-hex decluttering or unlimited-army performance claim.

## Visual decision reasons

* Dark outline: separates light armor from snow without hiding vehicle silhouette.
* Dominant faction bodies with secondary olive: ownership reads consistently across classes.
* Pale selection plus dark backing: dual-value contrast over both light/dark terrain.
* Fixed family panel placement: consistent faction recognition in grayscale.
* Overhead infantry: soldiers inhabit the same map viewpoint as tanks and structures.
* Native Godot count text: exact counts remain readable without baking numbers into art.
* Existing grouping: preserves input behavior and simulation count semantics.
* No new menu controls: integrates art without redesigning the user's active HUD work.

## Verification

Run `python tools/build_unit_art.py`, Godot headless editor import, existing smoke
tests, and `tests/unit_art_checks.gd` for every path, size, alpha and state lookup.
`tests/top_down_gallery.gd` produces the current rendered contact sheet for units,
buildings, factions, damage and native-size selection samples. See
`TOP_DOWN_VERIFICATION.md` for this revision's evidence. Runtime/map
profiling remains separate; a gallery is not proof of arbitrary army-scale performance.
