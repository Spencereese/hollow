extends Node3D
# House - Procedural level builder for the HOLLOW demo.
# Everything is spawned in _ready so the scene file stays tiny and changes are code-reviewable.
# Focus on oppressive small-space realism: low ceilings, thick walls, limited sightlines, one moonlight shaft.

# Relax strict inference warnings for this prototype (many local vars in builder code)
# warning-ignore-all:inferred_declaration
# warning-ignore-all:unsafe_method_access
# warning-ignore-all:unsafe_property_access

@export var build_on_ready: bool = true
@export var show_debug_markers: bool = true  # turn off once layout is solid; helps describe positions precisely (see LAYOUT DEBUG in console)

var _materials: Dictionary = {}
var _interactables: Array = []

@onready var player: CharacterBody3D = $Player
@onready var world_env: WorldEnvironment = $WorldEnvironment

func _ready() -> void:
    print("[House] _ready() entered. player node exists: ", player != null)
    if build_on_ready:
        _create_materials()
        _build_geometry()
        print("[House] _build_geometry() done")
        _add_lighting_and_fog()
        print("[House] _add_lighting_and_fog() done")
        _add_particles()
        _setup_player()
        _wire_events()

        # Initial audio tension
        if AudioManager:
            AudioManager.start_ambient(0.28, 0.11)

        print("[House] Level constructed. Welcome to the property. Player at: ", player.position if player else "N/A")

func _create_materials() -> void:
    # Plaster / drywall - cold and slightly stained (brighter for demo visibility)
    var plaster: StandardMaterial3D = StandardMaterial3D.new()
    plaster.albedo_color = Color(0.58, 0.56, 0.54)
    plaster.roughness = 0.92
    plaster.metallic = 0.0
    _materials["plaster"] = plaster

    # Old wood - dark, dry (brighter for demo)
    var wood: StandardMaterial3D = StandardMaterial3D.new()
    wood.albedo_color = Color(0.38, 0.32, 0.26)
    wood.roughness = 0.85
    wood.metallic = 0.02
    _materials["wood"] = wood

    # Floor wood - warmer from foot traffic (brighter for demo)
    var floor_wood: StandardMaterial3D = StandardMaterial3D.new()
    floor_wood.albedo_color = Color(0.48, 0.40, 0.32)
    floor_wood.roughness = 0.78
    _materials["floor_wood"] = floor_wood

    # Concrete basement
    var concrete: StandardMaterial3D = StandardMaterial3D.new()
    concrete.albedo_color = Color(0.31, 0.30, 0.29)
    concrete.roughness = 0.95
    _materials["concrete"] = concrete

    # Metal pipes / fixtures - cold
    var metal: StandardMaterial3D = StandardMaterial3D.new()
    metal.albedo_color = Color(0.25, 0.26, 0.28)
    metal.roughness = 0.35
    metal.metallic = 0.7
    _materials["metal"] = metal

    # Fabric / old couch
    var fabric: StandardMaterial3D = StandardMaterial3D.new()
    fabric.albedo_color = Color(0.18, 0.15, 0.16)
    fabric.roughness = 0.98
    _materials["fabric"] = fabric

    # Black for the anomaly water
    var black: StandardMaterial3D = StandardMaterial3D.new()
    black.albedo_color = Color(0.02, 0.015, 0.018)
    black.roughness = 0.1
    black.metallic = 0.0
    black.emission_enabled = true
    black.emission = Color(0.01, 0.008, 0.012)
    black.emission_energy_multiplier = 0.3
    _materials["black"] = black

    # Accent for "wrong" objects
    var wrong: StandardMaterial3D = StandardMaterial3D.new()
    wrong.albedo_color = Color(0.12, 0.09, 0.11)
    wrong.roughness = 0.6
    _materials["wrong"] = wrong

func _add_wall(pos: Vector3, size: Vector3, mat_name: String = "plaster", rot: float = 0.0) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.collision_mask = 1

    var mesh := MeshInstance3D.new()
    mesh.mesh = BoxMesh.new()
    mesh.mesh.size = size
    mesh.material_override = _materials.get(mat_name, _materials["plaster"]).duplicate()
    body.add_child(mesh)

    var shape := CollisionShape3D.new()
    shape.shape = BoxShape3D.new()
    shape.shape.size = size
    body.add_child(shape)

    body.position = pos
    if rot != 0.0:
        body.rotation.y = deg_to_rad(rot)
    add_child(body)
    return body

func _add_prop_box(pos: Vector3, size: Vector3, mat: String, name: String = "Prop") -> StaticBody3D:
    var b := _add_wall(pos, size, mat)
    b.name = name
    return b

func _add_cylinder(pos: Vector3, radius: float, height: float, mat: String, name: String = "") -> StaticBody3D:
    var body := StaticBody3D.new()
    var mesh := MeshInstance3D.new()
    mesh.mesh = CylinderMesh.new()
    mesh.mesh.top_radius = radius
    mesh.mesh.bottom_radius = radius
    mesh.mesh.height = height
    mesh.material_override = _materials.get(mat, _materials["metal"])
    body.add_child(mesh)

    var shape := CollisionShape3D.new()
    shape.shape = CylinderShape3D.new()
    shape.shape.radius = radius
    shape.shape.height = height
    body.add_child(shape)

    body.position = pos
    if name != "": body.name = name
    add_child(body)
    return body

