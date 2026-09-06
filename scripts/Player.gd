extends CharacterBody3D
# Player - First-person controller for HOLLOW.
# Mouse look (captured), WASD + sprint, head bob, lean, flashlight with battery + flicker.
# Interaction via RayCast + E. All input actions defined in project.godot.

# Relax strict inference warnings for this prototype (local vars in process/update)
@warning_ignore("inferred_declaration")
@warning_ignore("unsafe_method_access")

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
var _toast_text: String = ""
var _toast_until_ms: int = 0

# First-person viewmodel (the big technical immersion upgrade)
var _viewmodel: Node3D
var _vm_sway_time: float = 0.0
var _vm_reach_target: float = 0.0
var _vm_flash_rot_target: float = 0.0

func _ready() -> void:
    print("[Player] _ready() entered. camera node: ", camera != null, " ray: ", ray != null, " flashlight: ", flashlight != null)
    if camera:
        print("[Player] camera.current before force: ", camera.current)
        camera.current = true
        print("[Player] camera.current forced to true")

    # Build the first-person viewmodel (hands + grip). This + shaders + upgraded assets = technically impressive.
    _build_viewmodel()
    _attach_flashlight_particles()  # godray dust in the beam â€” huge technical + atmosphere win

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
        GameManager.has_flashlight = true
        if not GameManager.pending_continue:
            GameManager.flashlight_battery = 1.0

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

    print("[Player] Ready. Mouse starts visible â€” click or move mouse in the 3D view to capture for looking. F toggles light, E interacts.")

func _unhandled_input(event: InputEvent) -> void:
    # Click-to-capture (or motion) for mouse look â€” required on macOS for reliable cursor grab.
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
        _trigger_vm_reach()

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
    _update_viewmodel_sway(delta, input_dir.length() > 0.01, is_sprinting, flashlight_on)

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

    # Keep beam dust in sync (the real technical volumetric touch)
    var beam := flashlight.get_node_or_null("BeamDust") as GPUParticles3D
    if beam:
        beam.emitting = flashlight_on and GameManager.flashlight_battery > 0.04
        if beam.emitting:
            beam.amount = int(lerp(28, 85, GameManager.flashlight_battery))

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
    _trigger_vm_flash_toggle()  # hand reacts to the click

