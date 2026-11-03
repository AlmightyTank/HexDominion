# Slice G — Basic skirmish loop

## Rules

- Player retains three starting units (including a tank). Rival starts with one rifle squad, an HQ and a barracks, eight hexes from the player HQ on reachable land. Both HQs are marked with command-center badges; the match panel lists their coordinates.
- Rival waits eight seconds, then decides once per second: engage nearby player units, hold to fire when in range, otherwise capture one hex at a time toward the player HQ. It waits for captures to complete before continuing expansion.
- Rival earns normal faction-specific income and pays the same rifle training cost/time as the player. Recruitment is limited to eight living plus queued units; captured rival production pauses. No free reinforcement spawning.
- Capturing the rival HQ gives **victory**; the rival capturing yours gives **defeat**. Simultaneous HQ capture is a **draw**. Unit elimination alone does not end a match: production can recover an army.
- Result is latched. Movement, damage, capturing, AI, income and production stop at match end; construction/training commands are blocked. Camera and save/load/restart remain available.
- Restart reloads the main scene, resetting all simulation and input state without overwriting the save.

## Controls

Press **Escape** to open a centered modal with **Resume**, **Save**, **Load**, and **Restart**. The match and camera pause while the menu is open. Save opens a browser: enter a name and create a new save, or select an existing save and confirm overwriting it. Load opens a timestamped list of saved matches; select one and load it. Invalid/incompatible saves are marked and cannot be loaded. Empty lists show a message. Escape/Back returns from the browser to the pause menu; Escape/Resume closes the pause menu. Successful loading resumes the match. Shortcuts **F5/F9** open the Save/Load browsers; **F10** restarts. Restart/load replace the current match without a confirmation dialog. Saving/loading are explicit, not automatic on launch or exit. Click empty ground to deselect units.

## Save baseline

Multiple local named saves live in `user://saves/` (Godot's per-project user-data directory). Each has a unique filename, user-visible name, UTC timestamp and match status. Names are metadata, never filesystem paths; duplicate names may exist as independent saves. Overwriting can rename the selected save and retains its previous snapshot as `.bak`. Legacy `user://quicksave.hds` is also listed if present. Version 1 uses binary Variant data with object serialization/decoding disabled; optional name/timestamp metadata preserves compatibility with existing snapshots. It is not compatible with arbitrary maps or future schema versions; the current Earth map has an explicit compatibility identifier.

Includes units/kinds/factions/health, remaining routes and interpolation progress, garrisons, owners and capture timers, both factions' credits/buildings/queues/rallies/production progress, HQ objectives, result, AI timer, camera position/zoom and inspected tile. Unit stats are reconstructed from kind definitions. Selection, drag gestures and combat-display references are intentionally cleared on load.

Writes go to a temporary file, flush, preserve the previous save as `.bak`, then rename into place. I/O failures are reported. Load validates the complete snapshot before changing the running match and falls back to a valid backup if the primary is invalid. Unsupported versions, wrong map identifiers, malformed coordinates/routes, invalid values and incompatible queues are rejected. No migrations are needed yet; future schema changes must add migrations or explicitly reject old saves.

## Limits and verification

AI is deliberately basic: rifles only, fixed starting production, no strategic construction, repairs, difficulty settings, fog of war or ocean travel. Rival structures remain rival production sites when captured (inactive), not transferable player buildings. Existing far-flung player starts are retained; this is not a balanced scenario yet.

Headless smoke tests cover AI grace/movement/capture/engagement/recruitment costs and cap, HQ defeat/draw/latching, live victory and simulation freeze, scene restart, complete snapshot round-trip and identical continued simulation, invalid-data rejection and backup fallback. Test files use a separate slot and are cleaned up.

Interactive acceptance remains pending:

- Observe AI expansion, combat and recruiting over several minutes.
- Win by capturing rival HQ; lose by allowing your HQ to fall; confirm result text and frozen battlefield.
- Restart during play and after a result; confirm fresh roster and credits.
- Save while units move and production/capture progress; quit, relaunch, load, verify camera and resumed state.
- Create two differently named saves, overwrite one with confirmation, and load each independently. Confirm names/timestamps persist after relaunch.
- Check match controls and tile-context panels at desktop and narrow viewport sizes.
