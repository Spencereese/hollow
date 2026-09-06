extends SceneTree
# Headless R4 smoke: scene load + save round-trip + escape-vs-fail climax endings.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[SMOKE_R4] start")
	for path in ["res://scenes/MainMenu.tscn", "res://scenes/Main.tscn", "res://scenes/House.tscn", "res://data/endings.json", "res://data/notes.json"]:
		if load(path) == null and not FileAccess.file_exists(path):
			printerr("[SMOKE_R4] FAIL missing %s" % path)
			quit(2)
			return
		print("[SMOKE_R4] OK %s" % path)

	var gm = root.get_node_or_null("GameManager")
	if gm == null:
		printerr("[SMOKE_R4] FAIL GameManager missing")
		quit(5)
		return

	# --- Save round-trip still works (R3 regression) ---
	gm.reset_for_new_game()
	gm.delete_save()
	gm.collect_note("intake_form", "Intake")
	gm.collect_note("polaroid", "Polaroid")
	gm.collect_note("letter", "Letter")
	if not gm.has_flag("basement_unlocked"):
		printerr("[SMOKE_R4] FAIL basement not unlocked after 3 notes")
		quit(6)
		return
	if not gm.save_game(Vector3(1.2, 0.01, 2.5), 0.4, true) or not gm.has_save():
		printerr("[SMOKE_R4] FAIL save_game")
		quit(7)
		return
	gm.reset_for_new_game()
	if not gm.load_game() or gm.collected_notes.size() < 3 or not gm.has_flag("basement_unlocked"):
		printerr("[SMOKE_R4] FAIL load restore")
		quit(8)
		return
	print("[SMOKE_R4] save/load OK")

	# --- Endings.json loads ---
	var claimed = gm.get_ending_card("claimed")
	var escaped = gm.get_ending_card("escaped")
	var caught = gm.get_ending_card("caught")
	if str(claimed.get("outcome", "")) != "fail" or str(claimed.get("title", "")) == "":
		printerr("[SMOKE_R4] FAIL claimed card")
		quit(9)
		return
	if str(escaped.get("outcome", "")) != "escape" or str(escaped.get("badge", "")) == "":
		printerr("[SMOKE_R4] FAIL escaped card")
		quit(10)
		return
	if str(caught.get("outcome", "")) != "fail" or str(caught.get("title", "")) == "":
		printerr("[SMOKE_R4] FAIL caught card")
		quit(11)
		return
	if str(claimed.get("title")) == str(escaped.get("title")):
		printerr("[SMOKE_R4] FAIL endings not distinct")
		quit(12)
		return
	print("[SMOKE_R4] endings cards distinct OK")

	# --- Escape requires 4 discoveries ---
	gm.reset_for_new_game()
	gm.collect_note("intake_form", "A")
	gm.collect_note("polaroid", "B")
	gm.collect_note("letter", "C")
	if gm.can_attempt_escape():
		printerr("[SMOKE_R4] FAIL escape should need recorder too")
		quit(13)
		return
	gm.collect_note("recorder", "D")
	if not gm.can_attempt_escape():
		printerr("[SMOKE_R4] FAIL escape should unlock with 4 notes")
		quit(14)
		return

	# --- resolve claimed ---
	gm.reset_for_new_game()
	gm.collect_note("intake_form", "A")
	gm.collect_note("polaroid", "B")
	gm.collect_note("letter", "C")
	gm.collect_note("recorder", "D")
	var e1: String = gm.resolve_climax_choice("step")
	if e1 != "claimed" or gm.sequence_state != "end" or gm.last_ending != "claimed":
		printerr("[SMOKE_R4] FAIL claimed resolve got=%s" % e1)
		quit(15)
		return
	print("[SMOKE_R4] claimed OK")

	# --- resolve escaped ---
	gm.reset_for_new_game()
	gm.collect_note("intake_form", "A")
	gm.collect_note("polaroid", "B")
	gm.collect_note("letter", "C")
	gm.collect_note("recorder", "D")
	var e2: String = gm.resolve_climax_choice("refuse")
	if e2 != "escaped" or not gm.has_flag("escaped_house"):
		printerr("[SMOKE_R4] FAIL escaped resolve got=%s" % e2)
		quit(16)
		return
	print("[SMOKE_R4] escaped OK")

	# --- resolve caught (refuse without thorough notes) ---
	gm.reset_for_new_game()
	gm.collect_note("intake_form", "A")
	gm.collect_note("polaroid", "B")
	gm.collect_note("letter", "C")
	# no recorder
	var e3: String = gm.resolve_climax_choice("refuse")
	if e3 != "caught" or not gm.has_flag("caught_in_loop"):
		printerr("[SMOKE_R4] FAIL caught resolve got=%s" % e3)
		quit(17)
		return
	print("[SMOKE_R4] caught OK")

	# Save skipped after end
	if gm.save_game(Vector3.ZERO, 0.0, true):
		printerr("[SMOKE_R4] FAIL should not save after end")
		quit(18)
		return

	gm.delete_save()
	gm.reset_for_new_game()
	print("[SMOKE_R4] PASS")
	quit(0)
