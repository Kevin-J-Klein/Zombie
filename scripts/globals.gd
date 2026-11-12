extends Node
## Autoload "G": Spieldaten (Waffen, Perks, Preise) und Tastenbelegung.

const TILE := 16

## Kollisions-Ebenen (Bitwerte)
const L_WORLD := 1      # Waende, Tueren, Kisten
const L_PLAYER_BLOCK := 2  # Fenster: Spieler kommt nicht durch, Zombies und Kugeln schon
const L_HURT := 4       # Trefferzonen der Zombies

const START_POINTS := 500
const MAX_ZOMBIES_ALIVE := 24

## Panzer-Zombie (der grosse Zombie aus dem Asset-Pack): langsam, zaeh, schlaegt hart zu.
## Ab TANK_FROM_ROUND mit TANK_CHANCE_PER_ROUND mehr Wahrscheinlichkeit je Runde, hoechstens TANK_MAX_CHANCE.
const TANK_FROM_ROUND := 4
const TANK_CHANCE_PER_ROUND := 0.04
const TANK_MAX_CHANCE := 0.2
const TANK_HP_MULT := 4.0
const TANK_SPEED := 20.0
const TANK_DAMAGE := 80.0
const TANK_WINDUP := 0.55       # laenger ausholen als normale Zombies (0.3 s): Zeit zum Ausweichen
const TANK_TEAR_TIME := 0.8     # reisst Bretter schneller ab (normal 1.3 s)
const TANK_KILL_BONUS := 140    # zusaetzlich zu den normalen Kill-Punkten

## Waffen. damage = Schaden pro Kugel, rate = Sekunden zwischen Schuessen,
## pierce = wie viele Zombies eine Kugel durchschlaegt, box = nur aus der Mystery-Box.
const WEAPONS := {
	"pistol": {"name": "Pistole", "damage": 40.0, "mag": 8, "reserve": 96, "rate": 0.16, "reload": 1.3,
		"auto": false, "pellets": 1, "spread": 1.5, "pierce": 1, "range": 300.0, "cost": 0, "box": false, "splash": 0.0},
	"smg": {"name": "MP", "damage": 32.0, "mag": 30, "reserve": 180, "rate": 0.075, "reload": 1.6,
		"auto": true, "pellets": 1, "spread": 4.0, "pierce": 1, "range": 260.0, "cost": 1000, "box": true, "splash": 0.0},
	"shotgun": {"name": "Schrotflinte", "damage": 45.0, "mag": 6, "reserve": 54, "rate": 0.7, "reload": 2.0,
		"auto": false, "pellets": 7, "spread": 9.0, "pierce": 1, "range": 150.0, "cost": 1200, "box": true, "splash": 0.0},
	"rifle": {"name": "Sturmgewehr", "damage": 60.0, "mag": 30, "reserve": 210, "rate": 0.11, "reload": 2.0,
		"auto": true, "pellets": 1, "spread": 2.5, "pierce": 2, "range": 340.0, "cost": 1500, "box": true, "splash": 0.0},
	"dmr": {"name": "Präzisionsgewehr", "damage": 260.0, "mag": 10, "reserve": 80, "rate": 0.35, "reload": 2.2,
		"auto": false, "pellets": 1, "spread": 0.3, "pierce": 4, "range": 420.0, "cost": 1750, "box": true, "splash": 0.0},
	"lmg": {"name": "LMG", "damage": 58.0, "mag": 100, "reserve": 300, "rate": 0.085, "reload": 3.6,
		"auto": true, "pellets": 1, "spread": 4.5, "pierce": 2, "range": 340.0, "cost": 0, "box": true, "splash": 0.0},
	"raygun": {"name": "Strahlenkanone", "damage": 900.0, "mag": 20, "reserve": 160, "rate": 0.28, "reload": 2.4,
		"auto": false, "pellets": 1, "spread": 1.0, "pierce": 1, "range": 340.0, "cost": 0, "box": true, "splash": 26.0},
}

## Reihenfolge im Shop-Menue
const SHOP_WEAPONS := ["smg", "shotgun", "rifle", "dmr"]

const PERKS := {
	"revive": {"name": "Zweite Chance", "cost": 1500, "power": false, "color": Color("#4aa8e0"),
		"desc": "Rettet dich einmal vor dem Tod"},
	"health": {"name": "Stahlhaut", "cost": 2500, "power": true, "color": Color("#e0483a"),
		"desc": "Mehr Lebenspunkte"},
	"fire": {"name": "Doppelfeuer", "cost": 2000, "power": true, "color": Color("#e0a030"),
		"desc": "Schnellere Schussfolge"},
	"reload": {"name": "Schnellhand", "cost": 3000, "power": true, "color": Color("#4ec06a"),
		"desc": "Doppelt so schnell nachladen"},
	"stamina": {"name": "Marathon", "cost": 2000, "power": true, "color": Color("#e0d040"),
		"desc": "Länger und schneller sprinten"},
}

const POWERUPS := {
	"max_ammo": {"name": "Max. Munition", "tex": "Objects/Pickable/Ammo-crate_Green.png"},
	"insta_kill": {"name": "Sofort-Kill", "tex": "Objects/Pickable/Bat.png"},
	"double_points": {"name": "Doppelte Punkte", "tex": "Objects/Chips-pack_Red.png"},
	"nuke": {"name": "Bombe", "tex": "Objects/Barrel_red_1.png"},
}

const COST_BOX := 950
const COST_ARMOR := 750
const COST_UPGRADE := [5000, 10000, 20000]  # pro Upgrade-Stufe
const MAX_WEAPON_LEVEL := 3
const DEFEND_SECONDS := 90.0

