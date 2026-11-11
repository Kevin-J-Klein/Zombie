extends Node
## Autoload "G": Spieldaten (Waffen, Perks, Preise) und Tastenbelegung.

const TILE := 16

## Kollisions-Ebenen (Bitwerte)
const L_WORLD := 1      # Waende, Tueren, Kisten
const L_PLAYER_BLOCK := 2  # Fenster: Spieler kommt nicht durch, Zombies und Kugeln schon
const L_HURT := 4       # Trefferzonen der Zombies

const START_POINTS := 500
const MAX_ZOMBIES_ALIVE := 24

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
	"max_ammo": {"name": "Max. Munition", "tex": "res://art/pu_max_ammo.png"},
	"insta_kill": {"name": "Sofort-Kill", "tex": "res://art/pu_insta_kill.png"},
	"double_points": {"name": "Doppelte Punkte", "tex": "res://art/pu_double_points.png"},
	"nuke": {"name": "Bombe", "tex": "res://art/pu_nuke.png"},
}

const COST_BOX := 950
const COST_ARMOR := 750
const COST_UPGRADE := [5000, 10000, 20000]  # pro Upgrade-Stufe
const MAX_WEAPON_LEVEL := 3
const DEFEND_SECONDS := 90.0

## Statistik der letzten Partie (fuer den End-Bildschirm)
var last_result := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_mouse("shoot", MOUSE_BUTTON_LEFT)
	_mouse("melee", MOUSE_BUTTON_RIGHT)
	_mouse("swap", MOUSE_BUTTON_WHEEL_UP)
	_mouse("swap", MOUSE_BUTTON_WHEEL_DOWN)


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


func weapon_tex(id: String) -> Texture2D:
	return load("res://art/gun_%s.png" % id)


## Zombies pro Runde (aehnlich wie im Vorbild: langsam steigend)
func zombies_for_round(r: int) -> int:
	var table := [6, 8, 13, 18, 24]
	if r <= table.size():
		return table[r - 1]
	return int(24 + (r - 5) * 5 + pow(r - 5, 1.5))


func zombie_health(r: int) -> float:
	if r < 10:
		return 150.0 + 100.0 * (r - 1)
	return 950.0 * pow(1.1, r - 9)


## Einheitlicher Look fuer UI-Panels (warmes Pergament wie in der Stilvorlage)
func panel_style(bg := Color("#f3d9a4"), border := Color("#7a4a21"), width := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(8)
	return sb


func style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", panel_style())
	b.add_theme_stylebox_override("hover", panel_style(Color("#ffe9bd")))
	b.add_theme_stylebox_override("pressed", panel_style(Color("#e0c088")))
	b.add_theme_stylebox_override("disabled", panel_style(Color("#b9a98a"), Color("#6a5a48")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("#3a2414"))
	b.add_theme_color_override("font_disabled_color", Color("#6a5a48"))
