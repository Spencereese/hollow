extends Interactable
# Anomaly - The black water / threshold in the basement. The point of no return.
# R4: routes through climax choice (escape vs fail) instead of auto-ending.

@warning_ignore("inferred_declaration")

@export var prompt_text: String = "E — Reach into the water"

var _activated: bool = false

func _ready() -> void:
	super._ready()
	one_shot = true

func _on_interact(_player: Node) -> void:
	if _activated:
		return
	if GameManager and GameManager.sequence_state == "end":
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
