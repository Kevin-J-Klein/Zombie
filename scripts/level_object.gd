@tool
class_name LevelObject
extends Node2D
## Ein Ding im Zombie-Level: Tuer, Wandkauf, Automat, Kiste, Startpunkt ...
## Im Editor in den Knoten «Objekte» einer Level-Szene legen (Ctrl+D kopiert) und
## auf eine Kachel schieben. Was es ist, bestimmt «art» im Inspektor; darunter erscheinen
## nur die Felder, die zu dieser Art gehoeren. level.gd liest die Dinge beim Start aus.
##
## Massgebend ist die Kachel, auf der der Punkt liegt. Im Editor wird das Ding so
## gezeichnet, wie es im Spiel steht (eingerastet auf die Kachel).

const Globals := preload("res://scripts/globals.gd")
const TILE := 16

const ARTEN := ["Startpunkt", "Tür", "Wandkauf", "Perk", "Shop", "Mystery-Box", "Werkbank",
	"Stromschalter", "Funkgerät", "Funkteil", "Glückspilz", "Kiste", "Fass", "Mülltonne", "Baum"]
## Feste Hindernisse: Bild-Varianten aus dem Pack (eine wird mit «variante» gewaehlt)
const PROP_BILDER := {
	"Kiste": ["Objects/Cardboard_1.png", "Objects/Cardboard_2.png", "Objects/Pallet_1.png"],
	"Fass": ["Objects/Barrel_rust_red_1.png", "Objects/Barrel_blue_1.png", "Objects/Barrel_rust_blue_1.png"],
	"Mülltonne": ["Objects/Garbage-Bin_4.png", "Objects/Trash-can_1.png"],
	"Baum": ["Objects/Nature/Green/Tree_3_Normal_Green.png", "Objects/Nature/Green/Tree_10_Small-oak_Green.png"],
}
const TUER_SENKRECHT := "Objects/Buildable/Wooden/Wooden-wall_Vertical.png"
const TUER_WAAGRECHT := "Objects/Buildable/Wooden/Wooden-wall_Gate_Horizontal.png"

@export_enum("Startpunkt", "Tür", "Wandkauf", "Perk", "Shop", "Mystery-Box", "Werkbank",
	"Stromschalter", "Funkgerät", "Funkteil", "Glückspilz", "Kiste", "Fass", "Mülltonne", "Baum")
var art := "Kiste":
	set(value):
		art = value
		notify_property_list_changed()
		queue_redraw()

@export_group("Tür")
@export var tuer_name := "Tür":
	set(value):
		tuer_name = value
		queue_redraw()
@export var preis := 750:
	set(value):
		preis = value
		queue_redraw()
## Wie viele Kacheln die Tuer belegt (ab der Kachel des Punkts nach rechts/unten)
@export var groesse := Vector2i(1, 2):
	set(value):
		groesse = Vector2i(maxi(1, value.x), maxi(1, value.y))
		queue_redraw()
## Geht von selbst auf, sobald der Helikopter kommt (Weg zum Landeplatz)
@export var bei_flucht_offen := false

@export_group("Wandkauf")
## Waffe an der Wand. Der Wandkauf gehoert auf eine Wand-Kachel und ist nur von unten erreichbar.
@export var waffe := "smg":
	set(value):
		waffe = value
		queue_redraw()

@export_group("Perk")
@export var perk := "revive":
	set(value):
		perk = value
		queue_redraw()

@export_group("Aussehen")
## Bild-Variante bei Kiste, Fass, Muelltonne und Baum
@export var variante := 0:
	set(value):
		variante = value
		queue_redraw()


func _ready() -> void:
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


## Felder, die nicht zur gewaehlten Art gehoeren, im Inspektor ausblenden;
## Waffen und Perks als Auswahlliste aus globals.gd.
func _validate_property(property: Dictionary) -> void:
	var n: String = property.name
	var group := ""
	if n in ["tuer_name", "preis", "groesse", "bei_flucht_offen"]:
		group = "Tür"
	elif n == "waffe":
		group = "Wandkauf"
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(Globals.WEAPONS.keys().filter(func(id): return id != "pistol" and id != "raygun"))
	elif n == "perk":
		group = "Perk"
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(Globals.PERKS.keys())
	elif n == "variante":
		group = "prop"
	if group == "":
		return
	var show := art == group or (group == "prop" and PROP_BILDER.has(art))
	if not show:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Kachel, auf der das Ding steht (Level-Koordinaten)
func cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE), floori(position.y / TILE))


func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := cell()
	var g := groesse if art == "Tür" else Vector2i.ONE
	for y in g.y:
		for x in g.x:
			out.append(c + Vector2i(x, y))
	return out


func is_solid_prop() -> bool:
	return PROP_BILDER.has(art)


## Bild, so wie es im Spiel erscheint (leer bei Tuer und Startpunkt)
func texture() -> Texture2D:
	match art:
		"Wandkauf":
			return Pack.tex("guns/icon_" + waffe)
		"Perk":
			return Pack.tex("props/perk_" + perk)
		"Shop":
			return Pack.tex("props/shop")
		"Mystery-Box":
			return Pack.file("UI/Inventory/Objects/Icon_Bullet-crate_Green.png")
		"Werkbank":
			return Pack.file("Objects/Washing-machine.png")
		"Stromschalter":
			return Pack.file("Objects/Buildings/Door_4_Metal.png")
		"Funkgerät":
			return Pack.file("Objects/Buildings/Antenna_1.png")
		"Funkteil":
			return Pack.file("Objects/Buildings/Antenna_2.png")
		"Glückspilz":
			return Pack.file("Objects/Nature/Flowers_Mashrooms_Other-nature-stuff/Mushroom.png")
	if PROP_BILDER.has(art):
		var v: Array = PROP_BILDER[art]
		return Pack.file(v[posmod(variante, v.size())])
	return null


func tuer_senkrecht() -> bool:
	return groesse.y > groesse.x


# ------------------------------------------------------------------ Editor-Ansicht

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# Gezeichnet wird relativ zur Kachelmitte, damit man sieht, wo das Ding im Spiel steht
	var center := (Vector2(cell()) + Vector2(0.5, 0.5)) * TILE - position
	var font := ThemeDB.fallback_font
	match art:
		"Startpunkt":
			draw_circle(center, 6.0, Color(0.3, 0.9, 0.4, 0.5))
			draw_arc(center, 6.0, 0.0, TAU, 24, Color(0.3, 0.9, 0.4), 1.0)
			_label(font, center + Vector2(-10, -9), "Start", Color(0.5, 1.0, 0.6))
			return
		"Tür":
			var tex := Pack.file(TUER_SENKRECHT if tuer_senkrecht() else TUER_WAAGRECHT)
			for y in groesse.y:
				for x in groesse.x:
					var c := center + Vector2(x, y) * TILE
					draw_texture(tex, c - tex.get_size() * 0.5)
			var r := Rect2(center - Vector2(TILE, TILE) * 0.5, Vector2(groesse) * TILE)
			draw_rect(r, Color(1.0, 0.8, 0.2), false, 1.0)
			_label(font, r.position + Vector2(0, -2), "%s %d" % [tuer_name, preis], Color(1.0, 0.85, 0.3))
			return
	var t := texture()
	if t == null:
		return
	if art == "Wandkauf":
		draw_rect(Rect2(center + Vector2(-7.5, -5.5), Vector2(15, 9)), Color(0.1, 0.08, 0.06, 0.55))
		draw_texture(t, center + Vector2(0, -1) - t.get_size() * 0.5)
	else:
		# Fusspunkt am unteren Rand der Kachel, Bild ragt nach oben
		draw_texture(t, center + Vector2(-t.get_width() * 0.5, 8.0 - t.get_height()))
	if art in ["Perk", "Wandkauf"]:
		_label(font, center + Vector2(-8, 13), perk if art == "Perk" else waffe, Color(1.0, 0.85, 0.3))


func _label(font: Font, pos: Vector2, text: String, c: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 2, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, c)
