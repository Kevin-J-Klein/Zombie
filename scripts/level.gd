@tool
class_name Level
extends Node2D
## Ein Zombie-Level. Wird im Godot-Editor gebaut (z. B. scenes/vorstadt.tscn):
##   Karte     TileMapLayer mit dem Tileset art/karte.tres - Waende, Fenster, Hecke und
##             Bodenarten malen. Daraus entstehen Grafik, Kollision und Zombie-Wegfindung.
##   Objekte   LevelObject-Knoten: Startpunkt, Tueren, Wandkaeufe, Automaten, Kisten ...
## Im Editor zeigt das Skript ueber der Karte eine Vorschau mit der echten Grafik
## (wird nicht gespeichert). Beim Spielstart baut build() daraus das Level.

## Kartenzeichen je Kachel im Tileset art/karte.tres (Spalte im Atlas)
const KARTE_ZEICHEN := ["#", "W", " ", ".", ",", ":", "~", ";", "X", "Z", "_"]

## Im Editor: true = die gemalte Karte statt der Vorschau zeigen (zum Pruefen von Spawns usw.)
@export var karte_zeigen := false:
	set(value):
		karte_zeigen = value
		if _preview != null:
			_preview.visible = not value

## Grafiken kommen direkt aus dem Asset-Pack (siehe pack.gd): Boden- und Wand-Atlas setzt
## Pack.tex("tiles") / Pack.tex("walls") aus den Pack-Tilesets zusammen.

const TILE := 16
const SRC_FLOOR := 0
const SRC_WALL := 1          # Spalte = Nachbarmaske (N=1, O=2, S=4, W=8)
const WALL_TOP := 0          # Zeilen im Wand-Atlas
const WALL_FRONT := 1
const WALL_WINDOW := 2
const T_HEDGE := 7
const T_WOODS_GROUND := 8    # Waldboden ohne Buesch (Spawns, Luecken in der Hecke)
const FLOOR_TILES := {".": 0, ",": 1, ":": 2, "~": 3, ";": 4, "X": 9, "_": 8}
const WOODS_TREES := ["Objects/Nature/Dark-Green/Tree_1_Spruce_Dark-Green.png",
	"Objects/Nature/Dark-Green/Tree_3_Normal_Dark-Green.png", "Objects/Nature/Dark-Green/Tree_8_Birch_Dark-Green.png",
	"Objects/Nature/Dark-Green/Tree_2_Spruce-Sparse_Dark-Green.png"]

var game: Node
var grid: Array[String] = []
var size := Vector2i.ZERO
var astar := AStarGrid2D.new()

var floor_map: TileMapLayer
var decals: Node2D
var entities: Node2D
var fx: Node2D

var windows := {}                         # Vector2i -> Barricade
var doors := {}                           # Tuer-Name -> Door
var spawns: Array[Vector2i] = []
var active_spawns: Array[Vector2i] = []
var reached := {}                         # Zellen, die der Spieler aktuell erreichen kann
var extraction_cells := {}
var player_start := Vector2.ZERO
var objects := {}                         # Art -> Array von Nodes (fuer Tests/Quest), siehe _register

var _preview: Node2D                      # nur im Editor
var _preview_dirty := false


# ------------------------------------------------------------------ Karte lesen

## Liest die gemalte Karte als Zeichen-Raster (unbemalt = Hecke).
func _read_grid() -> void:
	grid.clear()
	var karte: TileMapLayer = get_node_or_null("Karte")
	size = Vector2i.ZERO if karte == null else karte.get_used_rect().end
	for y in size.y:
		var row := ""
		for x in size.x:
			var c := Vector2i(x, y)
			var ch := " "
			if karte.get_cell_source_id(c) != -1:
				var a := karte.get_cell_atlas_coords(c)
				if a.x >= 0 and a.x < KARTE_ZEICHEN.size():
					ch = KARTE_ZEICHEN[a.x]
			row += ch
		grid.append(row)


func _markers() -> Array[LevelObject]:
	var out: Array[LevelObject] = []
	var holder := get_node_or_null("Objekte")
	if holder == null:
		return out
	for n in holder.find_children("*", "", true, false):
		if n is LevelObject:
			out.append(n)
	return out


# ------------------------------------------------------------------ Aufbau (Spiel)

