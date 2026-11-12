@tool
class_name Pack
extends RefCounted
## Alle Grafiken kommen direkt aus dem Asset-Pack (art/asset_pack/).
##
## Was das Spiel unveraendert braucht, laedt Pack.file("Objects/Cardboard_1.png").
## Was erst zusammengesetzt, eingefaerbt oder vergroessert werden muss, baut Pack.tex(name)
## beim ersten Zugriff im Speicher (es entstehen keine Bilddateien):
##   tiles, walls             Boden- und Wand-Atlas fuer die Level (level.gd)
##   guns/gun_<id>, guns/icon_<id>   Waffen und Hotbar-Symbole, je Waffe eingefaerbt
##   props/shop, props/perk_<id>     Automaten, umgefaerbt
##   props/helipad            Landeplatz-Markierung (gezeichnet)
##   ui/...                   Oberflaeche, 3x vergroessert (scharfe Pixel)
## Pack.anims(gruppe) liefert die Figuren-Animationen (fuer SheetAnims).
##
## Eigene Grafiken ausserhalb des Packs (erzeugt mit tools/make_character_art.py):
##   art/characters/<skin>/   umgefaerbte Spielfiguren (SKINS), gleiches Raster wie der Player
##   art/weapons/             Waffen, die es im Pack nicht gibt (CUSTOM_GUNS)

const DIR := "res://art/asset_pack/"
const T := 16
const UI_SCALE := 3

static var _tex := {}
static var _anims := {}


## Eine Datei aus dem Pack, z. B. Pack.file("Objects/Barrel_red_1.png").
## Volle Pfade (res://...) gehen auch, z. B. fuer art/characters/.
static func file(rel: String) -> Texture2D:
	return load(rel if rel.begins_with("res://") else DIR + rel)


static func image(rel: String) -> Image:
	var img := file(rel).get_image().duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## Zusammengesetzte Grafik (siehe Liste oben), zwischengespeichert.
static func tex(id: String) -> Texture2D:
	if not _tex.has(id):
		_tex[id] = ImageTexture.create_from_image(_build(id))
	return _tex[id]


## Gibt alles Zwischengespeicherte frei (beim Beenden, sonst meldet der Grafik-Server Lecks).
static func clear() -> void:
	_tex.clear()
	_anims.clear()


static func _build(id: String) -> Image:
	var parts := id.split("/")
	match parts[0]:
		"tiles":
			return _floors()
		"walls":
			return _walls()
		"guns":
			return _gun(parts[1])
		"props":
			return _prop(parts[1])
		"ui":
			return _ui(parts[1])
	push_error("Pack: unbekannte Grafik '%s'" % id)
	return _new(1, 1)


# ------------------------------------------------------------------ Hilfen

static func _new(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


static func _tile(img: Image, tx: int, ty: int) -> Image:
	return img.get_region(Rect2i(tx * T, ty * T, T, T))


static func _win(img: Image, x: int, y: int) -> Image:
	return img.get_region(Rect2i(x, y, T, T))


static func _flip_x(img: Image) -> Image:
	var c := img.duplicate() as Image
	c.flip_x()
	return c


static func _flip_y(img: Image) -> Image:
	var c := img.duplicate() as Image
	c.flip_y()
	return c


static func _rot180(img: Image) -> Image:
	return _flip_y(_flip_x(img))


static func _paste(dst: Image, src: Image, x: int, y: int) -> void:
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(x, y))


static func _upscale(img: Image, s := UI_SCALE) -> Image:
	var c := img.duplicate() as Image
	c.resize(img.get_width() * s, img.get_height() * s, Image.INTERPOLATE_NEAREST)
	return c


## Teilt ein Pack-Sheet ('...-SheetN.png') in seine N gleich breiten Frames.
static func _frames_of(rel: String, n: int) -> Array[Image]:
	var img := image(rel)
	var w := img.get_width() / n
	var out: Array[Image] = []
	for i in n:
		out.append(img.get_region(Rect2i(i * w, 0, w, img.get_height())))
	return out


