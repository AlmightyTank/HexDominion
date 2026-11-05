# Hex Frontlines — Current Development Roadmap

**Tagline:** Conquer the world. Hold the line.  
**Updated:** November 4, 2026  
**Repository:** https://github.com/AlmightyTank/HexFrontlines  
**Engine:** Godot 4.7.2 / GDScript  
**Current development stage:** Pre-alpha; **v0.5 Slice A implemented; v0.5 Slice B is next**.

> The repository was previously named HexDominion. HexFrontlines is its current name. This roadmap supersedes the high-level v0.5 description in older plans. Historical slice documents remain records of what was implemented at that time.

## Status conventions

- **[x] Implemented:** feature code and tests are present on main; it does not mean final artwork, physical-device acceptance, or play balance is finished.
- **[ ] Planned:** not marked implemented until the code, integrations, regression tests, and documentation are committed.
- **Proposed balance numbers** are design targets, not proof of current implementation.
- The previous milestones were built for a two-faction skirmish. Three distinct playable factions are a v0.6 target.

## Current baseline

- One continuous real-time Earth-inspired 120 × 70 hex world (8,400 tiles), with named city/resource sites and no turn-based battles.
- Territory capture, terrain modifiers, roads, continent control, power, construction, repairs, sales, production queues, rally points, and versioned saves.
- Combined-arms roster: 3 infantry, 5 ground vehicles, 2 aircraft and 3 naval units. A separate unarmed logistics Supply Truck now exists as v0.5 scaffolding, **not** as a fourteenth combat class.
- Army orders: Move, Attack, Attack-Move, Hold Position, Guard, Patrol; transport loading and unloading; three visual zoom tiers.
- Existing minimap is camera navigation and territory display; it does not yet implement true faction-specific radar detection and fog of war.
- v0.5 Slice A starts both factions with 2,000 credits, an HQ, one Supply Center, one unarmed Supply Truck and one nearby **5,000-unit finite deposit** each.
- **Important current limitation:** trucks do not yet collect or deliver supplies. City, HQ and legacy extractor passive income has been removed; recurring income is currently zero until Slices B and C are built.
- Last reviewed code baseline: main at commit 8002a59 (2026-11-04 UTC / 2026-11-04 US Central). Two Godot Actions workflows passed for that commit. Future changes should be re-audited before marking a slice complete.

## Milestone overview

| Version | Milestone | Current status | Primary outcome |
| --- | --- | --- | --- |
| v0.1 | First playable world war | **Implemented baseline** | Earth hex map, capturing, combat, base production, AI, save/load |
| v0.2 | Economy and construction | **Implemented historically** | Credits, buildings, power, queues, repairs and construction controls |
| v0.3 | Territorial strategy | **Implemented historically** | Terrain, roads, supply links, continent control, bunkers |
| v0.4 | Military expansion | **Implemented baseline** | 13 combat roles, air/sea operations, mixed orders and AI |
| v0.5 | Logistics economy, cities and technology | **In progress: A done, B–F planned** | Physical deliveries, oil derricks, city/research, radar and fog |
| v0.6 | Three asymmetric factions | Planned | Distinct strategies and recognizable faction identity |
| v0.7 | Smarter opponents and neutral world | Planned | Strategic AI, utility competition, diplomacy |
| v0.8 | Skirmish customization | Planned | Match setup, victory options, difficulty and scenarios |
| v0.9 | Interface and polish | Planned | Desktop/mobile UX, audio, readability, performance and balance |
| v1.0 | First complete release | Planned | Validated, stable, packaged single-player release |

---

## v0.1 — First playable world war (implemented)

- [x] **A — Foundation:** Godot project, main scene, camera, pan/zoom and input.
- [x] **B — World map:** deterministic hex world, land/ocean masking, terrain and point-of-interest inspection. The old README checkbox for B was stale; actual world map and slice documentation exist.
- [x] **C — Unit selection and movement:** single/group selection, orders and hex pathfinding.
- [x] **D — Territory capture:** ownership, capture progress, contests, garrisons and borders.
- [x] **E — Combat:** infantry/tanks, health, attack ranges and damage.
- [x] **F — Base production:** headquarters, barracks, vehicle factory, recruitment and rally points.
- [x] **G — Skirmish loop:** baseline enemy AI, win/loss, restart and save/load.