func build(p_game: Node) -> void:
	game = p_game
	_read_grid()
	var markers := _markers()
	# Die Editor-Knoten werden nur gelesen; im Spiel entstehen daraus echte Objekte
	var karte := get_node_or_null("Karte")
	if karte != null:
		karte.visible = false
		karte.collision_enabled = false
	var holder := get_node_or_null("Objekte")
	if holder != null:
		holder.name = "Objekte_Editor"
		holder.visible = false
		holder.process_mode = Node.PROCESS_MODE_DISABLED

	floor_map = TileMapLayer.new()
	floor_map.name = "Boden"
	floor_map.tile_set = _make_tileset(true)
	add_child(floor_map)
	decals = Node2D.new()
	decals.name = "Blut"
	add_child(decals)
	entities = Node2D.new()
	entities.name = "Objekte"
	entities.y_sort_enabled = true
	add_child(entities)
	fx = Node2D.new()
	fx.name = "Effekte"
	add_child(fx)

	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = Vector2(TILE, TILE)
	astar.offset = Vector2(TILE, TILE) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	_paint(floor_map, entities, true)
	for m in markers:
		_add_object(m)
	_add_helipad(floor_map)
	if holder != null:
		holder.queue_free()


## Malt Boden und Waende aus dem Raster. Im Spiel (live) kommen Kollision, Wegfindung,
## Fenster und Spawns dazu; im Editor nur die Grafik.
func _paint(layer: TileMapLayer, trees_parent: Node2D, live: bool) -> void:
	for y in size.y:
		for x in size.x:
			var ch := grid[y][x]
			var cell := Vector2i(x, y)
			var variant := posmod(x * 7 + y * 13 + (x * y) % 5, 4)
			if ch == " ":
				layer.set_cell(cell, SRC_FLOOR, Vector2i(T_HEDGE, variant))
				if live:
					astar.set_point_solid(cell, true)
				_maybe_add_tree(x, y, trees_parent)
			elif ch == "#":
				var front := _is_open(x, y + 1)
				layer.set_cell(cell, SRC_WALL, Vector2i(_wall_mask(x, y), WALL_FRONT if front else WALL_TOP))
				if live:
					astar.set_point_solid(cell, true)
			elif ch == "W":
				var mask := _wall_mask(x, y)
				if mask == 0:
					# Fenster mitten in der Hecke: nur eine Luecke, die Bretter zeichnet die Barrikade
					layer.set_cell(cell, SRC_FLOOR, Vector2i(T_WOODS_GROUND, variant))
				else:
					layer.set_cell(cell, SRC_WALL, Vector2i(mask, WALL_WINDOW))
				if live:
					_add_window(cell)
			else:
				var t: int = FLOOR_TILES.get(ch, -1)
				if t == -1:
					t = _neighbor_floor(x, y)
				layer.set_cell(cell, SRC_FLOOR, Vector2i(t, variant))
				if ch == "X":
					extraction_cells[cell] = true
				elif ch == "Z" and live:
					spawns.append(cell)


func _make_tileset(physics: bool) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	if physics:
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, G.L_WORLD)
		ts.set_physics_layer_collision_mask(0, 0)
	var h := TILE * 0.5
	var poly := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])

	# Boden: 10 Typen x 4 Varianten, nur die Hecke ist fest
	var floor_src := TileSetAtlasSource.new()
	floor_src.texture = Pack.tex("tiles")
	floor_src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(floor_src, SRC_FLOOR)
	for tx in 10:
		for v in 4:
			var c := Vector2i(tx, v)
			floor_src.create_tile(c)
			if physics and tx == T_HEDGE:
				_solid_tile(floor_src, c, poly)

	# Waende: 16 Nachbarmasken x (oben, Vorderseite, Fenster). Fenster haben keine
	# Kollision - dort sperrt die Barrikade nur den Spieler.
	var wall_src := TileSetAtlasSource.new()
	wall_src.texture = Pack.tex("walls")
	wall_src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(wall_src, SRC_WALL)
	for m in 16:
		for row in 3:
			var c := Vector2i(m, row)
			wall_src.create_tile(c)
			if physics and row != WALL_WINDOW:
				_solid_tile(wall_src, c, poly)
	return ts


func _solid_tile(src: TileSetAtlasSource, c: Vector2i, poly: PackedVector2Array) -> void:
	var td := src.get_tile_data(c, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, poly)


func _is_wall(x: int, y: int) -> bool:
	var ch := _char(x, y)
	return ch == "#" or ch == "W"


## Welche Nachbarn sind ebenfalls Wand? Bestimmt, wo die Mauerkrone einen Rand bekommt.
func _wall_mask(x: int, y: int) -> int:
	var m := 0
	if _is_wall(x, y - 1):
		m |= 1
	if _is_wall(x + 1, y):
		m |= 2
	if _is_wall(x, y + 1):
		m |= 4
	if _is_wall(x - 1, y):
		m |= 8
	return m


