# Slice D — Territory

- Three player squads start on owned cities; a nearby red rival garrison demonstrates opposing ownership and defense.
- Stationary squads capture neutral or enemy land in three seconds. Friendly stacking does not accelerate capture. Moving squads cannot capture; arrival starts capture on the following physics tick.
- Opposing stationary squads freeze capture progress. Abandonment resets it; a different sole captor starts fresh. Ownership persists after departure.
- Select a squad and press **G** on owned land to toggle garrison duty. Garrisoned squads refuse movement until released. Square markers indicate garrisons.
- Faction tint and exposed-edge borders show ownership; an arc shows capture progress. Friendly adjacent tiles have no internal borders. Inspection reports ownership.
- Terrain remains cached; territory uses live overlays. State is session-only.

Garrisons are stationed squads, not free troops or a separate troop pool. Slice E adds combat and defender removal, making the rival conquerable; production and pursuit AI remain future work. Garrison assignment currently requires keyboard G (no touch button).

## Verification

Headless tests cover delayed capture, persistence, contesting, replacement captors, enemy recapture, movement exclusion, abandonment and garrison movement locking, alongside existing map/movement regressions.

Interactive checks pending:

- Capture neutral land; watch the arc complete and ownership persist after leaving.
- Capture adjacent land; check all six border sides and absence of internal edges.
- Assign/release garrisons; check square markers and rejected/accepted movement.
- Occupy the rival garrison's hex; verify no capture completes.
- Check camera dragging, zoom extremes and touch movement.
