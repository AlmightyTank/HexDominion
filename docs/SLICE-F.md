# Slice F — Economy and production

Start with 400 credits and a free headquarters at the first player city. Select an empty owned land tile to open **Construction**, then choose a building to construct directly on that tile. **H/B/F** are equivalent shortcuts for headquarters (300), barracks (100), or factory (200). Unaffordable or invalid choices are disabled. There is no cursor-placement step. Select an existing building to open **Training**, showing compatible unit buttons, queue size and current production progress. Headquarters show income information rather than unit buttons. Neutral/enemy/invalid tiles hide the action panel.

Income is continuous: the controlled HQ gives 5 credits/second, controlled cities give 1/second and resource hexes give 2/second. The header displays credits and income. Only one HQ is allowed, including an HQ on lost territory; attempts to build another are rejected without charge.

Inspect a barracks and press **I** to queue a rifle squad (50 credits, 4 seconds). Inspect a factory and press **T** to queue a tank (150 credits, 8 seconds). Queues hold at most five units and charge immediately; insufficient credits, wrong building and full queues are rejected. Production progress appears under the building marker. Inspection shows queue size.

To set a rally point, inspect the building, press **Esc** to clear any overlapping unit selection, then right-click reachable land. A line shows the inspected building's rally route endpoint. New units spawn at the building and receive a land movement order to its rally point; the default is to remain at the building. Invalid rallies preserve the old target. Existing recruits keep their previous orders when the rally changes.

Buildings on lost territory become inactive: no HQ income or production, no orders. Paid queues and partial progress pause and resume on recapture. Buildings are not transferred to enemy control. Terrain-site income also follows current ownership.

Limitations: no build time, building health/destruction, refunds/cancel queue, upkeep, storage caps, enemy economy, persistence, or touch production buttons. Units may share spawn hexes, matching previous movement rules. Production runs after movement each physics tick, so newly spawned recruits begin movement/combat next tick.

## Verification

Headless tests cover costs, ownership and placement validation, income, compatible unit training, rally validation, production timing, pause/resume, configured tank output, queue limits, multiple completions, insufficient funds and nonpositive time.

Manual checks pending: building/queue visuals at zoom extremes, header readability on narrow screens, construction and training key flow, Escape/right-click rally assignment, recruits joining combat/capture, and paused buildings after territory loss.