## Baeume im Wald: nur tief im Dickicht, damit sie nichts Begehbares verdecken.
func _maybe_add_tree(x: int, y: int, parent: Node2D) -> void:
	if posmod(x * 13 + y * 7 + (x * y) % 3, 5) != 0:
		return
	for o in [Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(-1, -1), Vector2i(0, -1),
			Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		var c: Vector2i = Vector2i(x, y) + o
		if in_bounds(c) and grid[c.y][c.x] != " ":
			return
	# Knoten steht am Stamm (fuer die Sortierung nach y), das Bild ragt nach oben
	var s := Sprite2D.new()
	s.texture = Pack.file(WOODS_TREES[posmod(x * 5 + y * 3, WOODS_TREES.size())])
	s.position = cell_center(Vector2i(x, y)) + Vector2(posmod(x * 3 + y, 5) - 2, 7.0)
	s.offset = Vector2(0, -s.texture.get_height() * 0.5)
	parent.add_child(s)


## Markierung auf dem Landeplatz (X-Felder), mittig ueber alle Felder.
func _add_helipad(parent: Node2D) -> void:
	if extraction_cells.is_empty():
		return
	var r := Rect2i(extraction_cells.keys()[0], Vector2i.ONE)
	for c: Vector2i in extraction_cells:
		r = r.expand(c).expand(c + Vector2i.ONE)
	var s := Sprite2D.new()
	s.texture = Pack.tex("props/helipad")
	s.position = Vector2(r.position + r.end) * 0.5 * TILE
	parent.add_child(s)


func _char(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= size.x or y >= size.y:
		return " "
	return grid[y][x]


func _is_open(x: int, y: int) -> bool:
	var ch := _char(x, y)
	return not (ch == " " or ch == "#" or ch == "W")


func _neighbor_floor(x: int, y: int) -> int:
	for o in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var ch := _char(x + o.x, y + o.y)
		if FLOOR_TILES.has(ch) and ch != "X" and ch != "_":
			return FLOOR_TILES[ch]
	return T_WOODS_GROUND


## objects-Schluessel: Waffen-ID (Wandkauf), Perk-ID, "shop", "box", "upgrade", "power",
## "radio", "part" (Funkteile), "gnome" (Gluckspilze), "W" (Fenster)
func _register(key: String, node: Node) -> void:
	if not objects.has(key):
		objects[key] = []
	objects[key].append(node)


func _add_solid(node: Node2D, w := 16.0, h := 14.0) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	shape.shape = r
	body.add_child(shape)
	node.add_child(body)


func _add_window(cell: Vector2i) -> void:
	var b := Barricade.new()
	b.setup(game, cell)
	b.position = cell_center(cell)
	entities.add_child(b)
	windows[cell] = b
	_register("W", b)


func _add_wallbuy(cell: Vector2i, weapon_id: String) -> void:
	var it := Interactable.new()
	it.position = cell_center(cell)
	it.setup(game, "wallbuy", G.weapon_icon(weapon_id))
	it.weapon_id = weapon_id
	it.sprite.position = Vector2(0, -1)
	var plate := Polygon2D.new()
	plate.polygon = PackedVector2Array([Vector2(-7.5, -4.5), Vector2(7.5, -4.5), Vector2(7.5, 4.5), Vector2(-7.5, 4.5)])
	plate.color = Color(0.1, 0.08, 0.06, 0.55)
	plate.show_behind_parent = true
	it.sprite.add_child(plate)
	# Wandkaeufe liegen auf der Wand und duerfen nie von Figuren verdeckt wirken -> eigene Ebene unter den Objekten
	decals.add_child(it)
	_register(weapon_id, it)


const INTERACT_KINDS := {"Shop": "shop", "Mystery-Box": "box", "Werkbank": "upgrade",
	"Stromschalter": "power", "Funkgerät": "radio", "Perk": "perk"}


func _add_object(m: LevelObject) -> void:
	var cell := m.cell()
	if not in_bounds(cell):
		push_warning("%s liegt ausserhalb der Karte (%s)" % [m.name, cell])
		return
	var pos := cell_center(cell)
	match m.art:
		"Startpunkt":
			player_start = pos
			return
		"Tür":
			var d := Door.new()
			d.setup(game, self, m.tuer_name, m.cells(), m.preis, m.tuer_senkrecht())
			d.opens_on_escape = m.bei_flucht_offen
			entities.add_child(d)
			doors[m.tuer_name] = d
			for c in d.cells:
				astar.set_point_solid(c, true)
			return
		"Wandkauf":
			_add_wallbuy(cell, m.waffe)
			return
		"Funkteil":
			var p := Pickup.new()
			p.position = pos
			p.setup(game)
			entities.add_child(p)
			_register("part", p)
			return
		"Glückspilz":
			var g := Gnome.new()
			g.position = pos
			g.setup(game)
			entities.add_child(g)
			_register("gnome", g)
			return

	if m.is_solid_prop():
		var n := Node2D.new()
		n.position = pos
		var s := Sprite2D.new()
		s.texture = m.texture()
		s.position = Vector2(0, 8.0 - s.texture.get_height() * 0.5)
		n.add_child(s)
		if m.art == "Baum":
			_add_solid(n, 8.0, 8.0)
		else:
			_add_solid(n)
		entities.add_child(n)
		astar.set_point_solid(cell, true)
		return

	if not INTERACT_KINDS.has(m.art):
		push_warning("Unbekannte Art '%s' bei %s" % [m.art, m.name])
		return
	var kind: String = INTERACT_KINDS[m.art]
	var it := Interactable.new()
	it.position = pos
	it.setup(game, kind, m.texture())
	if kind == "perk":
		it.perk_id = m.perk
	_add_solid(it)
	entities.add_child(it)
	astar.set_point_solid(cell, true)
	_register(m.perk if kind == "perk" else kind, it)


# ------------------------------------------------------------------ Abfragen

func to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.y + 0.5) * TILE


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size) * TILE)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := to_cell(from)
	var b := to_cell(to)
	if not in_bounds(a) or not in_bounds(b):
		return PackedVector2Array()
	if astar.is_point_solid(a):
		a = _free_neighbor(a)
	if astar.is_point_solid(b):
		b = _free_neighbor(b)
	return astar.get_point_path(a, b)


