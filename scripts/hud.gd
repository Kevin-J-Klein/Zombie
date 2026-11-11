class_name Hud
extends CanvasLayer
## Anzeige im Spiel: Leben, Ausdauer, Punkte, Runde, Waffe, Hotbar, Ziel,
## Hinweise sowie Shop-, Pause- und End-Menue. Wird komplett im Code aufgebaut.

const TEXT := Color("#efe3c8")   # heller Text auf den dunklen Pack-Panels (= G.UI_TEXT)

var game: Node
var root: Control

var hp_bar: TextureProgressBar
var armor_bar: TextureProgressBar
var stamina_bar: TextureProgressBar
var bullet_icon: TextureRect
var reload_bar: ProgressBar
var points_label: Label
var round_label: Label
var objective_label: Label
var weapon_label: Label
var ammo_label: Label
var prompt_label: Label
var announce_label: Label
var announce_sub: Label
var timers_label: Label
var flash_rect: ColorRect
var low_rect: ColorRect
var slots: Array[Dictionary] = []

var shop_panel: PanelContainer
var shop_list: VBoxContainer
var shop_points: Label
var shop_items: Array[Dictionary] = []
var pause_panel: PanelContainer
var end_panel: PanelContainer
var announce_t := 0.0
var slot_normal := G.pack_cell(false)
var slot_selected := G.pack_cell(true)


func setup(p_game: Node) -> void:
	game = p_game
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	low_rect = _overlay(Color(0.7, 0.0, 0.0, 0.0))
	flash_rect = _overlay(Color(1, 1, 1, 0.0))

	_build_status()
	_build_points_and_objective()
	_build_round()
	_build_hotbar()
	_build_weapon()
	_build_texts()
	_build_shop()
	_build_pause()
	_build_end()


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


