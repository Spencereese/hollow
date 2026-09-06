extends Node3D
# Main - In-game orchestrator for HOLLOW.
# Handles House instancing, HUD, full-screen NoteReader, Journal, pause, and end sequence.
# This is the "real" main scene after menu.

# Relax strict inference warnings for this prototype (UI builder code)
@warning_ignore("inferred_declaration")

var house_container: Node = null

var note_reader: Control
var journal_panel: Control
var hud: Control
var pause_menu: Control
var postfx_rect: ColorRect
var postfx_mat: ShaderMaterial
var climax_panel: Control
var _climax_resolving: bool = false

var note_title_label: Label
var note_body_label: RichTextLabel
var note_reveal_label: RichTextLabel

var _is_paused: bool = false
var _journal_open: bool = false
var _current_tension: float = 0.0

func _ready() -> void:
    # Instance the heavy House scene (code-built)
    var house_scene: Resource = load("res://scenes/House.tscn")
    if house_scene:
        var house: Node = house_scene.instantiate()
        house.name = "House"
        add_child(house)
        house_container = house
        print("[Main] House scene instanced and added as child")
    else:
        push_error("House.tscn missing! The demo will be empty.")

    # Create a CanvasLayer so 2D UI (HUD, menus, notes) renders correctly on top of 3D
    var ui_layer := CanvasLayer.new()
    ui_layer.name = "UILayer"
    add_child(ui_layer)

    _build_hud(ui_layer)
    _build_note_reader(ui_layer)
    _build_journal(ui_layer)
    _build_pause_menu(ui_layer)
    _build_postfx(ui_layer)

    # Connect GameManager signals for global reactions
    if GameManager:
        GameManager.demo_ended.connect(_on_demo_ended)
        GameManager.note_collected.connect(_on_note_collected_for_hud)
        GameManager.tension_changed.connect(_on_tension_changed)

    # Mouse capture is now handled in Player.gd (starts visible, click-to-capture for macOS compatibility).
    # Do not force CAPTURED here.

    print("[Main] HOLLOW in-game ready. Explore carefully. House children: ", house_container.get_child_count() if house_container else 0)

    # Wire GameManager refs + apply Continue restore (R3 save/load)
    if GameManager and house_container:
        GameManager.world = house_container
        if house_container.has_node("Player"):
            GameManager.player = house_container.get_node("Player")
        if GameManager.pending_continue:
            call_deferred("_apply_continue_state")

