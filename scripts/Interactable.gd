class_name Interactable
extends Node3D
# Base class for all examinable objects in HOLLOW.
# Provides hover highlight, prompt, and a virtual interact().

# warning-ignore-all:inferred_declaration

@export var prompt_text: String = "E — Examine"
@export var one_shot: bool = false
@export var highlight_color: Color = Color(0.95, 0.9, 0.7, 1.0)

var _original_materials: Array = []
var _highlighted: bool = false
var _used: bool = false

func _ready() -> void:
    # Collect meshes under us for highlighting
    _cache_materials()

func _cache_materials() -> void:
    _original_materials.clear()
    for child in get_children():
        if child is MeshInstance3D:
            for i in child.get_surface_override_material_count():
                var mat: Material = child.get_surface_override_material(i)
                if mat:
                    _original_materials.append({"mesh": child, "index": i, "mat": mat})

func get_interact_prompt() -> String:
    if one_shot and _used:
        return ""
    return prompt_text

func interact(_player: Node) -> void:
    if one_shot and _used:
        return
    _used = true
    _on_interact(_player)
    if one_shot:
        _remove_highlight()

func _on_interact(_player: Node) -> void:
    # Override in subclasses
    push_warning("Interactable %s has no _on_interact implementation" % name)

func highlight(on: bool) -> void:
    if _highlighted == on:
        return
    _highlighted = on
    if on:
        _apply_highlight()
    else:
        _remove_highlight()

func _apply_highlight() -> void:
    for entry in _original_materials:
        var mi: MeshInstance3D = entry.mesh
        var idx: int = entry.index
        var base: Material = entry.mat
        if base is StandardMaterial3D:
            var h := base.duplicate() as StandardMaterial3D
            h.emission_enabled = true
            h.emission = highlight_color * 0.6
            h.emission_energy_multiplier = 0.8
            mi.set_surface_override_material(idx, h)

func _remove_highlight() -> void:
    for entry in _original_materials:
        var mi: MeshInstance3D = entry.mesh
        var idx: int = entry.index
        mi.set_surface_override_material(idx, entry.mat)
    _highlighted = false