func _overlay(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


func _label(text: String, font_size: int, color := Color.WHITE, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
		l.add_theme_constant_override("outline_size", maxi(4, font_size / 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(fill: Color, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.06, 0.85)
	bg.border_color = Color("#e8dcc0")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	fg.set_border_width_all(2)
	fg.border_color = Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Leiste aus dem Pack: Rahmen (mit Symbol) oben, Fuellung in der Rinne, darunter dunkle Rinne.
## Alle Grafiken sind 3x vergroessert; die Fuellung sitzt bei (fx, fy) Pack-Pixeln.
func _tex_bar(name: String, fill: String, fx: int, fy: int) -> TextureProgressBar:
	var b := TextureProgressBar.new()
	b.texture_under = load("res://art/pack/ui/%s_under.png" % name)
	b.texture_over = load("res://art/pack/ui/%s_over.png" % name)
	b.texture_progress = load("res://art/pack/ui/%s.png" % fill)
	b.texture_progress_offset = Vector2(fx, fy) * 3.0
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.max_value = 100.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	G.style_button(b)
	b.pressed.connect(action)
	return b


func _build_status() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_place(box, 0, 0, 16, 16, 320, 130)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	# Herz = Leben, blaues Herz = Panzerung (nur sichtbar, wenn gekauft), Keule = Ausdauer
	hp_bar = _tex_bar("hp", "hp_fill", 10, 4)
	armor_bar = _tex_bar("armor", "armor_fill", 10, 4)
	stamina_bar = _tex_bar("stamina", "stamina_fill", 11, 6)
	for b in [hp_bar, armor_bar, stamina_bar]:
		box.add_child(b)


func _build_points_and_objective() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_place(box, 1, 0, -356, 16, 340, 220)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", G.tex_style("res://art/pack/ui/panel.png", 18.0, 14.0))
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(26, 26)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("#f2c230")
	cs.border_color = Color("#a8761a")
	cs.set_border_width_all(3)
	cs.set_corner_radius_all(13)
	coin.add_theme_stylebox_override("panel", cs)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(coin)
	points_label = _label("500", 26, TEXT, false)
	points_label.custom_minimum_size = Vector2(110, 0)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(points_label)
	p.add_child(h)
	box.add_child(p)

	var o := PanelContainer.new()
	o.add_theme_stylebox_override("panel", G.panel_style(Color(0.17, 0.11, 0.21, 0.78), Color("#c3b7a4"), 3))
	o.size_flags_horizontal = Control.SIZE_SHRINK_END
	var v := VBoxContainer.new()
	v.add_child(_label("ZIEL", 12, Color("#f2c230"), false))
	objective_label = _label("", 16, Color.WHITE, false)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(300, 0)
	v.add_child(objective_label)
	o.add_child(v)
	box.add_child(o)


func _build_round() -> void:
	round_label = _label("", 84, Color("#b01414"))
	_place(round_label, 0, 1, 24, -124, 260, 110)
	round_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(round_label)


func _build_hotbar() -> void:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 4)
	_place(hb, 0.5, 1, -260, -78, 520, 62)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hb)
	for i in 7:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(57, 60)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(icon)
		var num := _label(str(i + 1) if i < 2 else "", 12, TEXT, false)
		num.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		p.add_child(num)
		hb.add_child(p)
		p.add_theme_stylebox_override("panel", slot_normal)
		slots.append({"panel": p, "icon": icon, "selected": false})


func _build_weapon() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	_place(box, 1, 1, -336, -140, 320, 124)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	weapon_label = _label("", 18)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label = _label("", 38)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Patrone aus dem Pack neben der Munitionszahl
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bullet_icon = TextureRect.new()
	bullet_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	bullet_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bullet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bullet_icon)
	row.add_child(ammo_label)
	reload_bar = _bar(Color("#f2c230"), 160, 8)
	reload_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(weapon_label)
	box.add_child(row)
	box.add_child(reload_bar)


func _build_texts() -> void:
	prompt_label = _label("", 20)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(prompt_label, 0.5, 1, -500, -128, 1000, 36)
	root.add_child(prompt_label)

	timers_label = _label("", 18, Color("#f2c230"))
	timers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(timers_label, 0.5, 0, -400, 16, 800, 30)
	root.add_child(timers_label)

	announce_label = _label("", 36)
	announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(announce_label, 0.5, 0, -600, 92, 1200, 50)
	root.add_child(announce_label)
	announce_sub = _label("", 18, Color("#f0e0c0"))
	announce_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(announce_sub, 0.5, 0, -600, 142, 1200, 30)
	root.add_child(announce_sub)


func _menu_panel(w: float, h: float) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", G.pack_panel())
	_place(p, 0.5, 0.5, -w * 0.5, -h * 0.5, w, h)
	p.visible = false
	root.add_child(p)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	return [p, v]


func _title(text: String, color := TEXT) -> Label:
	var l := _label(text, 34, color, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_shop() -> void:
	var pv := _menu_panel(500, 440)
	shop_panel = pv[0]
	var v: VBoxContainer = pv[1]
	v.add_child(_title("SHOP"))
	shop_points = _label("", 18, TEXT, false)
	shop_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(shop_points)
	shop_list = VBoxContainer.new()
	shop_list.add_theme_constant_override("separation", 6)
	shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(shop_list)
	var hint := _label("Zahlentaste oder Klick zum Kaufen  ·  E oder Esc schliesst", 14, TEXT, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


func _build_pause() -> void:
	var pv := _menu_panel(460, 470)
	pause_panel = pv[0]
	var v: VBoxContainer = pv[1]
	v.add_child(_title("PAUSE"))
	var help := _label("WASD  bewegen          Maus  zielen\nLinksklick  schiessen     R  nachladen\nRechtsklick / V  Messer     Shift  sprinten\nE  benutzen / kaufen     Q / 1 / 2  Waffe wechseln\nE halten  Barrikade reparieren", 15, TEXT, false)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	v.add_child(_button("Weiter", _toggle_pause))
	v.add_child(_button("Neustart", _restart))
	v.add_child(_button("Hauptmenü", _to_menu))


func _build_end() -> void:
	var pv := _menu_panel(460, 400)
	end_panel = pv[0]


# ------------------------------------------------------------------ Laufende Anzeige

func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game.player):
		return
	var p: Player = game.player
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	armor_bar.value = p.armor
	armor_bar.visible = p.armor > 0.0
	stamina_bar.max_value = p.max_stamina
	stamina_bar.value = p.stamina
	points_label.text = str(game.points)
	round_label.text = str(game.round_num) if game.round_num > 0 else ""
	objective_label.text = game.objective_text()
	prompt_label.text = "" if game.menu_open or game.over else p.prompt_text

	var w := p.weapon()
	weapon_label.text = G.weapon_name(w["id"], w["level"])
	ammo_label.text = "%d / %d" % [w["mag"], w["reserve"]]
	bullet_icon.texture = G.bullet_icon(w["id"])
	ammo_label.add_theme_color_override("font_color", Color("#ff6a5a") if w["mag"] <= p.mag_size(w) / 4 else Color.WHITE)
	reload_bar.visible = p.reload_t > 0.0
	if p.reload_t > 0.0:
		reload_bar.value = (1.0 - p.reload_t / p.reload_total) * 100.0

	for i in slots.size():
		var s: Dictionary = slots[i]
		var icon: TextureRect = s["icon"]
		var selected := false
		if i < 2:
			if i < p.weapons.size():
				icon.texture = G.weapon_icon(p.weapons[i]["id"])
				icon.modulate = Color.WHITE if p.weapons[i]["level"] == 0 else Color(1.15, 0.85, 1.35)
				selected = i == p.current
			else:
				icon.texture = null
		else:
			var pi := i - 2
			if pi < game.perks.size():
				icon.texture = preload("res://art/perk_icon.png")
				icon.modulate = G.PERKS[game.perks[pi]]["color"]
			else:
				icon.texture = null
		if s["selected"] != selected:
			s["selected"] = selected
			s["panel"].add_theme_stylebox_override("panel", slot_selected if selected else slot_normal)

	var timers: PackedStringArray = []
	if game.insta_kill_t > 0.0:
		timers.append("Sofort-Kill %ds" % ceili(game.insta_kill_t))
	if game.double_points_t > 0.0:
		timers.append("Doppelte Punkte %ds" % ceili(game.double_points_t))
	timers_label.text = "     ".join(timers)

	if announce_t > 0.0:
		announce_t -= delta
		var a := clampf(announce_t / 0.6, 0.0, 1.0)
		announce_label.modulate.a = a
		announce_sub.modulate.a = a

	flash_rect.color.a = move_toward(flash_rect.color.a, 0.0, delta * 1.6)
	var low := 1.0 - clampf(p.hp / (p.max_hp * 0.5), 0.0, 1.0)
	low_rect.color.a = low * 0.28

	if shop_panel.visible:
		shop_points.text = "Punkte: %d" % game.points


func announce(text: String, sub := "") -> void:
	announce_label.text = text
	announce_sub.text = sub
	announce_label.modulate.a = 1.0
	announce_sub.modulate.a = 1.0
	announce_t = 3.5 if sub == "" else 5.5


func show_round(n: int) -> void:
	announce("Runde %d" % n)
	round_label.modulate = Color(3, 3, 3)
	var tw := create_tween()
	tw.tween_property(round_label, "modulate", Color.WHITE, 1.2)


func flash(color: Color) -> void:
	flash_rect.color = color


# ------------------------------------------------------------------ Shop

func open_shop() -> void:
	shop_panel.visible = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_rebuild_shop()


func close_shop() -> void:
	shop_panel.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)


func _rebuild_shop() -> void:
	for c in shop_list.get_children():
		c.queue_free()
	shop_items = game.shop_items()
	for i in shop_items.size():
		var it: Dictionary = shop_items[i]
		var b := _button("[%d]   %s   –   %d" % [i + 1, it["label"], it["cost"]], _buy.bind(it["id"]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not it["enabled"]
		shop_list.add_child(b)


func _buy(id: String) -> void:
	game.buy_shop_item(id)
	_rebuild_shop()


# ------------------------------------------------------------------ Eingaben fuer Menues

func _input(event: InputEvent) -> void:
	if game == null or game.over:
		return
	if event.is_action_pressed("pause"):
		if game.menu_open:
			game.close_shop()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()
	elif game.menu_open and not get_tree().paused:
		if event.is_action_pressed("interact"):
			game.close_shop()
		elif event is InputEventKey and event.pressed and not event.echo:
			var idx: int = event.physical_keycode - KEY_1
			if idx >= 0 and idx < shop_items.size():
				_buy(shop_items[idx]["id"])


func _toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	pause_panel.visible = tree.paused
	Input.set_default_cursor_shape(Input.CURSOR_ARROW if tree.paused else Input.CURSOR_CROSS)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ------------------------------------------------------------------ Ende

func show_end(victory: bool) -> void:
	shop_panel.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var v: VBoxContainer = end_panel.get_child(0).get_child(0)
	for c in v.get_children():
		c.queue_free()
	v.add_child(_title("GESCHAFFT!" if victory else "GAME OVER", Color("#8fd88a") if victory else Color("#e0483a")))
	var sub := "Du bist mit dem Helikopter entkommen." if victory else "Die Zombies haben dich erwischt."
	var s := _label(sub, 17, TEXT, false)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var r: Dictionary = G.last_result
	var t := int(r["time"])
	var stats := _label("Runde:  %d\nKills:  %d\nPunkte gesamt:  %d\nZeit:  %d:%02d" % [r["round"], r["kills"], r["points"], t / 60, t % 60], 20, TEXT, false)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	v.add_child(_button("Nochmal spielen", _restart))
	v.add_child(_button("Hauptmenü", _to_menu))
	end_panel.visible = true
	get_tree().paused = true