func _build_hud(parent: Node) -> void:
    hud = Control.new()
    hud.name = "HUD"
    hud.set_anchors_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Do not block mouse motion from reaching the 3D Player
    parent.add_child(hud)

    # Battery bar (top right)
    var battery_bg: PanelContainer = PanelContainer.new()
    battery_bg.position = Vector2(1020, 28)
    battery_bg.size = Vector2(220, 28)
    var bb_style: StyleBoxFlat = StyleBoxFlat.new()
    bb_style.bg_color = Color(0.03, 0.025, 0.03, 0.85)
    bb_style.border_color = Color(0.2, 0.18, 0.2, 0.6)
    bb_style.border_width_left = 1
    bb_style.border_width_right = 1
    bb_style.border_width_top = 1
    bb_style.border_width_bottom = 1
    battery_bg.add_theme_stylebox_override("panel", bb_style)
    battery_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(battery_bg)

    var battery_label: Label = Label.new()
    battery_label.name = "BatteryLabel"
    battery_label.text = "LIGHT 100%"
    battery_label.position = Vector2(8, 4)
    battery_label.add_theme_font_size_override("font_size", 13)
    battery_bg.add_child(battery_label)

    # Subtle vignette overlay (simple dark edges)
    var vig: ColorRect = ColorRect.new()
    vig.name = "Vignette"
    vig.set_anchors_preset(Control.PRESET_FULL_RECT)
    vig.color = Color(0.0, 0.0, 0.0, 0.0)  # we animate this
    vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(vig)

    # Center crosshair (very faint)
    var cross: Label = Label.new()
    cross.text = "+"
    cross.position = Vector2(635, 355)
    cross.add_theme_font_size_override("font_size", 22)
    cross.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52, 0.25))
    cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(cross)

    # Interact prompt (bottom center, only when something is look-at-able)
    var ip: Label = Label.new()
    ip.name = "InteractPrompt"
    ip.text = ""
    ip.position = Vector2(480, 620)
    ip.add_theme_font_size_override("font_size", 17)
    ip.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82, 0.95))
    ip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(ip)

    # Location label (makes 2-3 spaces feel real)
    var loc: Label = Label.new()
    loc.name = "LocationLabel"
    loc.text = "Living Room"
    loc.position = Vector2(28, 28)
    loc.add_theme_font_size_override("font_size", 14)
    loc.add_theme_color_override("font_color", Color(0.72, 0.68, 0.6, 0.85))
    loc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(loc)

    # Toast (bottom center, driven by Player.show_toast)
    var toast: Label = Label.new()
    toast.name = "ToastLabel"
    toast.text = ""
    toast.position = Vector2(280, 560)
    toast.size = Vector2(720, 40)
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.add_theme_font_size_override("font_size", 16)
    toast.add_theme_color_override("font_color", Color(0.9, 0.82, 0.7, 0.95))
    toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast.visible = false
    hud.add_child(toast)

    # Bottom help line (fades after a while)
    var help: Label = Label.new()
    help.name = "HelpLine"
    help.text = "WASD move  |  F light  |  E examine  |  Tab/J journal  |  Esc pause  |  Click/move mouse to capture look"
    help.position = Vector2(380, 680)
    help.add_theme_font_size_override("font_size", 12)
    help.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48, 0.65))
    hud.add_child(help)

    # Auto hide help after 18 seconds
    get_tree().create_timer(18.0).timeout.connect(func():
        if is_instance_valid(help):
            var t := create_tween()
            t.tween_property(help, "modulate:a", 0.0, 1.8)
    )

    # Update loop for battery + interact prompt
    var t := Timer.new()
    t.wait_time = 0.2
    t.autostart = true
    t.timeout.connect(_update_battery_hud)
    t.timeout.connect(_update_interact_prompt_hud)
    t.timeout.connect(_update_location_hud)
    t.timeout.connect(_update_toast_hud)
    hud.add_child(t)

func _update_battery_hud() -> void:
    if not hud or not GameManager:
        return
    var lbl: Label = hud.get_node_or_null("BatteryLabel") as Label
    if not lbl: return
    var pct: int = int(GameManager.flashlight_battery * 100)
    lbl.text = "LIGHT %d%%" % pct
    if pct < 18:
        lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.25))
    elif pct < 40:
        lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
    else:
        lbl.add_theme_color_override("font_color", Color(0.82, 0.8, 0.75))

func _update_interact_prompt_hud() -> void:
    if not hud or not is_instance_valid(house_container):
        return
    var prompt_lbl: Label = hud.get_node_or_null("InteractPrompt")
    if not prompt_lbl:
        return

    var house: Node = house_container
    var p: CharacterBody3D = house.get_node_or_null("Player") as CharacterBody3D
    if not p:
        prompt_lbl.visible = false
        return

    var ray: RayCast3D = p.get_node_or_null("Head/Camera3D/InteractRay")
    if not ray or not ray.is_colliding():
        prompt_lbl.visible = false
        return

    var col: Object = ray.get_collider()
    var txt: String = ""
    if col and col.has_method("get_interact_prompt"):
        txt = col.get_interact_prompt()
    # R5: prompts live on Note/Radio/Anomaly children attached to prop bodies
    if txt == "" and col is Node:
        for child in (col as Node).get_children():
            if child.has_method("get_interact_prompt"):
                var child_txt: String = child.get_interact_prompt()
                if child_txt != "":
                    txt = child_txt
                    break
    if txt == "" and col and col.is_in_group("interactable"):
        txt = "E - Examine"
    if txt == "" and col and "door" in str(col.name).to_lower():
        if str(col.name) == "BasementDoor" and GameManager and not GameManager.has_flag("basement_unlocked"):
            txt = "E - Locked"
        else:
            txt = "E - Open"

    if txt != "":
        prompt_lbl.text = txt
        prompt_lbl.visible = true
    else:
        prompt_lbl.visible = false


