# HOLLOW - AI Assistant Rules

This is a **vertical slice horror demo**, not a full game. Scope is deliberately small and tight.

## Core Goals (Non-Negotiable)
- **Atmosphere over mechanics.** Every system must serve dread, implication, or the "house is aware and learning" theme.
- **Self-contained.** Procedural audio + code-built level + generated textures = zero external asset dependencies for a first play.
- **Data-driven narrative.** All text in `data/notes.json`. Changing the horror should not require touching GDScript.
- **Replay the first 3 minutes.** The demo must feel fresh and terrifying on a clean launch every time.

## Technical Conventions (Follow the existing patterns in this repo)
- GameManager + AudioManager are autoload singletons.
- All major state changes go through GameManager signals or flags.
- House.gd is the single source of truth for level layout. Do not hand-author complex geometry in .tscn files.
- Player input actions are defined in project.godot (do not add new ones without updating the launcher help text and MainMenu controls screen).
- Interactables inherit from the base class and implement `_on_interact`.
- When adding a new document, also add at least one world mutation (corrupt a visual, unlock something, spawn a watcher, change a prompt text, raise tension permanently).

## Writing Horror
- Short. Cold. Bureaucratic language that slowly becomes personal.
- The player character is a "specialist" who has done this before (the notes prove it). The horror is realizing the house has done this to *you* many times.
- Never explain the rules. Let the player feel them through the radio broadcast, the timestamp on the recorder, the carved list with their name already on it.
- One really good "the room changed while I wasn't looking" or "the voice is describing what I am doing right now" moment is worth ten jump scares.

## Testing
- Always launch with `./launch_hollow.sh` (it forces a clean state).
- Play at least once with the flashlight dying naturally.
- Read every document in different orders and note what still feels powerful.
- The end sequence (black water) must feel like a genuine point of no return.

## Scope Discipline
If something would take more than an hour to implement and test, cut it. The power is in the 6-8 minute loop being *perfect*.

Current vertical slice is complete when:
- You can walk the house, read all 5 pieces of paper, trigger the radio event, see the watcher once, reach the basement, and get the final screen.
- The whole experience feels like a real (tiny) commercial horror demo, not a tech prototype.

Update this file when new patterns or hard rules emerge.
