# Hex Dominion

**Conquer the world. Hold the line.**

> **Status:** Pre-alpha. v0.4 Slice D adds powered airfields, attack helicopters and fighter strike-and-return missions. Aircraft fly over land and water in a separate visual layer, with anti-air counters, animated rotors, shadows and missile feedback. Ground armies retain stack-first presentation; aircraft use type markers far away and individual sprites at medium/close zoom. Physical touchscreen acceptance and balance playtesting remain pending.

**Hex Dominion** is a real-time, hex-based world-conquest strategy game built with **Godot 4** and **GDScript**. It combines the territorial warfare of *Risk*, terrain and strategic depth inspired by *Civilization V*, and unit production, base building, and tactical combat inspired by *Command & Conquer: Generals Zero Hour*.

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
4. Use captured cities and resource locations to fund expansion.
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
| Cities | Economic centers and objectives |
| Resource areas | Additional income or supplies |
| Ocean | Naval travel and amphibious operations (later milestone) |

Terrain bonuses and penalties will be tuned through playtesting.

## Armies and combat

The initial roster is intentionally small. More specialized units unlock after the basic combat and economy systems are fun.

| Category | Early units | Main role |
| --- | --- | --- |
| Infantry | Rifle squad | Territory capture and defense |
| Infantry | Rocket squad | Anti-vehicle support (later in v0.x) |
| Armor | Main battle tank | Main offensive power |
| Support | Engineer | Repair and construction support (later) |
| Support | Artillery | Fire support across hexes (later) |
| Air | Helicopter / fighter | Recon and strikes (later) |
| Naval | Transport / warship | Ocean movement and naval combat (later) |

Combat happens directly on the map in real time. Each faction's deployed army in a hex has one marker showing its most numerous role and total count at every zoom. Click it for the composition panel; use Expand to reveal individual units.

## Base building and economy

Planned structures include:

- **Headquarters:** critical command and defeat objective.
- **Barracks:** train infantry and deploy reinforcements.
- **Vehicle factory:** produce armored units.
- **Power plant:** supply power to your infrastructure.
- **Resource collector / economy building:** generate or process income.
- **Bunker and defensive turret:** fortify contested front lines.
- **Radar / airfield:** later strategic and air-force expansion.

Buildings occupy a specific hex or designated building site. Factories support rally points so new units can reinforce assigned positions automatically. Exact building limits, costs, and production rates will be balanced iteratively.

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

The version milestones and slices below are **planned**, not completed.

### v0.1 — First playable world war

- [x] **Slice A:** Godot project setup, main scene, camera pan and zoom, input foundation. (Implemented locally; engine runtime verification remains pending.)
- [ ] **Slice B:** Earth-inspired hex world, land/ocean masking, basic terrain rendering.
- [x] **Slice C:** Unit selection, movement commands, hex pathfinding. (Headless verified; interactive acceptance checklist in [Slice C](docs/SLICE-C.md).)
- [x] **Slice D:** Territory ownership, capture progress, garrisons, faction borders. (Headless verified; [rules and manual checklist](docs/SLICE-D.md).)
- [x] **Slice E:** Rifle squads, tanks, health, damage, and real-time combat. (Headless verified; [rules and manual checklist](docs/SLICE-E.md).)
- [x] **Slice F:** Headquarters, barracks, factory, basic resource income, training and rally points. (Headless verified; [rules and controls](docs/SLICE-F.md).)
- [x] **Slice G:** Basic AI opponent, HQ win/loss conditions, match restart, and versioned save/load. (Headless verified; [rules, controls and limitations](docs/SLICE-G.md).)

**v0.1 acceptance test:** Start a match on a small hexagonal world map, capture territory with infantry, station defenders, produce reinforcements, fight an AI opponent, and win by taking its headquarters. The goal is a complete small skirmish, not final artwork or perfect balance.

**Prototype sizing target:** Approximately 30 × 16 hex positions, with two factions and a limited playable land area. This is a tuning target, not a final map size.

### v0.2 — Economy and construction

Money, power, resources, building placement and cancellation, repairs, selling, construction rules.

- [x] **Slice A — Economy Foundation:** Shared player/AI credits accounts, configurable starting funds, income, atomic spending checks and saved transaction history. Construction and training cannot overdraw funds. ([API and verification](docs/V0.2-SLICE-A.md).)
- [x] **Slice B — Territory Income:** Owned, uncontested cities provide passive credits; ordinary/resource hexes do not. Capture, loss and contest immediately update faction rates. ([Rules and verification](docs/V0.2-SLICE-B.md).)
- [x] **Slice C — Resource Extraction:** Build destructible extractors on captured resource deposits for automated income. Lost, contested or destroyed extractors stop earning. ([Rules and verification](docs/V0.2-SLICE-C.md).)
- [x] **Slice D: Building Placement:** Construction sidebar, hex-snapped valid/invalid ghosts, six-way rotation and controlled empty-hex placement. ([Rules and verification](docs/V0.2-SLICE-D.md).)
- [x] **Slice E: Construction Progress:** Timed, vulnerable foundations with visible progress, operational gating and saved construction state. ([Rules and verification](docs/V0.2-SLICE-E.md).)
- [x] **Slice F: Cancellation & Refunds:** Cancel controlled unfinished sites for a 50% refund, once only, releasing the construction hex. ([Rules and verification](docs/V0.2-SLICE-F.md).)
- [x] **Slice G: Power System:** Power plants, faction supply/demand meters, half-speed factories and offline extractors under low power, with immediate recovery when supply returns. ([Rules and verification](docs/V0.2-SLICE-G.md).)
- [x] **Slice H: Repairing & Selling Buildings:** Paid repairs over time, stop-repair controls, completed-building sales with 50% salvage, and destruction cleanup. ([Rules and verification](docs/V0.2-SLICE-H.md).)
- [x] **Slice I: Production & Construction Interface:** Scrollable structure/job roster, costs and requirements catalog, pinned facility controls, individual production queues and rally points. ([Rules and verification](docs/V0.2-SLICE-I.md).)
- [x] **Slice J: AI, Balancing & Integration:** Enemy base construction, resource expansion, power recovery, repair budgets, mixed recruitment and economic recovery with exploit, save/load and full-match regression tests. ([Rules and verification](docs/V0.2-SLICE-J.md).)

