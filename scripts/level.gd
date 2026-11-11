class_name Level
extends Node2D
## Baut das Level aus der Textkarte (level_data.gd): Kacheln, Kollision,
## Wegfindung fuer Zombies und alle Objekte (Tueren, Fenster, Automaten ...).

const LevelData := preload("res://scripts/level_data.gd")
## Grafiken kommen aus dem Asset-Pack (tools/import_asset_pack.py -> art/pack/)
const TILES_TEX := preload("res://art/pack/tiles.png")
const WALLS_TEX := preload("res://art/pack/walls.png")

const SRC_FLOOR := 0
const SRC_WALL := 1          # Spalte = Nachbarmaske (N=1, O=2, S=4, W=8)
const WALL_TOP := 0          # Zeilen im Wand-Atlas
const WALL_FRONT := 1
const WALL_WINDOW := 2
const T_HEDGE := 7
const T_WOODS_GROUND := 8    # Waldboden ohne Buesch (Spawns, Luecken in der Hecke)
const FLOOR_TILES := {".": 0, ",": 1, ":": 2, "~": 3, ";": 4, "X": 9}
## Kartenzeichen -> Varianten (eine wird pro Zelle fest ausgewuerfelt)
const SOLID_PROPS := {
	"B": ["res://art/pack/props/crate_0.png", "res://art/pack/props/crate_1.png", "res://art/pack/props/crate_2.png"],
	"O": ["res://art/pack/props/barrel_0.png", "res://art/pack/props/barrel_1.png", "res://art/pack/props/barrel_2.png"],
	"C": ["res://art/pack/props/container_0.png", "res://art/pack/props/container_1.png"],
	"Y": ["res://art/pack/props/tree_0.png", "res://art/pack/props/tree_1.png"],
}
const WOODS_TREES := ["res://art/pack/props/woods_tree_0.png", "res://art/pack/props/woods_tree_1.png",
	"res://art/pack/props/woods_tree_2.png", "res://art/pack/props/woods_tree_3.png"]

var game: Node
var grid: Array[String] = []
var size := Vector2i.ZERO
var astar := AStarGrid2D.new()

var floor_map: TileMapLayer
var decals: Node2D
var entities: Node2D
var fx: Node2D

var windows := {}                         # Vector2i -> Barricade
var doors := {}                           # String -> Door
var spawns: Array[Vector2i] = []
var active_spawns: Array[Vector2i] = []
var reached := {}                         # Zellen, die der Spieler aktuell erreichen kann
var extraction_cells := {}
var player_start := Vector2.ZERO
var objects := {}                         # Kartenzeichen -> Array von Nodes (fuer Tests/Quest)