**Remaining acceptance work:** Real-device interaction, broad balance testing and final art polish are not guaranteed by these checkboxes. Earlier v0.1 income behavior was superseded by v0.5A.

## v0.2 — Economy and construction (implemented historically)

- [x] **A — Credits ledger:** player/AI accounts, atomic spending and transaction records.
- [x] **B — City income:** originally implemented; **superseded by v0.5A**.
- [x] **C — Resource extraction:** originally implemented; **its passive income is disabled by v0.5A**.
- [x] **D — Placement:** owned-hex validation and placement preview.
- [x] **E — Construction progress:** build timing and vulnerable foundations.
- [x] **F — Cancellation/refunds:** cancellation and one-time partial refunds.
- [x] **G — Power:** supply, demand and brownout behavior.
- [x] **H — Repairs/selling:** paid repairs and building sales.
- [x] **I — Production interface:** structure roster, per-facility queues, selection and rally controls.
- [x] **J — Economic AI/integration:** construction/repair budgets, training and regression testing.

**Preserve:** existing CreditsAccount, EconomyState, power, construction and production code; do not rebuild a second economy.

## v0.3 — Territorial strategy (implemented historically)

- [x] **A — Terrain:** forest/mountain defensive effects, desert vehicle speed and weighted pathfinding.
- [x] **B — Roads:** visible roads, 100-credit construction and 30% faster eligible ground travel.
- [x] **C — Supply connections:** friendly land/road networks and supply status. Former city/extractor income payouts were retired in v0.5A; connectivity remains useful infrastructure.
- [x] **D — Continent control:** control progress and +10% per full continent. v0.5A now applies bonuses **only to approved delivery/derrick income**, not to arbitrary passive territory income.
- [x] **E — Defense:** bunkers, garrisons, Hold Position and basic defense AI.

**Preserve:** road movement, ownership, connectivity and defense behavior while changing economic payout sources.

## v0.4 — Military expansion (implemented baseline)

- [x] **A — Infantry:** Rifleman, Rocket Soldier and Machine Gunner.
- [x] **B — Vehicles:** tank, scout, APC, mobile anti-air and infantry transport.
- [x] **C — Artillery:** three-hex bombardment and fortification damage.
- [x] **D — Aircraft:** helicopters, fighters, airfields and strike/rearm missions.
- [x] **E — Naval:** patrol boat, destroyer, landing transport, shipyards and amphibious landings.
- [x] **F — Combined arms:** Attack-Move, Guard, Patrol, attack-move rally, mixed AI and far/medium/close display.

**Visual standard:** Existing military art uses original SVG/sprite assets. Infantry should follow the approved hexagonal badge design; vehicles/aircraft/ships retain distinct top-down silhouettes. Track any remaining visual differences or placeholders as polish work rather than claiming art is final.

**Known QA gaps:** Physical touch acceptance, human review of all zoom tiers and broad combat-balance/performance playtests remain necessary.

---

## v0.5 — Physical economy, neutral utilities, cities, research and reconnaissance

**Design rule:** No automatic credits for merely owning land, cities, HQs, legacy extractors or ordinary buildings. Credits come from **successfully unloaded supply deliveries** or **operational captured oil derricks**. Building-sale returns/refunds are one-time accounting transactions, not recurring income.

### Slice A — Economy foundation and starting funds — IMPLEMENTED

- [x] Exactly 2,000 starting credits per faction.
- [x] One completed HQ, Supply Center, unarmed Supply Truck and nearby 5,000-unit finite deposit per faction.
- [x] Remove previous city, HQ and extractor passive-credit production.
- [x] Keep CreditsAccount, spending, refunds, power, roads, territory and military systems.
- [x] Add controlled payout entry point for supply_delivery and oil_derrick only.
- [x] Preserve additive continent bonuses; allow a road bonus only on qualifying **completed supply deliveries**.
- [x] Save schema v2 with validated migration from v1 and no duplicated starting assets.
- [x] HUD recent approved income reporting.

**Not yet playable:** Truck loading, cargo, unloading, completed deliveries and oil payments are still missing. See [v0.5 Slice A detail](V0.5-SLICE-A.md).

### Slice B — Physical supply collection — NEXT

