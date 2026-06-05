extends CharacterBody3D
# Player - First-person controller for HOLLOW.
# Mouse look (captured), WASD + sprint, head bob, lean, flashlight with battery + flicker.
# Interaction via RayCast + E. All input actions defined in project.godot.

# Relax strict inference warnings for this prototype (local vars in process/update)
# warning-ignore-all:inferred_declaration
# warning-ignore-all:unsafe_method_access

@export var walk_speed: float = 3.2
@export var sprint_speed: float = 5.1
@export var acceleration: float = 18.0
@export var friction: float = 12.0
@export var mouse_sens: float = 0.0022
@export var bob_freq: float = 1.65
@export var bob_amp: float = 0.028

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
# interact prompt is now handled by the 2D HUD in Main.gd (via CanvasLayer)

var _mouse_captured: bool = false
var _head_bob_time: float = 0.0
var _base_camera_y: float = 0.0
var _current_speed: float = 0.0

# Flashlight state (synced with GameManager)
var flashlight_on: bool = true
var _flicker_timer: float = 0.0
var _flicker_target: float = 1.0

# Interaction
var _last_interact_target: Node = null

func _ready() -> void:
    print("[Player] _ready() entered. camera node: ", camera != null, " ray: ", ray != null, " flashlight: ", flashlight != null)
    if camera:
        print("[Player] camera.current before force: ", camera.current)
        camera.current = true
        print("[Player] camera.current forced to true")

    # On macOS (and often other platforms), forcing CAPTURED immediately in _ready frequently fails to grab the cursor
    # until the user has clicked inside the game window. Start with visible mouse; we'll capture on first click.
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    _mouse_captured = false
    print("[Player] Mouse starts VISIBLE (macOS-friendly). Click or move mouse inside the 3D view to capture for looking around.")

    if camera:
        _base_camera_y = camera.position.y
    else:
        print("[Player] WARNING: camera is null in _ready!")

    # Connect to GameManager for battery etc.
    if GameManager:
        GameManager.flashlight_battery = 1.0
        GameManager.has_flashlight = true

    # Initial flashlight (full power at spawn) - stronger for demo visibility
    if flashlight:
        flashlight.visible = flashlight_on
        flashlight.light_energy = 4.5
        flashlight.spot_range = 12.0
        flashlight.spot_angle = 42.0
        flashlight.shadow_enabled = true

    # Make sure ray is set up (length ~3.5m for intimate space)
    if ray:
        ray.target_position = Vector3(0, 0, -3.8)
        ray.collision_mask = 1 | 2  # walls + interactables

    print("[Player] Ready. Mouse starts visible — click or move mouse in the 3D view to capture for looking. F toggles light, E interacts.")

func _unhandled_input(event: InputEvent) -> void:
    # Click-to-capture (or motion) for mouse look — required on macOS for reliable cursor grab.
    if not _mouse_captured:
        if (event is InputEventMouseButton and event.pressed) or event is InputEventMouseMotion:
            capture_mouse(true)
            if event is InputEventMouseButton:
                get_viewport().set_input_as_handled()
            return

    if event is InputEventMouseMotion and _mouse_captured:
        rotate_y(-event.relative.x * mouse_sens)
        head.rotate_x(-event.relative.y * mouse_sens)
        head.rotation.x = clamp(head.rotation.x, deg_to_rad(-88), deg_to_rad(88))

    if event.is_action_pressed("flashlight"):
        toggle_flashlight()

    if event.is_action_pressed("interact"):
        _try_interact()

    if event.is_action_pressed("pause"):
        _toggle_pause()

    if event.is_action_pressed("journal"):
        _toggle_journal()

func _physics_process(delta: float) -> void:
    if not _mouse_captured:
        return

    var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var wish_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

    var is_sprinting: bool = Input.is_action_pressed("sprint") and input_dir.length() > 0.1
    var target_speed: float = sprint_speed if is_sprinting else walk_speed

    if wish_dir.length() > 0.01:
        _current_speed = move_toward(_current_speed, target_speed, acceleration * delta)
        velocity.x = wish_dir.x * _current_speed
        velocity.z = wish_dir.z * _current_speed
    else:
        _current_speed = move_toward(_current_speed, 0.0, friction * delta)
        velocity.x = move_toward(velocity.x, 0.0, friction * delta)
        velocity.z = move_toward(velocity.z, 0.0, friction * delta)

    # Gravity is 0 in project (walking sim), but keep for future
    if not is_on_floor():
        velocity.y -= 9.8 * delta * 0.6  # very light for "weight"

    move_and_slide()

    _update_headbob(delta, input_dir.length() > 0.1, is_sprinting)
    _update_flashlight(delta, is_sprinting)
    _update_interact_prompt()
    _update_tension_audio()

func _update_headbob(delta: float, is_moving: bool, sprinting: bool) -> void:
    if not is_moving:
        _head_bob_time = 0.0
        camera.position.y = lerp(camera.position.y, _base_camera_y, 8.0 * delta)
        return

    var freq: float = bob_freq * (1.35 if sprinting else 1.0)
    _head_bob_time += delta * freq
    var bob: float = sin(_head_bob_time) * bob_amp * (1.0 if not sprinting else 1.35)
    camera.position.y = _base_camera_y + bob

    # Very subtle roll lean on strafe (adds realism)
    var strafe: float = Input.get_axis("move_left", "move_right")
    camera.rotation.z = lerp(camera.rotation.z, -strafe * 0.018, 6.0 * delta)

