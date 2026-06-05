# HOLLOW

A short first-person psychological horror demo built in Godot 4 to showcase atmospheric 3D, procedural audio, data-driven narrative, and tension systems.

**Play time:** ~6-10 minutes for a full careful run.  
**Tone:** Slow-burn dread, implication, and "the house is learning you."

## How to Run (from anywhere)

You can launch HOLLOW no matter what directory your terminal is currently in.

**Easiest (copy-paste these lines):**

```bash
cd /Users/spencereese/projects/hollow
./launch_hollow.sh
```

**If you are inside another project** (e.g. your terminal prompt shows `timmy-time %` or similar):

```bash
cd ../hollow
./launch_hollow.sh
```

**Or run the script directly using its full path** (the script will switch to the correct folder automatically):

```bash
/Users/spencereese/projects/hollow/launch_hollow.sh
```

For even faster access, there is now a symlink in your home directory:

```bash
~/launch-hollow
```

The launcher always forces a completely fresh game state (no progress carry-over) — this is intentional for the horror experience.

By default it preserves the `.godot` cache for quicker startup. If you edit scripts and see weird stale errors, force a clean import with:

```bash
CLEAN=1 ~/launch-hollow
```

Godot 4.3+ is required. The path to the Godot binary is hardcoded in `launch_hollow.sh`. If it can't find Godot it will print instructions to open the folder manually in the Godot app instead.

## Controls

- **WASD** — Walk  
- **Mouse** — Look (captured on start)  
- **Shift** — Sprint (light drains faster)  
- **F** — Toggle flashlight  
- **E** — Examine / interact with documents, radio, the anomaly  
- **Tab / J** — Open Journal (collected documents)  
- **Esc** — Pause / restart / return to menu  

## What This Demonstrates

- **Fully procedural audio** (AudioManager.gd): sub-bass drone, static, heartbeat, creaks, and "voice" swells all generated with AudioStreamGenerator at runtime. No external WAV/OGG files required. Tension dynamically layers the soundscape.
- **Code-driven 3D level** (House.gd): walls, furniture, stairs, props, collision, and interactables all spawned from a compact script. Easy to iterate, review, or regenerate.
- **Narrative delivery via objects** (NoteInteractable, Radio, Anomaly): 5 distinct documents loaded from `data/notes.json`. Reading them mutates the world (photo corrupts, basement door unlocks, tension spikes, watcher silhouette appears).
- **First-person systems**: proper head bob, flashlight with realistic battery + cone decay + heavy flicker when dying, interaction ray + prompt, sprint, journal re-read system.
- **Atmosphere first**: thick distance fog, limited moonlight shaft, dust particles, one real-time shadowed flashlight, cold color grading, and a "watcher" that appears only when you are not looking directly at it for long.
- **Data-driven content**: all text lives in `data/notes.json` so writers or AI can edit the horror without touching code.
- **Clean architecture**: GameManager singleton for state + flags + tension, signals for loose coupling, separate AudioManager, Player, Interactable base class.

## The Story (No Spoilers)

You were sent to "clear" an unlisted property for a client who does not want their name on paper.  
The previous specialist left notes. The house left more.

There is no combat. There is no escape button once you go too deep.  
The demo ends when you reach the threshold in the basement.

## Extending the Demo

- Add more rooms or an upstairs by extending `_build_geometry()` in House.gd.
- New note types: drop a new entry in `data/notes.json` and place a NoteInteractable with that `note_id`.
- Stronger scares: the `_spawn_watcher_silhouette` and `_basement_entered` hooks are the places to attach new events.
- Real audio assets: replace the generator fills in AudioManager with loaded OGGs for creaks/voice. The API (play_creak, set_tension, etc.) stays the same.
- Export: Godot export templates for macOS/Windows/Linux work out of the box. The demo is small.

## Known Limitations (This Is a Vertical Slice)

- No save system (by design — clean start every launch).
- The "letter" and some props are simple boxes; a real production would have modeled or imported meshes + PBR textures.
- Procedural audio is effective but not as rich as hand-designed horror SFX.
- The basement is the end. There is intentionally no "win" state beyond reaching the final revelation.

## Credits

Built as a capability demonstration by Grok (xAI) in a single focused session using the godot-dev workflow patterns from the surrounding workspace.

The three key images (cabin interior, polaroid, intake form) were generated specifically for this demo.

---

Some houses don't want to be left alone.