## Farben der Oberflaeche (aus der Palette des Asset-Packs)
const UI_TEXT := Color("#efe3c8")        # heller Text auf den dunklen Panels
const UI_INK := Color("#2c1d35")         # dunkler Text auf den hellen Knoepfen
const UI_INK_OFF := Color("#4f4452")

## Statistik der letzten Partie (fuer den End-Bildschirm)
var last_result := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Mauszeiger aus dem Pack (Spitze oben links); im Spiel bleibt das Fadenkreuz
	# Als Image uebergeben: eine Textur wuerde vom Betriebssystem-Cursor bis nach dem
	# Grafik-Server festgehalten (Fehlermeldung beim Beenden)
	Input.set_custom_mouse_cursor(Pack.tex("ui/cursor").get_image(), Input.CURSOR_ARROW, Vector2(1, 1))
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_keys("move_up", [KEY_W, KEY_UP])
	_keys("move_down", [KEY_S, KEY_DOWN])
	_keys("reload", [KEY_R])
	_keys("interact", [KEY_E])
	_keys("sprint", [KEY_SHIFT])
	_keys("melee", [KEY_V, KEY_F])
	_keys("swap", [KEY_Q])
	_keys("weapon_1", [KEY_1])
	_keys("weapon_2", [KEY_2])
	_keys("pause", [KEY_ESCAPE, KEY_P])
	_keys("fullscreen", [KEY_F11])
	_mouse("shoot", MOUSE_BUTTON_LEFT)
	_mouse("melee", MOUSE_BUTTON_RIGHT)
	_mouse("swap", MOUSE_BUTTON_WHEEL_UP)
	_mouse("swap", MOUSE_BUTTON_WHEEL_DOWN)


func _exit_tree() -> void:
	SheetAnims.clear()
	Pack.clear()


## F11: Vollbild an/aus. Statt des kleinen Startfensters (1280x720 Pixel) wird das
## Fenster dann maximiert; das Bild skaliert sich in beiden Faellen mit (Stretch-Modus).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


func _keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func weapon_name(id: String, level: int) -> String:
	var n: String = WEAPONS[id]["name"]
	if level > 0:
		n += " " + "+".repeat(level)
	return n


## Waffe in der Hand (mit Haenden, zeigt nach rechts)
func weapon_tex(id: String) -> Texture2D:
	return Pack.tex("guns/gun_" + id)


## Waffe als Symbol (Hotbar, Wandkauf)
func weapon_icon(id: String) -> Texture2D:
	return Pack.tex("guns/icon_" + id)


## Patronen-Symbol neben der Munitionsanzeige
func bullet_icon(id: String) -> Texture2D:
	return Pack.tex("ui/bullet_" + SheetAnims.weapon(id)["bullet"])


## Zombies pro Runde (aehnlich wie im Vorbild: langsam steigend)
func zombies_for_round(r: int) -> int:
	var table := [6, 8, 13, 18, 24]
	if r <= table.size():
		return table[r - 1]
	return int(24 + (r - 5) * 5 + pow(r - 5, 1.5))


## Wahrscheinlichkeit, dass ein neuer Zombie in Runde r ein Panzer-Zombie ist
func tank_chance(r: int) -> float:
	if r < TANK_FROM_ROUND:
		return 0.0
	return minf(TANK_CHANCE_PER_ROUND * (r - TANK_FROM_ROUND + 1), TANK_MAX_CHANCE)


func zombie_health(r: int) -> float:
	if r < 10:
		return 150.0 + 100.0 * (r - 1)
	return 950.0 * pow(1.1, r - 9)


## Flaches Panel (fuer halbtransparente Kaesten ueber der Spielwelt)
func panel_style(bg := Color("#f3d9a4"), border := Color("#7a4a21"), width := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(8)
	return sb


## 9-Teile-Box aus einer Oberflaechen-Grafik (Pack.tex("ui/...")). Diese Grafiken sind
## schon 3x vergroessert, die Raender (margin) sind daher in diesen grossen Pixeln angegeben.
func tex_style(ui_name: String, margin: float, content := -1.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Pack.tex("ui/" + ui_name)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(margin if content < 0.0 else content)
	return sb


## Grosses Panel (Shop, Pause, Ende, Punkte) im Stil des Pack-Inventars
func pack_panel() -> StyleBoxTexture:
	return tex_style("panel", 18.0, 20.0)


## Hotbar-Feld; gewaehlt = heller Rahmen
func pack_cell(selected: bool) -> StyleBoxTexture:
	return tex_style("cell_chosen" if selected else "cell", 9.0, 9.0)


func _button_box(ui_name: String, bottom: float, pressed := false) -> StyleBoxTexture:
	var sb := tex_style(ui_name, 15.0)
	sb.texture_margin_bottom = bottom
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0 if pressed else 6.0
	sb.content_margin_bottom = 8.0 if pressed else 14.0
	return sb


## Knopf im Stil der Pack-Menueknoepfe (leere Vorlage, Text kommt vom Spiel)
func style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _button_box("button", 18.0))
	b.add_theme_stylebox_override("hover", _button_box("button_hover", 18.0))
	b.add_theme_stylebox_override("pressed", _button_box("button_pressed", 12.0, true))
	var off := _button_box("button", 18.0)
	off.modulate_color = Color(0.8, 0.76, 0.76)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, UI_INK)
	b.add_theme_color_override("font_disabled_color", UI_INK_OFF)
