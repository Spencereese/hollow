# UPGRADE_R5.md - HOLLOW Round 5 HEAVY

**Date:** 2026-09-06 (America/New_York)
**Base:** `b4643a4` (R4 escape-vs-fail climax reckoning)
**Slice:** Wire orphan NoteInteractable / RadioInteractable / Anomaly into the live interact path

## Before (honest leftovers after R4)
- House spawned bare StaticBody props; comments said "use Note/Radio/Anomaly class" but never attached them.
- Player name-fallback was the only live interact path for discoveries + threshold.
- Orphan scripts drifted from save-aware radio / climax behavior.
- No attic / second location. No manual full playthrough.

## What shipped
1. **`House.gd`** — `_attach_note` / `_attach_radio` / `_attach_anomaly`; wires IntakeForm, Polaroid, Letter, VoiceRecorder, Radio, TheThreshold.
2. **`Player.gd`** — prefers child Interactable scripts on ray hit; name-fallback + doors remain as safety.
3. **`Main.gd`** — interact HUD reads `get_interact_prompt` from wired children.
4. **`RadioInteractable.gd`** — honors `radio_on` flag so Continue does not replay first listen; toast on hiss.
5. **`Anomaly.gd`** — live-wired; respects already-collected basement note / pending climax.
6. **`NoteInteractable.gd`** — fixed reader body/title scope; ASCII prompts.
7. **`tools/smoke_r5.gd`** + **`tools/smoke_parse_r5.gd`** — assert six wired children + script interact path + save/load + claimed/escaped/caught.
8. **`PLAN_R5.md`** locked this slice before implementation.

### Live path (unchanged surface rules)
- 3-of-4 upstairs discoveries unlock basement; all 4 required for ESCAPED.
- Threshold → carvings → climax choice (CLAIMED / ESCAPED / CAUGHT).
- Save/load API unchanged; endings still skip save.

## Smoke
- Godot 4.6.3 headless `tools/smoke_r5.gd` — **PASS** (exit 0): wired children, Note/Radio/Anomaly script interact, save/load, endings.
- Godot 4.6.3 headless `tools/smoke_parse_r5.gd` — **PASS** (exit 0): MainMenu + Main/House instantiate with wires.
- `--quit --import` — PASS (no parse errors).

## Leftovers (still out of scope)
- No attic / second location / new discovery IDs.
- No manual full playthrough this pass.
- Player name-fallback still present as safety (not removed).
- Pre-existing headless ObjectDB leak warning / Image.load export warnings / occasional `_add_decal` look_at tree warning unchanged.
- No push. No Steam claims. Engine remains Godot 4.