func _build_geometry() -> void:
    # === FLOORS ===
    # Main floor - living + kitchen + hall (slightly raised)
    _add_prop_box(Vector3(0, -0.1, 0), Vector3(11.5, 0.2, 9.0), "floor_wood", "MainFloor")

    # Basement floor (lower)
    _add_prop_box(Vector3(0, -4.8, 6.5), Vector3(5.5, 0.2, 5.0), "concrete", "BasementFloor")

    # Ceilings for house feel
    _add_prop_box(Vector3(0, 3.5, 0), Vector3(11.5, 0.15, 9.0), "plaster", "MainCeiling")
    _add_prop_box(Vector3(4.0, 3.0, 2.8), Vector3(3.0, 0.15, 3.0), "plaster", "BedroomCeiling")
    _add_prop_box(Vector3(0, -0.6, 6.5), Vector3(5.5, 0.15, 5.0), "concrete", "BasementCeiling")

    # === EXTERIOR / PORCH ===
    # Porch floor
    _add_prop_box(Vector3(0, -0.05, -3.8), Vector3(3.8, 0.15, 2.2), "wood", "Porch")

    # Proper enclosing front walls of the house at z=-2.55 with central entrance gap for the door.
    # This ensures the front is fully walled except for the proper doorway (no more open sides or floating door).
    # Left far front wall (connects left side wall to left entrance side)
    _add_wall(Vector3(-3.35, 1.7, -2.55), Vector3(4.3, 3.5, 0.35), "plaster")
    # Right far front wall
    _add_wall(Vector3(3.35, 1.7, -2.55), Vector3(4.3, 3.5, 0.35), "plaster")

    # Entrance side walls (porch only, to frame the entrance without protruding into main living room)
    _add_wall(Vector3(-1.0, 1.6, -3.3), Vector3(0.35, 3.4, 1.0), "plaster")
    _add_wall(Vector3(1.0, 1.6, -3.3), Vector3(0.35, 3.4, 1.0), "plaster")

    # Door frame (thin) aligned to the entrance gap
    _add_prop_box(Vector3(0, 1.1, -2.55), Vector3(1.6, 0.18, 0.18), "wood", "DoorHeader")

    # === LIVING ROOM (center) ===
    # Back wall
    _add_wall(Vector3(0, 1.7, 4.3), Vector3(11.2, 3.5, 0.35), "plaster", 0)
    # Left wall (kitchen side open)
    _add_wall(Vector3(-5.5, 1.7, 0), Vector3(0.35, 3.5, 8.5), "plaster")
    # Right wall - split to include a window opening for house-like detail
    # South part (z low)
    _add_wall(Vector3(5.5, 1.7, -1.775), Vector3(0.35, 3.5, 4.95), "plaster")
    # North part (z high)
    _add_wall(Vector3(5.5, 1.7, 3.275), Vector3(0.35, 3.5, 1.95), "plaster")
    # Window inside the opening (frame + glass) at x slightly inside
    var win_frame := _add_prop_box(Vector3(5.4, 1.9, 1.5), Vector3(0.1, 1.2, 1.6), "wood", "WindowFrame")
    var glass := MeshInstance3D.new()
    glass.mesh = QuadMesh.new()
    glass.mesh.size = Vector2(1.3, 1.0)
    glass.position = Vector3(5.35, 1.9, 1.5)
    var gmat := StandardMaterial3D.new()
    gmat.albedo_color = Color(0.35, 0.55, 0.75)
    gmat.roughness = 0.2
    glass.material_override = gmat
    add_child(glass)

    # (removed interior divider for more open plan as intended; kitchen side open to main)

    # === KITCHEN / DINING (left open plan) ===
    # Counter (long box)
    _add_prop_box(Vector3(-4.2, 0.6, 1.8), Vector3(2.2, 1.4, 0.7), "wood", "Counter")
    # Sink / fridge block
    _add_prop_box(Vector3(-4.6, 0.9, 3.2), Vector3(1.1, 1.8, 1.3), "metal", "Fridge")

    # === BEDROOM / STUDY (back right) ===
    # Split wall for doorway (makes it feel like a real room entrance)
    _add_wall(Vector3(2.6, 1.7, 1.5), Vector3(1.8, 3.5, 0.3), "plaster")  # left part of bedroom wall
    _add_wall(Vector3(5.2, 1.7, 1.5), Vector3(1.6, 3.5, 0.3), "plaster")  # right part of bedroom wall
    # Door header over the gap
    _add_prop_box(Vector3(4.0, 3.2, 1.55), Vector3(1.0, 0.2, 0.2), "wood", "BedroomDoorHeader")
    # Bedroom doorway trim (open passage but framed like a real interior door)
    var bdt_mat = _materials["wood"]
    var bd_l := MeshInstance3D.new()
    bd_l.mesh = BoxMesh.new()
    bd_l.mesh.size = Vector3(0.12, 2.2, 0.28)
    bd_l.position = Vector3(2.75, 1.7, 1.52)
    bd_l.material_override = bdt_mat
    add_child(bd_l)
    var bd_r := MeshInstance3D.new()
    bd_r.mesh = BoxMesh.new()
    bd_r.mesh.size = Vector3(0.12, 2.2, 0.28)
    bd_r.position = Vector3(5.05, 1.7, 1.52)
    bd_r.material_override = bdt_mat
    add_child(bd_r)
    var bd_top := MeshInstance3D.new()
    bd_top.mesh = BoxMesh.new()
    bd_top.mesh.size = Vector3(2.4, 0.15, 0.28)
    bd_top.position = Vector3(3.9, 2.85, 1.52)
    bd_top.material_override = bdt_mat
    add_child(bd_top)
    # Bedroom floor slightly different
    _add_prop_box(Vector3(4.0, -0.05, 2.8), Vector3(3.0, 0.18, 3.0), "floor_wood", "BedroomFloor")

    # === STAIRS DOWN (simple stepped boxes) ===
    for i in 5:
        var step_z := 4.8 + i * 0.55
        var step_y := -0.8 - i * 0.75
        _add_prop_box(Vector3(1.6, step_y, step_z), Vector3(1.4, 0.22, 0.55), "wood", "Step%d" % i)

    # Basement walls (enclosed)
    _add_wall(Vector3(-2.6, -2.8, 6.5), Vector3(0.3, 4.2, 5.0), "concrete")
    _add_wall(Vector3(2.6, -2.8, 6.5), Vector3(0.3, 4.2, 5.0), "concrete")
    _add_wall(Vector3(0, -2.8, 9.0), Vector3(5.2, 4.2, 0.3), "concrete")
    # Front basement wall with opening from stairs, aligned with stairs at x=1.6
    _add_wall(Vector3(-1.5, -2.8, 4.0), Vector3(2.2, 4.2, 0.3), "concrete")  # left of entrance
    _add_wall(Vector3(2.0, -2.8, 4.0), Vector3(1.0, 4.2, 0.3), "concrete")  # right of entrance

    # === FURNITURE & PROPS ===
    # Couch - composed (base + back + arms)
    _add_prop_box(Vector3(-2.8, 0.35, 2.4), Vector3(2.4, 0.35, 0.9), "fabric", "CouchBase")
    _add_prop_box(Vector3(-2.8, 0.75, 2.65), Vector3(2.4, 0.7, 0.2), "fabric", "CouchBack")
    _add_prop_box(Vector3(-3.9, 0.5, 2.4), Vector3(0.18, 0.55, 0.9), "fabric", "CouchArmL")
    _add_prop_box(Vector3(-1.7, 0.5, 2.4), Vector3(0.18, 0.55, 0.9), "fabric", "CouchArmR")
    # Coffee table with simple legs
    _add_prop_box(Vector3(-1.2, 0.35, 2.1), Vector3(1.3, 0.35, 0.7), "wood", "CoffeeTableTop")
    _add_prop_box(Vector3(-1.7, 0.1, 1.8), Vector3(0.12, 0.25, 0.12), "wood", "TableLeg1")
    _add_prop_box(Vector3(-0.7, 0.1, 1.8), Vector3(0.12, 0.25, 0.12), "wood", "TableLeg2")
    _add_prop_box(Vector3(-1.7, 0.1, 2.4), Vector3(0.12, 0.25, 0.12), "wood", "TableLeg3")
    _add_prop_box(Vector3(-0.7, 0.1, 2.4), Vector3(0.12, 0.25, 0.12), "wood", "TableLeg4")

    # Old TV (box on stand)
    var tv_stand := _add_prop_box(Vector3(2.9, 0.35, 2.6), Vector3(0.9, 0.7, 0.55), "wood", "TVStand")
    var tv := _add_prop_box(Vector3(2.9, 0.85, 2.6), Vector3(0.7, 0.55, 0.4), "metal", "TV")
    # Make TV screen slightly emissive dark
    var tv_mat := _materials["metal"].duplicate() as StandardMaterial3D
    tv_mat.emission_enabled = true
    tv_mat.emission = Color(0.03, 0.03, 0.04)
    tv.get_child(0).material_override = tv_mat

    # Radio on side table - use full RadioInteractable class
    var radio_table := _add_prop_box(Vector3(3.6, 0.45, -0.8), Vector3(0.6, 0.55, 0.6), "wood", "RadioTable")
    var radio_body := StaticBody3D.new()
    radio_body.name = "Radio"
    radio_body.position = Vector3(3.6, 0.85, -0.8)
    radio_body.scale = Vector3(0.6, 0.6, 0.6)
    radio_body.collision_layer = 2
    radio_body.collision_mask = 0
    var radio_shape := CollisionShape3D.new()
    var radio_box := BoxShape3D.new()
    radio_box.size = Vector3(0.7, 0.35, 0.5)
    radio_shape.shape = radio_box
    radio_body.add_child(radio_shape)
    var radio_mesh := MeshInstance3D.new()
    radio_mesh.mesh = BoxMesh.new()
    radio_mesh.mesh.size = Vector3(0.7, 0.35, 0.5)
    radio_mesh.material_override = _materials["metal"]
    radio_body.add_child(radio_mesh)
    add_child(radio_body)
    radio_body.add_to_group("interactable")

    # Mantel / fireplace (back wall) - filled out with shelf + brackets
    _add_prop_box(Vector3(0, 1.1, 4.0), Vector3(2.8, 1.6, 0.6), "wood", "Mantel")
    # Shelf lip (protrudes)
    _add_prop_box(Vector3(0, 1.55, 4.25), Vector3(2.6, 0.12, 0.2), "wood", "MantelLip")
    # Brackets
    _add_prop_box(Vector3(-1.1, 1.0, 4.2), Vector3(0.18, 0.7, 0.35), "wood", "MantelBracketL")
    _add_prop_box(Vector3(1.1, 1.0, 4.2), Vector3(0.18, 0.7, 0.35), "wood", "MantelBracketR")
    # Fireplace opening (dark)
    _add_prop_box(Vector3(0, 0.7, 4.15), Vector3(1.6, 1.1, 0.35), "black", "Firebox")

    # The polaroid on the mantel (plain body + visual for name fallback interaction)
    var photo_body := StaticBody3D.new()
    photo_body.name = "Polaroid"
    photo_body.position = Vector3(-0.6, 1.65, 3.85)
    photo_body.rotation_degrees = Vector3(-12, 8, 0)
    photo_body.scale = Vector3(0.38, 0.28, 0.08)
    photo_body.collision_layer = 2
    photo_body.collision_mask = 0
    var photo_shape := CollisionShape3D.new()
    var photo_box := BoxShape3D.new()
    photo_box.size = Vector3(0.6, 0.4, 0.05)
    photo_shape.shape = photo_box
    photo_body.add_child(photo_shape)
    var photo_mesh: MeshInstance3D = MeshInstance3D.new()
    photo_mesh.mesh = QuadMesh.new()
    photo_mesh.mesh.size = Vector2(1.6, 1.1)
    var photo_mat: StandardMaterial3D = StandardMaterial3D.new()
    var pimg: Image = Image.new()
    if pimg.load("res://assets/art/family_polaroid.jpg") == OK:
        photo_mat.albedo_texture = ImageTexture.create_from_image(pimg)
    photo_mat.roughness = 0.6
    photo_mesh.material_override = photo_mat
    photo_body.add_child(photo_mesh)
    add_child(photo_body)
    photo_body.add_to_group("interactable")

    # Intake form on entry table (near door) - use Note class
    var entry_table := _add_prop_box(Vector3(-1.4, 0.55, -1.6), Vector3(1.1, 0.65, 0.6), "wood", "EntryTable")
    var form_body := StaticBody3D.new()
    form_body.name = "IntakeForm"
    form_body.position = Vector3(-1.4, 1.0, -1.35)
    form_body.rotation_degrees = Vector3(-22, 4, 0)
    form_body.scale = Vector3(0.42, 0.32, 0.06)
    form_body.collision_layer = 2
    form_body.collision_mask = 0
    var form_shape := CollisionShape3D.new()
    var form_box := BoxShape3D.new()
    form_box.size = Vector3(0.7, 0.5, 0.03)
    form_shape.shape = form_box
    form_body.add_child(form_shape)
    var form_mesh: MeshInstance3D = MeshInstance3D.new()
    form_mesh.mesh = QuadMesh.new()
    form_mesh.mesh.size = Vector2(1.8, 1.25)
    var form_mat: StandardMaterial3D = StandardMaterial3D.new()
    var fimg: Image = Image.new()
    if fimg.load("res://assets/art/intake_form.jpg") == OK:
        form_mat.albedo_texture = ImageTexture.create_from_image(fimg)
    form_mat.roughness = 0.75
    form_mesh.material_override = form_mat
    form_body.add_child(form_mesh)
    add_child(form_body)
    form_body.add_to_group("interactable")

    # Bedroom props
    # Bed - composed for better look (frame, mattress, pillows, headboard)
    _add_prop_box(Vector3(4.2, 0.25, 3.6), Vector3(1.8, 0.25, 2.0), "wood", "BedFrame")
    _add_prop_box(Vector3(4.2, 0.45, 3.6), Vector3(1.7, 0.2, 1.9), "fabric", "Mattress")
    _add_prop_box(Vector3(4.0, 0.55, 4.9), Vector3(0.4, 0.15, 0.35), "fabric", "Pillow1")
    _add_prop_box(Vector3(4.6, 0.55, 4.9), Vector3(0.4, 0.15, 0.35), "fabric", "Pillow2")
    _add_prop_box(Vector3(4.2, 0.7, 5.2), Vector3(1.8, 0.9, 0.12), "wood", "Headboard")
    # Nightstand + recorder (use Note class)
    var night := _add_prop_box(Vector3(5.3, 0.45, 2.3), Vector3(0.55, 0.6, 0.55), "wood", "Nightstand")
    var recorder_body := StaticBody3D.new()
    recorder_body.name = "VoiceRecorder"
    recorder_body.position = Vector3(5.3, 0.9, 2.3)
    recorder_body.scale = Vector3(0.25, 0.18, 0.35)
    recorder_body.collision_layer = 2
    recorder_body.collision_mask = 0
    var rec_shape := CollisionShape3D.new()
    var rec_box := BoxShape3D.new()
    rec_box.size = Vector3(0.9, 0.4, 0.6)
    rec_shape.shape = rec_box
    recorder_body.add_child(rec_shape)
    var rec_mesh: MeshInstance3D = MeshInstance3D.new()
    rec_mesh.mesh = BoxMesh.new()
    rec_mesh.mesh.size = Vector3(0.9, 0.4, 0.6)
    rec_mesh.material_override = _materials["metal"]
    recorder_body.add_child(rec_mesh)
    add_child(recorder_body)
    recorder_body.add_to_group("interactable")

    # Letter in "drawer" (use Note class)
    var letter_body := StaticBody3D.new()
    letter_body.name = "Letter"
    letter_body.position = Vector3(3.4, 0.15, 4.1)
    letter_body.scale = Vector3(0.3, 0.08, 0.22)
    letter_body.collision_layer = 2
    letter_body.collision_mask = 0
    var let_shape := CollisionShape3D.new()
    var let_box := BoxShape3D.new()
    let_box.size = Vector3(1.0, 0.2, 0.7)
    let_shape.shape = let_box
    letter_body.add_child(let_shape)
    var letter_mesh: MeshInstance3D = MeshInstance3D.new()
    letter_mesh.mesh = BoxMesh.new()
    letter_mesh.mesh.size = Vector3(1.0, 0.2, 0.7)
    letter_mesh.material_override = _materials["wood"]
    letter_body.add_child(letter_mesh)
    add_child(letter_body)
    letter_body.add_to_group("interactable")

    # Basement anomaly (the black water) - use Anomaly class
    var anomaly_body := StaticBody3D.new()
    anomaly_body.name = "TheThreshold"
    anomaly_body.position = Vector3(0.3, -4.3, 7.8)
    anomaly_body.scale = Vector3(1.4, 0.15, 1.4)
    anomaly_body.collision_layer = 2
    anomaly_body.collision_mask = 0
    var anom_shape := CollisionShape3D.new()
    var anom_cyl := CylinderShape3D.new()
    anom_cyl.radius = 0.9
    anom_cyl.height = 0.3
    anom_shape.shape = anom_cyl
    anomaly_body.add_child(anom_shape)
    var water: MeshInstance3D = MeshInstance3D.new()
    water.mesh = CylinderMesh.new()
    water.mesh.top_radius = 0.9
    water.mesh.bottom_radius = 0.9
    water.mesh.height = 0.3
    water.material_override = _materials["black"]
    anomaly_body.add_child(water)
    add_child(anomaly_body)
    anomaly_body.add_to_group("interactable")

    # Pipes in basement for atmosphere
    _add_cylinder(Vector3(-1.8, -2.2, 5.8), 0.12, 2.8, "metal", "Pipe1")
    _add_cylinder(Vector3(1.9, -1.6, 8.2), 0.09, 3.6, "metal", "Pipe2")

    # === DOORS (visual only + locked feel) ===
    # Front door (slightly open) - now properly on the front wall in the entrance gap
    # Fixed slab dims: wide in x (along wall), thin in z (door thickness) so it sits flush in opening, not protruding.
    var front_door := _add_prop_box(Vector3(-0.05, 1.3, -2.55), Vector3(0.9, 2.1, 0.12), "wood", "FrontDoor")
    front_door.rotation_degrees = Vector3(0, -18, 0)  # ajar

    # Detailed door frame (jambs + header trim) so the door visibly "belongs" in the wall opening, not floating.
    var frame_mat = _materials["wood"]
    var fj_l := MeshInstance3D.new()
    fj_l.mesh = BoxMesh.new()
    fj_l.mesh.size = Vector3(0.14, 2.25, 0.38)
    fj_l.position = Vector3(-0.52, 1.25, -2.52)
    fj_l.material_override = frame_mat
    add_child(fj_l)
    var fj_r := MeshInstance3D.new()
    fj_r.mesh = BoxMesh.new()
    fj_r.mesh.size = Vector3(0.14, 2.25, 0.38)
    fj_r.position = Vector3(0.52, 1.25, -2.52)
    fj_r.material_override = frame_mat
    add_child(fj_r)
    var fj_top := MeshInstance3D.new()
    fj_top.mesh = BoxMesh.new()
    fj_top.mesh.size = Vector3(1.15, 0.18, 0.38)
    fj_top.position = Vector3(0, 2.45, -2.52)
    fj_top.material_override = frame_mat
    add_child(fj_top)

    # Basement door (starts locked, we can "unlock" visually later) - aligned to stairs/opening
    # Fixed: wide in x, thin in z (proper door slab orientation for wall at ~z=4)
    var base_door := _add_prop_box(Vector3(1.6, -2.2, 4.05), Vector3(0.85, 2.0, 0.1), "wood", "BasementDoor")
    # We will rotate it when basement_unlocked flag is set (via signal)

    # Basement door jambs (frame the opening in the concrete wall)
    var bj_l := MeshInstance3D.new()
    bj_l.mesh = BoxMesh.new()
    bj_l.mesh.size = Vector3(0.14, 2.15, 0.32)
    bj_l.position = Vector3(1.6 - 0.5, -2.15, 4.02)
    bj_l.material_override = frame_mat
    add_child(bj_l)
    var bj_r := MeshInstance3D.new()
    bj_r.mesh = BoxMesh.new()
    bj_r.mesh.size = Vector3(0.14, 2.15, 0.32)
    bj_r.position = Vector3(1.6 + 0.5, -2.15, 4.02)
    bj_r.material_override = frame_mat
    add_child(bj_r)

    # Small chair in corner
    _add_prop_box(Vector3(-4.0, 0.55, -1.0), Vector3(0.55, 0.9, 0.55), "wood", "Chair")

    # Books / clutter on coffee table
    _add_prop_box(Vector3(-0.7, 0.55, 1.9), Vector3(0.35, 0.12, 0.25), "wood", "Book1")
    _add_prop_box(Vector3(-1.4, 0.52, 2.3), Vector3(0.22, 0.18, 0.18), "fabric", "Book2")

    # Count nodes in the "interactable" group 
    var interactable_count = get_tree().get_nodes_in_group("interactable").size()
    print("[House] Geometry + props placed. %d interactables registered (via group)." % interactable_count)

    # Visual layout aids (spawned here so they exist early; positions are source-of-truth from build)
    if show_debug_markers:
        _spawn_layout_markers()

