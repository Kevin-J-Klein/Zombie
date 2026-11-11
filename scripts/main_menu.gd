extends Control
## Hauptmenue. Wird im Code aufgebaut.

var help_panel: PanelContainer


func _ready() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var bg := ColorRect.new()
	bg.color = Color("#1c2a1c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Deko: eine Reihe Zombies am unteren Rand
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -150.0
	row.offset_bottom = -18.0
	add_child(row)
	# Pack-Zombies (normale und Axt-Zombies), die langsam auf der Stelle schlurfen
	for i in 9:
		var group := "zombie_big" if i == 4 else ("zombie_axe" if i % 3 == 1 else "zombie_small")
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(96, 132)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var z := AnimatedSprite2D.new()
		z.sprite_frames = SheetAnims.frames(group)
		z.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z.scale = Vector2(5, 5)
		z.position = Vector2(48, 132 + SheetAnims.foot_offset(group) * 5.0)
		z.modulate = Color(1, 1, 1, 0.6)
		z.play(&"walk_down")
		z.frame = i % 6
		z.speed_scale = 0.6
		holder.add_child(z)
		row.add_child(holder)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.0
	box.anchor_bottom = 0.0
	box.offset_left = -210.0
	box.offset_right = 210.0
	box.offset_top = 70.0
	add_child(box)

	var title := Label.new()
	title.text = "ZOMBIE GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#c8281e"))
	title.add_theme_color_override("font_outline_color", Color("#1a0a08"))
	title.add_theme_constant_override("outline_size", 14)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Überlebe die Runden. Ruf den Helikopter. Entkomme."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color("#e8dcc0"))
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	box.add_child(gap)

	box.add_child(_button("Spielen", _play))
	box.add_child(_button("Steuerung", _toggle_help))
	box.add_child(_button("Beenden", get_tree().quit))

	help_panel = PanelContainer.new()
	help_panel.add_theme_stylebox_override("panel", G.pack_panel())
	help_panel.visible = false
	var help := Label.new()
	help.text = "WASD  bewegen  ·  Maus  zielen  ·  Linksklick  schiessen\nR  nachladen  ·  Rechtsklick / V  Messer  ·  Shift  sprinten\nE  benutzen / kaufen  ·  E halten  Barrikade reparieren\nQ / 1 / 2  Waffe wechseln  ·  Esc  Pause"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", G.UI_TEXT)
	help_panel.add_child(help)
	box.add_child(help_panel)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 22)
	G.style_button(b)
	b.pressed.connect(action)
	return b


func _play() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _toggle_help() -> void:
	help_panel.visible = not help_panel.visible
