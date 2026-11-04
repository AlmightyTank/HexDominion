# UI review

## Implemented

- Objective moved above the minimap, beside the existing Options button. Removed the duplicate Esc hint.
- Terrain/order feedback moved into the bottom command bar. The bar now uses the entire map width instead of reserving 35% for two separate information panels.
- Victory/defeat status remains visible when the production sidebar is hidden.
- Existing military palette, typography, selection controls and production behavior retained. This is a layout cleanup, not a reskin.

## Recommended next changes

1. **High: contextual orders.** `StrategyHUD.show_selection()` disables Attack for an empty selection, but Hold, Garrison, Load and Unload remain enabled. Store references to these buttons and enable them only for suitable selections, with a visible reason when unavailable. Preserve the add-selection toggle independently. (R-26, C-2)
2. **High: explain disabled production.** `show_tile_actions()` disables training for missing facilities, insufficient credits or a full queue, but its tooltip only distinguishes facility availability. Display the actual blocking reason and retain unit combat statistics, which are currently replaced by the production tooltip. (C-2, R-31)
3. **Medium: simplify the economy column.** The continent roster dominates the resource summary and requires scrolling. Keep credits, income and power visible; move detailed continent counts to an expandable view. Show bonuses and important changes in the compact summary. (R-05, R-31)
4. **Medium: improve small-screen and touch controls.** Tab headers and save-browser actions are shorter than the 44-pixel command buttons. The HUD scales down at 960 x 640, making labels and targets smaller still. Add a compact layout policy and consistent touch targets rather than relying only on scaling. (R-03, C-4)
5. **Medium: make selection details discoverable.** Health and combat statistics are generated into a hidden label, then exposed through the army-heading tooltip. Put a compact selected-unit summary in the command bar; keep the full breakdown available on demand for touch as well as mouse. (R-39, C-3)
6. **Medium: production and site clarity.** Build/Inf/Veh/Sites is compact but abbreviated. Site details are separated from build/training actions; the Sites empty state can show generic placement instructions. Use clear category names and distinguish no selection, construction, active production and idle facilities. (R-27, R-31)
7. **Low: restore discoverable camera help.** Zoom/reset controls exist in the hidden legacy controls panel. The minimap supports mouse navigation and Enter/Space reset, but the HUD offers no visible zoom/reset buttons. Consider small named controls adjacent to the minimap. (R-39)
8. **Low: unify menus with the military HUD.** The pause menu follows the HUD palette, while the save browser uses a blue full-screen background. Use the same surfaces and spacing; give the save-name input a persistent label rather than only a placeholder. Preserve empty/invalid-save states and overwrite confirmation. (R-20, R-39)

## Verification

Godot 4.7.2, debug Compatibility renderer. Rendered and reviewed the HUD at 1280 x 720 and its scaled 960 x 640 presentation, the Sites tab, pause menu and empty-load dialog. Captures are in the session temporary directory (`ui-*.png`, `unit-runtime-*.png`), not shipped assets.

- `tests/hud_tests.gd`: four tabs, building request, panel ancestry/full command width, map bounds, centering, cursor zoom, minimap navigation and pause/resume passed.
- `tests/unit_art_runtime.gd`: mouse and synthetic touch selection at far/medium/close zoom passed with 24 units unchanged.
- `tests/ui_review.gd`: tab captures, pause/resume, empty-load disabled state, empty save-name validation, compact capture and visible victory banner passed.
- No engine errors reported in these runs. Actual disk save/load/overwrite actions were not exercised by this review. Physical touch and gamepad navigation were not tested.

## Scoped delivery gate

- Hard gate PASS for this relocation: existing information and controls retained, no invented assets or claims, tested layouts and visible end-state banner. Broader touch/accessibility issues are explicitly listed above, not certified as resolved.
- Purpose gate PASS: objective is grouped with map navigation; contextual feedback shares the command bar; duplicate panels and shortcut text removed to recover command space.
- Liveliness PASS: approved faction/olive military direction retained, ENERGY 2 / RHYTHM 1 / MOTION 1; no decorative motion added.
- Craftsmanship PASS for the changed layout: rendered inspection plus HUD, runtime selection and menu-state tests passed. Full UI redesign remains a recommendation, not a claimed completion.