func _spawn_layout_markers() -> void:
    # Bright, non-colliding, labeled reference markers. Colors:
    # red = doors, yellow = the 6 key props, blue = wall planes/corners, green = stairs, magenta = porch/trim
    var markers: Array = [
        {"pos": Vector3(0, 0.2, -2.55), "col": Color(0.95, 0.2, 0.2), "lbl": "FrontWallPlane"},
        {"pos": Vector3(-0.05, 0.2, -2.55), "col": Color(1, 0.15, 0.15), "lbl": "FrontDoor"},
        {"pos": Vector3(1.6, -4.2, 4.05), "col": Color(1, 0.15, 0.15), "lbl": "BasementDoor"},
        {"pos": Vector3(-0.6, 1.3, 3.85), "col": Color(1, 0.95, 0.2), "lbl": "Polaroid"},
        {"pos": Vector3(-1.4, 0.8, -1.35), "col": Color(1, 0.95, 0.2), "lbl": "IntakeForm"},
        {"pos": Vector3(3.6, 0.55, -0.8), "col": Color(1, 0.95, 0.2), "lbl": "Radio"},
        {"pos": Vector3(5.3, 0.6, 2.3), "col": Color(1, 0.95, 0.2), "lbl": "VoiceRecorder"},
        {"pos": Vector3(3.4, 0.15, 4.1), "col": Color(1, 0.95, 0.2), "lbl": "Letter"},
        {"pos": Vector3(0.3, -4.5, 7.8), "col": Color(1, 0.95, 0.2), "lbl": "TheThreshold"},
        {"pos": Vector3(-5.5, 0.4, -4.2), "col": Color(0.35, 0.65, 1), "lbl": "NWCorner"},
        {"pos": Vector3(5.5, 0.4, -4.2), "col": Color(0.35, 0.65, 1), "lbl": "NECorner"},
        {"pos": Vector3(-5.5, 0.4, 4.2), "col": Color(0.35, 0.65, 1), "lbl": "SWCorner"},
        {"pos": Vector3(5.5, 0.4, 4.2), "col": Color(0.35, 0.65, 1), "lbl": "SECorner"},
        {"pos": Vector3(1.6, -0.3, 4.6), "col": Color(0.3, 0.95, 0.4), "lbl": "StairTop"},
        {"pos": Vector3(-4.2, 0.4, 1.8), "col": Color(0.75, 0.55, 0.95), "lbl": "Counter"},
        {"pos": Vector3(0, 0.7, 4.0), "col": Color(0.75, 0.55, 0.95), "lbl": "Mantel"},
        {"pos": Vector3(-1.0, 0.4, -3.3), "col": Color(0.95, 0.45, 0.85), "lbl": "LPorchWall"},
        {"pos": Vector3(1.0, 0.4, -3.3), "col": Color(0.95, 0.45, 0.85), "lbl": "RPorchWall"},
        {"pos": Vector3(4.0, 1.0, 1.55), "col": Color(0.6, 0.85, 0.6), "lbl": "BedroomDoorway"},
    ]
    for mdef in markers:
        var m := MeshInstance3D.new()
        m.name = "DebugMarker_" + mdef["lbl"]
        m.mesh = SphereMesh.new()
        m.mesh.radius = 0.09
        var mat := StandardMaterial3D.new()
        mat.albedo_color = mdef["col"]
        mat.emission_enabled = true
        mat.emission = mdef["col"] * 0.9
        mat.emission_energy_multiplier = 1.4
        m.material_override = mat
        m.position = mdef["pos"] + Vector3(0, 0.65, 0)  # hover above floor/near object
        add_child(m)
        # In-game label (billboard so always readable)
        var l := Label3D.new()
        l.text = mdef["lbl"]
        l.font_size = 9
        l.outline_size = 1
        l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        l.position = Vector3(0, 0.22, 0)
        l.modulate = Color(1, 1, 1, 0.95)
        m.add_child(l)
    print("[House] Spawned %d layout debug markers (bright emissive spheres + floating labels). No collision. Toggle off with House.show_debug_markers=false once layout solid. Use labels + console coords to describe problems precisely." % markers.size())

