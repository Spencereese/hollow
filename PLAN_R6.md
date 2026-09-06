# PLAN_R6.md - HOLLOW Round 6 HEAVY upgrade

**Date:** 2026-09-06 (America/New_York)
**Branch:** main
**Base:** R5 tip `68ee320` (wire orphan Note/Radio/Anomaly)
**Scope:** ONE coherent heavy slice. Godot 4 atmosphere preserved. No Steam claims. No engine swap. Commit; do not push.

## Audit after R5 (honest leftovers)

| Leftover | Status at R6 start |
|---|---|
| Attic / second location / new discovery IDs | Not present (explicit R5 leftover) |
| Save/load + CLAIMED/ESCAPED/CAUGHT | Working (R3/R4); must stay intact |
| Wired Note/Radio/Anomaly children | Working (R5); must stay intact |
| Manual full playthrough | Still not walked; headless smoke only |

## Slice chosen: Short attic beat with 2-3 discoveries

**Why this over further interact rewiring / Steam / OGG**
- Highest remaining atmospheric leverage from R5 leftovers.
- Second location makes Living / Bedroom / Attic / Basement feel like a real path before descent.
- New documents stay data-driven (`data/notes.json`) per AGENTS.md.

### Player-facing flow
1. Explore main floor discoveries as before.
2. Bedroom ceiling hatch (`AtticHatch`) climbs into a short attic space.
3. Find **3** attic documents: ledger / girl's box / rope-day tally.
4. Attic discoveries count toward the existing 3-discovery basement unlock.
5. Trapdoor returns to bedroom; basement unlock + climax endings unchanged.
6. Escape still requires the original four main-floor discoveries (thoroughness).

### Deliverables
1. `PLAN_R6.md` (this file).
2. `data/notes.json` - `attic_ledger`, `girl_box`, `rope_days`.
3. `scripts/HatchInteractable.gd` - climb / descend teleport with toast.
4. `House.gd` - attic geometry + light + hatch/trapdoor + 3 wired notes + mutations.
5. `GameManager.gd` - note hooks + attic IDs in unlock pool.
6. `Main.gd` - LocationLabel shows Attic when y > 3.2.
7. `Player.gd` - name-fallback safety for new props / hatches.
8. `tools/smoke_r6.gd` (+ parse) - attic wires + progression + save/load + endings regression.
9. `UPGRADE_R6.md`. Commit; **do not push**.

### Out of scope
- Manual full playthrough
- Steam, OGG pack, engine swap
- Removing Player name-fallback safety net

## Success criteria
- Attic reachable via hatch; 3 discoveries collectable through NoteInteractable.
- Basement still unlocks after 3 discoveries (attic IDs eligible).
- Save/load + three climax endings still PASS headless.
- Prior R5 wires still present. No push.
