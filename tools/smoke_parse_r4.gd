extends SceneTree
# Headless parse/instantiate smoke for R4.
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	print("[SMOKE_PARSE_R4] instantiate MainMenu")
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.queue_free()
	await process_frame
	print("[SMOKE_PARSE_R4] instantiate Main (House build)")
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.4).timeout
	if main.get_node_or_null("House") == null:
		printerr("[SMOKE_PARSE_R4] FAIL no House")
		quit(2)
		return
	# Ensure climax helpers exist on Main
	if not main.has_method("show_climax_choice") or not main.has_method("play_escape_sequence"):
		printerr("[SMOKE_PARSE_R4] FAIL climax methods missing")
		quit(3)
		return
	print("[SMOKE_PARSE_R4] PASS")
	main.queue_free()
	await process_frame
	quit(0)