## Faerbt alle Pixel um, deren Farbton nahe hue_from liegt (z. B. Holz -> Oliv).
## max_val laesst helle Pixel aus (z. B. die Haut der Haende an den Waffen).
static func _recolor(img: Image, hue_from: float, hue_to: float, sat := 1.0, val := 1.0,
		hue_tol := 0.09, min_sat := 0.2, max_val := 1.0) -> Image:
	var out := img.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var d := absf(c.h - hue_from)
			d = minf(d, 1.0 - d)
			if d <= hue_tol and c.s >= min_sat and c.v <= max_val:
				out.set_pixel(x, y, Color.from_hsv(fposmod(hue_to, 1.0), minf(1.0, c.s * sat), minf(1.0, c.v * val), c.a))
	return out


static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	img.fill_rect(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1), c)


## Runden wie Python (bei .5 zur geraden Zahl), damit die Figuren pixelgleich stehen wie frueher.
static func _round_even(x: float) -> int:
	var f := floorf(x)
	var r := x - f
	if is_equal_approx(r, 0.5):
		return int(f) + (int(f) % 2)
	return roundi(x)


# ------------------------------------------------------------------ Boden (Level)

## 10 Typen x 4 Varianten (Spalte = Typ, siehe Level.FLOOR_TILES)
static func _floors() -> Image:
	var bg := image("Tiles/Background_Green_TileSet.png")
	var dark := image("Tiles/Background_Dark-Green_TileSet.png")
	var atlas := _new(10 * T, 4 * T)
	# 0 Holzboden, 1 Pflaster (sauberer Ausschnitt), 2 Asphalt, 3 Gras, 4 Erde
	var wood := [_tile(bg, 3, 11), _tile(bg, 4, 11), _tile(bg, 5, 11), _flip_x(_tile(bg, 4, 11))]
	var p := _win(bg, 100, 5)
	var cobble := [p, _flip_x(p), _flip_y(p), _rot180(p)]
	var asphalt := [_tile(bg, 5, 9), _win(bg, 66, 117), _flip_x(_win(bg, 66, 117)), _flip_y(_tile(bg, 5, 9))]
	var grass := [_tile(bg, 0, 0), _tile(bg, 2, 0), _tile(bg, 0, 2), _tile(bg, 2, 2)]
	var d := _win(bg, 278, 24)
	var dirt := [d, _flip_x(d), _flip_y(d), _rot180(d)]
	# 8 Waldboden ohne Busch (Spawns, Luecken in der Hecke), 7 Wald mit Busch (nicht begehbar)
	var ground := [_tile(dark, 0, 0), _tile(dark, 2, 0), _tile(dark, 0, 2), _tile(dark, 2, 2)]
	var bush := image("Objects/Nature/Dark-Green/Bush_1_Dark-Green.png")
	var grass3 := image("Objects/Nature/Dark-Green/Grass_3_Dark-Green.png")
	var woods := []
	for i in 4:
		var t := _tile(dark, [0, 2, 0, 2][i], [0, 0, 2, 2][i])
		var b := bush if i % 2 == 0 else _flip_x(bush)
		if i == 3:
			_paste(t, grass3, 0, T - grass3.get_height())
		else:
			_paste(t, b, (T - b.get_width()) / 2, T - b.get_height() - [1, 2, 0][i])
		woods.append(t)
	for v in 4:
		_paste(atlas, wood[v], 0, v * T)
		_paste(atlas, cobble[v], 1 * T, v * T)
		_paste(atlas, asphalt[v], 2 * T, v * T)
		_paste(atlas, grass[v], 3 * T, v * T)
		_paste(atlas, dirt[v], 4 * T, v * T)
		_paste(atlas, woods[v], 7 * T, v * T)
		_paste(atlas, ground[v], 8 * T, v * T)
		_paste(atlas, asphalt[v], 9 * T, v * T)
	return atlas