func _add_lighting_and_fog() -> void:
    # WorldEnvironment with heavy fog for confined oppressive feel
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.008, 0.006, 0.01)
    env.fog_enabled = true
    env.fog_light_color = Color(0.04, 0.035, 0.05)
    env.fog_light_energy = 0.15
    env.fog_sun_scatter = 0.0
    env.fog_density = 0.015  # much thinner for demo visibility; still atmospheric with flashlight
    env.fog_height = 0.4
    env.fog_height_density = 0.6
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.adjustment_enabled = true
    env.adjustment_contrast = 1.08
    env.adjustment_saturation = 0.82
    world_env.environment = env

    # Moonlight shaft from "window" high on back wall (living room)
    var moon := DirectionalLight3D.new()
    moon.name = "Moon"
    moon.light_color = Color(0.72, 0.78, 0.92)
    moon.light_energy = 0.9
    moon.shadow_enabled = true
    moon.rotation_degrees = Vector3(-62, 28, 0)
    add_child(moon)

    # Small warm fill light near the entry so the starting view has *some* visibility (prevents solid grey at spawn)
    var entry_fill := OmniLight3D.new()
    entry_fill.name = "EntryFill"
    entry_fill.position = Vector3(-0.5, 2.0, -0.5)
    entry_fill.light_color = Color(0.9, 0.82, 0.65)
    entry_fill.light_energy = 0.8
    entry_fill.omni_range = 6.0
    entry_fill.shadow_enabled = false
    add_child(entry_fill)

    # Interior ceiling light (on, to make house feel lived-in and less cave-like)
    var ceil_light := OmniLight3D.new()
    ceil_light.name = "CeilingLight"
    ceil_light.position = Vector3(0, 3.2, 1.5)
    ceil_light.light_color = Color(0.95, 0.9, 0.8)
    ceil_light.light_energy = 0.6
    ceil_light.omni_range = 6.0
    add_child(ceil_light)

    # Weak interior lamp (off at start, we can turn on via event)
    var lamp := OmniLight3D.new()
    lamp.name = "BrokenLamp"
    lamp.position = Vector3(3.2, 2.4, 0.8)
    lamp.light_color = Color(0.95, 0.82, 0.55)
    lamp.light_energy = 0.0  # starts dead
    lamp.omni_range = 4.5
    lamp.shadow_enabled = false
    add_child(lamp)

    # Very dim red "pilot" from the anomaly area (subtle)
    var red_glow := OmniLight3D.new()
    red_glow.position = Vector3(0.3, -4.6, 7.8)
    red_glow.light_color = Color(0.25, 0.08, 0.06)
    red_glow.light_energy = 0.08
    red_glow.omni_range = 2.8
    add_child(red_glow)

    # The all-important flashlight is on the Player

