# UPGRADE_R6.md - HOLLOW Round 6 HEAVY

**Date:** 2026-09-06 (America/New_York)
**Base:** `68ee320` (R5 wire orphan Note/Radio/Anomaly)
**Slice:** Short attic / second-location beat with 3 discoveries before basement descent

## Before (honest leftovers after R5)
- No attic / second location / new discovery IDs.
- Save/load + CLAIMED/ESCAPED/CAUGHT working; wired interactables working.
- No manual full playthrough.

## What shipped
1. **`data/notes.json`** - `attic_ledger`, `girl_box`, `rope_days` (bureaucratic -> personal attic documents).
2. **`scripts/HatchInteractable.gd`** - climb/descend teleport with toast + optional flag.
3. **`House.gd`** - `_build_attic()` + `_attach_hatch`; attic geometry/light/rungs; `AtticHatch` / `AtticTrapdoor`; three wired NoteInteractables; world mutations (decal / puff / bulb flicker).
4. **`GameManager.gd`** - attic note flags + attic IDs in basement unlock pool (3-of-expanded).
5. **`Main.gd`** - LocationLabel shows **Attic** when `y > 3.2`.
6. **`Player.gd`** - name-fallback safety for hatch + attic props.
7. **`tools/smoke_r6.gd`** + **`tools/smoke_parse_r6.gd`** - attic wires + progression + save/load + endings + R5 regression.
8. **`PLAN_R6.md`** locked this slice before implementation.

### Live path (preserved rules)
- 3 discoveries among main-floor + attic pool unlock basement.
- Escape still requires original four main-floor discoveries (`intake_form`, `polaroid`, `letter`, `recorder`).
- Threshold -> carvings -> climax choice (CLAIMED / ESCAPED / CAUGHT).
- Save/load API unchanged; endings still skip save.
- R5 Note/Radio/Anomaly wires remain live.

## Smoke
- Godot 4.6.3 headless `tools/smoke_r6.gd` - **PASS** (exit 0): attic notes, unlock via attic, hatch wires, save/load, endings, R5 props.
- Godot 4.6.3 headless `tools/smoke_parse_r6.gd` - **PASS** (exit 0): MainMenu + Main/House instantiate with attic wires.
- Pre-existing headless ObjectDB leak / Image.load / `_add_decal` look_at warnings unchanged.

## Leftovers (still out of scope)
- No manual full playthrough this pass.
- Player name-fallback still present as safety (not removed).
- Attic is teleport-hatch (not walkable ladder collision climb).
- Group interactable count print still under-counts during build (layout debug lists all).
- No push. No Steam claims. Engine remains Godot 4.