func _update_location_hud() -> void:
    if not hud or not is_instance_valid(house_container):
        return
    var lbl: Label = hud.get_node_or_null("LocationLabel") as Label
    if not lbl:
        return
    var p: CharacterBody3D = house_container.get_node_or_null("Player") as CharacterBody3D
    if not p:
        return
    var pos: Vector3 = p.global_position
    var name_loc := "Living Room"
    if pos.y < -2.0:
        name_loc = "Basement"
    elif pos.x > 2.5 and pos.z > 1.2:
        name_loc = "Bedroom"
    elif pos.z < -2.2:
        name_loc = "Porch"
    lbl.text = name_loc

func _update_toast_hud() -> void:
    if not hud or not is_instance_valid(house_container):
        return
    var toast: Label = hud.get_node_or_null("ToastLabel") as Label
    if not toast:
        return
    var p: Node = house_container.get_node_or_null("Player")
    if not p or not p.has_method("show_toast"):
        toast.visible = false
        return
    var until_ms: int = int(p.get("_toast_until_ms"))
    if until_ms > Time.get_ticks_msec():
        toast.text = str(p.get("_toast_text"))
        toast.visible = toast.text != ""
    else:
        toast.visible = false

func _build_note_reader(parent: Node) -> void:
    note_reader = Control.new()
    note_reader.name = "NoteReader"
    note_reader.set_anchors_preset(Control.PRESET_FULL_RECT)
    note_reader.visible = false
    note_reader.process_mode = Node.PROCESS_MODE_ALWAYS
    parent.add_child(note_reader)

    # Dark backdrop
    var bg: ColorRect = ColorRect.new()
    bg.color = Color(0.015, 0.012, 0.018, 0.96)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    note_reader.add_child(bg)

    # Use the filled-out aged paper texture for a more physical, document-like feel (layered behind the clipboard)
    var paper := TextureRect.new()
    paper.name = "PaperBG"
    paper.set_anchors_preset(Control.PRESET_FULL_RECT)
    var pimg := Image.new()
    if pimg.load("res://assets/ui/aged_paper.jpg") == OK:
        paper.texture = ImageTexture.create_from_image(pimg)
        paper.stretch_mode = TextureRect.STRETCH_TILE
        paper.modulate = Color(0.95, 0.9, 0.82, 0.55)  # subtle tint so text stays readable
    else:
        paper.visible = false
    note_reader.add_child(paper)
    note_reader.move_child(paper, 1)  # above the solid dark bg

    # "Clipboard" panel
    var panel: PanelContainer = PanelContainer.new()
    panel.name = "PanelContainer"
    panel.position = Vector2(220, 90)
    panel.size = Vector2(840, 540)
    var pstyle: StyleBoxFlat = StyleBoxFlat.new()
    pstyle.bg_color = Color(0.07, 0.055, 0.05, 1.0)
    pstyle.border_width_left = 2
    pstyle.border_width_top = 2
    pstyle.border_width_right = 2
    pstyle.border_width_bottom = 2
    pstyle.border_color = Color(0.25, 0.22, 0.18, 1)
    panel.add_theme_stylebox_override("panel", pstyle)
    note_reader.add_child(panel)

    # Title
    var title: Label = Label.new()
    title.name = "Title"
    title.position = Vector2(40, 24)
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
    panel.add_child(title)
    note_title_label = title

    # Body text
    var body: RichTextLabel = RichTextLabel.new()
    body.name = "Body"
    body.position = Vector2(40, 70)
    body.size = Vector2(760, 360)
    body.bbcode_enabled = true
    body.scroll_active = true
    body.add_theme_font_size_override("normal_font_size", 15)
    body.add_theme_color_override("default_color", Color(0.82, 0.78, 0.72))
    panel.add_child(body)
    note_body_label = body

    # Reveal line (the gut punch)
    var reveal: RichTextLabel = RichTextLabel.new()
    reveal.name = "Reveal"
    reveal.position = Vector2(40, 440)
    reveal.size = Vector2(760, 70)
    reveal.bbcode_enabled = true
    reveal.add_theme_font_size_override("normal_font_size", 14)
    reveal.add_theme_color_override("default_color", Color(0.65, 0.55, 0.48))
    panel.add_child(reveal)
    note_reveal_label = reveal

    # Close button
    var close: Button = Button.new()
    close.text = "Close Document (E / Esc)"
    close.position = Vector2(620, 490)
    close.size = Vector2(190, 32)
    close.pressed.connect(_close_note_reader)
    panel.add_child(close)

    # Click anywhere to close too
    bg.gui_input.connect(func(ev):
        if ev is InputEventMouseButton and ev.pressed:
            _close_note_reader()
    )

