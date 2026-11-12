extends Node2D
## Das Dorf ist das Hauptmenue: Man laeuft herum und benutzt mit E das Haus (Rekorde,
## Startwaffe), den Haendler (Shop), das Auftragsbrett und den Wagen (Navi -> Level).
##
## Die Welt wird im Godot-Editor gebaut (scenes/village.tscn), dieses Skript liest sie nur aus:
##   Boden        TileMapLayer - mit dem Tileset ground.tres malen (Gras, Pflaster, Asphalt)
##   Objekte      alles, was steht: Szenen aus scenes/props/ hineinziehen (nach y sortiert)
##   Orte         VillageSpot: wo man mit E etwas benutzt
##   Schilder     VillageTag: Namensschilder ueber den Orten
##   Start, StartNachPartie   wo die Figur auftaucht (beim Spielstart / nach einer Partie)
##   Zombies      ZombieZone: Bereiche, in denen Zombies als Kulisse schlurfen
##   Bewohner     VillageNpc: hier laufen die Charaktere herum, die man gerade nicht spielt;
##                mit E ansprechen = Charakter wechseln
##   Grenzen      unsichtbare Waende (Kollisionsformen)
## Die Fenster baut village_ui.gd.

const ZOMBIE_GROUPS := ["zombie_small", "zombie_axe", "zombie_small", "zombie_big"]

var size := Vector2i.ZERO                   # Kartengroesse in Kacheln (bemalter Bereich)
var spots: Array[Dictionary] = []           # {"kind", "pos", "reach", "prompt"}
var tags: Array[Dictionary] = []            # {"text", "pos", "alert"}
var start := Vector2.ZERO
var start_after_run := Vector2.ZERO
var player: VillagePlayer
var ui: VillageUi
var zombies: Array[Dictionary] = []
var nearest := {}
var npcs: Array[VillageNpc] = []
var block_t := 0.0

@onready var floor_map: TileMapLayer = $Boden
@onready var entities: Node2D = $Objekte


func _ready() -> void:
	get_tree().paused = false
	Save.ensure_active()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	size = floor_map.get_used_rect().end
	for n in $Orte.get_children():
		if n is VillageSpot:
			spots.append(n.as_dict())
	for n in $Schilder.get_children():
		if n is VillageTag:
			tags.append(n.as_dict())
	start = $Start.global_position
	start_after_run = $StartNachPartie.global_position
	_add_zombies()
	# Bewohner zu den anderen Figuren stellen (nach y sortiert); Bereich merkt sich jeder selbst
	for n in $Bewohner.get_children():
		if n is VillageNpc:
			npcs.append(n)
	for n in npcs:
		n.reparent(entities)
	_assign_npcs()
	Save.changed.connect(_assign_npcs)

	player = VillagePlayer.new()
	player.name = "Spieler"
	player.position = start_after_run if Save.back_from_run else start
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
	for it: Dictionary in spots:
		var d: float = player.global_position.distance_to(it["pos"])
		if d < it["reach"] and d < best:
			best = d
			nearest = it
	for npc in npcs:
		if npc.charakter == "":
			continue
		var d := player.global_position.distance_to(npc.global_position)
		if d < npc.reach * 2.0:
			npc.look_at_player(player.global_position)
		if d < npc.reach and d < best:
			best = d
			nearest = {"kind": "npc", "npc": npc, "prompt": npc.prompt()}
	ui.set_prompt("" if nearest.is_empty() or not player.input_enabled else nearest["prompt"])
	if not nearest.is_empty() and player.input_enabled and block_t <= 0.0 \
			and Input.is_action_just_pressed("interact"):
		if nearest["kind"] == "npc":
			talk_to(nearest["npc"])
		else:
			ui.open(nearest["kind"])


## Bewohner ansprechen: man spielt ab jetzt diesen Charakter, er begruesst einen.
## Der bisherige Charakter laeuft danach an seiner Stelle herum (_assign_npcs).
func talk_to(npc: VillageNpc) -> void:
	var id := npc.charakter
	if id == "" or id == Save.character():
		return
	Save.set_character(id)
	ui.say(HubData.CHARACTERS[id].get("gruss", ""), player)
	block_t = 0.4


## Alle Charaktere ausser dem gewaehlten auf die Bewohner-Plaetze verteilen.
func _assign_npcs() -> void:
	var others: Array[String] = []
	for id: String in HubData.CHARACTERS:
		if id != Save.character():
			others.append(id)
	for i in npcs.size():
		npcs[i].set_charakter(others[i] if i < others.size() else "")


## Nach dem Schliessen eines Fensters kurz warten, damit dasselbe E es nicht gleich wieder oeffnet.
func on_window_closed() -> void:
	block_t = 0.25


# ------------------------------------------------------------------ Zombies als Kulisse

func _add_zombies() -> void:
	var i := 0
	for zone in $Zombies.get_children():
		if not zone is ZombieZone:
			continue
		var x0: float = zone.position.x
		var x1: float = x0 + zone.width
		for k in zone.count:
			var group: String = ZOMBIE_GROUPS[(i + k) % ZOMBIE_GROUPS.size()]
			var s := AnimatedSprite2D.new()
			s.sprite_frames = SheetAnims.frames(group)
			s.offset.y = SheetAnims.foot_offset(group)
			s.position = Vector2(lerpf(x0, x1, (k + 0.5) / zone.count), zone.position.y + k * zone.row_gap + (i * 9) % 10)
			s.speed_scale = 0.7
			entities.add_child(s)
			var z := {"node": s, "zone": Vector2(x0, x1), "dir": 1.0 if (i + k) % 2 == 0 else -1.0,
				"speed": 7.0 + 2.5 * k, "wait": 0.0}
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
