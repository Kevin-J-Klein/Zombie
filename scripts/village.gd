extends Node2D
## Das Dorf ist das Hauptmenue: Man laeuft herum und benutzt mit E das Haus (Rekorde,
## Startwaffe), den Haendler (Shop), das Auftragsbrett und den Wagen (Navi -> Level).
## Die Karte steht in village_data.gd, die Fenster baut village_ui.gd.

const Data := preload("res://scripts/village_data.gd")
const TILES_TEX := preload("res://art/pack/tiles.png")              # Gras und Asphalt wie im Level
const VILLAGE_TEX := preload("res://art/pack/village/tiles.png")    # Pflaster, Randsteine
const ART := "res://art/pack/village/"

const SRC_FLOOR := 0
const SRC_VILLAGE := 1
const T_ASPHALT := 2
const T_GRASS := 3
const BORDER_TREES := ["tree_0.png", "tree_3.png", "tree_1.png", "tree_2.png", "tree_4.png", "tree_5.png"]
const ZOMBIE_GROUPS := ["zombie_small", "zombie_axe", "zombie_small", "zombie_big"]

var size := Vector2i.ZERO
var floor_map: TileMapLayer
var entities: Node2D
var player: VillagePlayer
var ui: VillageUi
var zombies: Array[Dictionary] = []
var nearest := {}
var block_t := 0.0


func _ready() -> void:
	get_tree().paused = false
	Save.ensure_active()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	size = Vector2i(Data.MAP[0].length(), Data.MAP.size())
	_build_ground()
	entities = Node2D.new()
	entities.name = "Objekte"
	entities.y_sort_enabled = true
	add_child(entities)
	for o: Dictionary in Data.OBJECTS:
		_add_object(o)
	_add_border_trees()
	_add_fence()
	_add_bounds()
	_add_zombies()

	player = VillagePlayer.new()
	player.name = "Spieler"
	player.position = Data.START_AFTER_RUN if Save.back_from_run else Data.START
	Save.back_from_run = false
	entities.add_child(player)
	var b := Vector2(size) * G.TILE
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = int(b.x)
	player.camera.limit_bottom = int(b.y)
	player.camera.reset_smoothing()

	ui = VillageUi.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup(self)


func _process(delta: float) -> void:
	block_t -= delta
	_move_zombies(delta)
	player.input_enabled = not ui.window_open() and not Fade.busy
	nearest = {}
	var best := 1e9
	for it: Dictionary in Data.INTERACT:
		var d: float = player.global_position.distance_to(it["pos"])
		if d < it["reach"] and d < best:
			best = d
			nearest = it
	ui.set_prompt("" if nearest.is_empty() or not player.input_enabled else nearest["prompt"])
	if not nearest.is_empty() and player.input_enabled and block_t <= 0.0 \
			and Input.is_action_just_pressed("interact"):
		ui.open(nearest["kind"])


## Nach dem Schliessen eines Fensters kurz warten, damit dasselbe E es nicht gleich wieder oeffnet.
func on_window_closed() -> void:
	block_t = 0.25


# ------------------------------------------------------------------ Boden

func _build_ground() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(G.TILE, G.TILE)
	var floor_src := TileSetAtlasSource.new()
	floor_src.texture = TILES_TEX
	floor_src.texture_region_size = Vector2i(G.TILE, G.TILE)
	ts.add_source(floor_src, SRC_FLOOR)
	for tx in [T_ASPHALT, T_GRASS]:
		for v in 4:
			floor_src.create_tile(Vector2i(tx, v))
	var village_src := TileSetAtlasSource.new()
	village_src.texture = VILLAGE_TEX
	village_src.texture_region_size = Vector2i(G.TILE, G.TILE)
	ts.add_source(village_src, SRC_VILLAGE)
	for tx in 8:
		for ty in 2:
			village_src.create_tile(Vector2i(tx, ty))

	floor_map = TileMapLayer.new()
	floor_map.name = "Boden"
	floor_map.tile_set = ts
	add_child(floor_map)
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var variant := posmod(x * 7 + y * 13 + (x * y) % 5, 4)
			match Data.MAP[y][x]:
				"P", "p":
					floor_map.set_cell(cell, SRC_VILLAGE, Vector2i(variant, 0))
				"c":
					floor_map.set_cell(cell, SRC_VILLAGE, Vector2i(_curb(x, y), 1))
				":":
					floor_map.set_cell(cell, SRC_FLOOR, Vector2i(T_ASPHALT, variant))
				"-":
					floor_map.set_cell(cell, SRC_VILLAGE, Vector2i(4, 0))
				_:
					# Gras, ab und zu mit Blumen oder Bueschel
					var h := posmod(x * 31 + y * 17 + (x * y) % 7, 23)
					if h < 3 and y < 19:
						floor_map.set_cell(cell, SRC_VILLAGE, Vector2i(5 + h, 0))
					else:
						floor_map.set_cell(cell, SRC_FLOOR, Vector2i(T_GRASS, variant))


