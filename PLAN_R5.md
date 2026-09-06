# PLAN_R5.md - HOLLOW Round 5 HEAVY upgrade

**Date:** 2026-09-06 (America/New_York)
**Branch:** main
**Base:** R4 tip `b4643a4` (escape-vs-fail climax reckoning)
**Scope:** ONE coherent heavy slice. Godot 4 atmosphere preserved. No Steam claims. No engine swap. Commit; do not push.

## Audit after R4 (honest leftovers)

| Leftover | Status at R5 start |
|---|---|
| Orphan `NoteInteractable` / `RadioInteractable` / `Anomaly` | Scripts exist + comments say "use full class"; House still spawns bare StaticBodies; Player name-fallback is the live path |
| Second location / attic / extra discoveries | Not present |
| Full manual playthrough | Still not walked; headless smoke only |
| Save/load + endings | Working (R3/R4); must stay intact |

## Slice chosen: Wire orphan Note / Radio / Anomaly into live path

**Why this over attic / second location**
- Highest structural leverage: finishes incomplete R2–R4 intent already documented in House comments.
- Removes dual-path drift (script vs name-fallback) that breaks save-aware radio / one-shot anomaly.
- Keeps geometry, discovery count (3-of-4 unlock, 4 for escape), climax choice, and save/load unchanged.

### Player-facing flow (unchanged surface, corrected wiring)
1. IntakeForm / Polaroid / Letter / VoiceRecorder → `NoteInteractable` children fire `collect_note` + reader.
2. Radio → `RadioInteractable` (flag-persistent re-hiss; still maps to `recorder` discovery).
3. TheThreshold → `Anomaly` routes basement carvings → climax choice (claimed / escaped / caught).
4. Mid-run Save → Continue still restores notes/battery/door; endings still skip save.

### Deliverables
1. `House.gd` — `_attach_note` / `_attach_radio` / `_attach_anomaly` helpers; wire all six live props.
2. `Player.gd` — prefer child Interactable scripts on ray hit; keep name-fallback + doors as safety.
3. `Main.gd` — interact HUD reads `get_interact_prompt` from attached children.
4. `RadioInteractable.gd` — honor `radio_on` flag so Continue does not replay as first listen.
5. `Anomaly.gd` — drop shadowing export; respect already-collected basement note.
6. `tools/smoke_r5.gd` (+ parse) — assert wired children + save/load + endings regression.
7. `UPGRADE_R5.md`. Commit; **do not push**.

### Out of scope
- Attic / second location / new discovery IDs
- Manual full playthrough
- Steam, OGG pack, engine swap

## Success criteria
- House props have live Note/Radio/Anomaly children; Player hits scripts first.
- Save/load + three climax endings still PASS headless.
- Godot 4.6 identity unchanged. No Steam claims.