# ------------------------------------------------------------------ Waende (Level)

## Spalte = Nachbarmaske (N=1, O=2, S=4, W=8); Zeile 0 = Wand von oben,
## 1 = Wand mit Vorderseite, 2 = Vorderseite mit Fenster. Jede Kachel wird aus vier
## 8x8-Vierteln des Dachrahmens zusammengesetzt, je nachdem, wo Nachbarwaende anschliessen.
static func _walls() -> Image:
	var bld := image("Tiles/Buildings/Buildings_beige_TileSet.png")
	var frame := bld.get_region(Rect2i(5 * T, 0, 4 * T, 3 * T))
	var facade := bld.get_region(Rect2i(4 * T, 3 * T, 6 * T, 41))
	var win_img := image("Objects/Windows/Window_1_broken_wood.png")
	var q := func(x: int, y: int) -> Image: return frame.get_region(Rect2i(x, y, 8, 8))
	var parts := {
		"corner": {"TL": q.call(0, 0), "TR": q.call(56, 0), "BL": q.call(0, 40), "BR": q.call(56, 40)},
		"horiz": {"TL": q.call(16, 0), "TR": q.call(24, 0), "BL": q.call(16, 40), "BR": q.call(24, 40)},
		"vert": {"TL": q.call(0, 16), "TR": q.call(56, 16), "BL": q.call(0, 24), "BR": q.call(56, 24)},
		"fill": {"TL": q.call(16, 16), "TR": q.call(24, 16), "BL": q.call(16, 24), "BR": q.call(24, 24)},
	}
	var quarter := func(key: String, v_conn: bool, h_conn: bool) -> Image:
		var kind := "fill" if v_conn and h_conn else ("horiz" if h_conn else ("vert" if v_conn else "corner"))
		return parts[kind][key]
	var top := func(mask: int) -> Image:
		var n := mask & 1 != 0
		var e := mask & 2 != 0
		var s := mask & 4 != 0
		var w := mask & 8 != 0
		var t := _new(T, T)
		_paste(t, quarter.call("TL", n, w), 0, 0)
		_paste(t, quarter.call("TR", n, e), 8, 0)
		_paste(t, quarter.call("BL", s, w), 0, 8)
		_paste(t, quarter.call("BR", s, e), 8, 8)
		return t
	var atlas := _new(16 * T, 3 * T)
	var rows := [9, 10, 11, 12, 13, 16, 17, 35, 36, 38]
	for m in 16:
		_paste(atlas, top.call(m), m * T, 0)
		# Vorderseite: oben 6 px Mauerkrone, darunter Gesims, Mauer, Sockel
		var f := _new(T, T)
		_paste(f, (top.call(m & ~4) as Image).get_region(Rect2i(0, 0, T, 6)), 0, 0)
		for x in T:
			var xs := 16 + x
			if x < 2 and m & 8 == 0:
				xs = x
			elif x >= T - 2 and m & 2 == 0:
				xs = facade.get_width() - T + x
			for i in rows.size():
				f.set_pixel(x, 6 + i, facade.get_pixel(xs, rows[i]))
		_paste(atlas, f, m * T, T)
		var wi := f.duplicate() as Image
		_paste(wi, win_img, (T - win_img.get_width()) / 2, T - win_img.get_height())
		_paste(atlas, wi, m * T, 2 * T)
	return atlas


# ------------------------------------------------------------------ Figuren

