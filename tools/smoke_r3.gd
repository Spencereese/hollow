extends SceneTree
# Headless R3 smoke: scene load + save/load round-trip via GameManager.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[SMOKE_R3] start")
	var menu_res = load("res://scenes/MainMenu.tscn")
	if menu_res == null:
		printerr("[SMOKE_R3] FAIL MainMenu.tscn load")
		quit(2)
		return
	print("[SMOKE_R3] MainMenu.tscn OK")

	var main_res = load("res://scenes/Main.tscn")
	if main_res == null:
		printerr("[SMOKE_R3] FAIL Main.tscn load")
		quit(3)
		return
	print("[SMOKE_R3] Main.tscn OK")

	var house_res = load("res://scenes/House.tscn")
	if house_res == null:
		printerr("[SMOKE_R3] FAIL House.tscn load")
		quit(4)
		return
	print("[SMOKE_R3] House.tscn OK")

	var gm = root.get_node_or_null("GameManager")
	if gm == null:
		printerr("[SMOKE_R3] FAIL GameManager missing at /root")
		quit(5)
		return

	gm.reset_for_new_game()
	gm.delete_save()
	gm.collect_note("intake_form", "Intake")
	gm.collect_note("polaroid", "Polaroid")
	gm.collect_note("letter", "Letter")
	if not gm.has_flag("basement_unlocked"):
		printerr("[SMOKE_R3] FAIL basement not unlocked after 3 notes")
		quit(6)
		return
	var ok: bool = gm.save_game(Vector3(1.2, 0.01, 2.5), 0.4, true)
	if not ok or not gm.has_save():
		printerr("[SMOKE_R3] FAIL save_game")
		quit(7)
		return

	gm.reset_for_new_game()
	if gm.collected_notes.size() != 0:
		printerr("[SMOKE_R3] FAIL reset did not clear notes")
		quit(8)
		return

	if not gm.load_game():
		printerr("[SMOKE_R3] FAIL load_game")
		quit(9)
		return
	if gm.collected_notes.size() < 3:
		printerr("[SMOKE_R3] FAIL notes not restored")
		quit(10)
		return
	if not gm.has_flag("basement_unlocked"):
		printerr("[SMOKE_R3] FAIL flag not restored")
		quit(11)
		return
	if abs(gm.saved_player_pos.x - 1.2) > 0.01:
		printerr("[SMOKE_R3] FAIL player pos not restored")
		quit(12)
		return
	if not gm.pending_continue:
		printerr("[SMOKE_R3] FAIL pending_continue not set")
		quit(13)
		return

	print("[SMOKE_R3] save/load round-trip OK (notes=%d, unlocked=%s, pos=%s)" % [
		gm.collected_notes.size(),
		str(gm.has_flag("basement_unlocked")),
		str(gm.saved_player_pos)
	])
	gm.delete_save()
	gm.reset_for_new_game()
	print("[SMOKE_R3] PASS")
	quit(0)