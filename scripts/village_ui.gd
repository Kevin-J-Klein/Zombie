class_name VillageUi
extends CanvasLayer
## Oberflaeche im Dorf: Schrott-Anzeige, Namensschilder, Hinweise und die Fenster
## Haus, Shop, Auftragsbrett, Navi und Einstellungen. Wird komplett im Code aufgebaut,
## im selben Stil wie die Menues im Level (hud.gd).

const TEXT := Color("#efe3c8")
const MUTED := Color("#b9ab9c")
const GOLD := Color("#f2c230")
const GREEN := Color("#8fd88a")
const ORANGE := Color("#e88040")


var village: Node
var root: Control
var scrap_label: Label
var slot_label: Label
var prompt_label: Label
var alert_label: Label
var tags: Array[Dictionary] = []
var dim: ColorRect
var window: Control          # das offene Fenster (oder null)
var window_kind := ""
var navi_dest := HubData.START_DEST


func setup(p_village: Node) -> void:
	village = p_village
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	_build_tags()
	dim = ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.1, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	root.add_child(dim)
	Save.changed.connect(_on_save_changed)
	_on_save_changed()


# ------------------------------------------------------------------ Bausteine

func _place(c: Control, ax: float, ay: float, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h


func _label(text: String, font_size: int, color := TEXT, outline := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
		l.add_theme_constant_override("outline_size", maxi(4, font_size / 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, action: Callable, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 44)
	b.add_theme_font_size_override("font_size", 18)
	G.style_button(b)
	b.pressed.connect(action)
	return b


func _icon(tex: Texture2D, w: float, h: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = Vector2(w, h)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Schrott-Betrag mit Symbol
func _scrap(amount: int, font_size := 20, color := TEXT) -> HBoxContainer:
	var h := _hbox(6)
	h.add_child(_icon(Pack.tex("ui/scrap"), 30, 24))
	h.add_child(_label(HubData.num(amount), font_size, color))
	return h


## Zeile in einer Liste: dunkler Kasten mit farbigem Rand links
func _row(accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.12, 0.55)
	sb.border_color = accent
	sb.border_width_left = 4
	sb.set_content_margin_all(8)
	sb.content_margin_left = 14
	p.add_theme_stylebox_override("panel", sb)
	return p


func _bar(value: float, max_value: float, fill: Color, w := 150.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, 12)
	b.max_value = max_value
	b.value = value
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.06, 0.85)
	bg.border_color = Color("#e8dcc0")
	bg.set_border_width_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_border_width_all(2)
	fg.border_color = Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


# ------------------------------------------------------------------ Anzeige im Dorf

func _build_hud() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", G.tex_style("panel", 18.0, 14.0))
	_place(p, 0, 0, 16, 16, 190, 56)
	var h := _hbox(10)
	h.add_child(_icon(Pack.tex("ui/scrap"), 38, 30))
	scrap_label = _label("0", 26)
	scrap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(scrap_label)
	h.add_child(_label("Schrott", 14, MUTED))
	p.add_child(h)
	root.add_child(p)
	# Name des Speicherplatzes
	slot_label = _label("", 14, TEXT, true)
	_place(slot_label, 0, 0, 22, 74, 260, 22)
	root.add_child(slot_label)

	var title := _label("ZOMBIE GAME", 32, Color("#c8281e"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(title, 0.5, 0, -300, 8, 600, 46)
	root.add_child(title)

	var gear := Button.new()
	gear.icon = Pack.tex("ui/gear")
	gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear.tooltip_text = "Einstellungen (Esc)"
	gear.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed"]:
		gear.add_theme_stylebox_override(st, G.pack_cell(st != "normal"))
	gear.pressed.connect(open.bind("settings"))
	_place(gear, 1, 0, -74, 16, 58, 60)
	root.add_child(gear)

	prompt_label = _label("", 20, Color.WHITE, true)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(prompt_label, 0.5, 1, -500, -96, 1000, 36)
	root.add_child(prompt_label)

	var hint := _label("WASD  laufen   ·   Shift  sprinten   ·   E  benutzen   ·   Esc  Einstellungen", 14, TEXT, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(hint, 0.5, 1, -500, -40, 1000, 26)
	root.add_child(hint)


## Namensschilder schweben ueber den Orten und folgen der Kamera.
## Das Schild des Auftragsbretts bekommt ein "!", wenn es dort etwas Neues gibt.
func _build_tags() -> void:
	for t: Dictionary in village.tags:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.08, 0.14, 0.8)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 2
		sb.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := _hbox(8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_label(t["text"], 15))
		if t.get("alert", false):
			alert_label = _label("!", 18, ORANGE)
			h.add_child(alert_label)
		p.add_child(h)
		root.add_child(p)
		tags.append({"node": p, "pos": t["pos"]})


func _process(_delta: float) -> void:
	var xf := get_viewport().get_canvas_transform()
	for t: Dictionary in tags:
		var node: Control = t["node"]
		var world: Vector2 = t["pos"]
		node.reset_size()
		node.position = (xf * world - node.size * Vector2(0.5, 1.0)).round()


func set_prompt(text: String) -> void:
	prompt_label.text = text


func _on_save_changed() -> void:
	scrap_label.text = HubData.num(Save.scrap())
	slot_label.text = str(Save.data["name"])
	alert_label.visible = Save.board_alert()
	if window != null and window_kind != "settings":
		_rebuild()


# ------------------------------------------------------------------ Fenster allgemein

func window_open() -> bool:
	return window != null


func open(kind: String) -> void:
	if Fade.busy:
		return
	window_kind = kind
	if kind == "board":
		Save.board_seen()
	if kind == "car":
		navi_dest = Save.current_dest
	_rebuild()


func close() -> void:
	if window == null:
		return
	window.queue_free()
	window = null
	window_kind = ""
	dim.visible = false
	village.on_window_closed()


func _rebuild() -> void:
	if window != null:
		window.queue_free()
		window = null
	dim.visible = true
	match window_kind:
		"house":
			_build_house()
		"shop":
			_build_shop()
		"board":
			_build_board()
		"car":
			_build_navi()
		"settings":
			_build_settings()


## Leeres Fenster im Pack-Stil mit Titel. Gibt die VBox fuer den Inhalt zurueck.
func _window(title: String, w: float, h: float) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", G.pack_panel())
	_place(p, 0.5, 0.5, -w * 0.5, -h * 0.5, w, h)
	root.add_child(p)
	window = p
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	p.add_child(m)
	var v := _vbox(10)
	m.add_child(v)
	var t := _label(title, 32)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


func _footer(v: VBoxContainer, hint: String) -> void:
	var h := _hbox(12)
	h.add_child(_scrap(Save.scrap()))
	var l := _label(hint, 14, MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(l)
	h.add_child(_button("Schliessen", close, 150))
	v.add_child(h)


func _input(event: InputEvent) -> void:
	if Fade.busy:
		return
	if event.is_action_pressed("pause"):
		if window != null:
			close()
		else:
			open("settings")
		get_viewport().set_input_as_handled()
	elif window != null and event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ Haus: Rekorde und Startwaffe

func _build_house() -> void:
	var v := _window("DEIN HAUS", 800, 500)
	var cols := _hbox(32)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	var left := _vbox(6)
	left.custom_minimum_size = Vector2(340, 0)
	cols.add_child(left)
	left.add_child(_label("TROPHÄENWAND", 14, GOLD))
	var d: Dictionary = Save.data
	var fastest: float = d["fastest_escape"]
	for row in [["Beste Runde", str(d["best_round"]) if d["best_round"] > 0 else "–"],
			["Schnellste Flucht", HubData.time_text(fastest) if fastest > 0.0 else "–"],
			["Meiste Kills", HubData.num(d["most_kills"]) if d["most_kills"] > 0 else "–"],
			["Partien gespielt", str(d["games"])],
			["Schrott gesamt", HubData.num(d["scrap_total"])]]:
		var h := _hbox()
		var name_l := _label(row[0], 18, MUTED)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_l)
		h.add_child(_label(row[1], 20))
		left.add_child(h)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	left.add_child(gap)
	left.add_child(_label("EASTER EGGS", 14, GOLD))
	for egg in [["gnomes", "Alle Glückspilze erwischt"], ["escape", "Mit dem Helikopter geflohen"]]:
		var found: bool = d["eggs"][egg[0]]
		left.add_child(_label(("✔  " + egg[1]) if found else "?  ? ? ?", 18, GREEN if found else MUTED))

	var right := _vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(_label("WAFFENSTÄNDER", 14, GOLD))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	right.add_child(grid)
	for id: String in HubData.START_WEAPONS:
		var cell := _vbox(2)
		var b := Button.new()
		b.custom_minimum_size = Vector2(76, 76)
		b.focus_mode = Control.FOCUS_NONE
		var chosen := Save.start_weapon() == id
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, G.pack_cell(chosen or st == "hover"))
		if Save.owns(id):
			b.icon = G.weapon_icon(id)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b.pressed.connect(Save.set_start_weapon.bind(id))
		else:
			b.text = "?"
			b.disabled = true
			b.add_theme_font_size_override("font_size", 26)
			b.add_theme_color_override("font_disabled_color", MUTED)
		cell.add_child(b)
		var n := _label(G.WEAPONS[id]["name"] if Save.owns(id) else "", 13, ORANGE if chosen else TEXT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.custom_minimum_size = Vector2(76, 0)
		n.clip_text = true
		cell.add_child(n)
		grid.add_child(cell)
	var sw := _hbox(8)
	sw.add_child(_label("Startwaffe:", 18, MUTED))
	sw.add_child(_label(G.WEAPONS[Save.start_weapon()]["name"], 20, ORANGE))
	right.add_child(sw)
	var info := _label("Klick auf eine Waffe wählt sie als Startwaffe. Damit beginnst du die nächste Partie statt mit der Pistole. Weitere Waffen gibt es beim Händler.", 14, MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(info)
	_footer(v, "E oder Esc schliesst")


# ------------------------------------------------------------------ Shop: Startwaffen fuer Schrott

func _build_shop() -> void:
	var v := _window("SHOP", 720, 560)
	var quote := _label("«Schrott gegen Feuerkraft. Was darf es sein?»", 16, MUTED)
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(quote)
	var list := _vbox(6)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(list)
	for id: String in HubData.START_WEAPONS:
		var owned := Save.owns(id)
		var cost: int = HubData.START_WEAPONS[id]
		var row := _row(GREEN if owned else MUTED)
		var h := _hbox(14)
		row.add_child(h)
		h.add_child(_icon(G.weapon_icon(id), 60, 44))
		var texts := _vbox(0)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(_label(G.WEAPONS[id]["name"], 20))
		texts.add_child(_label(HubData.WEAPON_BLURB[id], 14, MUTED))
		h.add_child(texts)
		if owned:
			var got := _label("Gekauft", 18, GREEN)
			got.custom_minimum_size = Vector2(140, 0)
			got.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.add_child(got)
		else:
			h.add_child(_scrap(cost, 20, TEXT if Save.scrap() >= cost else Color("#ff6a5a")))
			var b := _button("Kaufen", _buy_weapon.bind(id), 140)
			b.disabled = Save.scrap() < cost
			h.add_child(b)
		list.add_child(row)
	_footer(v, "Gekaufte Waffen im Haus als Startwaffe wählen")


func _buy_weapon(id: String) -> void:
	Save.buy_weapon(id)


# ------------------------------------------------------------------ Auftragsbrett

func _build_board() -> void:
	var v := _window("AUFTRAGSBRETT", 820, 600)
	var top := _hbox()
	top.add_child(_label("Aktive Aufträge: %d / %d" % [Save.active_count(), HubData.MAX_ACTIVE_CONTRACTS], 18))
	var note := _label("Neue Aufträge nach jeder Partie", 14, MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(note)
	v.add_child(top)
	var list := _vbox(6)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(list)
	var full := Save.active_count() >= HubData.MAX_ACTIVE_CONTRACTS
	for c: Dictionary in Save.contracts():
		var def: Dictionary = HubData.CONTRACTS[c["id"]]
		var state: String = c["state"]
		var accent := MUTED
		if state == "active":
			accent = ORANGE
		elif state == "done":
			accent = GREEN
		var row := _row(accent)
		var h := _hbox(14)
		row.add_child(h)
		var texts := _vbox(0)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(_label(def["name"], 20))
		texts.add_child(_label(def["text"], 14, MUTED))
		h.add_child(texts)
		var mid := _vbox(2)
		mid.custom_minimum_size = Vector2(200, 0)
		mid.add_child(_scrap(def["reward"]))
		if state != "open":
			var prog := _hbox(8)
			prog.add_child(_bar(c["progress"], def["target"], GREEN if state == "done" else ORANGE, 120))
			prog.add_child(_label("%d/%d" % [c["progress"], def["target"]], 14, GREEN if state == "done" else TEXT))
			mid.add_child(prog)
		h.add_child(mid)
		match state:
			"open":
				var b := _button("Annehmen", Save.accept_contract.bind(c["id"]), 150)
				b.disabled = full
				h.add_child(b)
			"active":
				h.add_child(_button("Abbrechen", Save.cancel_contract.bind(c["id"]), 150))
			"done":
				h.add_child(_button("Abholen", Save.claim_contract.bind(c["id"]), 150))
		list.add_child(row)
	_footer(v, "Aufträge erfüllst du in den Zombie-Levels")


# ------------------------------------------------------------------ Navi: Ziel waehlen und losfahren

func _build_navi() -> void:
	var p := PanelContainer.new()
	var body := StyleBoxFlat.new()
	body.bg_color = Color("#34323e")
	body.border_color = Color("#18141c")
	body.set_border_width_all(6)
	body.set_corner_radius_all(18)
	body.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", body)
	_place(p, 0.5, 0.5, -450, -280, 900, 560)
	root.add_child(p)
	window = p
	var v := _vbox(10)
	p.add_child(v)
	var screen := _hbox(0)
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(screen)

	var map := NaviMap.new()
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.selected = navi_dest
	map.picked.connect(_navi_pick)
	screen.add_child(map)

	var info_panel := PanelContainer.new()
	var ib := StyleBoxFlat.new()
	ib.bg_color = Color("#242830")
	ib.set_content_margin_all(16)
	info_panel.add_theme_stylebox_override("panel", ib)
	info_panel.custom_minimum_size = Vector2(300, 0)
	screen.add_child(info_panel)
	var info := _vbox(6)
	info_panel.add_child(info)

	var dest: Dictionary = HubData.DESTINATIONS[navi_dest]
	var unlocked := Save.dest_unlocked(navi_dest)
	var stats := Save.dest_stats(navi_dest)
	info.add_child(_label("ZIEL", 13, MUTED))
	info.add_child(_label(dest["name"], 32, ORANGE))
	info.add_child(_label("Schwierigkeit", 14, MUTED))
	var skulls := _hbox(4)
	for i in 4:
		skulls.add_child(_icon(Pack.tex("ui/skull" if i < int(dest["skulls"]) else "ui/skull_off"), 21, 21))
	info.add_child(skulls)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	info.add_child(gap)
	for row in [["Gebiete", str(dest["areas"])],
			["Beste Runde", str(stats["best_round"]) if stats["best_round"] > 0 else "–"],
			["Geflohen", "%d×" % stats["escapes"]],
			["Schrott-Bonus", "×%s" % str(dest["bonus"]).replace(".", ",")]]:
		var h := _hbox()
		var name_l := _label(row[0], 16, MUTED)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_l)
		h.add_child(_label(row[1], 18))
		info.add_child(h)
	info.add_child(_label("Mission", 14, MUTED))
	var mission := _label(dest["mission"], 16)
	mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(mission)
	info.add_child(_spacer())
	if not unlocked:
		var lock := _label("Gesperrt\n" + HubData.unlock_text(navi_dest), 16, Color("#ff8a7a"))
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(lock)
	elif dest["scene"] == "":
		info.add_child(_label("Freigeschaltet, aber das\nLevel ist noch im Bau", 16, GOLD))
	var go := _button("Losfahren", _navi_go, 0)
	go.disabled = not Save.dest_playable(navi_dest)
	info.add_child(go)
	if not go.disabled:
		go.grab_focus.call_deferred()

	var bottom := _hbox()
	bottom.add_child(_label("NAVI-TRAX 3000", 13, MUTED))
	var hint := _label("Ziel auf der Karte anklicken   ·   Enter  losfahren   ·   Esc  aussteigen", 13, MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(hint)
	v.add_child(bottom)


func _navi_pick(dest_id: String) -> void:
	navi_dest = dest_id
	_rebuild()


func _navi_go() -> void:
	if not Save.dest_playable(navi_dest):
		return
	Save.current_dest = navi_dest
	var dest: Dictionary = HubData.DESTINATIONS[navi_dest]
	Fade.go(dest["scene"], dest["name"])


# ------------------------------------------------------------------ Einstellungen

func _build_settings() -> void:
	var v := _window("EINSTELLUNGEN", 520, 570)
	var vol := _hbox(12)
	var vol_l := _label("Lautstärke", 18)
	vol_l.custom_minimum_size = Vector2(150, 0)
	vol.add_child(vol_l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Save.setting("volume")
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(x: float) -> void: Save.set_setting("volume", x))
	vol.add_child(slider)
	v.add_child(vol)

	var full := _hbox(12)
	var full_l := _label("Vollbild", 18)
	full_l.custom_minimum_size = Vector2(150, 0)
	full.add_child(full_l)
	var check := CheckButton.new()
	check.button_pressed = Save.setting("fullscreen")
	check.toggled.connect(func(on: bool) -> void: Save.set_setting("fullscreen", on))
	full.add_child(check)
	v.add_child(full)

	v.add_child(_label("STEUERUNG", 14, GOLD))
	var help := _label("WASD  bewegen          Maus  zielen\nLinksklick  schiessen     R  nachladen\nRechtsklick / V  Messer     Shift  sprinten\nE  benutzen / kaufen     Q / 1 / 2  Waffe wechseln\nE halten  Barrikade reparieren     Esc  Pause", 15)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	v.add_child(_spacer())
	var saved := _label("«%s» wird automatisch gespeichert" % str(Save.data["name"]), 14, MUTED)
	saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(saved)
	v.add_child(_button("Weiter", close))
	v.add_child(_button("Spielstand wechseln", _to_title))
	v.add_child(_button("Spiel beenden", _quit))


func _to_title() -> void:
	Save.write()
	Fade.go(Fade.TITLE)


func _quit() -> void:
	Save.write()
	get_tree().quit()