func _free_neighbor(cell: Vector2i) -> Vector2i:
	for o in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var c: Vector2i = cell + o
		if in_bounds(c) and not astar.is_point_solid(c):
			return c
	return cell


## Ermittelt, welche Bereiche der Spieler erreichen kann, und aktiviert nur die
## Zombie-Spawns hinter Fenstern, die an diese Bereiche grenzen.
func refresh_spawns(player_pos: Vector2) -> void:
	reached.clear()
	var start := to_cell(player_pos)
	var queue: Array[Vector2i] = [start]
	reached[start] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for o in dirs:
			var n: Vector2i = c + o
			if reached.has(n) or not in_bounds(n):
				continue
			if astar.is_point_solid(n) or windows.has(n) or spawns.has(n):
				continue
			reached[n] = true
			queue.append(n)
	active_spawns.clear()
	for s in spawns:
		for o in dirs:
			var w: Vector2i = s + o
			if not windows.has(w):
				continue
			for o2 in dirs:
				if reached.has(w + o2):
					if not active_spawns.has(s):
						active_spawns.append(s)


func on_door_opened(door: Door) -> void:
	for c in door.cells:
		astar.set_point_solid(c, false)
	doors.erase(door.id)
	refresh_spawns(game.player.global_position)


func is_extraction(pos: Vector2) -> bool:
	return extraction_cells.has(to_cell(pos))


func random_spawn() -> Vector2:
	return cell_center(active_spawns[randi() % active_spawns.size()])


# ------------------------------------------------------------------ Vorschau im Editor

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	var karte := get_node_or_null("Karte") as TileMapLayer
	if karte != null and not karte.changed.is_connected(_queue_preview):
		karte.changed.connect(_queue_preview)
	_queue_preview()


func _queue_preview() -> void:
	if _preview_dirty:
		return
	_preview_dirty = true
	_rebuild_preview.call_deferred()


## Zeichnet die gemalte Karte mit der echten Grafik (Waende mit Mauerkrone, Hecke, Baeume,
## Landeplatz). Haengt als interner Knoten an «Karte» und wird nicht gespeichert.
func _rebuild_preview() -> void:
	_preview_dirty = false
	var karte := get_node_or_null("Karte") as TileMapLayer
	if karte == null:
		return
	if _preview != null:
		_preview.queue_free()
	_read_grid()
	extraction_cells.clear()
	_preview = Node2D.new()
	_preview.name = "Vorschau"
	_preview.visible = not karte_zeigen
	var layer := TileMapLayer.new()
	layer.tile_set = _make_tileset(false)
	_preview.add_child(layer)
	var deko := Node2D.new()
	deko.y_sort_enabled = true
	_preview.add_child(deko)
	_paint(layer, deko, false)
	_add_helipad(layer)
	# Zombie-Spawns rot markieren, sonst sieht man sie in der Hecke nicht
	var marks := Node2D.new()
	marks.draw.connect(func() -> void:
		for y in size.y:
			for x in size.x:
				if grid[y][x] == "Z":
					var r := Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE)).grow(-2.0)
					marks.draw_rect(r, Color(0.9, 0.15, 0.15, 0.35))
					marks.draw_rect(r, Color(1.0, 0.3, 0.3), false, 1.0))
	_preview.add_child(marks)
	karte.add_child(_preview, false, Node.INTERNAL_MODE_BACK)