func _add_particles() -> void:
    # Dust motes in the main moonlight shaft
    var dust := GPUParticles3D.new()
    dust.name = "DustMotes"
    dust.position = Vector3(0.2, 1.8, 2.8)
    dust.amount = 38
    dust.lifetime = 9.0
    dust.preprocess = 4.0
    dust.emitting = true

    var mat := ParticleProcessMaterial.new()
    mat.direction = Vector3(0.02, -0.6, 0.08)
    mat.spread = 12.0
    mat.gravity = Vector3(0.01, -0.03, -0.01)
    mat.initial_velocity_min = 0.02
    mat.initial_velocity_max = 0.07
    mat.scale_min = 0.012
    mat.scale_max = 0.022
    mat.color = Color(0.82, 0.79, 0.72, 0.55)
    dust.process_material = mat

    var draw := QuadMesh.new()
    draw.size = Vector2(0.03, 0.03)
    dust.draw_pass_1 = draw
    add_child(dust)

    # Very subtle "moth" or floating specks near anomaly (creepy)
    var moths := GPUParticles3D.new()
    moths.position = Vector3(0.3, -3.9, 7.2)
    moths.amount = 12
    moths.lifetime = 6.5
    var mmat := ParticleProcessMaterial.new()
    mmat.direction = Vector3(0.1, 0.3, 0.0)
    mmat.spread = 60.0
    mmat.gravity = Vector3(0, -0.01, 0)
    mmat.initial_velocity_min = 0.1
    mmat.initial_velocity_max = 0.25
    mmat.scale_min = 0.018
    mmat.scale_max = 0.026
    mmat.color = Color(0.15, 0.12, 0.11, 0.4)
    moths.process_material = mmat
    moths.draw_pass_1 = draw
    add_child(moths)