- [ ] Support finite small/medium/large supply stockpiles, with visible remaining amounts and depletion. Preserve Slice A's valid 5,000-unit starting deposits; add broader map deposits through stable IDs.
- [ ] Give the existing Supply Truck actual assignments, loading, cargo capacity, travel, unloading and delivery states. Initial balance target: **150 credits/cargo**, **3-second load**, **2-second unload**.
- [ ] Pay credits **only after** unloading at an eligible friendly operational Supply Center through the approved EconomyState payout API; do not credit on pickup.
- [ ] Reserve or atomically withdraw stock so competing trucks cannot extract more than the deposit contains. Undelivered cargo is lost with a destroyed truck.
- [ ] Make additional Supply Trucks buildable (proposed **200 credits / 6 seconds**) and Supply Centers constructible with the existing build/power/repair/sell rules (proposed **300 credits / 8 seconds / 10 power**).
- [ ] Use actual terrain/pathfinding/road travel. Road payout bonus must be proven by a qualifying route; it cannot be claimed by merely being near a road.
- [ ] Add distinct top-down logistics sprites and appropriate strategic icons, not reused tank or scout art.
- [ ] Persist deposits, cargo, routes and every delivery phase; handle center loss and retry without free credits.
- [ ] Test contested deposits, simultaneous collection, partial loads, empty deposits, truck destruction, brownouts, alternate centers, save/load and non-duplication.

**Acceptance:** A match can earn spendable credits from the starting finite supplies through a completed visible truck round trip. No direct pickup payout.

### Slice C — Neutral oil derricks — PLANNED

- [ ] Place roughly **18–24** capturable oil derricks across valid, reachable world hexes; avoid existing city/resource site collisions and unfair early-game placement.
- [ ] Eligible infantry can contest/capture derricks (initial target **5 seconds**). No remote instant capture; ownership transfers once.
- [ ] Operational uncontested owned derricks pay **3 CR/second**, using approved oil_derrick income only.
- [ ] Apply continent bonus additively; **no road payout bonus for derricks**, and no truck needed.
- [ ] Support health, destruction, repair/restore and disabled income while contested/destroyed.
- [ ] Provide neutral/owned/damaged/destroyed art, strategic markers and HUD events.
- [ ] Teach basic rival AI to capture accessible derricks using real infantry.
- [ ] Save ownership/condition and prevent double payment.

**Acceptance:** Taking a derrick provides the only passive recurring money; losing it or contesting it stops payment.

### Slice D — Logistics automation, economic AI and raids — PLANNED

- [ ] Idle trucks find discovered reachable stockpiles and operational drop-off centers using bounded route-cost searches.
- [ ] Trucks collect/reassign automatically; players can override deposits, centers or automation.
- [ ] Avoid pileups and repeated selection of depleted or unreachable sites; handle multiple trucks and centers.
- [ ] Supply trucks are attackable and can be intercepted; actual route disruption should materially impact income.
- [ ] Upgrade RivalEconomyAI and CombinedArmsAI to protect routes, replace trucks, expand collection, capture derricks and raid enemy logistics under the same cost rules as the player.
- [ ] Show recent deliveries, oil payments, active/idle/blocked trucks, known remaining supplies and loss-of-income warnings in the existing HUD.
- [ ] Report true economic deadlocks rather than secretly creating bailout credits.
- [ ] Test rival solvency, long-running depletion, deadlocks, destroyed routes, save recovery and match progression.

**Acceptance:** Player and AI can finance armies with the new economy over complete matches, including after initial deposits deplete.

### Slice E — Cities, improvements, research and technology — PLANNED

- [ ] Reuse the **14 existing named city hexes**. Captured cities have **zero passive income**.
- [ ] Add a city management panel, persistent owner/development state and clear improvement slots.
- [ ] Define three city levels (upgrade costs proposed **150 / 300 credits**) granting local construction/production benefits, **not money**.
- [ ] Add city improvements: Research Office (**200 credits**) and Logistics Office (**150 credits**, proposed faster truck loading for a valid associated center).
- [ ] Implement one active research project per faction, prerequisite enforcement, credit costs, durations, interruption/restart rules and researched effects.
- [ ] Initial tech branches: **Economy/Logistics** (faster loading, +25 truck cargo); **Industry** (-10% unit training time, +10 power per plant); **Military** (+10% weapon damage, 10% ground-vehicle damage reduction); **Reconnaissance** (radar research and improved scout sight).
- [ ] Apply faction upgrades to existing and new units/buildings through centralized modifiers, not by mutating shared static catalogs.
- [ ] Extend player/AI HUD and AI research priorities, while ensuring research never starves essential collection.
- [ ] Persist city levels, improvements, tech unlocks and in-progress research; test legacy saves.

