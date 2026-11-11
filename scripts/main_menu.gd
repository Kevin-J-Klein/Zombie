extends Control
## Startbildschirm: einen von drei Speicherplaetzen waehlen (und benennen), dann geht es ins Dorf.
## Das Dorf ist das eigentliche Hauptmenue. Wird im Code aufgebaut.

const TEXT := Color("#efe3c8")
const MUTED := Color("#b9ab9c")
const GOLD := Color("#f2c230")

var slots_box: HBoxContainer
var name_edits := {}        # Platz -> LineEdit
var delete_armed := 0       # Platz, bei dem "Loeschen" schon einmal gedrueckt wurde


func _ready() -> void:
	get_tree().paused = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var bg := ColorRect.new()
	bg.color = Color("#1c2a1c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_zombie_row()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -580.0
	box.offset_right = 580.0
	box.offset_top = 34.0
	add_child(box)

	var title := Label.new()
	title.text = "ZOMBIE GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#c8281e"))
	title.add_theme_color_override("font_outline_color", Color("#1a0a08"))
	title.add_theme_constant_override("outline_size", 14)
	box.add_child(title)
	var sub := _label("Wähle einen Spielstand. Das Spiel speichert automatisch.", 18, Color("#e8dcc0"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	box.add_child(gap)

	slots_box = HBoxContainer.new()
	slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_box.add_theme_constant_override("separation", 20)
	box.add_child(slots_box)
	_rebuild()

	var quit := _button("Beenden", get_tree().quit)
	quit.anchor_left = 1.0
	quit.anchor_right = 1.0
	quit.offset_left = -176.0
	quit.offset_right = -16.0
	quit.offset_top = 16.0
	quit.offset_bottom = 60.0
	add_child(quit)


## Deko: eine Reihe Pack-Zombies am unteren Rand, die auf der Stelle schlurfen
func _build_zombie_row() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -150.0
	row.offset_bottom = -18.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
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


func _label(text: String, font_size: int, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	G.style_button(b)
	b.pressed.connect(action)
	return b


# ------------------------------------------------------------------ Speicherplaetze

func _rebuild() -> void:
	for c in slots_box.get_children():
		c.queue_free()
	name_edits.clear()
	for n in range(1, Save.SLOTS + 1):
		slots_box.add_child(_slot_card(n))


func _slot_card(n: int) -> PanelContainer:
	var info := Save.slot_info(n)
	var exists: bool = info["exists"]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", G.pack_panel())
	p.custom_minimum_size = Vector2(360, 330)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)

	var head := HBoxContainer.new()
	head.add_child(_label("PLATZ %d" % n, 14, GOLD))
	if exists and int(Save.setting("last_slot")) == n:
		var last := _label("zuletzt gespielt", 13, MUTED)
		last.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		last.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(last)
	v.add_child(head)

	# Name: bei leeren Plaetzen freiwillig, bei vorhandenen zum Umbenennen
	var edit := LineEdit.new()
	edit.text = info["name"]
	edit.placeholder_text = "Name (freiwillig)"
	edit.max_length = 18
	edit.add_theme_font_size_override("font_size", 20)
	edit.text_submitted.connect(func(_t: String) -> void: _play(n))
	if exists:
		edit.focus_exited.connect(func() -> void: Save.rename_slot(n, edit.text))
	v.add_child(edit)
	name_edits[n] = edit

	if exists:
		for row in [["Schrott", HubData.num(info["scrap"])],
				["Beste Runde", str(info["best_round"]) if info["best_round"] > 0 else "–"],
				["Partien", str(info["games"])],
				["Zuletzt", _date_text(info["played_at"])]]:
			var h := HBoxContainer.new()
			var name_l := _label(row[0], 16, MUTED)
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(name_l)
			h.add_child(_label(row[1], 17))
			v.add_child(h)
	else:
		var empty := _label("Leer", 22, MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(empty)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	v.add_child(_button("Spielen" if exists else "Neues Spiel", _play.bind(n)))
	if exists:
		v.add_child(_button("Wirklich löschen?" if delete_armed == n else "Löschen", _delete.bind(n)))
	return p


## "2026-11-11 16:40:12" -> "11.11.2026 16:40"
func _date_text(stamp: String) -> String:
	if stamp.length() < 16:
		return "–"
	return "%s.%s.%s %s" % [stamp.substr(8, 2), stamp.substr(5, 2), stamp.substr(0, 4), stamp.substr(11, 5)]


func _play(n: int) -> void:
	if Fade.busy:
		return
	var edit: LineEdit = name_edits[n]
	Save.select_slot(n, edit.text)
	Fade.to_village()


## Loeschen fragt einmal nach: erst der zweite Klick loescht.
func _delete(n: int) -> void:
	if delete_armed != n:
		delete_armed = n
	else:
		delete_armed = 0
		Save.delete_slot(n)
	_rebuild()