func _setup_player() -> void:
    if not player:
        push_error("No Player node found under House!")
        return

    # Add collision shape so CharacterBody3D can stand on floor and collide with walls (prevents falling through)
    if player.get_node_or_null("CollisionShape3D") == null:
        var cs := CollisionShape3D.new()
        cs.name = "CollisionShape3D"
        var capsule := CapsuleShape3D.new()
        capsule.radius = 0.3
        capsule.height = 1.7
        cs.shape = capsule
        cs.position = Vector3(0, 0.85, 0)  # center capsule so feet roughly at player origin y
        player.add_child(cs)
        player.collision_layer = 2
        player.collision_mask = 1  # collide with world (floors/walls on layer 1)
        player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
        player.up_direction = Vector3.UP
        print("[House] Added collision shape to Player for physics/floor")

    # Start position just inside the door on the porch side, looking into living room
    # Player body low (feet), head will be raised for eye level
    # Place feet just above floor surface (floor top ~ y=0)
    player.position = Vector3(-0.3, 0.01, -1.8)
    player.rotation_degrees = Vector3(0, 12, 0)
    player.velocity = Vector3.ZERO

    # Tell GameManager
    if GameManager:
        GameManager.player = player
        GameManager.world = self

    # Note: HUD prompt lives in Main.gd (2D overlay). Player ray logic still runs for detection.

    # Raise the Head for proper eye-level camera (standard FPS setup)
    var head := player.get_node_or_null("Head")
    if head:
        head.position.y = 1.65   # eye height
        head.rotation_degrees.x = -6.0  # slight downward tilt for "heavy" feel

        var cam: Camera3D = head.get_node_or_null("Camera3D") as Camera3D
        if cam:
            cam.current = true
            print("[House] Camera3D forced .current = true at ", player.position)
        else:
            print("[House] WARNING: No Camera3D found under Head!")

    # Settle physics on floor (with shape, move_and_slide will stop falling)
    for i in 3:
        player.move_and_slide()
    print("[House] Player settled, y=", player.position.y)

    # === LAYOUT DIAGNOSTICS (accurate post-settle positions; run with CLEAN=1 to see) ===
    # Use the printed numbers + the bright labeled debug marker spheres (spawned in scene, no collision)
    # to precisely describe what's wrong, e.g.:
    #   "FrontDoor marker (red) is 0.4m inside the FrontWallPlane marker"
    #   "Polaroid (yellow) is floating 0.3 above the Mantel (magenta) instead of sitting on lip"
    #   "Player start is good, but the LPorchWall marker is clipping the entrance"
    print("[House] === LAYOUT DEBUG (post-settle) ===")
    print("[House] Player: ", player.position if player else "N/A")
    var fd = get_node_or_null("FrontDoor")
    if fd:
        print("[House] FrontDoor: ", fd.global_position, " rot=", fd.rotation_degrees)
    var bd = get_node_or_null("BasementDoor")
    if bd:
        print("[House] BasementDoor: ", bd.global_position, " rot=", bd.rotation_degrees)
    print("[House] Interactables (global pos):")
    for n in get_tree().get_nodes_in_group("interactable"):
        print("  ", n.name, " @ ", n.global_position)
    print("[House] Debug markers (if House.show_debug_markers=true): 19 hovering emissive spheres w/ labels are in the scene. Look for 'FrontDoor', 'Polaroid', 'NWCorner' etc while playing to give precise feedback.")
    print("[House] === END LAYOUT DEBUG ===")