**Acceptance:** Cities unlock infrastructure/research advantages without printing money. All bonuses affect real gameplay and are visible in the UI.

**Scope note:** E is the largest slice. Implement in tested internal increments (city state → offices → research → effects) within the same milestone, or formally split it before coding if risk is excessive.

### Slice F — Radar, scouting, fog of war and v0.5 acceptance — PLANNED

- [ ] Extend the **existing minimap**, not a duplicate radar UI.
- [ ] Add per-faction **visible / explored / unexplored** hex states without changing the underlying simulation.
- [ ] Implement sight ranges for infantry, scouts, aircraft, ships, headquarters and radar; avoid omniscient targeting.
- [ ] Add a power-consuming Radar Station unlocked via reconnaissance technology (proposed **200 credits / 8 seconds / 10 power**, radius **6 hexes**).
- [ ] Keep the terrain texture cached; render fog with an independent efficient overlay.
- [ ] Restrict player and enemy UI, combat targeting, scouting and automated truck destination knowledge to valid faction information.
- [ ] Persist exploration and recompute current visibility after loading; never reveal live hidden enemy movement or economy.
- [ ] Playtest the new economy, including 2,000-credit starts, 5,000-unit initial deposits, truck cadence, derrick income, unit costs and AI recovery.
- [ ] Run desktop and small-screen rendered checks, Godot headless tests, CI and full-match scenarios.

**Acceptance:** A skirmish can progress from finite starting supplies to raids, contested oil income, city upgrades, research, radar and fog-covered battles without resource duplication or information leaks.

### v0.5 Economy contract

| Income/event | Generates credits? | Conditions |
| --- | --- | --- |
| Starting funds | One-time | 2,000 credits at new-match creation |
| HQ/city/ordinary owned territory | **No** | Ownership alone never pays |
| Legacy resource extractor | **No** | Retained for compatibility; not an income source |
| Supply pickup/loading | **No** | Cargo remains in truck, subject to loss |
| Completed supply delivery | **Yes** | Valid friendly center, actual cargo, one-time approved payout |
| Operational owned oil derrick | **Yes** | Positive recurring rate; stops on contest/destruction |
| Road travel | **No** | Travel-speed benefit only |
| Qualified all-road delivery | **Bonus only** | +10% to that delivery, checked at payout |
| Fully controlled continent | **Bonus only** | +10% per continent to approved payouts |
| Repairs, selling, refunds | One-time balance changes | Existing atomic ledger rules |

**Design safeguard:** Do not invent alternate passive income to resolve AI or player starvation. Fix routes, starting opportunities, prices and player feedback instead.

---

## v0.6 — Three asymmetric factions (planned; slice boundaries provisional)

- [ ] **A — Faction definition:** finalize three factions, visual identities and strategic strengths. Preserve existing A/B/C art slots where usable.
- [ ] **B — Faction infrastructure:** distinct variants of key buildings and production prerequisites, integrated with construction/power.
- [ ] **C — Unit differentiation:** faction-specific behavior, selected unit alternatives or abilities without copying commercial RTS assets.
- [ ] **D — Technology differentiation:** faction research variations built on the v0.5 system, with meaningful strengths and weaknesses.
- [ ] **E — AI, balance and integration:** all factions use same core income/capture rules, save/load correctly, and can complete a skirmish.

**Gate:** Three genuinely different playable faction strategies, not merely recolored armies.

## v0.7 — Smarter opponents and neutral world (planned; slice boundaries provisional)

- [ ] **A — Strategic AI:** multi-front objectives, chokepoints, cities, derricks, logistics targeting and reinforcement planning.
- [ ] **B — Tactical AI:** combined-arms coordination, sensible retreats, transport staging, counter-unit decisions and defensive posture.
- [ ] **C — Neutral objectives:** expand utility sites such as repair depots, neutral power stations or communication facilities, with distinct effects and capture rules.
- [ ] **D — Diplomacy and alliances:** simple relationships between factions, clearly presented to the player; no complex diplomacy simulation.
- [ ] **E — Difficulty and validation:** parameter-driven AI difficulty, fair visibility and long-form match tests.

**Gate:** AI poses a credible challenge without cheating on credits, fog, capture or supply travel.