const _CHAR := "Character/Main/"
const PLAYER_SHEETS := {
	"idle_down": [_CHAR + "Idle/Character_down_idle_no-hands-Sheet6.png", 6],
	"idle_up": [_CHAR + "Idle/Character_up_idle_no-hands-Sheet6.png", 6],
	"idle_side": [_CHAR + "Idle/Character_side_idle_no-hands-Sheet6.png", 6],
	"idle_left": [_CHAR + "Idle/Character_side-left_idle_no-hands-Sheet6.png", 6],
	"run_down": [_CHAR + "Run/Character_down_run_no-hands-Sheet6.png", 6],
	"run_up": [_CHAR + "Run/Character_up_run_no-hands-Sheet6.png", 6],
	"run_side": [_CHAR + "Run/Character_side_run_no-hands-Sheet6.png", 6],
	"run_left": [_CHAR + "Run/Character_side-left_run_no-hands-Sheet6.png", 6],
	"death_side": [_CHAR + "Death/Character_side_death1_NoHands-Sheet6.png", 6],
	"death_left": [_CHAR + "Death/Character_side-left_death1_NoHands-Sheet6.png", 6],
}
## Umgefaerbte Spielfiguren: gleiche Sheets wie PLAYER_SHEETS, aber aus dem eigenen Ordner.
## hands = Farbtausch fuer die Haende an den Waffen (Pack-Hautfarbe -> Hautfarbe der Figur).
const SKINS := {
	"lamar": {"dir": "res://art/characters/lamar/",
		"hands": {"e6c2b0": "be8056", "ba868f": "8c583c"}},
}
const ZOMBIE_DIRS := {"zombie_small": "Enemies/Zombie_Small/", "zombie_axe": "Enemies/Zombie_Axe/",
	"zombie_big": "Enemies/Zombie_Big/"}
## Bildrate des Angriffs passend zur Ausholzeit im Spiel (0.3 s, Panzer 0.55 s)
const ATTACK_FPS := {"zombie_small": 14.0, "zombie_axe": 22.0, "zombie_big": 15.0}


## Animationen einer Gruppe ("player", "zombie_small", "zombie_axe", "zombie_big", "fx"):
## Name -> {tex, w, h, frames, fps, loop}. Jede Animation ist ein Streifen gleich grosser
## Zellen; die Fuesse stehen unten in der Mitte der Zelle.
static func anims(group: String) -> Dictionary:
	if not _anims.has(group):
		match group:
			"player":
				_anims[group] = _character(PLAYER_SHEETS, {"idle": 6.0, "run": 11.0, "death": 9.0}, {"death": false})
			"fx":
				# Treffer-Spritzer der Zombies: das Sheet ist schon ein Streifen
				var fx := {}
				for i in [1, 2]:
					var t := file("Enemies/Shot/shot_%d-Sheet3.png" % i)
					fx["shot_%d" % i] = {"tex": t, "w": int(t.get_width()) / 3, "h": int(t.get_height()),
						"frames": 3, "fps": 18.0, "loop": false}
				_anims[group] = fx
			_:
				if SKINS.has(group):
					# umgefaerbte Spielfigur (z. B. Lamar): gleiche Animationen wie der Player
					_anims[group] = _character(_skin_sheets(group), {"idle": 6.0, "run": 11.0, "death": 9.0}, {"death": false})
					return _anims[group]
				_anims[group] = _character(_zombie_sheets(ZOMBIE_DIRS[group]),
					{"walk": 9.0, "idle": 6.0, "attack": ATTACK_FPS[group], "death": 10.0},
					{"attack": false, "death": false})
	return _anims[group]


## Sheets einer umgefaerbten Spielfigur (gleiche Dateinamen wie im Pack, eigener Ordner)
static func _skin_sheets(skin: String) -> Dictionary:
	var sheets := {}
	for anim: String in PLAYER_SHEETS:
		var entry: Array = PLAYER_SHEETS[anim]
		sheets[anim] = [SKINS[skin]["dir"] + String(entry[0]).get_file(), entry[1]]
	return sheets


