# UPGRADE_R4.md - HOLLOW Round 4 HEAVY

**Date:** 2026-09-06 (America/New_York)
**Base:** `1dc026d` (R3 save/load + Continue)
**Slice:** Escape-vs-fail climax reckoning (distinct CLAIMED / ESCAPED / CAUGHT outcomes)

## Before (honest leftovers after R3)
- Threshold interaction auto-ended into a single "PROPERTY TRANSFERRED" card — no agency.
- Orphan `NoteInteractable` / `RadioInteractable` / `Anomaly` still unused (Player name-fallback live path).
- No second location / extra discoveries.
- No manual full playthrough; headless smoke only.

## What shipped
1. **`data/endings.json`** — three climax cards: `claimed` (fail), `escaped` (escape), `caught` (fail variant) with distinct titles/bodies/badges.
2. **`GameManager`** — `can_attempt_escape()` (all 4 upstairs discoveries), `resolve_climax_choice("step"|"refuse")`, `get_ending_card()`, `last_ending` / `climax_choice_pending`. Save/load API unchanged; still skips save after end.
3. **`Player` threshold** — collects `basement_note` + opens reader; sets `climax_choice_pending` instead of auto-`trigger_end`.
4. **`Main`** — closing carvings opens climax choice UI; branched sequences (`play_end_sequence` / `play_escape_sequence` / `play_caught_sequence`); end screen uses ending card + run stats.
5. **`Anomaly.gd`** — aligned to same climax-choice path (still unwired orphan; name-fallback remains live).
6. **`tools/smoke_r4.gd`** + **`tools/smoke_parse_r4.gd`** — regression save/load + three endings + Main instantiate.
7. **`PLAN_R4.md`** locked this slice before implementation.

### Climax rules
- **Step into the water** → CLAIMED.
- **Refuse — run for the door** + all 4 upstairs notes → ESCAPED.
- **Refuse** without thorough notes → CAUGHT (hallway loop fail).

## Smoke
- Godot 4.6.3 headless `tools/smoke_r4.gd` — **PASS** (exit 0): save/load, distinct cards, claimed/escaped/caught.
- Godot 4.6.3 headless `tools/smoke_parse_r4.gd` — **PASS** (exit 0): MainMenu + Main/House instantiate; climax methods present.
- `--quit --import` — PASS (no parse errors).

## Leftovers (still out of scope)
- Orphan Note/Radio interactable nodes still not attached in House (Player name-fallback remains).
- No second basement beat / new discovery props / second location wing.
- No manual full playthrough this pass.
- Pre-existing headless ObjectDB leak warning / Image.load export warnings unchanged.
- No push. No Steam claims. Engine remains Godot 4.