## v0.8 — Skirmish customization (planned; slice boundaries provisional)

- [ ] **A — New match setup:** choose faction(s), opponents and starting parameters.
- [ ] **B — Map options:** support defined alternative map sizes or scenarios while maintaining stable hex logic.
- [ ] **C — Victory conditions:** explicit headquarters-elimination and domination options with clear win/loss signals.
- [ ] **D — Match rules:** selectable game speed, starting credits and resource abundance with AI parity.
- [ ] **E — Scenario persistence and tests:** configuration saved with matches and regression checks for each supported setup.

**Gate:** Players can start, save, load and complete multiple valid skirmish configurations.

## v0.9 — Interface, performance and polish (planned; slice boundaries provisional)

- [ ] **A — Desktop command UX:** contextual orders, explicit disabled reasons, construction/technology/supply information and readable minimap.
- [ ] **B — Mobile/touch UX:** responsive production/selection surfaces, safe map gestures, physical touch testing and reliable hit targets.
- [ ] **C — Audio/feedback:** original unit, construction, combat, alert and victory feedback with adjustable volumes.
- [ ] **D — Map/unit polish:** consistent original sprites, hexagonal infantry badges, faction accents, effects and damaged/destroyed presentation.
- [ ] **E — Performance and accessibility:** large-army draw costs, pathfinding, economy/fog updates, contrast, controls and scalable UI.
- [ ] **F — Balance and regression:** production/research/combat/economy tuning through full-match playtests.

**Gate:** The map remains readable and the game controls work reliably on supported platforms and screen sizes.

## v1.0 — First complete release (planned; slice boundaries provisional)

- [ ] **A — Full-game stabilization:** resolve crashes, save corruption, AI stalls, desync-like simulation bugs and critical exploits.
- [ ] **B — End-to-end playtests:** repeated matches from setup to victory across each faction, difficulty and supported map.
- [ ] **C — Accessibility and UX acceptance:** tutorials/help, warnings, settings, input validation and physical-device testing.
- [ ] **D — Release packaging:** produce and verify installable desktop builds; mobile support only when target requirements and testing are met.
- [ ] **E — Documentation/licensing:** player guide, controls, changelog, asset provenance and licensing decisions.
- [ ] **F — Release signoff:** CI green, tested builds, blocker list cleared and versioned v1.0 tag.

**Gate:** A stable, complete single-player RTS; not a claim of multiplayer or store acceptance.

---

## Engineering rules for every upcoming slice

1. Inspect the latest main branch **before** coding; this document may lag active development. Reuse current architecture rather than creating parallel unit, currency, radar or map systems.
2. Build each slice in a testable increment with a clear acceptance scenario and new regression coverage.
3. Keep gameplay simulation authoritative and separate from rendered army groups, artwork, HUD controls and fog overlays.
4. Maintain save migration, deterministic placement and validated loading; never duplicate cargo, credits, units or structures during load.
5. Keep AI and player rules symmetrical for credits, movement, vision, capturing and transport. AI decision quality may differ, but not underlying rules.
6. Avoid fake UI data and unfinished controls that appear to work. Disabled/unimplemented actions must be clearly described.
7. Prefer existing 120 × 70 Earth map, named city/resource sites, Godot assets, CreditsAccount, EconomyState, SupplyNetwork, UnitCatalog and StrategyHUD.
8. Verify headless import, smoke/regression tests, main scene boot and GitHub CI. Report actual run results; human visual/mobile acceptance is separate.
9. Keep original artwork and source/code cleanly licensed. The project takes mechanical inspiration from RTS titles, not copied assets.
10. After each slice, update this roadmap, the README status, and a slice detail document with commit/test evidence and known limitations.

## Immediate next pickup

**Implement v0.5 Slice B — Physical Supply Collection.** Specifically: make the existing Supply Truck travel to its already-created finite starting deposit, load up to its configured cargo capacity, return to its existing Supply Center, unload, and pay through EconomyState.credit_approved_income exactly once. Add tests for simultaneous pickup, lost cargo, brownouts, save/load at every phase and depleted deposits **before** broadening distribution and adding new art.

Start from [v0.5 Slice A](V0.5-SLICE-A.md) and current Godot validation workflows. Once deliveries are end-to-end and economically sustainable, move to **v0.5 Slice C — Oil Derricks**.
