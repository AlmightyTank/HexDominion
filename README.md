# Hex Frontlines

**Conquer the world. Hold the line.**

> **Status:** Pre-alpha. v0.5 Slice A replaces passive territory income with a logistics-ready economy foundation. Both factions start with 2,000 credits, a headquarters, a Supply Center, an unarmed Supply Truck and equivalent finite supply access. Supply deliveries are not active until Slice B, so recurring income is currently zero.

**Hex Frontlines** is a real-time, hex-based world-conquest strategy game built with **Godot 4** and **GDScript**. It combines the territorial warfare of *Risk*, terrain and strategic depth inspired by *Civilization V*, and unit production, base building, and tactical combat inspired by *Command & Conquer: Generals Zero Hour*.

The entire war happens on **one continuous world map**. There are no turns and no separate battle screens: command armies, capture territory, construct bases, and defend your front lines in real time.

## The vision

Every hex matters. A rapidly expanding empire can become difficult to defend, while a smaller faction with strong garrisons and clever positioning can hold a front line against a larger force.

**Our design pillars:**

1. **One map, one war.** All movement, production, expansion, and combat take place on the same hexagonal world map.
2. **Territory requires defense.** A captured hex remains yours when troops depart, but leaving no garrison exposes it to a rapid counterattack.
3. **Easy to understand, hard to master.** Clear orders and readable front lines, with depth from terrain, unit counters, production, and logistics.
4. **RTS first.** Players command units in real time; terrain and territory influence tactics without introducing a turn system.
5. **Playable at every milestone.** Each major development version should finish with a testable game loop, not just isolated features.

## Core gameplay loop

1. Start with a headquarters, a small force, and a few controlled hexes.
2. Explore and capture neighboring territories using ground troops.
3. Secure strategic hexes with garrisons and defenses.
4. Protect supply routes and capture approved income locations to fund expansion.
5. Construct barracks, factories, and support buildings.
6. Produce troops and vehicles, set rally points, and launch coordinated assaults.
7. Defeat enemy armies, cut off their positions, and take their headquarters.

### Territory and capturing

- The world is built from hexagonal land and ocean cells.
- Faction borders follow controlled hexes, not real-world national borders.
- Ground troops capture neutral or enemy territory by occupying it uncontested for a short period.
- Contested hexes cannot complete capture until defenders are removed.
- Captured hexes retain their owner after troops move away.
- Troops assigned to a garrison stay to defend; empty territory is vulnerable.
- Special terrain, cities, and resources make some hexes more valuable than others.

### World map and terrain

The strategic map uses **real Earth land outlines** from public-domain Natural Earth 1:110m data, sampled onto **120 × 70 hexes** (8,400 cells). This reduced density keeps the world footprint while cutting the earlier 33,360-cell map by about 75%. The flat equirectangular map preserves recognizable continent locations, with simplified geographic terrain bands and no political borders. Small islands and narrow coastlines remain limited by hex resolution.

Snow covers Antarctica, Greenland, and the high Arctic, with tundra across northern Canada and Siberia, snow-capped mountain symbols, and illustrative static polar sea ice. These are simplified climate regions, not seasonal weather or surveyed snow cover. Sea ice remains ocean for gameplay, and city/resource markers retain the underlying biome color.

To refresh the bundled geography, run `python data/world/import_earth.py` (requires internet access). The game itself uses the bundled JSON offline. Source and license links are included in `data/world/earth_regions.json`.

Static terrain is rendered once into a cached texture; camera movement and hex selection do not redraw the terrain. The 8,400 selectable hexes are unchanged. Run `godot --path . --script res://tests/profile_map.gd --disable-vsync` with a display to benchmark full-map and zoomed/panning rendering, validate the cache and selection, and check the 100-draw-call budget. Headless smoke tests do not measure graphics performance.