func build(p_game: Node) -> void:
	game = p_game
	grid.assign(LevelData.MAP)
	size = Vector2i(grid[0].length(), grid.size())

	floor_map = TileMapLayer.new()
	floor_map.name = "Boden"
	floor_map.tile_set = _make_tileset()
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
	astar.cell_size = Vector2(G.TILE, G.TILE)
	astar.offset = Vector2(G.TILE, G.TILE) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	var door_cells := {}
	for y in size.y:
		for x in size.x:
			var ch := grid[y][x]
			var cell := Vector2i(x, y)
			var variant := posmod(x * 7 + y * 13 + (x * y) % 5, 4)
			if ch == " ":
				floor_map.set_cell(cell, SRC_FLOOR, Vector2i(T_HEDGE, variant))
				astar.set_point_solid(cell, true)
				_maybe_add_tree(x, y)
			elif ch == "#" or LevelData.WALLBUYS.has(ch):
				var front := _is_open(x, y + 1)
				floor_map.set_cell(cell, SRC_WALL, Vector2i(_wall_mask(x, y), WALL_FRONT if front else WALL_TOP))
				astar.set_point_solid(cell, true)
				if LevelData.WALLBUYS.has(ch):
					_add_wallbuy(cell, LevelData.WALLBUYS[ch])
			elif ch == "W":
				var mask := _wall_mask(x, y)
				if mask == 0:
					# Fenster mitten in der Hecke: nur eine Luecke, die Bretter zeichnet die Barrikade
					floor_map.set_cell(cell, SRC_FLOOR, Vector2i(T_WOODS_GROUND, variant))
				else:
					floor_map.set_cell(cell, SRC_WALL, Vector2i(mask, WALL_WINDOW))
				_add_window(cell)
			else:
				var t: int = FLOOR_TILES.get(ch, -1)
				if t == -1:
					t = _neighbor_floor(x, y)
				floor_map.set_cell(cell, SRC_FLOOR, Vector2i(t, variant))
				if ch == "X":
					extraction_cells[cell] = true
				elif ch == "Z":
					spawns.append(cell)
				elif ch == "P":
					player_start = cell_center(cell)
				elif LevelData.DOORS.has(ch):
					if not door_cells.has(ch):
						door_cells[ch] = []
					door_cells[ch].append(cell)
					astar.set_point_solid(cell, true)
				elif not FLOOR_TILES.has(ch):
					_add_object(ch, cell)

	for id in door_cells:
		var d := Door.new()
		d.setup(game, self, id, door_cells[id])
		entities.add_child(d)
		doors[id] = d

	_add_helipad()


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(G.TILE, G.TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, G.L_WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	var h := G.TILE * 0.5
	var poly := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])

	# Boden: 10 Typen x 4 Varianten, nur die Hecke ist fest
	var floor_src := TileSetAtlasSource.new()
	floor_src.texture = TILES_TEX
	floor_src.texture_region_size = Vector2i(G.TILE, G.TILE)
	ts.add_source(floor_src, SRC_FLOOR)
	for tx in 10:
		for v in 4:
			var c := Vector2i(tx, v)
			floor_src.create_tile(c)
			if tx == T_HEDGE:
				_solid_tile(floor_src, c, poly)

	# Waende: 16 Nachbarmasken x (oben, Vorderseite, Fenster). Fenster haben keine
	# Kollision - dort sperrt die Barrikade nur den Spieler.
	var wall_src := TileSetAtlasSource.new()
	wall_src.texture = WALLS_TEX
	wall_src.texture_region_size = Vector2i(G.TILE, G.TILE)
	ts.add_source(wall_src, SRC_WALL)
	for m in 16:
		for row in 3:
			var c := Vector2i(m, row)
			wall_src.create_tile(c)
			if row != WALL_WINDOW:
				_solid_tile(wall_src, c, poly)
	return ts


func _solid_tile(src: TileSetAtlasSource, c: Vector2i, poly: PackedVector2Array) -> void:
	var td := src.get_tile_data(c, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, poly)


