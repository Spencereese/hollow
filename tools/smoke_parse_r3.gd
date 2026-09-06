extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	print("[SMOKE_PARSE] instantiate MainMenu")
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	print("[SMOKE_PARSE] MainMenu children=", menu.get_child_count())
	menu.queue_free()
	await process_frame
	print("[SMOKE_PARSE] instantiate Main (House build)")
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	# Allow House _ready + deferred continue path
	await create_timer(1.2).timeout
	print("[SMOKE_PARSE] Main OK house=", main.get_node_or_null("House") != null)
	main.queue_free()
	await process_frame
	print("[SMOKE_PARSE] PASS")
	quit(0)