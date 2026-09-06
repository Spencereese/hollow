# UPGRADE_R3.md - HOLLOW Round 3

**Date:** 2026-09-06 (America/New_York)  
**Base:** `ad68f56` (R1 core loop)  
**Slice:** Save / Load + Continue from MainMenu

## Before (honest leftovers after R1)
- No save/load; Begin always wiped state; pause only Restart / Quit to Menu.
- Orphan `NoteInteractable` / `RadioInteractable` / `Anomaly` scripts unused.
- `House.show_debug_markers` still default **true**.
- Full playthrough not manually walked (R1 was headless scene-load only).

## What shipped
1. **GameManager save API** — `user://hollow_save.json` (`save_game` / `load_game` / `has_save` / `delete_save` / `auto_save_from_player`).
2. Persists notes, flags, tension, time, battery, sequence_state, player pos/yaw, flashlight_on.
3. **MainMenu Continue** (disabled until a save exists) + Begin still resets for a fresh run.
4. **Pause → Save Progress**; Quit to Menu auto-saves; Restart Demo clears save.
5. Auto-save on note collect / basement unlock / descent.
6. **Continue restore** — Main deferred apply; House `apply_save_state()` reopens door, restores polaroid corruption, relocates player, skips watcher one-shot.
7. Debug layout markers default **off**.

## Smoke
- Godot 4.6.3 headless `tools/smoke_r3.gd`: scene loads + save/load round-trip **PASS** (exit 0).
- Godot 4.6.3 headless `tools/smoke_parse_r3.gd`: MainMenu + Main/House instantiate **PASS** (exit 0). Debug markers not spawned.

## Leftovers (still out of scope)
- Orphan Note/Radio/Anomaly interactable scripts (Player name-fallback remains live path).
- No escape-vs-fail ending branches / second location wing.
- No manual full playthrough this pass.
- No push. No Steam claims. Engine remains Godot 4.