func _is_wall(x: int, y: int) -> bool:
	var ch := _char(x, y)
	return ch == "#" or ch == "W" or LevelData.WALLBUYS.has(ch)


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
func _maybe_add_tree(x: int, y: int) -> void:
	if posmod(x * 13 + y * 7 + (x * y) % 3, 5) != 0:
		return
	for o in [Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(-1, -1), Vector2i(0, -1),
			Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		var c: Vector2i = Vector2i(x, y) + o
		if in_bounds(c) and grid[c.y][c.x] != " ":
			return
	# Knoten steht am Stamm (fuer die Sortierung nach y), das Bild ragt nach oben
	var s := Sprite2D.new()
	s.texture = load(WOODS_TREES[posmod(x * 5 + y * 3, WOODS_TREES.size())])
	s.position = cell_center(Vector2i(x, y)) + Vector2(posmod(x * 3 + y, 5) - 2, 7.0)
	s.offset = Vector2(0, -s.texture.get_height() * 0.5)
	entities.add_child(s)


## Markierung auf dem Landeplatz (X-Felder), mittig ueber alle Felder.
func _add_helipad() -> void:
	if extraction_cells.is_empty():
		return
	var r := Rect2i(extraction_cells.keys()[0], Vector2i.ONE)
	for c: Vector2i in extraction_cells:
		r = r.expand(c).expand(c + Vector2i.ONE)
	var s := Sprite2D.new()
	s.texture = preload("res://art/pack/props/helipad.png")
	s.position = Vector2(r.position + r.end) * 0.5 * G.TILE
	floor_map.add_child(s)


func _char(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= size.x or y >= size.y:
		return " "
	return grid[y][x]


func _is_open(x: int, y: int) -> bool:
	var ch := _char(x, y)
	return not (ch == " " or ch == "#" or ch == "W" or LevelData.WALLBUYS.has(ch))


func _neighbor_floor(x: int, y: int) -> int:
	for o in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var ch := _char(x + o.x, y + o.y)
		if FLOOR_TILES.has(ch) and ch != "X":
			return FLOOR_TILES[ch]
	return T_WOODS_GROUND


func _register(ch: String, node: Node) -> void:
	if not objects.has(ch):
		objects[ch] = []
	objects[ch].append(node)


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
	var plate := Sprite2D.new()
	plate.texture = preload("res://art/white.png")
	plate.scale = Vector2(15, 9)
	plate.modulate = Color(0.1, 0.08, 0.06, 0.55)
	plate.show_behind_parent = true
	it.sprite.add_child(plate)
	# Wandkaeufe liegen auf der Wand und duerfen nie von Figuren verdeckt wirken -> eigene Ebene unter den Objekten
	decals.add_child(it)
	_register(weapon_id, it)


func _add_object(ch: String, cell: Vector2i) -> void:
	var pos := cell_center(cell)
	if SOLID_PROPS.has(ch):
		var n := Node2D.new()
		n.position = pos
		var s := Sprite2D.new()
		var variants: Array = SOLID_PROPS[ch]
		s.texture = load(variants[posmod(cell.x * 31 + cell.y * 17, variants.size())])
		s.position = Vector2(0, 8.0 - s.texture.get_height() * 0.5)
		n.add_child(s)
		if ch == "Y":
			_add_solid(n, 8.0, 8.0)
		else:
			_add_solid(n)
		entities.add_child(n)
		astar.set_point_solid(cell, true)
		return

	if ch == "x" or ch == "y" or ch == "z":
		var p := Pickup.new()
		p.position = pos
		p.setup(game)
		entities.add_child(p)
		_register("part", p)
		return
	if ch == "o":
		var g := Gnome.new()
		g.position = pos
		g.setup(game)
		entities.add_child(g)
		_register("gnome", g)
		return

	var it := Interactable.new()
	it.position = pos
	match ch:
		"A":
			it.setup(game, "shop", preload("res://art/pack/props/shop.png"))
		"M":
			it.setup(game, "box", preload("res://art/pack/props/box.png"))
		"U":
			it.setup(game, "upgrade", preload("res://art/pack/props/upgrade.png"))
		"E":
			# Kein passender Schalter im Pack -> Platzhalter
			it.setup(game, "power", preload("res://art/switch_base.png"))
		"K":
			it.setup(game, "radio", preload("res://art/pack/props/radio.png"))
		_:
			if LevelData.PERK_CHARS.has(ch):
				var perk: String = LevelData.PERK_CHARS[ch]
				# Perk-Automaten sind schon in der Perk-Farbe eingefaerbt
				it.setup(game, "perk", load("res://art/pack/props/perk_%s.png" % perk))
				it.perk_id = perk
			else:
				push_warning("Unbekanntes Kartenzeichen '%s' bei %s" % [ch, cell])
				return
	_add_solid(it)
	entities.add_child(it)
	astar.set_point_solid(cell, true)
	_register(ch, it)


# ------------------------------------------------------------------ Abfragen

func to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / G.TILE), floori(pos.y / G.TILE))


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.y + 0.5) * G.TILE


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size) * G.TILE)


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