func _wire_events() -> void:
    if GameManager:
        GameManager.note_collected.connect(_on_note_collected)
        GameManager.event_triggered.connect(_on_world_event)
        GameManager.demo_ended.connect(_on_demo_end)

    # Basement door unlock reaction
    # (polled lightly in a timer for demo simplicity)
    var t := Timer.new()
    t.wait_time = 0.8
    t.autostart = true
    t.timeout.connect(_check_basement_door)
    add_child(t)

func _on_note_collected(note_id: String, _title: String) -> void:
    if note_id == "polaroid" and GameManager:
        GameManager.set_flag("painting_corrupted")
        # Also corrupt the physical photo a bit more if possible
        var photo := get_node_or_null("Polaroid")
        if photo and photo.has_method("set_corrupted"):
            photo.set_corrupted(true)

    if note_id == "intake_form":
        # After reading the form, the house "notices" you
        if AudioManager:
            AudioManager.play_creak(0.9)
        get_tree().create_timer(2.8).timeout.connect(func():
            if AudioManager: AudioManager.play_whisper_swell(1.6)
        )

func _on_world_event(event_name: String) -> void:
    match event_name:
        "basement_unlocked":
            _unlock_basement_door()
        "entered_basement":
            _basement_entered()

func _check_basement_door() -> void:
    if not GameManager or not GameManager.has_flag("basement_unlocked"):
        return
    var door := get_node_or_null("BasementDoor")
    if door and door.rotation_degrees.y > -45:
        door.rotation_degrees.y = move_toward(door.rotation_degrees.y, -52, 18.0)

