extends Interactable
# HatchInteractable - Climb / descend between bedroom and attic (R6).
# Teleports the player to a destination; keeps collision geometry simple.

@export var destination: Vector3 = Vector3(3.4, 3.75, 2.1)
@export var toast_on_use: String = "Dust. Heat. The boards remember every footfall."
@export var set_flag_on_use: String = ""

func _ready() -> void:
    super._ready()
    if prompt_text == "" or prompt_text.begins_with("E — Examine") or prompt_text.begins_with("E - Examine"):
        prompt_text = "E - Climb hatch"

func _on_interact(player: Node) -> void:
    # Allow re-use (not one-shot) so player can go up and down repeatedly.
    _used = false
    if player and player is Node3D:
        (player as Node3D).global_position = destination
        if "velocity" in player:
            player.velocity = Vector3.ZERO
    if set_flag_on_use != "" and GameManager:
        GameManager.set_flag(set_flag_on_use)
        GameManager.adjust_tension(0.04)
        GameManager.auto_save_from_player()
    if player and player.has_method("show_toast"):
        player.show_toast(toast_on_use)
    if AudioManager:
        AudioManager.play_creak(0.75)
