# Art caching measurements

## Implemented

`UnitLayer.visual_stacks()` reuses grouping dictionaries, member arrays, class counts
and sorted stack order. An allocation-free validation scan checks roster identity/order,
hex, faction, kind and deployment before reuse. Health, selection, flash and interpolated
position remain live; they are not cached. Rebuilds replace the cache rather than retaining
old rosters. Drawing and both picking paths use the same cache.

`UnitArt.texture()` aliases icon requests to base resources. All 39 generated pairs
have identical artwork; only their SVG title differs. `art_cache_checks.gd` verifies
the source equivalence so future distinct icon artwork cannot silently use this alias.
Canonical file paths remain available for manifests and existing import tests.

## Measurements

Godot 4.7.2 debug executable, Windows, Compatibility renderer, Radeon RX 5500 XT.
These are development microbenchmarks, not release-build FPS or GPU timings.
Reproduce with `--path . --script tests/art_performance.gd` using a real renderer.

* 1,200-unit stack construction, 100 iterations: 17.5-20.6 ms per call.
* Validated cache hit, same roster: 1.55-1.60 ms per call, roughly 11-13x less CPU time.
* Shared icon/base pairs: 0 before, 39 after. Avoids 39 duplicate texture resources.
* Observed whole-scene texture monitor: 72,035,975 bytes before, 68,628,155 after.
  This is a whole-scene observation, not an isolated allocation measurement.
* Whole-scene draw calls: 3,699 before, 3,676 after. Terrain/HUD are included;
  this does not establish unit texture switches as the frame bottleneck.
* Warm static building body submission: 4.17 microseconds per building in a 600-call
  sample. Does not include construction/health/production overlays or GPU execution.

## Deferred deliberately

Separate retained building nodes were not added: three initial building bodies cost
roughly 0.013 ms in the warm submission sample. Splitting them out also requires
preserving territory, construction, ghost, selection and unit ordering. The current
measured stack cost is substantially larger. Buildings still share cached textures.

No atlas was added. Before making that change, isolate unit draw calls/GPU cost from
terrain and HUD in a representative release build. An atlas will not remove stack
construction or terrain/HUD work, and adds packing, filtering and import complexity.

## Regression evidence

`art_cache_checks.gd`: cache reuse plus invalidation for movement, kind/faction,
death/revival, embark/unload, reordered/replaced/removed units, empty roster and all
39 source-verified texture aliases. Art checks: 784 passed. Smoke: 1,190 passed.
Runtime mouse and synthetic touch selection passed at far, medium and close zoom.
No visual direction, gameplay rule or input anchor changed.