func _try_interact() -> void:
    if not ray or not ray.is_colliding():
        return
    var collider: Object = ray.get_collider()
    if not collider:
        return

    _trigger_vm_reach()

    # Prefer explicit interactable scripts
    if collider.has_method("interact"):
        collider.interact(self)
        return

    # Fallback: parent or group
    var parent: Node = collider.get_parent()
    if parent and parent.has_method("interact"):
        parent.interact(self)
        return

    # If collider in group "interactable", find the interactable node
    if collider.is_in_group("interactable"):
        var interact_node: Node = collider
        if not interact_node.has_method("interact"):
            interact_node = collider.get_parent()
        if interact_node and interact_node.has_method("interact"):
            interact_node.interact(self)
            return
        var note: Node = collider.find_child("NoteInteractable", true, false)
        if note and note.has_method("interact"):
            note.interact(self)
            return

    # Fallback for plain visual props created in House
    var nm: String = str(collider.name)
    if nm in ["Polaroid", "IntakeForm", "VoiceRecorder", "Letter", "Radio", "TheThreshold"]:
        # === THRESHOLD CLIMAX (R4: escape-vs-fail choice) ===
        if nm == "TheThreshold":
            if GameManager and GameManager.sequence_state == "end":
                return
            var data_t: Dictionary = {}
            if GameManager:
                data_t = GameManager.get_note_data("basement_note")
                GameManager.collect_note("basement_note", data_t.get("title", "Carvings"))
                GameManager.enter_basement()
                GameManager.climax_choice_pending = true
            var ms_t: Node = get_tree().current_scene
            if ms_t and ms_t.has_method("show_note_reader"):
                ms_t.show_note_reader(
                    data_t.get("title", "Carvings"),
                    data_t.get("excerpts", []),
                    data_t.get("reveals", ""),
                    "basement_note"
                )
            # Do not auto-end — closing the carvings opens the climax choice.
            show_toast("The water does not reflect you anymore.")
            return

        # === RADIO (match RadioInteractable intent) ===
        if nm == "Radio":
            var data_r: Dictionary = {}
            if GameManager:
                if GameManager.has_flag("radio_on"):
                    GameManager.adjust_tension(0.05)
                    if AudioManager:
                        AudioManager.set_tension(0.75)
                    show_toast("The radio is only hissing now.")
                    return
                GameManager.set_flag("radio_on")
                data_r = GameManager.get_note_data("recorder")
                GameManager.collect_note("recorder", data_r.get("title", "Broadcast"))
                GameManager.adjust_tension(0.25)
                GameManager.set_flag("heard_the_list")
            var ms_r: Node = get_tree().current_scene
            if ms_r and ms_r.has_method("show_note_reader"):
                ms_r.show_note_reader(
                    "AM Band â€” 193 kHz (bleeding through)",
                    data_r.get("excerpts", []),
                    data_r.get("reveals", ""),
                    "recorder"
                )
            if AudioManager:
                AudioManager.static_volume = 0.6
                AudioManager.play_whisper_swell(2.4)
                get_tree().create_timer(3.2).timeout.connect(func():
                    if AudioManager:
                        AudioManager.play_anomaly_pulse()
                )
            return

        var nid: String = ""
        if nm == "Polaroid":
            nid = "polaroid"
        elif nm == "IntakeForm":
            nid = "intake_form"
        elif nm == "VoiceRecorder":
            nid = "recorder"
        elif nm == "Letter":
            nid = "letter"
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

    # Doors: locked basement gate, otherwise simple open
    if "door" in nm.to_lower():
        if nm == "BasementDoor":
            if not GameManager or not GameManager.has_flag("basement_unlocked"):
                show_toast("The door is locked from this side. Something still wants to be found.")
                if AudioManager:
                    AudioManager.play_creak(0.35)
                return
            # Already unlocked â€” nudge further open if still mostly shut
            if abs(collider.rotation_degrees.y) < 40.0:
                collider.rotation_degrees.y = -55.0
                if AudioManager:
                    AudioManager.play_creak(0.7)
            else:
                show_toast("The stairs breathe cold air.")
            return
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


func show_toast(msg: String, duration_sec: float = 3.2) -> void:
    _toast_text = msg
    _toast_until_ms = Time.get_ticks_msec() + int(duration_sec * 1000.0)
    print("[Player] Toast: %s" % msg)
func set_flashlight_battery(value: float) -> void:
    if GameManager:
        GameManager.flashlight_battery = clamp(value, 0.0, 1.0)

# === VIEWMODEL (first-person hands + flashlight grip) ===
# Built from primitives so the whole demo stays self-contained.
# Sway, reach on interact, flashlight grip reaction, sprint pump.
# This is one of the highest "technically impressive" bang-for-buck additions for a code-built FPS horror slice.