func _update_flashlight(delta: float, sprinting: bool) -> void:
    if not GameManager or not GameManager.has_flashlight:
        flashlight.visible = false
        return

    # Drain battery slowly when on + faster when sprinting in dark
    if flashlight_on:
        var drain: float = 0.012 * delta
        if sprinting:
            drain *= 1.6
        GameManager.flashlight_battery = max(0.0, GameManager.flashlight_battery - drain)

    # Flicker when low
    _flicker_timer -= delta
    if GameManager.flashlight_battery < 0.22 and _flicker_timer <= 0.0:
        _flicker_timer = 0.06 + randf() * 0.09
        _flicker_target = 0.15 + randf() * 0.6 if randf() > 0.3 else 1.0

    var target_energy: float = 1.9 if flashlight_on else 0.0
    if GameManager.flashlight_battery < 0.18:
        target_energy *= _flicker_target
    elif GameManager.flashlight_battery < 0.08:
        target_energy *= 0.15  # almost dead

    flashlight.light_energy = lerp(flashlight.light_energy, target_energy, 22.0 * delta)
    flashlight.visible = flashlight.light_energy > 0.05

    # Range and angle also decay for "realism"
    flashlight.spot_range = lerp(7.5, 4.2, 1.0 - GameManager.flashlight_battery)
    flashlight.spot_angle = lerp(38.0, 22.0, 1.0 - GameManager.flashlight_battery * 0.6)

    # Sync global
    GameManager.flashlight_battery = GameManager.flashlight_battery

    # Low battery tension
    if GameManager.flashlight_battery < 0.15 and GameManager.tension < 0.6:
        GameManager.adjust_tension(0.03 * delta)

func toggle_flashlight() -> void:
    if not GameManager or not GameManager.has_flashlight or GameManager.flashlight_battery < 0.02:
        return
    flashlight_on = not flashlight_on
    if AudioManager:
        AudioManager.play_flashlight_click(flashlight_on)
    if not flashlight_on:
        GameManager.adjust_tension(0.04)  # turning it off increases dread slightly

func _try_interact() -> void:
    if not ray or not ray.is_colliding():
        return
    var collider: Object = ray.get_collider()
    if not collider:
        return

    # Prefer explicit interactable scripts
    if collider.has_method("interact"):
        collider.interact(self)
        return

    # Fallback: parent or group
    var parent: Node = collider.get_parent()
    if parent and parent.has_method("interact"):
        parent.interact(self)
        return

    # If collider in group "interactable", find the interactable node (may be parent if collider is the Area child)
    if collider.is_in_group("interactable"):
        var interact_node: Node = collider
        if not interact_node.has_method("interact"):
            interact_node = collider.get_parent()
        if interact_node and interact_node.has_method("interact"):
            interact_node.interact(self)
            return
        # fallback to old find child
        var note: Node = collider.find_child("NoteInteractable", true, false)
        if note and note.has_method("interact"):
            note.interact(self)
            return

    # Fallback for plain visual props created in House (the ones that used to be Note/Radio/Anomaly instances)
    var nm: String = str(collider.name)
    if nm in ["Polaroid", "IntakeForm", "VoiceRecorder", "Letter", "Radio", "TheThreshold"]:
        var nid: String = ""
        if nm == "Polaroid": nid = "polaroid"
        elif nm == "IntakeForm": nid = "intake_form"
        elif nm == "VoiceRecorder": nid = "recorder"
        elif nm == "Letter": nid = "letter"
        elif nm == "Radio": nid = "recorder"
        elif nm == "TheThreshold": nid = "basement_note"
        if nid != "" and GameManager:
            var data: Dictionary = GameManager.get_note_data(nid)
            GameManager.collect_note(nid, data.get("title", nm))
            var ms: Node = get_tree().current_scene
            if ms and ms.has_method("show_note_reader"):
                var t: String = data.get("title", nm)
                var lines: Array = data.get("excerpts", [])
                var rev: String = data.get("reveals", "")
                if nm == "Polaroid" and GameManager.has_flag("painting_corrupted"):
                    if data.has("corrupted_desc"):
                        lines = [data.get("corrupted_desc")]
                    if data.has("final_reveal"):
                        rev = data.get("final_reveal", rev)
                ms.show_note_reader(t, lines, rev, nid)
        return

    # Doors: simple "open" interaction (rotate the visual body)
    if "door" in nm.to_lower():
        collider.rotation_degrees.y += 55.0
        if AudioManager:
            AudioManager.play_creak(0.6)
        return

func _update_interact_prompt() -> void:
    # Prompt display is handled by Main HUD (see Main.gd). We only compute for potential future use.
    if not ray:
        return
    if not ray.is_colliding():
        _last_interact_target = null
        return
    var col: Object = ray.get_collider()
    if col == _last_interact_target:
        return
    _last_interact_target = col
    # The actual label update happens in the 2D HUD layer for correct rendering.

func _update_tension_audio() -> void:
    if AudioManager:
        AudioManager.set_tension(GameManager.tension if GameManager else 0.0)

func _toggle_pause() -> void:
    # Simple pause: release mouse and show menu or just free look for now.
    # Full pause menu is in Main scene.
    if _mouse_captured:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        _mouse_captured = false
        if get_tree():
            get_tree().paused = true
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        _mouse_captured = true
        if get_tree():
            get_tree().paused = false

func _toggle_journal() -> void:
    # The Main scene listens for this or we call a global.
    # For simplicity we emit or find the journal.
    var main: Node = get_tree().current_scene
    if main and main.has_method("toggle_journal"):
        main.toggle_journal()
    elif main and main.has_node("Journal"):
        var j: Node = main.get_node("Journal")
        j.visible = not j.visible
        if j.visible:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
            _mouse_captured = false
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            _mouse_captured = true

func capture_mouse(capture: bool) -> void:
    _mouse_captured = capture
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE)

func set_flashlight_battery(value: float) -> void:
    if GameManager:
        GameManager.flashlight_battery = clamp(value, 0.0, 1.0)