func show_note_reader(title: String, lines: Array, reveal_text: String, note_id: String) -> void:
    if not note_reader:
        return

    note_reader.visible = true
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

    var tlabel: Label = note_title_label
    var body: RichTextLabel = note_body_label
    var rev: RichTextLabel = note_reveal_label

    if tlabel:
        tlabel.text = title
    if body:
        var bb := ""
        for line in lines:
            bb += line + "\n\n"
        body.text = bb.strip_edges()
    if rev:
        if reveal_text != "":
            rev.text = "[i]" + reveal_text + "[/i]"
        else:
            rev.text = ""

    # Mark as read in state
    if GameManager:
        GameManager.mark_note_read(note_id)

    # Deepen vignette a little
    _set_vignette(0.35)

    # Tiny technical polish: pop the clipboard panel in (makes reading the upgraded photo/doc assets feel physical)
    var panel: PanelContainer = note_reader.get_node_or_null("PanelContainer") as PanelContainer
    if panel:
        panel.scale = Vector2(0.92, 0.92)
        panel.modulate.a = 0.6
        var tw := create_tween()
        tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tw.tween_property(panel, "scale", Vector2(1, 1), 0.22)
        tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.18)

func _close_note_reader() -> void:
    if note_reader:
        note_reader.visible = false
    _set_vignette(0.0)
    # R4: after basement carvings, open escape-vs-fail climax choice
    if GameManager and GameManager.climax_choice_pending and GameManager.sequence_state != "end":
        show_climax_choice()
        return
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _build_journal(parent: Node) -> void:
    journal_panel = Control.new()
    journal_panel.name = "Journal"
    journal_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    journal_panel.visible = false
    parent.add_child(journal_panel)

    var bg: ColorRect = ColorRect.new()
    bg.color = Color(0.01, 0.008, 0.012, 0.94)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    journal_panel.add_child(bg)

    # Filled UI asset: journal cover / aged paper layer for the notes screen
    var cover := TextureRect.new()
    cover.name = "JournalCover"
    cover.set_anchors_preset(Control.PRESET_FULL_RECT)
    var cimg := Image.new()
    if cimg.load("res://assets/ui/journal_cover.jpg") == OK:
        cover.texture = ImageTexture.create_from_image(cimg)
        cover.stretch_mode = TextureRect.STRETCH_SCALE
        cover.modulate = Color(0.7, 0.65, 0.58, 0.35)
    else:
        cover.visible = false
    journal_panel.add_child(cover)
    journal_panel.move_child(cover, 1)

    var title: Label = Label.new()
    title.text = "YOUR NOTES â€” Property Relocation Division"
    title.position = Vector2(80, 40)
    title.add_theme_font_size_override("font_size", 20)
    journal_panel.add_child(title)

    var list: VBoxContainer = VBoxContainer.new()
    list.name = "List"
    list.position = Vector2(80, 90)
    list.size = Vector2(520, 480)
    journal_panel.add_child(list)

    var close_btn: Button = Button.new()
    close_btn.text = "Close Journal (Tab / J)"
    close_btn.position = Vector2(620, 620)
    close_btn.pressed.connect(toggle_journal)
    journal_panel.add_child(close_btn)

