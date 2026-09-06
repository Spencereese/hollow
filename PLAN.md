# PLAN.md — HOLLOW major-upgrade (code-trust audit)

**Date:** 2026-09-06 (America/New_York)  
**Branch:** main  
**Scope:** ONE coherent slice only — finish the broken core loop.

## What actually works (verified in code)
- Godot 4.6 project; MainMenu → Main → House procedural level.
- FPS movement, flashlight battery/flicker, viewmodel hands, interact ray.
- Journal + NoteReader UI; `data/notes.json` has 5 documents.
- Procedural AudioManager, tension postFX, anomaly water / corruption shaders.
- Polaroid corruption + decals fire on `note_collected` if collection happens.
- Props/art identity is solid (textures, framed art, carvings).

## What is stubbed / broken (trust code over README/AGENTS "complete" claims)
1. **`GameManager.unlock_basement()` is never called** anywhere. Basement-unlock signal/door swing/timer are dead.
2. **Interactable classes are orphaned.** House comments say "use Note/Radio/Anomaly class" but spawn plain `StaticBody3D` + group only. Scripts never attach (wrong base vs StaticBody anyway).
3. **Player name-fallback is the real interact path**, but for `TheThreshold` it only `collect_note("basement_note")` + show reader — **never** `enter_basement()`, `trigger_end()`, or `play_end_sequence()`. **Climax is unreachable.**
4. **BasementDoor "lock" is fake:** any `*door*` name rotates +55° on E with no gate. Player can force-open OR be soft-blocked with no narrative unlock beat.
5. **Watcher / descent beat never fires** because `enter_basement()` is only referenced from dead `Anomaly.gd`.
6. No save/load (intentional per README). Journal works; no separate inventory.
7. Locations exist geometrically (living/kitchen, bedroom, basement) but have **no location awareness** in HUD/progression.

## Highest-leverage upgrade (20–40 min atmospheric loop)
**Finish core loop: explore → discover (notes) → tension unlock → descend → short climax.**

Not chosen this pass: save/load, engine swap, full rewrite, new rooms from scratch, Steam claims.

### Slice: "Progression Gate + Real Climax"
1. Gate basement unlock after **3 discovery notes** among `{intake_form, polaroid, letter, recorder}` via `GameManager.check_progression()`.
2. Lock BasementDoor interaction until unlocked; auto-swing on unlock signal (keep existing House tween).
3. Detect basement entry by player position → `enter_basement()` once (watcher + light die).
4. Fix `TheThreshold` interact → show carvings beat, then `trigger_end` + `Main.play_end_sequence()`.
5. Add `Player.show_toast` + thin **location HUD** (Living Room / Bedroom / Basement) so 2–3 spaces feel real.
6. Radio fallback gets static/whisper swell (match RadioInteractable intent).

### Out of scope leftovers
- Attaching true Interactable subclasses (would need StaticBody-compatible redesign).
- Extra upstairs wing / combat / Steam.
- Replacing procedural audio with OGGs.

## Success criteria
- Clean run: read 3 docs → door unlocks with audio → descend triggers watcher once → threshold ends demo with end screen.
- Journal still lists collected notes.
- Godot 4 + art identity preserved. No push.