## Sucht die Sheets eines Zombies, z. B. Zombie_Small_Side-left_First-Attack-Sheet4.png -> attack_left
static func _zombie_sheets(dir: String) -> Dictionary:
	var prefix := dir.get_slice("/", 1) + "_"
	var sheets := {}
	var files := Array(ResourceLoader.list_directory(DIR + dir))
	files.sort()
	for f: String in files:
		if not f.ends_with(".png") or not f.contains("-Sheet"):
			continue
		var bits := f.trim_prefix(prefix).trim_suffix(".png").split("_")
		var d: String = {"Down": "down", "Up": "up", "Side": "side", "Side-left": "left"}.get(bits[0], "")
		var what := bits[1].get_slice("-Sheet", 0)
		var n := bits[1].get_slice("-Sheet", 1).to_int()
		var anim: String = {"walk": "walk", "Walk": "walk", "Idle": "idle", "First-Attack": "attack",
			"First-Death": "death"}.get(what, "")
		if d != "" and anim != "":
			sheets["%s_%s" % [anim, d]] = [dir + f, n]
	return sheets


## Ankerpunkt einer Figur: Kopfmitte (x) und Fusslinie (y). Die Pack-Sheets sind
## unterschiedlich breit zugeschnitten; ueber die Kopfmitte stehen Laufen, Angriff und Tod
## trotzdem an derselben Stelle.
static func _anchor(frame: Image) -> Vector2:
	var box := frame.get_used_rect()
	var top := box.position.y
	var bottom := box.end.y
	var sum := 0.0
	var count := 0
	for y in range(top, mini(top + 5, bottom)):
		for x in frame.get_width():
			if frame.get_pixel(x, y).a > 0.0:
				sum += x
				count += 1
	return Vector2(sum / count, bottom)


## sheets: Animation -> [Pack-Datei, Frames]. Alle Animationen einer Figur bekommen dieselbe
## Zellgroesse; Kopfmitte liegt auf der Zellmitte, Fuesse auf der Unterkante.
static func _character(sheets: Dictionary, fps: Dictionary, loop: Dictionary) -> Dictionary:
	var placed := {}
	var left := 0.0
	var right := 0.0
	var up := 0.0
	for anim: String in sheets:
		var fr := _frames_of(sheets[anim][0], sheets[anim][1])
		var a := _anchor(fr[0])
		placed[anim] = [fr, a]
		for f in fr:
			var b := f.get_used_rect()
			if b.size == Vector2i.ZERO:
				continue
			left = maxf(left, a.x - b.position.x)
			right = maxf(right, b.end.x - a.x)
			up = maxf(up, a.y - b.position.y)
	var half := int(maxf(left, right) + 1.5)
	var cw := half * 2
	var ch := int(up + 1)
	cw += cw % 2
	ch += ch % 2
	var out := {}
	for anim: String in placed:
		var fr: Array[Image] = placed[anim][0]
		var a: Vector2 = placed[anim][1]
		var strip := _new(cw * fr.size(), ch)
		var ox := _round_even(half - a.x)
		var oy := ch - int(a.y)
		for i in fr.size():
			_paste(strip, fr[i], i * cw + ox, oy)
		var kind := anim.get_slice("_", 0)
		out[anim] = {"tex": ImageTexture.create_from_image(strip), "w": cw, "h": ch, "frames": fr.size(),
			"fps": fps.get(kind, 8.0), "loop": loop.get(kind, true)}
	return out


# ------------------------------------------------------------------ Waffen