func _unlock_basement_door() -> void:
    var door := get_node_or_null("BasementDoor")
    if door:
        # Swing it open dramatically
        var tw := create_tween()
        tw.tween_property(door, "rotation_degrees:y", -58.0, 1.6).set_trans(Tween.TRANS_SINE)
    if AudioManager:
        AudioManager.play_door_close()
    # Creak from below
    get_tree().create_timer(0.9).timeout.connect(func(): if AudioManager: AudioManager.play_creak(1.0))

func _basement_entered() -> void:
    # Lights die, static rises, the house reacts
    var lamp := get_node_or_null("BrokenLamp")
    if lamp:
        var tw := create_tween()
        tw.tween_property(lamp, "light_energy", 0.0, 0.6)
    if AudioManager:
        AudioManager.static_volume = 0.48
        AudioManager.play_anomaly_pulse()
    # Spawn a "watcher" silhouette at the top of the stairs for 1.8 seconds
    _spawn_watcher_silhouette()

func _spawn_watcher_silhouette() -> void:
    var w := MeshInstance3D.new()
    w.name = "Watcher"
    w.position = Vector3(1.4, 0.4, 1.2)
    w.rotation_degrees = Vector3(0, -35, 0)

    var body := CylinderMesh.new()
    body.top_radius = 0.22
    body.bottom_radius = 0.28
    body.height = 2.1
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.02, 0.015, 0.018)
    mat.roughness = 1.0
    w.mesh = body
    w.material_override = mat
    add_child(w)

    # Head
    var head_m := SphereMesh.new()
    head_m.radius = 0.26
    var head := MeshInstance3D.new()
    head.mesh = head_m
    head.position = Vector3(0, 1.25, 0)
    head.material_override = mat
    w.add_child(head)

    # Two tiny "eye" dots (emissive)
    for x_off in [-0.11, 0.11]:
        var eye := MeshInstance3D.new()
        eye.mesh = SphereMesh.new()
        eye.mesh.radius = 0.035
        var eye_mat := StandardMaterial3D.new()
        eye_mat.albedo_color = Color(0.9, 0.92, 0.95)
        eye_mat.emission_enabled = true
        eye_mat.emission = Color(0.6, 0.65, 0.7)
        eye_mat.emission_energy_multiplier = 0.4
        eye.material_override = eye_mat
        eye.position = Vector3(x_off, 1.32, -0.22)
        head.add_child(eye)

    # Remove after short time or when player gets close
    get_tree().create_timer(1.9).timeout.connect(func():
        if is_instance_valid(w):
            var fade := create_tween()
            fade.tween_property(w, "modulate:a", 0.0, 0.4)
            fade.finished.connect(w.queue_free)
    )

func play_creak_at(pos: Vector3, intensity: float = 0.8) -> void:
    if AudioManager:
        AudioManager.play_creak(intensity)

func _on_demo_end(_reason: String) -> void:
    # The Main scene handles the actual fade + text
    pass
