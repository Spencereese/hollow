extends Interactable
# Anomaly - The black water / threshold in the basement. The point of no return.
# R4: routes through climax choice (escape vs fail) instead of auto-ending.
# R5: live-wired from House as child of TheThreshold.

@warning_ignore("inferred_declaration")

var _activated: bool = false

func _ready() -> void:
    super._ready()
    prompt_text = "E - Reach into the water"
    one_shot = true
    if GameManager and GameManager.is_note_collected("basement_note"):
        _activated = true
        prompt_text = ""

func _on_interact(_player: Node) -> void:
    if _activated:
        return
    if GameManager and GameManager.sequence_state == "end":
        return
    if GameManager and GameManager.is_note_collected("basement_note"):
        _activated = true
        if GameManager.climax_choice_pending:
            var main_pending: Node = get_tree().current_scene
            if main_pending and main_pending.has_method("show_climax_choice"):
                main_pending.show_climax_choice()
        return
    _activated = true

    var main: Node = get_tree().current_scene
    if GameManager:
        var data: Dictionary = GameManager.get_note_data("basement_note")
        GameManager.collect_note("basement_note", data.get("title", "Carvings"))
        GameManager.enter_basement()
        GameManager.climax_choice_pending = true
        if main and main.has_method("show_note_reader"):
            main.show_note_reader(
                data.get("title", "Carvings"),
                data.get("excerpts", []),
                data.get("reveals", ""),
                "basement_note"
            )

    if _player and _player.has_method("show_toast"):
        _player.show_toast("The water does not reflect you anymore.")
