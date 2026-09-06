extends Control
# MainMenu - Atmospheric title screen for HOLLOW demo.

@onready var bg: TextureRect = $Background

var start_btn: Button
var continue_btn: Button
var controls_btn: Button
var quit_btn: Button
var controls_panel: Control

func _ready() -> void:
	# Solid dark fallback so the menu is never just "grey window"
	var solid_bg := ColorRect.new()
	solid_bg.color = Color(0.04, 0.03, 0.035, 1.0)
	solid_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(solid_bg)
	move_child(solid_bg, 0)  # put behind the photo Background and everything else

	# Load the generated cabin photo at runtime (no editor import dependency)
	var img := Image.new()
	if img.load("res://assets/art/cabin_interior.jpg") == OK:
		var tex := ImageTexture.create_from_image(img)
		bg.texture = tex
		bg.modulate = Color(0.72, 0.68, 0.62, 1.0)  # desaturated cold tone
	else:
		print("[MainMenu] Warning: could not load title background image")

	_build_ui()

	# Subtle drone on menu
	if AudioManager:
		AudioManager.start_ambient(0.18, 0.06)

	print("[MainMenu] HOLLOW ready. Click Begin or Continue.")

func _build_ui() -> void:
	# Dark overlay for readability
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Title
	var title := Label.new()
	title.text = "HOLLOW"
	title.position = Vector2(120, 160)
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.88, 0.82, 0.72))
	add_child(title)

	var tag := Label.new()
	tag.text = "A short psychological horror experience"
	tag.position = Vector2(124, 238)
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	add_child(tag)

	# Buttons
	start_btn = Button.new()
	start_btn.text = "Begin"
	start_btn.position = Vector2(124, 300)
	start_btn.size = Vector2(220, 46)
	start_btn.pressed.connect(_on_start)
	add_child(start_btn)

	continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.position = Vector2(124, 356)
	continue_btn.size = Vector2(220, 42)
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)
	_refresh_continue()

	controls_btn = Button.new()
	controls_btn.text = "Controls"
	controls_btn.position = Vector2(124, 412)
	controls_btn.size = Vector2(220, 42)
	controls_btn.pressed.connect(_show_controls)
	add_child(controls_btn)

	quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.position = Vector2(124, 468)
	quit_btn.size = Vector2(220, 42)
	quit_btn.pressed.connect(func(): get_tree().quit())
	add_child(quit_btn)

	# Controls panel (hidden)
	controls_panel = Control.new()
	controls_panel.visible = false
	controls_panel.position = Vector2(420, 140)
	controls_panel.size = Vector2(520, 420)
	add_child(controls_panel)

	var cp_bg := PanelContainer.new()
	cp_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.035, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.18, 0.22, 1)
	cp_bg.add_theme_stylebox_override("panel", style)
	controls_panel.add_child(cp_bg)
	cp_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var ctrl_text := RichTextLabel.new()
	ctrl_text.text = """[b]Movement[/b]
WASD — Walk
Shift — Sprint (drains light faster)

[b]Interaction[/b]
Mouse — Look (click or move mouse in the 3D window to capture the cursor — required on macOS)
E — Examine objects, open doors, read documents
F — Toggle flashlight

[b]Interface[/b]
Tab / J — Open your collected notes (Journal)
Esc — Pause / Menu (Save Progress)

[b]Atmosphere[/b]
The light is your only reliable tool.
The house reacts to how long you stay and what you choose to read.

When the battery dies, stand still.
Progress is auto-saved when you discover documents or unlock the basement.
"""
	ctrl_text.position = Vector2(24, 36)
	ctrl_text.size = Vector2(470, 320)
	ctrl_text.bbcode_enabled = true
	cp_bg.add_child(ctrl_text)

	var controls_title := Label.new()
	controls_title.text = "Controls"
	controls_title.position = Vector2(24, 8)
	controls_title.add_theme_font_size_override("font_size", 20)
	cp_bg.add_child(controls_title)

	var close := Button.new()
	close.text = "Back"
	close.position = Vector2(380, 370)
	close.pressed.connect(_hide_controls)
	cp_bg.add_child(close)

func _refresh_continue() -> void:
	if continue_btn == null:
		return
	var can := GameManager != null and GameManager.has_save()
	continue_btn.disabled = not can
	continue_btn.modulate = Color(1, 1, 1, 1) if can else Color(1, 1, 1, 0.45)
	if can:
		continue_btn.tooltip_text = "Resume your last visit to the property."
	else:
		continue_btn.tooltip_text = "No saved progress yet."

func _on_start() -> void:
	if GameManager:
		GameManager.reset_for_new_game()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_continue() -> void:
	if GameManager == null or not GameManager.has_save():
		_refresh_continue()
		return
	if not GameManager.load_game():
		_refresh_continue()
		return
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _show_controls() -> void:
	controls_panel.visible = true
	start_btn.visible = false
	if continue_btn:
		continue_btn.visible = false
	controls_btn.visible = false
	quit_btn.visible = false

func _hide_controls() -> void:
	controls_panel.visible = false
	start_btn.visible = true
	if continue_btn:
		continue_btn.visible = true
	controls_btn.visible = true
	quit_btn.visible = true