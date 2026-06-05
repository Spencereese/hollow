extends Node
# GameManager - Central state for the HOLLOW demo.
# Tracks narrative progress, collected documents, tension, and demo completion.
# Uses signals so UI, audio, and world can react without tight coupling.

signal note_collected(note_id: String, title: String)
signal tension_changed(new_tension: float)
signal event_triggered(event_name: String)
signal demo_ended(reason: String)

# Core demo state
var collected_notes: Dictionary = {}  # note_id -> true
var read_notes: Dictionary = {}       # note_id -> true (for journal re-read)
var flags: Dictionary = {}            # e.g. "radio_on", "basement_unlocked", "painting_corrupted"
var tension: float = 0.0              # 0.0 calm -> 1.0 maximum dread
var time_in_house: float = 0.0
var has_flashlight: bool = true
var flashlight_battery: float = 1.0   # 0-1

# Narrative sequence tracking (simple linear + branches for demo)
var sequence_state: String = "arrival"  # arrival -> entry -> investigation -> descent -> end

# References set by scenes
var player: Node = null
var world: Node = null

func _ready() -> void:
    print("[GameManager] HOLLOW demo initialized. Clean state.")

func _process(delta: float) -> void:
    if sequence_state != "end":
        time_in_house += delta
        # Passive tension creep in the dark / after certain milestones
        if time_in_house > 45.0 and tension < 0.35:
            adjust_tension(0.008 * delta)

func adjust_tension(delta: float) -> void:
    var old = tension
    tension = clamp(tension + delta, 0.0, 1.0)
    if abs(tension - old) > 0.01:
        tension_changed.emit(tension)

func set_tension(value: float) -> void:
    tension = clamp(value, 0.0, 1.0)
    tension_changed.emit(tension)

func set_flag(key: String, value: bool = true) -> void:
    flags[key] = value
    print("[GameManager] Flag set: %s = %s" % [key, value])

func has_flag(key: String) -> bool:
    return flags.get(key, false)

func collect_note(note_id: String, title: String) -> void:
    if collected_notes.has(note_id):
        return
    collected_notes[note_id] = true
    read_notes[note_id] = true
    note_collected.emit(note_id, title)
    # Narrative hooks
    match note_id:
        "intake_form":
            adjust_tension(0.12)
            set_flag("intake_read")
            if sequence_state == "arrival":
                sequence_state = "investigation"
        "polaroid":
            adjust_tension(0.18)
            set_flag("painting_corrupted")  # actually the photo, but we reuse for the painting too
        "letter":
            adjust_tension(0.15)
            set_flag("letter_read")
        "recorder":
            adjust_tension(0.22)
            set_flag("recorder_played")
        "basement_note":
            adjust_tension(0.3)
            set_flag("basement_truth_seen")
    print("[GameManager] Note collected: %s (tension=%.2f)" % [note_id, tension])

func mark_note_read(note_id: String) -> void:
    read_notes[note_id] = true

func is_note_collected(note_id: String) -> bool:
    return collected_notes.has(note_id)

func get_collected_note_ids() -> Array:
    return collected_notes.keys()

func unlock_basement() -> void:
    set_flag("basement_unlocked")
    adjust_tension(0.1)
    event_triggered.emit("basement_unlocked")

func enter_basement() -> void:
    if sequence_state != "descent":
        sequence_state = "descent"
        set_tension(0.65)
        event_triggered.emit("entered_basement")
        print("[GameManager] Descent begun.")

func trigger_end(reason: String = "threshold") -> void:
    if sequence_state == "end":
        return
    sequence_state = "end"
    set_tension(1.0)
    demo_ended.emit(reason)
    print("[GameManager] DEMO END triggered: %s" % reason)

func get_note_data(note_id: String) -> Dictionary:
    # Load from data/notes.json at runtime
    var path := "res://data/notes.json"
    if not FileAccess.file_exists(path):
        return {"title": "Missing Data", "excerpts": ["The document is blank. The ink has run."]}
    var file := FileAccess.open(path, FileAccess.READ)
    var json_str := file.get_as_text()
    file.close()
    var data: Dictionary = JSON.parse_string(json_str)
    if data and data.has(note_id):
        return data[note_id]
    return {"title": note_id, "excerpts": ["Corrupted entry."]}

func reset_for_new_game() -> void:
    collected_notes.clear()
    read_notes.clear()
    flags.clear()
    tension = 0.0
    time_in_house = 0.0
    flashlight_battery = 1.0
    sequence_state = "arrival"
    print("[GameManager] State reset for fresh demo playthrough.")