| Terrain | Intended role |
| --- | --- |
| Plains | Standard movement and construction |
| Forest | Defensive advantage for infantry |
| Mountains | Restricted movement and strong defensive positions |
| Desert | Open terrain favorable to mobile vehicles |
| Cities | Strategic objectives; no automatic income |
| Resource areas | Finite supply locations; delivery collection arrives in v0.5 Slice B |
| Ocean | Naval travel and amphibious operations (later milestone) |

Terrain bonuses and penalties will be tuned through playtesting.

## Armies and combat

The roster is now complete: thirteen roles across infantry, vehicles, aircraft and naval warfare.

| Category | Units | Main role |
| --- | --- | --- |
| Infantry | Rifleman, Rocket Soldier, Machine Gunner | Territory capture and defense |
| Ground vehicles | Main battle tank, Scout vehicle, APC, Mobile anti-air, Self-propelled artillery | Break lines, recon, troop transport, air defense, bombardment |
| Aircraft | Attack helicopter, Fighter jet | Recon and strike missions from airfields |
| Naval | Patrol boat, Destroyer, Landing transport | Ocean control, coastal bombardment, amphibious landings |

Combat happens directly on the map in real time. The world map presents an army in three zoom tiers, and the zoom only changes presentation — it never merges, duplicates or removes a simulated unit:

- **Far zoom (world strategy view):** one compact marker per hex, faction and unit type with the true unit count.
- **Medium zoom (army view):** one readable representative sprite per role with a count badge and a health bar.
- **Close zoom (tactical view):** individual unit sprites with facing, health, selection and attack feedback.

### Tactical orders

| Order | Key | Behaviour |
| --- | --- | --- |
| Move | Right-click | Pathfinding with terrain, road and domain rules |
| Attack | X | Engage an explicitly selected target |
| Attack-Move | Z | Move while engaging threats, then resume and finish at the destination |
| Hold Position | J | Fire in range, never pursue across the map |
| Guard | V | Follow a friendly unit or defend a hex without uncontrolled pursuit |
| Patrol | O | Loop between two and sixteen waypoints, engaging threats in range |

Every order accepts a multi-unit selection and each unit is validated independently, so mixed armies only take an order where the movement domain and route allow it. Fighters keep their explicit strike/return/rearm missions and reject geographic orders. Orders and rally points are saved with the match.

## Base building and economy

Implemented structures:

- **Headquarters:** critical command and defeat objective.
- **Supply Center:** starting logistics structure; active truck collection arrives in v0.5 Slice B.
- **Barracks:** train infantry and deploy reinforcements.
- **Vehicle factory:** produce armored units.
- **Power plant:** supply power to your infrastructure.
- **Legacy extractor:** strategic structure retained for compatibility; it no longer generates passive income.
- **Bunker and defensive turret:** fortify contested front lines.
- **Airfield:** produce aircraft that fly strike missions.
- **Shipyard:** produce naval units and stage amphibious landings.

Buildings occupy a specific hex or designated building site. Factories support rally points so new units can reinforce assigned positions automatically; a rally may be a plain move or an attack-move. Exact building limits, costs, and production rates will be balanced iteratively.

## Game modes

**First priority: Single-player skirmish** against a basic AI opponent.

Later possibilities:

- Multiple AI opponents and selectable difficulty.
- Different world sizes and starting positions.
- Alternative victory conditions, including domination and headquarters elimination.
- Custom maps and map editor.
- Multiplayer, after the single-player simulation and performance are stable.

## Technology

- **Engine:** Godot 4.x
- **Language:** GDScript
- **Presentation:** 2D, top-down hexagonal battlefield
- **Map:** Hex cells with axial `(q, r)` coordinates and data-driven tile state
- **Simulation:** Fixed-tick gameplay logic separated from rendering
- **Initial target:** Desktop development and testing
- **Later target:** Desktop and mobile-friendly controls and builds

Godot scene nodes should handle presentation and input; core systems should own gameplay state independently of animations or sprites. This separation makes AI, tests, saving, and future multiplayer easier to build.

