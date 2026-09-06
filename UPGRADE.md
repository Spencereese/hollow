# UPGRADE.md — HOLLOW major upgrade

## Before (honest)
README/AGENTS claim a complete vertical slice (walk house, read 5 docs, radio, watcher, basement, final screen). **Code disagreed:**

- `unlock_basement()` never called → unlock/door/watcher progression dead.
- Anomaly/Note/Radio scripts unused; Player name-fallback incomplete.
- Threshold interact did not end the demo.
- Basement door opened on any E with no narrative gate.
- No location HUD; climax path broken.

Art, shaders, audio, journal UI, and level geometry were largely in place — the **loop glue** was missing.

## Slice chosen
**Progression Gate + Real Climax** (one coherent core-loop finish). See PLAN.md.

## After (honest)
Implemented locally after Grok `acceptEdits` read the plan but wrote **zero** file changes (contention with other `grok.exe` on PC-Culture).

### What works now
1. **Discovery gate:** collecting any 3 of `{intake_form, polaroid, letter, recorder}` calls `GameManager.check_progression()` → `unlock_basement()`.
2. **Locked basement door:** E on `BasementDoor` while locked toasts and refuses; HUD shows `E - Locked`. Unlock swings door + toast.
3. **Descent beat:** entering basement zone (`y < -2.5`, `z > 5`) once calls `enter_basement()` → watcher/lights/audio.
4. **Climax:** interacting with `TheThreshold` shows carvings note, triggers end, plays `play_end_sequence()`, kills flashlight.
5. **Radio fallback** matches RadioInteractable intent (flags, tension, static/whisper).
6. **Location HUD** (Living Room / Bedroom / Basement / Porch) + toast HUD via `Player.show_toast`.

### Smoke
- Godot 4.6.3 headless: MainMenu loads OK; `res://scenes/Main.tscn` loads OK (House + Player + 6 interactables). No script parse errors. Exit 0.
- Full playthrough of the 20–40 min loop not manually walked this pass (headless only).

### Leftovers (not this slice)
- True `NoteInteractable` / `RadioInteractable` / `Anomaly` scripts still orphaned (Player name-fallback remains the live path).
- Save/load still absent (intentional demo design).
- Debug layout markers still default on in House.
- No push. No Steam claims.