const WOOD_HUE := 0.0  # das Holz der Pack-Waffen ist rot-braun
## Spiel-Waffe -> [Pack-Waffe, Einfaerbung des Holzes (Farbe, Saettigung, Helligkeit) oder leer]
const WEAPONS := {
	"pistol": ["Pistol", []],
	"shotgun": ["Shotgun", []],
	"rifle": ["Gun", []],
	"smg": ["Gun", ["#4a4a58", 0.4, 0.8]],      # schwarzer Schaft
	"dmr": ["Gun", ["#c8a060", 1.0, 1.35]],     # heller Holzschaft
	"lmg": ["Gun", ["#6a7a3a", 1.0, 1.1]],      # oliv
	"raygun": ["Gun", ["#40e0a0", 1.4, 1.6]],   # leuchtend gruen
	"uzi": ["Uzi", []],                         # eigene Grafik (CUSTOM_GUNS)
}
## Waffen, die es im Pack nicht gibt: Bild in der Hand (nach rechts, mit Hand) und Hotbar-Symbol
const CUSTOM_GUNS := {
	"Uzi": {"held": "res://art/weapons/uzi_side.png", "icon": "res://art/weapons/icon_uzi.png"},
}
## Griff (Drehpunkt in der Hand), Muendung und Grundwinkel je Pack-Waffe.
## Die Pistole wird im Pack leicht schraeg nach oben gehalten -> Winkel ausgleichen.
const HOLDS := {
	"Pistol": {"grip": [2, 6], "muzzle": [8, 2], "angle": 12.0, "bullet": "pistol"},
	"Gun": {"grip": [6, 7], "muzzle": [16, 3], "angle": 0.0, "bullet": "gun"},
	"Shotgun": {"grip": [5, 6], "muzzle": [15, 2], "angle": 0.0, "bullet": "shotgun"},
	"Uzi": {"grip": [5, 5], "muzzle": [14, 3], "angle": 0.0, "bullet": "pistol"},
}


## Halte-Daten einer Waffe: grip, muzzle, angle, bullet
static func weapon(id: String) -> Dictionary:
	return HOLDS[WEAPONS[id][0]]


## "gun_<id>" = Waffe mit Haenden (erster Frame des Lauf-Sheets), "icon_<id>" = Hotbar-Symbol.
## "gun_<id>~<skin>" = mit den Haenden einer umgefaerbten Figur (SKINS).
static func _gun(name: String) -> Image:
	var id_skin := name.get_slice("_", 1)
	var id := id_skin.get_slice("~", 0)
	var skin := id_skin.get_slice("~", 1) if id_skin.contains("~") else ""
	var src: String = WEAPONS[id][0]
	var tint: Array = WEAPONS[id][1]
	var img: Image
	if CUSTOM_GUNS.has(src):
		img = image(CUSTOM_GUNS[src]["icon" if name.begins_with("icon_") else "held"])
	elif name.begins_with("icon_"):
		img = image("UI/Inventory/Objects/Icon_%s.png" % src)
	else:
		img = _frames_of("Character/Guns/%s/%s_side_idle-and-run-Sheet6.png" % [src, src], 6)[0]
	if not tint.is_empty():
		img = _recolor(img, WOOD_HUE, Color(tint[0]).h, tint[1], tint[2], 0.09, 0.2, 0.62)
	if skin != "" and SKINS.has(skin):
		img = _swap_colors(img, SKINS[skin]["hands"])
	return img


## Tauscht exakte Farben aus (Hex ohne # -> Hex ohne #), z. B. die Hautfarbe der Haende.
static func _swap_colors(img: Image, swaps: Dictionary) -> Image:
	var out := img.duplicate() as Image
	var map := {}
	for from: String in swaps:
		map[Color(from).to_html(false)] = Color(swaps[from])
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a > 0.0 and map.has(c.to_html(false)):
				out.set_pixel(x, y, map[c.to_html(false)])
	return out


# ------------------------------------------------------------------ Objekte

const PERK_COLORS := {"revive": "#4aa8e0", "health": "#e0483a", "fire": "#e0a030",
	"reload": "#4ec06a", "stamina": "#e0d040"}


static func _prop(name: String) -> Image:
	if name == "shop":
		# blauer Automat, grau umgefaerbt (damit er nicht wie der blaue Perk aussieht)
		return _recolor(image("Objects/Vending-machine_Blue.png"), 0.62, 0.62, 0.12, 1.35, 0.12, 0.1)
	if name == "helipad":
		return _helipad()
	# perk_<id>: roter Automat, rote Flaechen in die Perk-Farbe umgefaerbt
	var perk := name.trim_prefix("perk_")
	return _recolor(image("Objects/Vending-machine_Red.png"), 0.98, Color(PERK_COLORS[perk]).h, 1.0, 1.05, 0.06, 0.25)


