# PLAN_R3.md - HOLLOW Round 3 major upgrade

**Date:** 2026-09-06 (America/New_York)  
**Branch:** main  
**Base:** R1 tip `ad68f56` (core loop finished)  
**Scope:** ONE coherent major slice.

## Audit after ad68f56 (honest leftovers)

| Leftover | Status at R3 start |
|---|---|
| Save / load / Continue | **Missing** — Begin always resets; pause can only Restart / Quit |
| Orphan `NoteInteractable` / `RadioInteractable` / `Anomaly` | Still unused; Player name-fallback is the live interact path |
| `House.show_debug_markers` | Still **true** (emissive spheres + labels in play) |
| Full playthrough | Headless scene-load smoke only in R1; no manual walk |

Core loop (3 discoveries → unlock → descend → threshold climax) is intact. Atmosphere, journal, shaders, procedural audio preserved.

## Slice chosen: Save / Load + Continue

**Why this over second location or climax polish**
- Highest-leverage leftover that makes the finished loop *replayable mid-run*.
- Touches MainMenu + GameManager + pause without rewriting the house or climax.
- Second location / ending branches would bloat scope; climax already works after R1.

### Deliverables
1. `user://hollow_save.json` via GameManager (`save_game` / `load_game` / `has_save` / `delete_save`).
2. Persist: notes, flags, tension, time, battery, sequence_state, player pos/yaw, flashlight_on.
3. MainMenu: **Continue** (enabled when save exists) + Begin still starts clean.
4. Pause: **Save Progress** + auto-save on note collect / basement unlock / descent.
5. On Continue: restore GameManager, relocate Player, re-apply world mutations (door open, polaroid corrupt) without replaying one-shot watcher.
6. Turn off debug layout markers (`show_debug_markers = false`).
7. Headless smoke for scene load + save round-trip. Commit; **do not push**.

### Out of scope
- Attaching orphan Interactable subclasses
- New rooms / escape-vs-fail ending branches
- Steam, engine swap, OGG replacement

## Success criteria
- Mid-run Save → Quit to Menu → Continue restores notes, battery, position, unlocked door.
- Begin still wipes state (and optionally clears save only on explicit Restart, not on Begin — Begin = new run; old save overwritten on next auto-save).
- Godot 4.6 + atmospheric identity unchanged.