func toggle_journal() -> void:
    _journal_open = not _journal_open
    journal_panel.visible = _journal_open

    if _journal_open:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        _refresh_journal_list()
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _refresh_journal_list() -> void:
    if not journal_panel or not GameManager:
        return
    var list: VBoxContainer = journal_panel.get_node("List")
    if not list: return
    for c in list.get_children():
        c.queue_free()

    var ids: Array = GameManager.get_collected_note_ids()
    if ids.is_empty():
        var l: Label = Label.new()
        l.text = "No documents examined yet."
        list.add_child(l)
        return

    for id in ids:
        var data: Dictionary = GameManager.get_note_data(id)
        var btn: Button = Button.new()
        btn.text = data.get("title", id)
        btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
        btn.pressed.connect(func(): _reopen_note_from_journal(id))
        list.add_child(btn)

func _reopen_note_from_journal(note_id: String) -> void:
    var data: Dictionary = GameManager.get_note_data(note_id)
    var lines: Array = data.get("excerpts", [])
    var rev: String = data.get("reveals", "")
    if note_id == "polaroid" and GameManager.has_flag("painting_corrupted"):
        lines = [data.get("corrupted_desc", lines[0] if lines else "")]
        rev = data.get("final_reveal", rev)
    show_note_reader(data.get("title", note_id), lines, rev, note_id)
    # Hide journal underneath
    journal_panel.visible = false
    _journal_open = false

func _build_pause_menu(parent: Node) -> void:
    pause_menu = Control.new()
    pause_menu.name = "PauseMenu"
    pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
    pause_menu.visible = false
    pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
    parent.add_child(pause_menu)

    var bg: ColorRect = ColorRect.new()
    bg.color = Color(0.0, 0.0, 0.0, 0.7)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    pause_menu.add_child(bg)

    var title: Label = Label.new()
    title.text = "HOLLOW"
    title.position = Vector2(540, 220)
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
    pause_menu.add_child(title)

    var resume: Button = Button.new()
    resume.text = "Resume"
    resume.position = Vector2(540, 320)
    resume.size = Vector2(200, 42)
    resume.pressed.connect(_resume)
    pause_menu.add_child(resume)

    var reset: Button = Button.new()
    reset.text = "Restart Demo"
    reset.position = Vector2(540, 380)
    reset.size = Vector2(200, 42)
    reset.pressed.connect(_restart_demo)
    pause_menu.add_child(reset)

    var save_btn: Button = Button.new()
    save_btn.text = "Save Progress"
    save_btn.position = Vector2(540, 440)
    save_btn.size = Vector2(200, 42)
    save_btn.pressed.connect(_save_progress)
    pause_menu.add_child(save_btn)

    var quit: Button = Button.new()
    quit.text = "Quit to Menu"
    quit.position = Vector2(540, 500)
    quit.size = Vector2(200, 42)
    quit.pressed.connect(_quit_to_menu)
    pause_menu.add_child(quit)

func _build_postfx(parent: Node) -> void:
    # Full-screen tension-driven post-processing overlay.
    # Uses custom shader for film grain, breathing vignette, chromatic fringe and cold color drain.
    # This + upgraded assets + procedural audio makes the demo feel technically rich.
    postfx_rect = ColorRect.new()
    postfx_rect.name = "TensionPostFX"
    postfx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    postfx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    postfx_rect.color = Color(1, 1, 1, 1)  # shader does the real work
    parent.add_child(postfx_rect)

    postfx_mat = ShaderMaterial.new()
    postfx_mat.shader = load("res://shaders/screen_tension_postfx.gdshader")
    postfx_mat.set_shader_parameter("tension", 0.0)
    postfx_mat.set_shader_parameter("vignette_strength", 0.0)
    postfx_mat.set_shader_parameter("grain_amount", 0.32)
    postfx_rect.material = postfx_mat

