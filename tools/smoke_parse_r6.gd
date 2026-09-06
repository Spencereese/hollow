extends SceneTree
# Headless parse/instantiate smoke for R6 attic wires.
func _init() -> void:
    call_deferred("_run")
func _run() -> void:
    print("[SMOKE_PARSE_R6] instantiate MainMenu")
    var menu = load("res://scenes/MainMenu.tscn").instantiate()
    root.add_child(menu)
    await process_frame
    menu.queue_free()
    await process_frame
    print("[SMOKE_PARSE_R6] instantiate Main (House + attic)")
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    await create_timer(1.6).timeout
    var house = main.get_node_or_null("House")
    if house == null:
        printerr("[SMOKE_PARSE_R6] FAIL no House")
        quit(2)
        return
    for pair in [
        ["IntakeForm", "NoteInteractable"],
        ["Radio", "RadioInteractable"],
        ["TheThreshold", "Anomaly"],
        ["AtticLedger", "NoteInteractable"],
        ["GirlBox", "NoteInteractable"],
        ["RopeDays", "NoteInteractable"],
        ["AtticHatch", "HatchInteractable"],
        ["AtticTrapdoor", "HatchInteractable"],
    ]:
        var body = house.get_node_or_null(pair[0])
        if body == null or body.get_node_or_null(pair[1]) == null:
            printerr("[SMOKE_PARSE_R6] FAIL wire %s/%s" % [pair[0], pair[1]])
            quit(3)
            return
    if not main.has_method("show_climax_choice"):
        printerr("[SMOKE_PARSE_R6] FAIL climax methods missing")
        quit(4)
        return
    print("[SMOKE_PARSE_R6] PASS")
    main.queue_free()
    await process_frame
    quit(0)
