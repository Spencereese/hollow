extends Interactable
# NoteInteractable - Physical object that opens the document reader when examined.
# Uses data/notes.json via GameManager. Supports "corrupted" state for some notes.
# R5: live-wired from House onto discovery props.

@warning_ignore("inferred_declaration")

@export var note_id: String = "intake_form"
@export var initial_prompt: String = "E - Read document"
@export var requires_flag: String = ""  # optional gate

var _corrupted: bool = false

func _ready() -> void:
    super._ready()
    prompt_text = initial_prompt
    if note_id == "polaroid" or note_id == "painting":
        # We will flip this from outside when GameManager sets the flag
        pass

func _on_interact(player: Node) -> void:
    if requires_flag != "" and GameManager and not GameManager.has_flag(requires_flag):
        # Soft gate - show a different message via the world
        if player and player.has_method("show_toast"):
            player.show_toast("It won't open yet. Something is missing.")
        return

    var data: Dictionary = {}
    if GameManager:
        data = GameManager.get_note_data(note_id)
        GameManager.collect_note(note_id, data.get("title", note_id))

    var title: String = data.get("title", "Document")
    var body_lines: Array = data.get("excerpts", ["The page is blank."])
    var reveal: String = data.get("reveals", "")
    if _corrupted and data.has("corrupted_desc"):
        body_lines = [data.get("corrupted_desc")]
    if note_id == "polaroid" and GameManager and GameManager.has_flag("painting_corrupted"):
        body_lines = [data.get("corrupted_desc", body_lines[0] if body_lines.size() > 0 else "")]
        if data.has("final_reveal"):
            reveal = data.get("final_reveal")

    # Find the main scene's reader
    var main: Node = get_tree().current_scene
    if main and main.has_method("show_note_reader"):
        main.show_note_reader(title, body_lines, reveal, note_id)
    else:
        print("[Note] %s: %s" % [title, body_lines])

    if AudioManager:
        AudioManager.play_note_page()

func set_corrupted(corrupted: bool) -> void:
    _corrupted = corrupted
    if corrupted:
        prompt_text = "E - Examine (something is wrong with this)"
        # Darken or tint the visual prop if it has a mesh
        for child in get_children():
            if child is MeshInstance3D:
                for i in child.get_surface_override_material_count():
                    var m: StandardMaterial3D = child.get_surface_override_material(i) as StandardMaterial3D
                    if m:
                        m.albedo_color = m.albedo_color.lerp(Color(0.15, 0.12, 0.18), 0.7)