func _toggle_pause() -> void:
    _is_paused = not _is_paused
    pause_menu.visible = _is_paused
    get_tree().paused = _is_paused
    if _is_paused:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _resume() -> void:
    _is_paused = false
    pause_menu.visible = false
    get_tree().paused = false
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _restart_demo() -> void:
    get_tree().paused = false
    if GameManager:
        GameManager.reset_for_new_game()
        GameManager.delete_save()
    get_tree().reload_current_scene()

func _quit_to_menu() -> void:
    get_tree().paused = false
    _save_progress()
    get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        if note_reader and note_reader.visible:
            _close_note_reader()
        elif _journal_open:
            toggle_journal()
        else:
            _toggle_pause()
        get_viewport().set_input_as_handled()

func _on_note_collected_for_hud(_id: String, _title: String) -> void:
    # Subtle feedback
    if hud:
        var v: ColorRect = hud.get_node_or_null("Vignette")
        if v:
            var tw: Tween = create_tween()
            tw.tween_property(v, "color:a", 0.22, 0.15)
            tw.tween_property(v, "color:a", 0.0, 1.4)

func _on_tension_changed(new_t: float) -> void:
    _current_tension = clamp(new_t, 0.0, 1.0)
    if postfx_mat:
        postfx_mat.set_shader_parameter("tension", _current_tension)
        # Grain and vignette breathe with dread
        postfx_mat.set_shader_parameter("grain_amount", 0.28 + _current_tension * 0.38)
        postfx_mat.set_shader_parameter("vignette_strength", _current_tension * 0.55)

func _set_vignette(alpha: float) -> void:
    if not hud: return
    var v: ColorRect = hud.get_node_or_null("Vignette")
    if v:
        v.color.a = alpha
    # Also push a bit into the postfx overlay for unified tech look
    if postfx_mat:
        postfx_mat.set_shader_parameter("vignette_strength", max(postfx_mat.get_shader_parameter("vignette_strength"), alpha * 0.7))

func _on_demo_ended(reason: String) -> void:
    # Let the end sequence play out, then show final card
    var delay := 3.2
    if reason == "escaped":
        delay = 4.0
    elif reason == "caught":
        delay = 3.6
    get_tree().create_timer(delay).timeout.connect(func():
        _show_final_screen(reason)
    )

func play_end_sequence() -> void:
    # Claimed path — overwhelming takeover.
    if AudioManager:
        AudioManager.play_end_sequence()

    if GameManager:
        GameManager.set_tension(1.0)
    if postfx_mat:
        postfx_mat.set_shader_parameter("tension", 1.0)
        postfx_mat.set_shader_parameter("grain_amount", 0.7)
        postfx_mat.set_shader_parameter("vignette_strength", 0.95)

    var house: Node = get_node_or_null("House")
    if house:
        for light in house.get_children():
            if light is Light3D and light.name != "TheThreshold":
                var tw: Tween = create_tween()
                tw.tween_property(light, "light_energy", 0.0, 1.2 + randf() * 0.8)

    if house:
        var p := house.get_node_or_null("Player") as CharacterBody3D
        if p:
            var tw2 := create_tween()
            tw2.tween_property(p, "rotation_degrees:y", p.rotation_degrees.y + 6.0, 4.5)
            if p.has_method("set_flashlight_battery"):
                p.set_flashlight_battery(0.0)

func play_escape_sequence() -> void:
    # Escape path — lights surge, front door yawns open, battery holds a last breath.
    if AudioManager:
        AudioManager.play_whisper_swell(1.4)
        AudioManager.play_door_close()
    if GameManager:
        GameManager.set_tension(0.55)
    if postfx_mat:
        postfx_mat.set_shader_parameter("tension", 0.45)
        postfx_mat.set_shader_parameter("grain_amount", 0.35)
        postfx_mat.set_shader_parameter("vignette_strength", 0.35)

    var house: Node = get_node_or_null("House")
    if house:
        var fd = house.get_node_or_null("FrontDoor")
        if fd:
            var tw := create_tween()
            tw.tween_property(fd, "rotation_degrees:y", -72.0, 1.1).set_trans(Tween.TRANS_SINE)
        var p := house.get_node_or_null("Player") as CharacterBody3D
        if p:
            # Nudge toward porch
            var twp := create_tween()
            twp.tween_property(p, "global_position", Vector3(-0.1, 0.01, -2.35), 2.4).set_trans(Tween.TRANS_SINE)
            if p.has_method("show_toast"):
                p.show_toast("Cold air. Gravel. The porch is still there.")