## Landeplatz-Markierung in der Farbe der Strassenmarkierungen des Packs:
## gestrichelter Rahmen und ein grosses H.
static func _helipad(cells := 5) -> Image:
	var size := cells * T
	var img := _new(size, size)
	var paint := Color8(196, 195, 188)
	var shade := Color8(163, 164, 166)
	var r := func(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)
	var m := 4
	var dash := 6
	for i in range(m, size - m, dash * 2):
		var e := mini(i + dash, size - m)
		r.call(i, m, e, m + 2, paint)
		r.call(i, size - m - 2, e, size - m, paint)
		r.call(m, i, m + 2, e, paint)
		r.call(size - m - 2, i, size - m, e, paint)
	var c := size / 2
	var hw := 12
	var hh := 16
	r.call(c - hw, c - hh, c - hw + 4, c + hh, paint)
	r.call(c + hw - 4, c - hh, c + hw, c + hh, paint)
	r.call(c - hw + 4, c - 2, c + hw - 4, c + 2, paint)
	for x0 in [c - hw, c + hw - 4]:
		r.call(x0, c + hh, x0 + 4, c + hh + 1, shade)
	r.call(c - hw + 4, c + 2, c + hw - 4, c + 3, shade)
	return img


# ------------------------------------------------------------------ Oberflaeche

## Pack-Grafiken, die nur 3x vergroessert werden
const UI_FILES := {
	"panel": "UI/Inventory/Inventory_1.png",
	"cell": "UI/Inventory/Inventory-Cell.png",
	"cell_chosen": "UI/Inventory/Inventory-Chosen.png",
	"button": "UI/Menu/Main Menu/Blank_Not-Pressed.png",
	"button_pressed": "UI/Menu/Main Menu/Blank_Pressed.png",
	"hp_fill": "UI/HP/HP.png",
	"bullet_pistol": "UI/Bullet Indicators/Small/Pistol-Bullet_Small.png",
	"bullet_gun": "UI/Bullet Indicators/Small/Gun-Bullet_Small.png",
	"bullet_shotgun": "UI/Bullet Indicators/Small/Shotgun-Bullet_Small.png",
	"cursor": "UI/Menu/Cursor.png",
	"scrap": "Objects/Metal-Plates.png",
}
const UI_INK := Color8(42, 31, 45)


static func _ui(name: String) -> Image:
	if UI_FILES.has(name):
		return _upscale(image(UI_FILES[name]))
	match name:
		# Leisten: Rahmen oben drueber, darunter dunkle Rinne, dazwischen die Fuellung
		"hp_over":
			return _upscale(image("UI/HP/HP-Bar.png"))
		"hp_under":
			return _upscale(_bar_under(image("UI/HP/HP-Bar.png")))
		# Panzerung: gleiche Leiste mit blauem Herz und blauer Fuellung
		"armor_over":
			return _upscale(_armor_bar())
		"armor_under":
			return _upscale(_bar_under(_armor_bar()))
		"armor_fill":
			return _upscale(_recolor(image("UI/HP/HP.png"), 0.97, 0.58, 1.0, 1.1, 0.08))
		# Ausdauer: Hunger-Leiste, Fuellung gruen
		"stamina_over":
			return _upscale(image("UI/Hunger/Hunger-Bar.png"))
		"stamina_under":
			return _upscale(_bar_under(image("UI/Hunger/Hunger-Bar.png")))
		"stamina_fill":
			return _upscale(_recolor(image("UI/Hunger/Hunger.png"), 0.03, 0.33, 1.6, 1.25, 0.12, 0.1))
		"button_hover":
			# Knopf im Hover-Zustand: etwas heller
			var b := image(UI_FILES["button"])
			for y in b.get_height():
				for x in b.get_width():
					var c := b.get_pixel(x, y)
					b.set_pixel(x, y, Color(minf(1.0, c.r + 18.0 / 255.0), minf(1.0, c.g + 18.0 / 255.0),
						minf(1.0, c.b + 14.0 / 255.0), c.a))
			return _upscale(b)
	return _upscale(_icon(name))