func _is_plaza(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y and Data.MAP[y][x] == "P"


## Randstein-Kachel: NW, N, NO, W, O, SW, S, SO - je nachdem, wo der Platz liegt.
func _curb(x: int, y: int) -> int:
	if _is_plaza(x, y + 1):
		return 1
	if _is_plaza(x, y - 1):
		return 6
	if _is_plaza(x + 1, y):
		return 3
	if _is_plaza(x - 1, y):
		return 4
	if _is_plaza(x + 1, y + 1):
		return 0
	if _is_plaza(x - 1, y + 1):
		return 2
	if _is_plaza(x + 1, y - 1):
		return 5
	return 7


# ------------------------------------------------------------------ Objekte

func _add_object(o: Dictionary) -> Node2D:
	var n := Node2D.new()
	n.position = o["pos"]
	var sink: float = o.get("sink", 0)
	if o.has("anim"):
		var a := AnimatedSprite2D.new()
		a.sprite_frames = SheetAnims.frames(o["anim"])
		a.position.y = SheetAnims.foot_offset(o["anim"])
		a.play(&"idle_down")
		n.add_child(a)
	else:
		var s := Sprite2D.new()
		s.texture = load(ART + o["tex"])
		s.offset = Vector2(0, -s.texture.get_height() * 0.5 + sink)
		n.add_child(s)
	if o.has("solid"):
		var sz: Array = o["solid"]
		_add_solid(n, Rect2(-sz[0] * 0.5, -sz[1], sz[0], sz[1]))
	entities.add_child(n)
	return n


func _add_solid(parent: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	shape.position = rect.get_center()
	body.add_child(shape)
	parent.add_child(body)


## Baumreihe am oberen, linken und rechten Rand (dahinter geht es nicht weiter).
func _add_border_trees() -> void:
	var i := 0
	var x := 10.0
	while x < size.x * G.TILE:
		_add_object({"tex": BORDER_TREES[i % BORDER_TREES.size()], "pos": Vector2(x, 30 + (i * 7) % 13)})
		x += 26 + (i * 5) % 9
		i += 1
	var y := 74.0
	while y < Data.FENCE_Y - 8:
		_add_object({"tex": BORDER_TREES[(i + 1) % BORDER_TREES.size()], "pos": Vector2(8 + (i * 3) % 5, y)})
		_add_object({"tex": BORDER_TREES[(i + 4) % BORDER_TREES.size()], "pos": Vector2(size.x * G.TILE - 8 - (i * 3) % 5, y + 12)})
		y += 44
		i += 1


func _add_fence() -> void:
	var fence: Texture2D = load(ART + "fence.png")
	for tx in size.x:
		if Data.GATE_TILES.has(tx):
			continue
		var s := Sprite2D.new()
		s.texture = fence
		s.position = Vector2(tx * G.TILE + 8, Data.FENCE_Y)
		s.offset = Vector2(0, -fence.get_height() * 0.5)
		entities.add_child(s)
	var gate_left: float = Data.GATE_TILES[0] * G.TILE
	var gate_right: float = (Data.GATE_TILES[-1] + 1) * G.TILE
	for px in [gate_left - 2.0, gate_right + 2.0]:
		_add_object({"tex": "fence_post.png", "pos": Vector2(px, Data.FENCE_Y + 2)})
	var holder := Node2D.new()
	add_child(holder)
	_add_solid(holder, Rect2(0, Data.FENCE_Y - 8, gate_left, 8))
	_add_solid(holder, Rect2(gate_right, Data.FENCE_Y - 8, size.x * G.TILE - gate_right, 8))


## Unsichtbare Grenzen: Kartenrand, Baumreihe und der Bereich der Strasse, den man betreten darf.
func _add_bounds() -> void:
	var w := float(size.x * G.TILE)
	var h := float(size.y * G.TILE)
	var holder := Node2D.new()
	add_child(holder)
	_add_solid(holder, Rect2(0, 0, w, 40))                       # Baeume oben
	_add_solid(holder, Rect2(0, 0, 16, Data.FENCE_Y))            # Baeume links
	_add_solid(holder, Rect2(w - 16, 0, 16, Data.FENCE_Y))       # Baeume rechts
	_add_solid(holder, Rect2(0, h - 6, w, 20))                   # unterer Rand
	_add_solid(holder, Rect2(0, Data.FENCE_Y, Data.ROAD_WALK.x, h - Data.FENCE_Y))
	_add_solid(holder, Rect2(Data.ROAD_WALK.y, Data.FENCE_Y, w - Data.ROAD_WALK.y, h - Data.FENCE_Y))


# ------------------------------------------------------------------ Zombies vor dem Zaun (nur Kulisse)

func _add_zombies() -> void:
	var i := 0
	for zone: Vector2 in Data.ZOMBIE_ZONES:
		for k in 3:
			var group: String = ZOMBIE_GROUPS[(i + k) % ZOMBIE_GROUPS.size()]
			var s := AnimatedSprite2D.new()
			s.sprite_frames = SheetAnims.frames(group)
			s.offset.y = SheetAnims.foot_offset(group)
			s.position = Vector2(lerpf(zone.x, zone.y, (k + 0.5) / 3.0), Data.FENCE_Y + 22 + k * 24 + (i * 9) % 10)
			s.speed_scale = 0.7
			entities.add_child(s)
			var z := {"node": s, "zone": zone, "dir": 1.0 if (i + k) % 2 == 0 else -1.0, "speed": 7.0 + 2.5 * k, "wait": 0.0}
			zombies.append(z)
			_zombie_anim(z)
		i += 1


func _zombie_anim(z: Dictionary) -> void:
	var s: AnimatedSprite2D = z["node"]
	if z["wait"] > 0.0:
		s.play(&"idle_side" if z["dir"] > 0.0 else &"idle_left")
	else:
		s.play(&"walk_side" if z["dir"] > 0.0 else &"walk_left")


func _move_zombies(delta: float) -> void:
	for z: Dictionary in zombies:
		var s: AnimatedSprite2D = z["node"]
		var zone: Vector2 = z["zone"]
		if z["wait"] > 0.0:
			z["wait"] -= delta
			if z["wait"] <= 0.0:
				_zombie_anim(z)
			continue
		s.position.x += z["dir"] * z["speed"] * delta
		if s.position.x < zone.x or s.position.x > zone.y:
			s.position.x = clampf(s.position.x, zone.x, zone.y)
			z["dir"] = -z["dir"]
			z["wait"] = randf_range(1.0, 3.5)
			_zombie_anim(z)
