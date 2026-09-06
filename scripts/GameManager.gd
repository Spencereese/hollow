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

# Climax ending (R4)
var last_ending: String = ""
var climax_choice_pending: bool = false

# Save / Continue (R3)
const SAVE_PATH: String = "user://hollow_save.json"
const SAVE_VERSION: int = 1
var pending_continue: bool = false
var saved_player_pos: Vector3 = Vector3.ZERO
var saved_player_yaw: float = 0.0
var saved_flashlight_on: bool = true

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
		"attic_ledger":
			adjust_tension(0.16)
			set_flag("attic_catalogued")
		"girl_box":
			adjust_tension(0.2)
			set_flag("found_her_box")
		"rope_days":
			adjust_tension(0.14)
			set_flag("counted_the_days")
		"basement_note":
			adjust_tension(0.3)
			set_flag("basement_truth_seen")
	check_progression()
	auto_save_from_player()
	print("[GameManager] Note collected: %s (tension=%.2f)" % [note_id, tension])

func check_progression() -> void:
	# Unlock basement after enough discovery - finishes the explore -> discover -> descend loop.
	if has_flag("basement_unlocked"):
		return
	# R6: attic discoveries also count toward the unlock pool.
	var keys := ["intake_form", "polaroid", "letter", "recorder", "attic_ledger", "girl_box", "rope_days"]
	var n := 0
	for k in keys:
		if collected_notes.has(k):
			n += 1
	if n >= 3:
		unlock_basement()
		print("[GameManager] Progression: %d discoveries - basement unlocked." % n)

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
	auto_save_from_player()

func enter_basement() -> void:
	if sequence_state != "descent":
		sequence_state = "descent"
		set_tension(0.65)
		event_triggered.emit("entered_basement")
		print("[GameManager] Descent begun.")
		auto_save_from_player()

func trigger_end(reason: String = "claimed") -> void:
	if sequence_state == "end":
		return
	# Normalize legacy reason
	if reason == "threshold":
		reason = "claimed"
	sequence_state = "end"
	last_ending = reason
	climax_choice_pending = false
	set_tension(1.0)
	demo_ended.emit(reason)
	print("[GameManager] DEMO END triggered: %s" % reason)

func can_attempt_escape() -> bool:
	# Thorough investigation: all four upstairs discoveries.
	var need := ["intake_form", "polaroid", "letter", "recorder"]
	for k in need:
		if not collected_notes.has(k):
			return false
	return true

func resolve_climax_choice(choice: String) -> String:
	# choice: "step" | "refuse" -> ending id
	var ending := "claimed"
	if choice == "refuse":
		if can_attempt_escape():
			ending = "escaped"
			set_flag("escaped_house")
		else:
			ending = "caught"
			set_flag("caught_in_loop")
	else:
		set_flag("stepped_into_threshold")
	trigger_end(ending)
	return ending

func get_ending_card(reason: String = "") -> Dictionary:
	var rid := reason
	if rid == "" or rid == "threshold":
		rid = last_ending if last_ending != "" else "claimed"
	var path := "res://data/endings.json"
	var fallback := {
		"id": rid,
		"outcome": "fail",
		"badge": "END",
		"title": "PROPERTY TRANSFERRED",
		"body": "The demo is over."
	}
	if not FileAccess.file_exists(path):
		return fallback
	var file := FileAccess.open(path, FileAccess.READ)
	var json_str := file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_str)
	if typeof(data) != TYPE_DICTIONARY:
		return fallback
	var d: Dictionary = data
	if d.has(rid) and typeof(d[rid]) == TYPE_DICTIONARY:
		return d[rid]
	return fallback

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
	last_ending = ""
	climax_choice_pending = false
	pending_continue = false
	saved_player_pos = Vector3.ZERO
	saved_player_yaw = 0.0
	saved_flashlight_on = true
	print("[GameManager] State reset for fresh demo playthrough.")

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		print("[GameManager] Save deleted.")

func save_game(player_pos: Vector3 = Vector3.ZERO, player_yaw: float = 0.0, flashlight_on: bool = true) -> bool:
	if sequence_state == "end":
		print("[GameManager] Skip save - demo already ended.")
		return false
	var data := {
		"version": SAVE_VERSION,
		"collected_notes": collected_notes.duplicate(),
		"read_notes": read_notes.duplicate(),
		"flags": flags.duplicate(),
		"tension": tension,
		"time_in_house": time_in_house,
		"flashlight_battery": flashlight_battery,
		"sequence_state": sequence_state,
		"player_pos": {"x": player_pos.x, "y": player_pos.y, "z": player_pos.z},
		"player_yaw": player_yaw,
		"flashlight_on": flashlight_on,
	}
	var json := JSON.stringify(data, "\t")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[GameManager] Could not write save: %s" % SAVE_PATH)
		return false
	f.store_string(json)
	f.close()
	print("[GameManager] Saved progress (%s notes, seq=%s, battery=%.2f)." % [collected_notes.size(), sequence_state, flashlight_battery])
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var json_str := f.get_as_text()
	f.close()
	var data = JSON.parse_string(json_str)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[GameManager] Corrupt save JSON.")
		return false
	var d: Dictionary = data
	collected_notes = {}
	var cn = d.get("collected_notes", {})
	if typeof(cn) == TYPE_DICTIONARY:
		for k in cn.keys():
			collected_notes[str(k)] = true
	read_notes = {}
	var rn = d.get("read_notes", {})
	if typeof(rn) == TYPE_DICTIONARY:
		for k in rn.keys():
			read_notes[str(k)] = true
	flags = {}
	var fl = d.get("flags", {})
	if typeof(fl) == TYPE_DICTIONARY:
		for k in fl.keys():
			flags[str(k)] = bool(fl[k])
	tension = float(d.get("tension", 0.0))
	time_in_house = float(d.get("time_in_house", 0.0))
	flashlight_battery = float(d.get("flashlight_battery", 1.0))
	sequence_state = str(d.get("sequence_state", "arrival"))
	var pp = d.get("player_pos", {})
	if typeof(pp) == TYPE_DICTIONARY:
		saved_player_pos = Vector3(float(pp.get("x", 0.0)), float(pp.get("y", 0.01)), float(pp.get("z", -1.8)))
	else:
		saved_player_pos = Vector3(-0.3, 0.01, -1.8)
	saved_player_yaw = float(d.get("player_yaw", 0.0))
	saved_flashlight_on = bool(d.get("flashlight_on", true))
	pending_continue = true
	print("[GameManager] Loaded save (notes=%d, seq=%s, pos=%s)." % [collected_notes.size(), sequence_state, saved_player_pos])
	return true

func capture_player_for_save(p: Node) -> Dictionary:
	var pos := Vector3(-0.3, 0.01, -1.8)
	var yaw := 0.0
	var fl_on := true
	if p and is_instance_valid(p):
		if p is Node3D:
			pos = (p as Node3D).global_position
			yaw = (p as Node3D).rotation.y
		var fl_val = p.get("flashlight_on")
		if fl_val != null:
			fl_on = bool(fl_val)
	return {"pos": pos, "yaw": yaw, "flashlight_on": fl_on}

func auto_save_from_player() -> void:
	if sequence_state == "end":
		return
	var p: Node = player
	if p == null and world and world.has_node("Player"):
		p = world.get_node("Player")
	var cap: Dictionary = capture_player_for_save(p)
	save_game(cap["pos"], cap["yaw"], cap["flashlight_on"])