static func _armor_bar() -> Image:
	return _recolor(image("UI/HP/HP-Bar.png"), 0.97, 0.58, 1.0, 1.1, 0.08, 0.15)


## Rahmen einer Leiste mit dunkel gefuellter Rinne (alles Transparente, das vom Bildrand
## aus nicht erreichbar ist). Wird unter die Fuellung gelegt.
static func _bar_under(frame: Image) -> Image:
	var out := frame.duplicate() as Image
	var w := out.get_width()
	var h := out.get_height()
	var outside := {}
	var todo: Array[Vector2i] = []
	for x in w:
		todo.append(Vector2i(x, 0))
		todo.append(Vector2i(x, h - 1))
	for y in h:
		todo.append(Vector2i(0, y))
		todo.append(Vector2i(w - 1, y))
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		if outside.has(p) or p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or out.get_pixelv(p).a > 0.0:
			continue
		outside[p] = true
		todo.append_array([p + Vector2i(1, 0), p + Vector2i(-1, 0), p + Vector2i(0, 1), p + Vector2i(0, -1)])
	for y in h:
		for x in w:
			if out.get_pixel(x, y).a == 0.0 and not outside.has(Vector2i(x, y)):
				out.set_pixel(x, y, Color8(44, 29, 53))
	return out


## Kleine Symbole fuer die Dorf-Menues, die es im Pack nicht gibt (gezeichnet, in Pack-Farben):
## skull, skull_off (Schwierigkeit), lock (gesperrtes Ziel), gear (Einstellungen)
static func _icon(name: String) -> Image:
	var bone := Color8(236, 226, 200)
	match name:
		"skull", "skull_off":
			var img := _new(7, 7)
			var col := bone if name == "skull" else Color8(104, 96, 110)
			_rect(img, 1, 0, 5, 0, col)
			_rect(img, 0, 1, 6, 4, col)
			_rect(img, 1, 5, 5, 6, col)
			for p in [Vector2i(2, 2), Vector2i(4, 2), Vector2i(2, 3), Vector2i(4, 3), Vector2i(3, 6)]:
				img.set_pixelv(p, UI_INK)
			return img
		"lock":
			var img := _new(7, 9)
			_rect(img, 1, 0, 5, 3, UI_INK)
			_rect(img, 2, 1, 4, 3, Color(0, 0, 0, 0))
			_rect(img, 0, 3, 6, 8, UI_INK)
			_rect(img, 1, 4, 5, 7, Color8(170, 165, 175))
			_rect(img, 3, 5, 3, 6, UI_INK)
			return img
		"gear":
			var img := _new(13, 13)
			for y in 13:
				for x in 13:
					var d := Vector2(x - 6, y - 6).length()
					if d <= 4.3:
						img.set_pixel(x, y, bone)
			for p in [Vector2i(6, 0), Vector2i(6, 11), Vector2i(0, 6), Vector2i(11, 6), Vector2i(1, 1),
					Vector2i(10, 1), Vector2i(1, 10), Vector2i(10, 10)]:
				_rect(img, p.x, p.y, p.x + 1, p.y + 1, bone)
			_rect(img, 1, 5, 11, 6, bone)
			_rect(img, 5, 1, 6, 11, bone)
			for y in 13:
				for x in 13:
					if Vector2(x - 5.5, y - 5.5).length() <= 1.9:
						img.set_pixel(x, y, UI_INK)
			return img
	push_error("Pack: unbekanntes Symbol '%s'" % name)
	return _new(1, 1)
