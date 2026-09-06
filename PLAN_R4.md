# PLAN_R4.md - HOLLOW Round 4 HEAVY upgrade

**Date:** 2026-09-06 (America/New_York)
**Branch:** main
**Base:** R3 tip `1dc026d` (save/load + Continue)
**Scope:** ONE coherent heavy slice. Godot 4 atmosphere preserved. No Steam claims. No engine swap. Commit; do not push.

## Audit after R3 (honest leftovers)

| Leftover | Status at R4 start |
|---|---|
| Orphan `NoteInteractable` / `RadioInteractable` / `Anomaly` | Still unused; Player name-fallback is the live interact path |
| Escape-vs-fail ending branches | **Missing** — threshold always auto-ends as single "PROPERTY TRANSFERRED" card |
| Second basement beat / extra discoveries | Not present; loop is 3-of-4 unlock → descend → one climax |
| Full manual playthrough | Still not walked; headless smoke only |
| Save/load | Working (R3); must stay intact |

## Slice chosen: Escape-vs-Fail Climax Reckoning

**Why this over second location / orphan wiring**
- Highest narrative leverage on the already-finished descent: the threshold currently has no agency.
- Distinct climax outcomes close the moral/horror loop without a new wing of geometry.
- Keeps R3 save/load untouched for mid-run Continue; endings still skip save.

### Player-facing flow
1. Reach `TheThreshold` as today → collect `basement_note` → document reader.
2. Closing the carvings opens a **climax choice overlay** (not an auto-end):
   - **Step into the water** → **CLAIMED** (fail) — property transferred / name carved.
   - **Refuse — run for the door** →
     - If thorough (all 4 upstairs discoveries: intake, polaroid, letter, recorder) → **ESCAPED** (escape win).
     - Otherwise → **CAUGHT** (fail variant) — porch gone / hallway again.
3. Distinct end-card title, body, outcome badge, run stats; Return to Menu.

### Deliverables
1. `data/endings.json` — claimed / escaped / caught copy + outcome tags.
2. `GameManager` — `can_attempt_escape()`, `get_ending_card(reason)`, climax reasons on `trigger_end`; save API unchanged.
3. `Main` — climax choice UI; branched `_show_final_screen`; escape/claimed end sequences; pending choice after note close.
4. `Player` (+ orphan `Anomaly` script aligned) — threshold no longer auto-ends; routes through climax choice.
5. Headless `tools/smoke_r4.gd` — scene loads, save round-trip still PASS, claimed + escaped + caught assert distinct cards.
6. `UPGRADE_R4.md`. Commit; **do not push**.

### Out of scope
- Attaching orphan interactable nodes into House (scripts may be aligned but remain unwired leftovers)
- Second location / new rooms / extra discovery props
- Steam, OGG pack, engine swap

## Success criteria
- Threshold offers a real choice; three distinct climax outcomes.
- Escape only when all 4 upstairs notes collected; refuse without them → Caught.
- Mid-run Save → Continue still restores notes/battery/door (R3 path).
- Godot 4.6 headless smoke PASS. Atmospheric identity unchanged.