## Roadmap

The **current, detailed slice-by-slice roadmap** is maintained in **[docs/ROADMAP.md](docs/ROADMAP.md)**. It distinguishes implemented code from proposed work and captures the v0.5 economy redesign.

| Version | Milestone | Status |
| --- | --- | --- |
| v0.1 | First playable world war | Implemented baseline |
| v0.2 | Economy and construction | Implemented historically; passive-income rules superseded by v0.5 |
| v0.3 | Territorial strategy | Implemented historically; payout rules revised in v0.5 |
| v0.4 | Military expansion | Implemented baseline, 13 combat roles |
| v0.5 | Physical supplies, oil derricks, cities, research and fog | **In progress: Slice A complete; Slice B next** |
| v0.6 | Three asymmetric factions | Planned |
| v0.7 | Smarter opponents and neutral world | Planned |
| v0.8 | Skirmish customization | Planned |
| v0.9 | Interface and polish | Planned |
| v1.0 | First complete release | Planned |

**Current pickup: v0.5 Slice B — Physical Supply Collection.** Both factions already start with 2,000 credits, a Supply Center, an unarmed Supply Truck and a nearby 5,000-unit finite deposit, but **trucks cannot collect or deliver cargo yet**, so passive income remains zero. Slice B implements actual pickup, travel, unloading and one-time delivery payments; Slice C adds capturable oil derricks for steady income.

Older milestone documents under docs/ record historical implementations, including features later changed by the v0.5 economy redesign. See [v0.5 Slice A](docs/V0.5-SLICE-A.md) for the approved payout API and save migration.

## Proposed project layout

```text
HexFrontlines/
├── README.md
├── project.godot
├── scenes/
│   ├── game/
│   ├── world/
│   ├── units/
│   ├── buildings/
│   └── ui/
├── scripts/
│   ├── core/
│   ├── systems/
│   ├── ai/
│   └── ui/
├── data/
│   ├── units/
│   ├── buildings/
│   └── terrain/
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
├── tests/
└── docs/
```

*The layout above is the intended long-term structure. Slice A creates the actual `project.godot`, `scenes/`, camera, HUD, and basic `scripts/`, `tests/`, and `docs/`. Other directories will fill in as their slices are implemented.*

## Getting started

> **Current pre-alpha:** The world map, military and construction systems are implemented. v0.5's new economy is in transition: supply trucks and finite deposits exist, but active collection begins in Slice B. No recurring income is active until deliveries and derricks are implemented.

To run the current project:

1. Install **Godot 4.7.2 stable**.
2. Clone the repository and open `project.godot` in Godot.
3. Press **F5** to run the configured main scene, then pan with WASD/arrows or drag and zoom with the mouse wheel. Touch drag and pinch gestures are also supported.
4. Read [Slice A acceptance criteria](docs/SLICE-A.md), then run the headless test commands documented there.
5. Try [Slice C selection and movement](docs/SLICE-C.md). Touch: tap a squad, then tap land. Escape clears selection; dragging still pans.

## Development guidelines

- Keep each development slice narrow and testable.
- Use data files or resources for unit stats and building costs rather than scattering values across scenes.
- Keep hex-grid logic, ownership, pathfinding, and combat independent from visuals.
- Add smoke tests for core rules, including hex neighbors, movement, capturing, combat, and victory.
- Run import/parse checks and smoke tests before merging changes.
- Do not confuse roadmap checkboxes with implemented features.
- Respect original intellectual property: inspiration comes from strategy mechanics, while code, art, audio, names, and faction designs must be our own or properly licensed.

## Project status and licensing

**Status:** Pre-alpha — v0.5 Slice A implemented; physical supply delivery is the next feature.

**License:** Not selected. All rights are reserved unless and until the repository owner adds an explicit license. Please do not assume the project is open source solely because its source might be publicly viewable.

---

**Hex Frontlines** — *Conquer the world. Hold the line.*