### v0.3 — Territorial strategy

Improved terrain rules, supply connections, continent bonuses, fortifications, defended choke points.

- [x] **Slice A: Terrain Advantages:** Forest infantry protection 15%, mountain ground speed -20% and protection 25%, desert vehicle speed +10%, city protection 20%. Weighted routing, hex inspection and existing crossing rules remain integrated. ([Rules and verification](docs/V0.3-SLICE-A.md).)
- [x] **Slice B: Roads and Transportation:** Persistent 100 CR roads on controlled land, continuous connections, 30% faster ground travel and road-aware routing. ([Rules and verification](docs/V0.3-SLICE-B.md).)
- [x] **Slice C: Supply Connections and Income:** Cities and extractors require friendly land supply from an operational HQ; connected friendly roads grant a single 10% income bonus. Cached networks, isolation indicators and save reconstruction. ([Rules and verification](docs/V0.3-SLICE-C.md).)
- [x] **Slice D: Continent Bonuses:** Complete eligible continents grant +10% income each, additive with roads, with event-driven control counts and a faction overview. ([Rules and verification](docs/V0.3-SLICE-D.md).)
- [x] **Slice E: Fortifications, Chokepoints and Defense AI:** Paid, repairable bunkers shelter two infantry; Hold Position (J) and Garrison (G) have sidebar controls; bounded AI defenses protect strategic sites without committing the whole army. ([Rules and verification](docs/V0.3-SLICE-E.md).)

### v0.4 — Military expansion

Expanded infantry and armor, artillery, air units, naval units, transports, expanded combat orders.

- [x] **Slice A: Infantry Expansion and Unit Visual Foundation:** Three barracks infantry roles, weapon cooldowns and counters, attack commands, shared faction-accented soldier silhouettes, grouped zoom presentation and backward-compatible saves. ([Tuning, controls, verification and limitations](docs/V0.4-SLICE-A.md).)
- [x] **Slice B: Vehicle Expansion:** Main battle tanks, scouts, four-seat APCs, mobile anti-air, stack-first army presentation and backward-compatible transport saves. ([Rules, controls and verification](docs/V0.4-SLICE-B.md).)
- [x] **Slice C: Artillery & Long-Range Warfare:** Factory-built self-propelled artillery, range-three bombardment, fortification damage, non-capture, range overlays and shell feedback. ([Rules, scope and verification](docs/V0.4-SLICE-C.md).)
- [x] **Slice D: Aircraft & Airfields:** Powered aircraft production, helicopters, fighter strike/return/rearm missions, AA counters, independent air presentation and validated saves. ([Rules and verification](docs/V0.4-SLICE-D.md).)

#### Infantry controls

- Train all three roles in the **Inf** tab with a completed barracks selected.
- Click/tap a marker to select its hex army. Use the existing panel's type rows, **Select all**, and **Expand/Collapse**. Shift-click or **Add selection** toggles whole stacks; drag a box for multiple armies. Expanded units can be picked individually.
- **Load APC (L)** then click a friendly stack with a stationary APC to board selected stationary, same-hex infantry. **Unload APC (U)** then click nearby land to deploy the selected APCs' passengers. Capacity is four; passengers are lost if their APC is destroyed.
- Right-click an enemy to attack, or use **Attack (X)** and tap/click the target. Right-click land moves. Touch: select then tap land to move.
- **Hold (J)** stops pursuit; **Garrison (G)** occupies a friendly bunker (two infantry slots). Accepted movement/attack releases Hold and garrison.
- Zoom changes presentation only: role/count markers, grouped sprites, then individual soldiers. All simulated units always remain present.

#### Validation

`.github/workflows/godot-validation.yml` imports the pinned Godot 4.7.2 project, runs smoke/HUD/startup checks, and renders zoom/feedback fixtures with Xvfb. Rendered screenshots are uploaded as CI artifacts. Local commands and evidence are documented in the slice notes.

### v0.5 — Cities and technology

Cities, research, upgrades, radar, scouting, and fog of war.

### v0.6 — Factions

Three asymmetric factions with distinct buildings, units, and battlefield abilities.

### v0.7 — Smarter opponents

Strategic AI, neutral locations, alliances, and diplomacy rules.

### v0.8 — Skirmish customization

Scenario setup, map sizes, game speed, difficulty, and victory mode options.

### v0.9 — Interface and polish

Desktop and mobile-oriented controls, performance optimization, sound, feedback, balance, and usability.

### v1.0 — First complete release

Full single-player testing, stability fixes, documentation, and release builds.

## Proposed project layout

```text
HexDominion/
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

> **v0.1 Slice C** runs on the Earth hex map. Click a teal squad, then right-click reachable land to move it; this is not yet a complete strategy game.

Once the project exists:

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

**Status:** Planning / pre-alpha.

**License:** Not selected. All rights are reserved unless and until the repository owner adds an explicit license. Please do not assume the project is open source solely because its source might be publicly viewable.

---

**Hex Dominion** — *Conquer the world. Hold the line.*
