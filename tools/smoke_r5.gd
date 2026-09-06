extends SceneTree
# Headless R5 smoke: wired Note/Radio/Anomaly children + save/load + endings regression.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[SMOKE_R5] start")
	for path in ["res://scenes/MainMenu.tscn", "res://scenes/Main.tscn", "res://scenes/House.tscn", "res://data/endings.json", "res://data/notes.json", "res://scripts/NoteInteractable.gd", "res://scripts/RadioInteractable.gd", "res://scripts/Anomaly.gd"]:
		if load(path) == null and not FileAccess.file_exists(path):
			printerr("[SMOKE_R5] FAIL missing %s" % path)
			quit(2)
			return
		print("[SMOKE_R5] OK %s" % path)

	var gm = root.get_node_or_null("GameManager")
	if gm == null:
		printerr("[SMOKE_R5] FAIL GameManager missing")
		quit(5)
		return

	# --- Save round-trip still works ---
	gm.reset_for_new_game()
	gm.delete_save()
	gm.collect_note("intake_form", "Intake")
	gm.collect_note("polaroid", "Polaroid")
	gm.collect_note("letter", "Letter")
	if not gm.has_flag("basement_unlocked"):
		printerr("[SMOKE_R5] FAIL basement not unlocked after 3 notes")
		quit(6)
		return
	if not gm.save_game(Vector3(1.2, 0.01, 2.5), 0.4, true) or not gm.has_save():
		printerr("[SMOKE_R5] FAIL save_game")
		quit(7)
		return
	gm.reset_for_new_game()
	if not gm.load_game() or gm.collected_notes.size() < 3 or not gm.has_flag("basement_unlocked"):
		printerr("[SMOKE_R5] FAIL load restore")
		quit(8)
		return
	print("[SMOKE_R5] save/load OK")

	# --- Endings still distinct ---
	var claimed = gm.get_ending_card("claimed")
	var escaped = gm.get_ending_card("escaped")
	var caught = gm.get_ending_card("caught")
	if str(claimed.get("title")) == str(escaped.get("title")) or str(caught.get("badge", "")) == "":
		printerr("[SMOKE_R5] FAIL endings not distinct")
		quit(9)
		return
	gm.reset_for_new_game()
	gm.collect_note("intake_form", "A")
	gm.collect_note("polaroid", "B")
	gm.collect_note("letter", "C")
	gm.collect_note("recorder", "D")
	if not gm.can_attempt_escape():
		printerr("[SMOKE_R5] FAIL escape gate")
		quit(10)
		return
	if gm.resolve_climax_choice("step") != "claimed":
		printerr("[SMOKE_R5] FAIL claimed resolve")
		quit(11)
		return
	gm.reset_for_new_game()
	gm.collect_note("intake_form", "A")
	gm.collect_note("polaroid", "B")
	gm.collect_note("letter", "C")
	gm.collect_note("recorder", "D")
	if gm.resolve_climax_choice("refuse") != "escaped":
		printerr("[SMOKE_R5] FAIL escaped resolve")
		quit(12)
		return
	gm.reset_for_new_game()
	gm.collect_note("intake_form", "A")
	gm.collect_note("polaroid", "B")
	gm.collect_note("letter", "C")
	if gm.resolve_climax_choice("refuse") != "caught":
		printerr("[SMOKE_R5] FAIL caught resolve")
		quit(13)
		return
	print("[SMOKE_R5] endings OK")

	# --- Instantiate House and assert wired children ---
	gm.reset_for_new_game()
	gm.delete_save()
	var house_ps = load("res://scenes/House.tscn")
	if house_ps == null:
		printerr("[SMOKE_R5] FAIL House.tscn")
		quit(14)
		return
	var house = house_ps.instantiate()
	root.add_child(house)
	await create_timer(1.2).timeout

	var expect := {
		"IntakeForm": "NoteInteractable",
		"Polaroid": "NoteInteractable",
		"Letter": "NoteInteractable",
		"VoiceRecorder": "NoteInteractable",
		"Radio": "RadioInteractable",
		"TheThreshold": "Anomaly",
	}
	for prop_name in expect.keys():
		var body = house.get_node_or_null(prop_name)
		if body == null:
			printerr("[SMOKE_R5] FAIL missing prop %s" % prop_name)
			quit(15)
			return
		var child = body.get_node_or_null(expect[prop_name])
		if child == null or not child.has_method("interact"):
			printerr("[SMOKE_R5] FAIL %s missing wired %s" % [prop_name, expect[prop_name]])
			quit(16)
			return
		print("[SMOKE_R5] wired %s -> %s" % [prop_name, expect[prop_name]])

	# Fire NoteInteractable once and ensure collect works through script path
	gm.reset_for_new_game()
	var intake_note = house.get_node("IntakeForm/NoteInteractable")
	intake_note.interact(null)
	if not gm.is_note_collected("intake_form"):
		printerr("[SMOKE_R5] FAIL NoteInteractable did not collect")
		quit(17)
		return
	print("[SMOKE_R5] NoteInteractable collect OK")

	# Radio script sets flag
	var radio = house.get_node("Radio/RadioInteractable")
	radio.interact(null)
	if not gm.has_flag("radio_on") or not gm.is_note_collected("recorder"):
		printerr("[SMOKE_R5] FAIL RadioInteractable path")
		quit(18)
		return
	print("[SMOKE_R5] RadioInteractable OK")

	# Anomaly sets climax pending
	var anom = house.get_node("TheThreshold/Anomaly")
	anom.interact(null)
	if not gm.climax_choice_pending or not gm.is_note_collected("basement_note"):
		printerr("[SMOKE_R5] FAIL Anomaly climax path")
		quit(19)
		return
	print("[SMOKE_R5] Anomaly climax OK")

	house.queue_free()
	await process_frame
	print("[SMOKE_R5] PASS")
	quit(0)
