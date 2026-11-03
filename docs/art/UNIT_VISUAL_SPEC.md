# Hex Dominion unit visual specification

## Direction and scope

Top-down, original silhouette-first military vectors. ENERGY 2 / RHYTHM 1 /
MOTION 1: tactical clarity, predictable map grouping, short combat feedback only.
The existing four approved vehicle SVGs are source art, not discarded experiments.
`tools/build_unit_art.py` creates the related family deterministically with no
dependencies or remote services. `assets/units/roster/manifest.json` records every
source path and silhouette. No traced or third-party military artwork is used.

Only rifle, rocket, gunner and tank currently have simulation/production definitions.
The other nine classes are **visual-only support**, not playable additions. Naval
pathfinding, flight, transports and additional production rules are outside this task.
Existing faction IDs 1/2 are player/rival, not formal faction names. Visual slots
A/B/C map to IDs 1/2/3; unknown IDs clamp to the nearest supported slot.

## Roster and silhouettes

| Stable visual ID | Name | Silhouette |
|---|---|---|
| rifle | Rifleman | Circular marker, rifle with stock and grip |
| rocket | Rocket Soldier | Circular marker, broad launcher and pointed round |
| gunner | Machine Gunner | Circular marker, heavy receiver, ammunition box and bipod |
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

All infantry remain circles, never humanoids. Their black outer silhouettes are
intentionally identical; role recognition comes from the high-contrast center symbol.
Ship scale and deck details complement hull shape; recognition must also be judged
at native 25-28 pixel display sizes, not only at source resolution.

## Factions

* A: cool steel with blue, pointed chevron rear panel.
* B: gunmetal with red, broad rectangular armor panel and two bright rivets.
* C: olive/sand with amber, twin utilitarian rails.

Panels provide grayscale identification without changing the class footprint. These
are deliberately modest panel variants, not independent redesigns. The accent on
the unit itself differs from the existing teal player ownership/HUD accent, which is
preserved to avoid changing established game interaction semantics.

## States

Each class/faction has base, damaged, destroyed and icon SVGs (156 files total).
Selected is a reusable dark-backed pale ring, not another texture copy. Its double
stroke remains legible on ocean, forest, desert, snow and city terrain.
Any health below maximum queries damaged; zero queries destroyed. Damaged art uses
a dark scorch patch and angular crack. Destroyed art uses muted burnt tones and a
broad structural fracture with debris; infantry use the same cracked inactive marker,
not corpses. These are simplified vector state treatments, not animated wreck art.
Attack flashes, movement facing and gameplay health bars remain separate layers.
The strategic damaged notch means at least one group member is injured; the health
bar shows the lowest member fraction, not an invented combined simulation health.

Dead simulation objects are removed normally. Close-view wreck snapshots last eight
simulation seconds, capped at 128, never selected or counted. They are cosmetic and
are not saved. Successful save restoration clears cosmetic snapshots atomically.
No wrecks clutter strategic view.

## Files and imports

`assets/units/roster/<category>/<kind>/<kind>_faction_<a|b|c>_<state>.svg`
is the canonical generated path; state is base/damaged/destroyed/icon.
Categories are infantry, vehicles, aircraft, naval. Icons live with their source
class rather than in a duplicate icon tree. The four original root SVGs remain
editable source inputs. All sources have transparent 128x128 canvases, center pivot
(64,64), north facing, no baked text, no environment, and 3px dark outlines.
Godot imports SVGs as Texture2D. Runtime scales them to 28 world pixels, with linear
filtering inherited from the project. This is vector-style art, not pixel art.
Strategic icons simplify the non-infantry silhouette and remain independent files.
Portraits are not added: the current text selection panel does not need them.

## Godot integration

`UnitArt` provides roster/category/path lookup, health-state query, cached Texture2D
lookup, faction mapping and modular selection drawing. Unknown/missing textures
draw a visible question-mark placeholder rather than silently drawing another class.
Definitions do not extend UnitCatalog and cannot accidentally enable production.
`UnitAppearance` retains existing health/hold/garrison and attack feedback.

`UnitVisuals` remains authoritative for zoom thresholds: far <0.65, medium <1.5,
close >=1.5. Far view shows one icon and exact count per hex/faction/class. Mixed
armies stay separate. Medium view uses one infantry marker with count or up to
three representative vehicle sprites plus exact count. Close view draws every live
unit with interpolated movement and facing (+X simulation to north-facing texture).
No zoom path creates, deletes, merges or duplicates simulation objects.
Existing mouse/touch picking and group cycling use the same presentation anchors.
Very crowded neighboring hex groups can still overlap; there is no screen-space
cross-hex decluttering or unlimited-army performance claim.

## Visual decision reasons

* Dark outline: separates light armor from snow without hiding vehicle silhouette.
* Muted body and restricted faction accents: keeps terrain and selected ring readable.
* Pale selection plus dark backing: dual-value contrast over both light/dark terrain.
* Fixed family panel placement: consistent faction recognition in grayscale.
* Circular infantry: honors the abstract marker rule and avoids noisy tiny humans.
* Native Godot count text: exact counts remain readable without baking numbers into art.
* Existing grouping: preserves input behavior and simulation count semantics.
* No new menu controls: integrates art without redesigning the user's active HUD work.

## Verification

Run `python tools/build_unit_art.py`, Godot headless editor import, existing smoke
tests, and `tests/unit_art_checks.gd` for every path, size, alpha and state lookup.
`tests/unit_art_gallery.gd` produces a rendered contact sheet for all classes,
factions and states plus native-size and terrain selection samples. Runtime/map
profiling remains separate; a gallery is not proof of arbitrary army-scale performance.
