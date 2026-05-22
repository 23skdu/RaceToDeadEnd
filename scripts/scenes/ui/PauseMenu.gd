extends CanvasLayer

signal resume_requested
signal options_requested
signal quit_requested

var panel: Panel
var resume_btn: Button
var options_btn: Button
var quit_btn: Button

func _ready() -> void:
	layer = 128
	_build_ui()

func _build_ui() -> void:
	panel = Panel.new()
	var vp_size = Vector2(1280, 720)
	var vp = get_viewport()
	if vp:
		vp_size = vp.get_visible_rect().size
	panel.size = Vector2(300, 250)
	panel.position = Vector2(
		(vp_size.x - 300) / 2,
		(vp_size.y - 250) / 2
	)
	add_child(panel)

	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.position = Vector2(0, 20)
	title.size = Vector2(300, 40)
	panel.add_child(title)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(50, 80)
	vbox.size = Vector2(200, 140)
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.offset_left = 50
	vbox.offset_top = 80
	vbox.offset_right = -50
	vbox.offset_bottom = -30
	panel.add_child(vbox)

	resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.size = Vector2(200, 40)
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	options_btn = Button.new()
	options_btn.text = "Options"
	options_btn.size = Vector2(200, 40)
	options_btn.pressed.connect(_on_options)
	vbox.add_child(options_btn)

	quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.size = Vector2(200, 40)
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)

func _on_resume() -> void:
	resume_requested.emit()

func _on_options() -> void:
	options_requested.emit()

func _on_quit() -> void:
	quit_requested.emit()