func _build_viewmodel() -> void:
    if not camera:
        return
    _viewmodel = Node3D.new()
    _viewmodel.name = "ViewModel"
    camera.add_child(_viewmodel)
    # Tuned local offset so the "hands" sit naturally in lower right of frame, forward a touch.
    _viewmodel.position = Vector3(0.13, -0.17, -0.38)
    _viewmodel.rotation_degrees = Vector3(-6, 4, 8)

    # Skin / hand material (simple but effective under flashlight)
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color(0.72, 0.58, 0.49)
    skin.roughness = 0.85
    skin.metallic = 0.0

    # Forearm (main "arm" visible)
    var forearm := MeshInstance3D.new()
    forearm.name = "Forearm"
    forearm.mesh = CylinderMesh.new()
    forearm.mesh.top_radius = 0.038
    forearm.mesh.bottom_radius = 0.044
    forearm.mesh.height = 0.42
    forearm.material_override = skin
    forearm.rotation_degrees = Vector3(22, 12, -38)
    forearm.position = Vector3(0.01, 0.03, 0.09)
    _viewmodel.add_child(forearm)

    # Palm base
    var palm := MeshInstance3D.new()
    palm.name = "Palm"
    palm.mesh = BoxMesh.new()
    palm.mesh.size = Vector3(0.09, 0.032, 0.11)
    palm.material_override = skin
    palm.position = Vector3(0.02, 0.01, -0.14)
    palm.rotation_degrees = Vector3(18, 8, -12)
    _viewmodel.add_child(palm)

    # Fingers (4 + thumb) â€” loose natural hold pose for gripping the light
    var finger_mat = skin
    for i in 4:
        var f := MeshInstance3D.new()
        f.name = "Finger%d" % i
        f.mesh = CylinderMesh.new()
        f.mesh.top_radius = 0.011
        f.mesh.bottom_radius = 0.0135
        f.mesh.height = 0.07 + (i % 2) * 0.01
        f.material_override = finger_mat
        var ang := -38.0 + i * 11.0
        f.rotation_degrees = Vector3(ang, 4 + i * 3, 6)
        f.position = Vector3(-0.028 + i * 0.022, 0.012, -0.19)
        palm.add_child(f)

    # Thumb
    var thumb := MeshInstance3D.new()
    thumb.name = "Thumb"
    thumb.mesh = CylinderMesh.new()
    thumb.mesh.top_radius = 0.012
    thumb.mesh.bottom_radius = 0.015
    thumb.mesh.height = 0.055
    thumb.material_override = finger_mat
    thumb.rotation_degrees = Vector3(-72, 38, 22)
    thumb.position = Vector3(0.05, 0.01, -0.11)
    palm.add_child(thumb)

    # Visual flashlight body gripped in the hand (the real light is the SpotLight on camera for correct shadows)
    var fl_body := MeshInstance3D.new()
    fl_body.name = "FlashlightBody"
    fl_body.mesh = CylinderMesh.new()
    fl_body.mesh.top_radius = 0.018
    fl_body.mesh.bottom_radius = 0.021
    fl_body.mesh.height = 0.14
    var fl_mat := StandardMaterial3D.new()
    fl_mat.albedo_color = Color(0.18, 0.17, 0.16)
    fl_mat.roughness = 0.4
    fl_mat.metallic = 0.35
    fl_body.material_override = fl_mat
    fl_body.rotation_degrees = Vector3(82, 3, 4)
    fl_body.position = Vector3(0.01, -0.03, -0.24)
    palm.add_child(fl_body)

    # Flashlight head (slightly wider, emissive rim when on)
    var fl_head := MeshInstance3D.new()
    fl_head.name = "FlashlightHead"
    fl_head.mesh = CylinderMesh.new()
    fl_head.mesh.top_radius = 0.024
    fl_head.mesh.bottom_radius = 0.019
    fl_head.mesh.height = 0.038
    fl_head.material_override = fl_mat
    fl_head.position = Vector3(0.0, 0.0, -0.09)
    fl_body.add_child(fl_head)

    print("[Player] Viewmodel (hands + gripped flashlight) built. Sway + interact reach + toggle reaction enabled.")

