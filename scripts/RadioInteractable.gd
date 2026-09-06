extends Interactable
# RadioInteractable - The old tube radio that delivers one of the strongest narrative beats.
# R5: live-wired from House; radio_on flag keeps Continue from replaying first listen.

@warning_ignore("inferred_declaration")

@export var note_id: String = "recorder"  # we reuse the recorder text block for the broadcast

var _has_played: bool = false

func _ready() -> void:
    super._ready()
    prompt_text = "E - Turn on the radio"
    if GameManager and GameManager.has_flag("radio_on"):
        _has_played = true
        prompt_text = "E - The radio is warm"

func _on_interact(_player: Node) -> void:
    if GameManager and GameManager.has_flag("radio_on"):
        _has_played = true
    if _has_played:
        # Second interact: it is now just hissing
        if GameManager:
            GameManager.adjust_tension(0.05)
        AudioManager.set_tension(0.75) if AudioManager else null
        if _player and _player.has_method("show_toast"):
            _player.show_toast("The radio is only hissing now.")
        return

    _has_played = true
    prompt_text = "E - The radio is warm"

    if GameManager:
        GameManager.set_flag("radio_on")
        var data: Dictionary = GameManager.get_note_data(note_id)
        GameManager.collect_note(note_id, data.get("title", "Broadcast"))

        var main: Node = get_tree().current_scene
        if main and main.has_method("show_note_reader"):
            var lines: Array = data.get("excerpts", [])
            main.show_note_reader("AM Band - 193 kHz (bleeding through)", lines, data.get("reveals", ""), note_id)

    # Audio: big static swell then "voice"
    if AudioManager:
        AudioManager.static_volume = 0.6
        AudioManager.play_whisper_swell(2.4)
        get_tree().create_timer(3.2).timeout.connect(func():
            if AudioManager: AudioManager.play_anomaly_pulse()
        )

    # Increase dread
    if GameManager:
        GameManager.adjust_tension(0.25)
        GameManager.set_flag("heard_the_list")