func play_caught_sequence() -> void:
    # Caught path — fake escape then hallway snap-back.
    if AudioManager:
        AudioManager.play_anomaly_pulse()
        AudioManager.static_volume = 0.7
    if GameManager:
        GameManager.set_tension(0.95)
    if postfx_mat:
        postfx_mat.set_shader_parameter("tension", 0.9)
        postfx_mat.set_shader_parameter("grain_amount", 0.65)
        postfx_mat.set_shader_parameter("vignette_strength", 0.9)

    var house: Node = get_node_or_null("House")
    if house:
        var fd = house.get_node_or_null("FrontDoor")
        if fd:
            # Door opens then violently shuts / spins wrong
            var tw := create_tween()
            tw.tween_property(fd, "rotation_degrees:y", -50.0, 0.45)
            tw.tween_property(fd, "rotation_degrees:y", 8.0, 0.55)
        var p := house.get_node_or_null("Player") as CharacterBody3D
        if p:
            var twp := create_tween()
            twp.tween_property(p, "global_position", Vector3(-0.2, 0.01, -1.2), 1.6)
            if p.has_method("set_flashlight_battery"):
                p.set_flashlight_battery(0.05)
            if p.has_method("show_toast"):
                p.show_toast("The porch was gone. Only the hallway.")

func show_climax_choice() -> void:
    if _climax_resolving:
        return
    if climax_panel and is_instance_valid(climax_panel):
        climax_panel.visible = true
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        return

    var ui = get_node_or_null("UILayer")
    var parent: Node = ui if ui else self
    climax_panel = Control.new()
    climax_panel.name = "ClimaxChoice"
    climax_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    climax_panel.process_mode = Node.PROCESS_MODE_ALWAYS
    parent.add_child(climax_panel)

    var dim := ColorRect.new()
    dim.color = Color(0.0, 0.0, 0.0, 0.78)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    climax_panel.add_child(dim)

    var card := PanelContainer.new()
    card.position = Vector2(340, 180)
    card.size = Vector2(600, 360)
    var st := StyleBoxFlat.new()
    st.bg_color = Color(0.04, 0.035, 0.04, 0.96)
    st.border_color = Color(0.35, 0.28, 0.25, 0.85)
    st.border_width_left = 1
    st.border_width_right = 1
    st.border_width_top = 1
    st.border_width_bottom = 1
    st.content_margin_left = 28
    st.content_margin_right = 28
    st.content_margin_top = 24
    st.content_margin_bottom = 24
    card.add_theme_stylebox_override("panel", st)
    climax_panel.add_child(card)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 14)
    card.add_child(vbox)

    var title := Label.new()
    title.text = "THE THRESHOLD"
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color(0.72, 0.62, 0.52))
    vbox.add_child(title)

    var body := RichTextLabel.new()
    body.bbcode_enabled = true
    body.fit_content = true
    body.custom_minimum_size = Vector2(520, 110)
    var tip := "You have read the carvings. The water waits."
    if GameManager and GameManager.can_attempt_escape():
        tip = "You catalogued everything upstairs. The house has fewer lies left.\nYou might still leave — if you refuse the water."
    else:
        tip = "Something upstairs is still unread. Running now is a guess.\nThe house loves guesses."
    body.text = tip
    body.add_theme_color_override("default_color", Color(0.75, 0.72, 0.68))
    vbox.add_child(body)

    var step_btn := Button.new()
    step_btn.text = "Step into the water"
    step_btn.pressed.connect(func(): _resolve_climax_choice("step"))
    vbox.add_child(step_btn)

    var refuse_btn := Button.new()
    refuse_btn.text = "Refuse — run for the door"
    refuse_btn.pressed.connect(func(): _resolve_climax_choice("refuse"))
    vbox.add_child(refuse_btn)

    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    print("[Main] Climax choice offered (escape_ready=%s)." % str(GameManager.can_attempt_escape() if GameManager else false))