func _update_viewmodel_sway(delta: float, moving: bool, sprinting: bool, light_on: bool) -> void:
    if not _viewmodel or not camera:
        return

    _vm_sway_time += delta * (1.9 if sprinting else 1.35)

    # Base arm sway (different phase/freq from head bob for secondary motion life)
    var sway_x := sin(_vm_sway_time * 1.1) * 0.009
    var sway_y := cos(_vm_sway_time * 0.85) * 0.006
    if sprinting and moving:
        sway_x *= 1.8
        sway_y *= 1.6
    elif not moving:
        sway_x *= 0.4
        sway_y *= 0.5

    # Reach on interact (brief forward poke when E is used)
    _vm_reach_target = move_toward(_vm_reach_target, 0.0, delta * 3.2)
    var reach_z := _vm_reach_target

    # Flashlight grip reaction (subtle roll when toggling)
    _vm_flash_rot_target = move_toward(_vm_flash_rot_target, 0.0, delta * 4.5)
    var fl_rot := _vm_flash_rot_target

    # Apply
    _viewmodel.position.x = 0.13 + sway_x * 0.6
    _viewmodel.position.y = -0.17 + sway_y + (0.012 if sprinting and moving else 0.0)
    _viewmodel.position.z = -0.38 + reach_z

    # Slight extra roll on sprint or tension feel
    var extra_roll := sin(_vm_sway_time * 0.6) * (0.8 if sprinting else 0.3)
    _viewmodel.rotation_degrees.z = 8.0 + extra_roll + fl_rot * 0.6

    # Micro finger flex (find children and give them a tiny living pulse)
    var palm := _viewmodel.get_node_or_null("Palm")
    if palm:
        for c in palm.get_children():
            if c.name.begins_with("Finger") or c.name == "Thumb":
                var f := c as MeshInstance3D
                if f:
                    var flex := sin(_vm_sway_time * 2.8 + _hash(c.name) * 1.5) * 1.4
                    f.rotation_degrees.x = (f.rotation_degrees.x if f.rotation_degrees.x != 0.0 else -38.0) + flex * 0.6 * (0.6 if sprinting else 1.0)

    # Flashlight visual body slight "click" response when toggled (we set target from toggle_flashlight)
    var flb := _viewmodel.get_node_or_null("Palm/FlashlightBody") as MeshInstance3D
    if flb:
        flb.rotation_degrees.x = 82.0 + fl_rot * 0.4

func _trigger_vm_reach() -> void:
    # Called on interact press for a satisfying "hand moves toward thing" feel.
    _vm_reach_target = 0.065
    # Also a little hand rotation
    _vm_flash_rot_target = 3.5

func _trigger_vm_flash_toggle() -> void:
    _vm_flash_rot_target = -7.0 if not flashlight_on else 5.5

func _hash(s: String) -> float:
    # Tiny deterministic hash for finger phase variety
    var h := 0.0
    for i in s.length():
        h += float(s.unicode_at(i)) * 0.037
    return fmod(h, 6.28)

# Attach a short-range GPUParticles3D to the flashlight so the beam has real volumetric dust motes.
# This is one of the cheapest ways to make first-person lighting feel expensive and alive.
func _attach_flashlight_particles() -> void:
    if not flashlight:
        return
    var dust := GPUParticles3D.new()
    dust.name = "BeamDust"
    dust.amount = 72
    dust.lifetime = 0.65
    dust.preprocess = 0.4
    dust.emitting = true
    # Local to the light so it moves and points with the flashlight
    flashlight.add_child(dust)
    dust.position = Vector3(0, 0, -0.6)  # a bit in front of the light origin

    var pmat := ParticleProcessMaterial.new()
    pmat.direction = Vector3(0, 0, -1)  # along the light forward
    pmat.spread = 7.0
    pmat.gravity = Vector3(0, -0.01, 0)
    pmat.initial_velocity_min = 1.8
    pmat.initial_velocity_max = 2.6
    pmat.scale_min = 0.009
    pmat.scale_max = 0.018
    pmat.color = Color(0.88, 0.85, 0.78, 0.38)
    dust.process_material = pmat

    var qm := QuadMesh.new()
    qm.size = Vector2(0.022, 0.022)
    dust.draw_pass_1 = qm

    # We toggle emitting from the flashlight update when battery/low or off
    # (kept simple here; the existing _update_flashlight already controls visibility of the light itself)
    print("[Player] Flashlight beam dust particles attached (volumetric godray feel).")
