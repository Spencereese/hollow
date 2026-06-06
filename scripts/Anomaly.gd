extends Interactable
# Anomaly - The black water / threshold in the basement. The point of no return.

@warning_ignore("inferred_declaration")

@export var prompt_text: String = "E — Reach into the water"

var _activated: bool = false

func _ready() -> void:
    super._ready()
    one_shot = true

func _on_interact(_player: Node) -> void:
    if _activated:
        return
    _activated = true

    var main: Node = get_tree().current_scene
    if GameManager:
        GameManager.collect_note("basement_note", "Carvings")
        GameManager.enter_basement()
        GameManager.trigger_end("threshold")

    if main and main.has_method("play_end_sequence"):
        main.play_end_sequence()
    elif AudioManager:
        AudioManager.play_end_sequence()

    # Dramatic: kill the flashlight
    if _player and _player.has_method("set_flashlight_battery"):
        _player.set_flashlight_battery(0.0)

    # The world will fade / show the final text
