extends SceneTree
# Headless R6 smoke: attic beat + discoveries + save/load + endings + R5 wires regression.

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    print("[SMOKE_R6] start")
    for path in [
        "res://scenes/MainMenu.tscn",
        "res://scenes/Main.tscn",
        "res://scenes/House.tscn",
        "res://data/endings.json",
        "res://data/notes.json",
        "res://scripts/NoteInteractable.gd",
        "res://scripts/RadioInteractable.gd",
        "res://scripts/Anomaly.gd",
        "res://scripts/HatchInteractable.gd",
    ]:
        if load(path) == null and not FileAccess.file_exists(path):
            printerr("[SMOKE_R6] FAIL missing %s" % path)
            quit(2)
            return
        print("[SMOKE_R6] OK %s" % path)

    var gm = root.get_node_or_null("GameManager")
    if gm == null:
        printerr("[SMOKE_R6] FAIL GameManager missing")
        quit(5)
        return

    # notes.json must include attic discoveries
    var nd = gm.get_note_data("attic_ledger")
    var nd2 = gm.get_note_data("girl_box")
    var nd3 = gm.get_note_data("rope_days")
    if str(nd.get("title", "")).length() < 3 or str(nd2.get("title", "")).length() < 3 or str(nd3.get("title", "")).length() < 3:
        printerr("[SMOKE_R6] FAIL attic notes missing from notes.json")
        quit(6)
        return
    print("[SMOKE_R6] attic note data OK")

    # Attic discoveries count toward unlock (2 main + 1 attic)
    gm.reset_for_new_game()
    gm.delete_save()
    gm.collect_note("intake_form", "Intake")
    gm.collect_note("polaroid", "Polaroid")
    gm.collect_note("attic_ledger", "Ledger")
    if not gm.has_flag("basement_unlocked"):
        printerr("[SMOKE_R6] FAIL attic discovery did not help unlock basement")
        quit(7)
        return
    if not gm.has_flag("attic_catalogued"):
        printerr("[SMOKE_R6] FAIL attic_catalogued flag")
        quit(8)
        return
    print("[SMOKE_R6] attic progression unlock OK")

    # Save/load still works with attic flag
    if not gm.save_game(Vector3(3.4, 3.95, 2.2), 0.2, true) or not gm.has_save():
        printerr("[SMOKE_R6] FAIL save_game")
        quit(9)
        return
    gm.reset_for_new_game()
    if not gm.load_game() or not gm.has_flag("basement_unlocked") or not gm.is_note_collected("attic_ledger"):
        printerr("[SMOKE_R6] FAIL load restore attic/progress")
        quit(10)
        return
    print("[SMOKE_R6] save/load OK")

    # Endings still distinct + resolve
    var claimed = gm.get_ending_card("claimed")
    var escaped = gm.get_ending_card("escaped")
    var caught = gm.get_ending_card("caught")
    if str(claimed.get("title")) == str(escaped.get("title")) or str(caught.get("badge", "")) == "":
        printerr("[SMOKE_R6] FAIL endings not distinct")
        quit(11)
        return
    gm.reset_for_new_game()
    gm.collect_note("intake_form", "A")
    gm.collect_note("polaroid", "B")
    gm.collect_note("letter", "C")
    gm.collect_note("recorder", "D")
    if not gm.can_attempt_escape():
        printerr("[SMOKE_R6] FAIL escape gate")
        quit(12)
        return
    if gm.resolve_climax_choice("step") != "claimed":
        printerr("[SMOKE_R6] FAIL claimed")
        quit(13)
        return
    gm.reset_for_new_game()
    gm.collect_note("intake_form", "A")
    gm.collect_note("polaroid", "B")
    gm.collect_note("letter", "C")
    gm.collect_note("recorder", "D")
    if gm.resolve_climax_choice("refuse") != "escaped":
        printerr("[SMOKE_R6] FAIL escaped")
        quit(14)
        return
    gm.reset_for_new_game()
    gm.collect_note("intake_form", "A")
    gm.collect_note("polaroid", "B")
    gm.collect_note("letter", "C")
    if gm.resolve_climax_choice("refuse") != "caught":
        printerr("[SMOKE_R6] FAIL caught")
        quit(15)
        return
    print("[SMOKE_R6] endings OK")

    # Instantiate House: R5 wires + R6 attic
    gm.reset_for_new_game()
    gm.delete_save()
    var house_ps = load("res://scenes/House.tscn")
    if house_ps == null:
        printerr("[SMOKE_R6] FAIL House.tscn")
        quit(16)
        return
    var house = house_ps.instantiate()
    root.add_child(house)
    await create_timer(1.4).timeout

    var expect := {
        "IntakeForm": "NoteInteractable",
        "Polaroid": "NoteInteractable",
        "Letter": "NoteInteractable",
        "VoiceRecorder": "NoteInteractable",
        "Radio": "RadioInteractable",
        "TheThreshold": "Anomaly",
        "AtticLedger": "NoteInteractable",
        "GirlBox": "NoteInteractable",
        "RopeDays": "NoteInteractable",
        "AtticHatch": "HatchInteractable",
        "AtticTrapdoor": "HatchInteractable",
    }
    for prop_name in expect.keys():
        var body = house.get_node_or_null(prop_name)
        if body == null:
            printerr("[SMOKE_R6] FAIL missing prop %s" % prop_name)
            quit(17)
            return
        var child = body.get_node_or_null(expect[prop_name])
        if child == null or not child.has_method("interact"):
            printerr("[SMOKE_R6] FAIL %s missing wired %s" % [prop_name, expect[prop_name]])
            quit(18)
            return
        print("[SMOKE_R6] wired %s -> %s" % [prop_name, expect[prop_name]])

    # Collect attic notes via script path
    gm.reset_for_new_game()
    house.get_node("AtticLedger/NoteInteractable").interact(null)
    house.get_node("GirlBox/NoteInteractable").interact(null)
    house.get_node("RopeDays/NoteInteractable").interact(null)
    if not gm.is_note_collected("attic_ledger") or not gm.is_note_collected("girl_box") or not gm.is_note_collected("rope_days"):
        printerr("[SMOKE_R6] FAIL attic NoteInteractable collect")
        quit(19)
        return
    if not gm.has_flag("basement_unlocked"):
        printerr("[SMOKE_R6] FAIL 3 attic notes should unlock basement")
        quit(20)
        return
    print("[SMOKE_R6] attic NoteInteractable collect + unlock OK")

    # Hatch destination fields present
    var h = house.get_node("AtticHatch/HatchInteractable")
    if h.destination.y < 3.0:
        printerr("[SMOKE_R6] FAIL AtticHatch destination not attic-height")
        quit(21)
        return
    print("[SMOKE_R6] hatch destination OK")

    house.queue_free()
    await process_frame
    print("[SMOKE_R6] PASS")
    quit(0)