func _resolve_climax_choice(choice: String) -> void:
    if _climax_resolving:
        return
    _climax_resolving = true
    if climax_panel and is_instance_valid(climax_panel):
        climax_panel.visible = false
    if not GameManager:
        return
    GameManager.climax_choice_pending = false
    var ending: String = GameManager.resolve_climax_choice(choice)
    match ending:
        "escaped":
            play_escape_sequence()
        "caught":
            play_caught_sequence()
        _:
            play_end_sequence()
    print("[Main] Climax resolved -> %s" % ending)

func _show_final_screen(reason: String) -> void:
    # Avoid stacking
    var ui = get_node_or_null("UILayer")
    if ui and ui.get_node_or_null("EndScreen"):
        return

    var card_data: Dictionary = {}
    if GameManager and GameManager.has_method("get_ending_card"):
        card_data = GameManager.get_ending_card(reason)
    else:
        card_data = {"badge": "END", "title": "PROPERTY TRANSFERRED", "body": "Demo over.", "outcome": "fail"}

    var end: Control = Control.new()
    end.name = "EndScreen"
    end.set_anchors_preset(Control.PRESET_FULL_RECT)
    if ui:
        ui.add_child(end)
    else:
        add_child(end)

    var bg: ColorRect = ColorRect.new()
    bg.color = Color(0.0, 0.0, 0.0, 1.0)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    end.add_child(bg)

    var badge: Label = Label.new()
    badge.text = str(card_data.get("badge", "END"))
    badge.position = Vector2(420, 200)
    badge.add_theme_font_size_override("font_size", 16)
    var outcome := str(card_data.get("outcome", "fail"))
    if outcome == "escape":
        badge.add_theme_color_override("font_color", Color(0.55, 0.75, 0.62))
    else:
        badge.add_theme_color_override("font_color", Color(0.75, 0.35, 0.32))
    end.add_child(badge)

    var title: Label = Label.new()
    title.text = str(card_data.get("title", "PROPERTY TRANSFERRED"))
    title.position = Vector2(420, 240)
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
    end.add_child(title)

    var sub: RichTextLabel = RichTextLabel.new()
    sub.bbcode_enabled = true
    sub.text = str(card_data.get("body", ""))
    sub.position = Vector2(380, 300)
    sub.size = Vector2(560, 220)
    end.add_child(sub)

    # Run stats
    var stats := Label.new()
    var notes_n := 0
    var t_min := 0.0
    var tens := 0.0
    if GameManager:
        notes_n = GameManager.collected_notes.size()
        t_min = GameManager.time_in_house / 60.0
        tens = GameManager.tension
    stats.text = "Documents %d  |  Time %.1f min  |  Tension %.0f%%  |  Ending %s" % [notes_n, t_min, tens * 100.0, reason]
    stats.position = Vector2(380, 520)
    stats.add_theme_font_size_override("font_size", 12)
    stats.add_theme_color_override("font_color", Color(0.45, 0.42, 0.4))
    end.add_child(stats)

    var again: Button = Button.new()
    again.text = "Return to Menu"
    again.position = Vector2(520, 560)
    again.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
    end.add_child(again)

    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
func _apply_continue_state() -> void:
    if not GameManager or not GameManager.pending_continue:
        return
    var house: Node = house_container
    if house and house.has_method("apply_save_state"):
        house.apply_save_state()
    if GameManager:
        GameManager.tension_changed.emit(GameManager.tension)
    GameManager.pending_continue = false
    print("[Main] Continue state applied.")

func _save_progress() -> void:
    if not GameManager:
        return
    GameManager.world = house_container
    if house_container and house_container.has_node("Player"):
        GameManager.player = house_container.get_node("Player")
    GameManager.auto_save_from_player()
    if GameManager.player and GameManager.player.has_method("show_toast"):
        GameManager.player.show_toast("Progress recorded.")
    print("[Main] Manual save requested.")

