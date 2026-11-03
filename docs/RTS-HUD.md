# RTS command sidebar

Direction: the user's classic Command & Conquer reference. ENERGY 2 / RHYTHM 1 / MOTION 1.

- A full-height right sidebar keeps radar and category tabs in predictable positions.
- Build, infantry, vehicles and sites separate placement, production and facility management.
- Two-column build tiles show price and duration; requirements move to tooltips to avoid a wall of text.
- HQ construction is omitted from the sidebar under the current HQ-capture victory rule. A future whole-army victory option must explicitly enable it.
- Square olive-metal panels follow the military reference; dark surfaces separate controls from the terrain.
- The existing engine font keeps small command labels readable without adding a font dependency.
- Tight spacing groups commands; 44-pixel action buttons retain usable targets.
- Radar reuses the actual cached terrain, with a live camera rectangle and click/drag navigation. No generated art is introduced.
- Hover and focus feedback are immediate; no decorative animation competes with the battlefield.
# Reserved playfield

The right sidebar and bottom command strip reserve screen space. Camera fit,
centering, clamping, cursor zoom and the radar footprint use only the remaining
map rectangle. Objectives sit in the bottom strip rather than covering terrain.
Solid panels separate commands from the playfield without changing world input coordinates.
