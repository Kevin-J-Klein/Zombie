extends Node
## Automatischer Durchlauf ohne Fenster:
##   godot --headless --path . res://tests/smoke_test.tscn
## Prueft Level-Aufbau, Zombie-Wegfindung, Schiessen, Runden, Kaeufe, Perks,
## Mystery-Box, Power-ups und die komplette Quest bis zum Sieg. Danach das Dorf:
## Spielstand, Schrott, Shop, Startwaffe, Auftraege, Navi und alle Fenster.
## Speicherplaetze und Startbildschirm. Benutzt eigene Test-Spielstaende (user://test_save_N.json).

var game: Node
var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("OK    " if cond else "FAIL  ") + msg)
	if not cond:
		fails += 1


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func new_game() -> void:
	if game != null:
		game.queue_free()
		await get_tree().process_frame
	get_tree().paused = false
	game = load("res://scenes/vorstadt.tscn").instantiate()
	add_child(game)
	await wait(0.3)


func nearest_zombie() -> Node2D:
	var best: Node2D = null
	for z in get_tree().get_nodes_in_group("zombies"):
		if best == null or z.global_position.distance_to(game.player.global_position) < best.global_position.distance_to(game.player.global_position):
			best = z
	return best


func _ready() -> void:
	Save.use_test_file()
	Engine.time_scale = 8.0
	await run()
	await run_village()
	await run_slots()
	print("SMOKE RESULT: %d Fehler" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func run() -> void:
	await new_game()
	var level: Level = game.level
	var p: Player = game.player

	check(level.size == Vector2i(60, 38), "Karte 60x38 geladen")
	check(not level.has_node("Objekte_Editor") or level.get_node("Objekte_Editor").is_queued_for_deletion(),
		"Editor-Objekte wurden in Spielobjekte umgewandelt")
	check(level.objects.has("shop") and level.objects["smg"].size() == 1 and level.objects["part"].size() == 3
		and level.player_start != Vector2.ZERO, "Shop, Wandkauf, Funkteile und Startpunkt aus der Szene")
	check(level.spawns.size() == 13, "13 Zombie-Spawns (%d)" % level.spawns.size())
	check(level.windows.size() == 13, "13 Fenster (%d)" % level.windows.size())
	check(level.doors.size() == 5, "5 Tueren (%d)" % level.doors.size())
	check(level.active_spawns.size() == 3, "Zu Beginn 3 aktive Spawns (%d)" % level.active_spawns.size())
	check(p.weapon()["id"] == "pistol" and game.points == 500, "Start mit Pistole und 500 Punkten")

	# --- Runde 1: Zombies muessen durch die Fenster kommen und den Spieler treffen
	var reached := false
	var hurt := false
	var torn := false
	for i in 400:
		await wait(0.1)
		var z := nearest_zombie()
		if z != null and z.global_position.distance_to(p.global_position) < 20.0:
			reached = true
		if p.hp < p.max_hp:
			hurt = true
		for w in level.windows.values():
			if w.planks < 5:
				torn = true
		if reached and hurt:
			break
	check(game.round_num == 1, "Runde 1 gestartet")
	check(torn, "Zombies reissen Barrikaden ab")
	check(reached, "Zombies erreichen den Spieler")
	check(hurt, "Zombies verursachen Schaden (HP %.0f)" % p.hp)

	# --- Schiessen
	p.invuln = 1e9
	var z0 := nearest_zombie()
	var before: int = game.points
	if z0 != null:
		p.aim_dir = (z0.global_position - p.global_position).normalized()
		var hp0: float = z0.hp
		p.fire()
		check(z0.hp < hp0 and game.points > before, "Schuss trifft Zombie und gibt Punkte")
	else:
		check(false, "Kein Zombie zum Beschiessen da")

	check(p.weapon()["mag"] == 7, "Magazin zaehlt herunter")

	# --- Runden durchspielen (Zombies werden automatisch erledigt)
	for i in 600:
		await wait(0.1)
		for z in get_tree().get_nodes_in_group("zombies"):
			if z.state != Zombie.St.RISE:
				z.hit(100000.0, Vector2.RIGHT, false)
		if game.round_num >= 3:
			break
	check(game.round_num >= 3, "Runden zaehlen hoch (Runde %d)" % game.round_num)
	check(game.kills >= 14, "Kills werden gezaehlt (%d)" % game.kills)

	# --- Panzer-Zombie
	check(G.tank_chance(G.TANK_FROM_ROUND - 1) == 0.0 and G.tank_chance(30) == G.TANK_MAX_CHANCE,
		"Panzer-Zombies erst ab Runde %d, Anteil begrenzt" % G.TANK_FROM_ROUND)
	var tank: Zombie = game.ZOMBIE_SCENE.instantiate()
	tank.setup(game, 5, true)
	tank.position = level.cell_center(Vector2i(13, 12))
	level.entities.add_child(tank)
	check(tank.tank and not tank.runner and tank.hp == G.zombie_health(5) * G.TANK_HP_MULT and tank.speed < 25.0,
		"Panzer-Zombie: viel Leben, langsam")
	await wait(1.2)
	check(tank.body.sprite_frames.has_animation(&"attack_side") and String(tank.body.animation).begins_with("walk"),
		"Panzer-Zombie laeuft mit eigener Animation (%s)" % tank.body.animation)
	var pts_before: int = game.points
	tank.hit(1e9, Vector2.RIGHT, false)
	var tank_pts := (60 + G.TANK_KILL_BONUS) * (2 if game.double_points_t > 0.0 else 1)
	check(game.points - pts_before == tank_pts, "Panzer-Zombie gibt Bonuspunkte (%d)" % (game.points - pts_before))

	# --- Tueren
	game.points = 500000
	var expected := {"Haustür": 7, "Markt": 8, "Lagerraum": 9, "Gartentor": 11, "Garage": 13}
	for id in ["Haustür", "Markt", "Lagerraum", "Gartentor", "Garage"]:
		level.doors[id].interact(p)
		await wait(0.05)
		check(level.active_spawns.size() == expected[id], "Tuer %s offen -> %d aktive Spawns (%d)" % [id, expected[id], level.active_spawns.size()])
	var all_paths := true
	for s in level.spawns:
		if level.find_path(level.cell_center(s), level.player_start).is_empty():
			all_paths = false
	check(all_paths, "Von jedem Spawn gibt es einen Weg zum Spieler")

	# --- Wandkaeufe und Shop
	level.objects["smg"][0].interact(p)
	check(p.has_weapon("smg") and p.weapons.size() == 2, "Wandkauf MP")
	level.objects["rifle"][0].interact(p)
	check(p.has_weapon("rifle") and not p.has_weapon("smg") and p.weapons.size() == 2, "Dritte Waffe ersetzt die aktuelle")
	p.aim_dir = Vector2.RIGHT
	p.fire()
	level.objects["rifle"][0].interact(p)
	check(p.ammo_full("rifle"), "Munition an der Wand nachkaufen")
	game.open_shop()
	check(game.menu_open and not p.input_enabled, "Shop oeffnet")
	game.buy_shop_item("armor")
	check(p.armor == 100.0, "Panzerung gekauft")
	game.buy_shop_item("dmr")
	check(p.has_weapon("dmr"), "Waffe im Shop gekauft")
	game.close_shop()
	check(not game.menu_open and p.input_enabled, "Shop schliesst")

	# --- Strom, Perks, Upgrade
	level.objects["health"][0].interact(p)
	check(not game.has_perk("health"), "Perk ohne Strom nicht kaufbar")
	level.objects["revive"][0].interact(p)
	check(game.has_perk("revive"), "Zweite Chance geht ohne Strom")
	level.objects["power"][0].interact(p)
	check(game.power_on, "Strom eingeschaltet")
	for ch in ["health", "fire", "reload", "stamina"]:
		level.objects[ch][0].interact(p)
	check(game.perks.size() == 5 and p.max_hp == 250.0, "Alle 5 Perks gekauft, Stahlhaut wirkt")
	for i in 4:
		level.objects["upgrade"][0].interact(p)
	check(p.weapon()["level"] == 3, "Waffe 3x aufgeruestet (%s)" % G.weapon_name(p.weapon()["id"], p.weapon()["level"]))
	p.fire()

	# --- Mystery-Box
	var box: Interactable = level.objects["box"][0]
	box.interact(p)
	check(box.box_state == Interactable.Box.ROLLING, "Mystery-Box dreht")
	await wait(3.0)
	check(box.box_state == Interactable.Box.OFFER, "Mystery-Box bietet Waffe an")
	var offered := box.box_weapon
	box.interact(p)
	check(p.has_weapon(offered), "Waffe aus der Box genommen (%s)" % offered)
	p.give_weapon("raygun")
	p.fire()

	# --- Power-ups
	for kind in G.POWERUPS:
		game.apply_powerup(kind)
	check(game.insta_kill_t > 0.0 and game.double_points_t > 0.0, "Power-ups aktiv")
	await wait(0.2)
	check(game.zombie_count() == 0, "Bombe raeumt alle Zombies ab")

	# --- Gartenzwerge
	for g in level.objects["gnome"].duplicate():
		g.hit(1.0, Vector2.RIGHT, false)
	check(game.gnomes == 3, "3 Gartenzwerge erwischt")

	# --- Quest
	check(level.objects["part"].size() == 3, "3 Funkteile auf der Karte")
	for part in level.objects["part"].duplicate():
		p.global_position = part.global_position
		await wait(0.15)
	check(game.parts == 3, "Funkteile eingesammelt (%d/3)" % game.parts)
	level.objects["radio"][0].interact(p)
	check(game.radio_fixed and game.defend_t > 0.0, "Funkgeraet repariert, Verteidigung laeuft")
	game.defend_t = 0.5
	await wait(1.0)
	check(game.extraction_open, "Landeplatz ist offen")
	p.global_position = level.cell_center(level.extraction_cells.keys()[0])
	await wait(0.3)
	check(game.over and game.won, "Sieg am Landeplatz")
	check(G.last_result.get("won", false), "Ergebnis gespeichert")

	# --- Zweite Chance und Game Over
	await new_game()
	p = game.player
	game.give_perk("revive")
	p.take_damage(9999.0)
	check(not game.over and p.hp > 0.0 and not game.has_perk("revive"), "Zweite Chance rettet einmal")
	p.invuln = 0.0
	p.take_damage(9999.0)
	check(game.over and not game.won, "Game Over ohne Zweite Chance")
	get_tree().paused = false


# ------------------------------------------------------------------ Dorf, Spielstand, Auftraege

func run_village() -> void:
	if game != null:
		game.queue_free()
		game = null
		await get_tree().process_frame

	# --- Ergebnis der beiden Partien oben (ein Sieg, ein Game Over) im Spielstand
	var d: Dictionary = Save.data
	check(d["games"] == 2 and d["best_round"] >= 3 and d["most_kills"] >= 14, "Rekorde nach 2 Partien (%d Partien, Runde %d)" % [d["games"], d["best_round"]])
	check(d["fastest_escape"] > 0.0 and d["eggs"]["escape"] and d["eggs"]["gnomes"], "Flucht und Gartenzwerge als Easter Eggs vermerkt")
	check(Save.scrap() > HubData.SCRAP_ESCAPE_BONUS, "Schrott fuer die Partien gutgeschrieben (%d)" % Save.scrap())
	check(G.last_result.has("scrap") and G.last_result["scrap"] >= 0, "End-Bildschirm kennt den Schrott der Partie")
	check(Save.dest_stats("vorstadt")["escapes"] == 1, "Flucht zaehlt fuers Ziel Vorstadt")
	check(Save.dest_unlocked("tankstelle") and not Save.dest_playable("tankstelle"), "Tankstelle freigeschaltet, aber noch nicht gebaut")
	check(not Save.dest_unlocked("spital"), "Spital noch gesperrt (%s)" % HubData.unlock_text("spital"))

	# --- Speichern und Laden
	var scrap_before := Save.scrap()
	Save.write()
	Save.load_file()
	check(Save.scrap() == scrap_before and Save.data["games"] == 2 and Save.data["scrap"] is int, "Spielstand uebersteht Speichern und Laden")

	# --- Shop und Startwaffe
	Save.data["scrap"] = 100
	check(not Save.buy_weapon("smg") and not Save.owns("smg"), "Ohne genug Schrott kein Kauf")
	Save.data["scrap"] = 1000
	check(Save.buy_weapon("smg") and Save.owns("smg") and Save.scrap() == 1000 - HubData.START_WEAPONS["smg"], "MP im Dorf-Shop gekauft")
	Save.set_start_weapon("rifle")
	check(Save.start_weapon() == "pistol", "Nicht gekaufte Waffe kann nicht Startwaffe sein")
	Save.set_start_weapon("smg")
	await new_game()
	check(game.player.weapons.size() == 1 and game.player.weapon()["id"] == "smg", "Partie beginnt mit der gewaehlten Startwaffe")

	# --- Auftraege
	check(Save.contracts().size() == HubData.CONTRACT_OFFERS, "Auftragsbrett hat %d Angebote" % HubData.CONTRACT_OFFERS)
	Save.data["contracts"] = [
		{"id": "kills_75", "state": "open", "progress": 0}, {"id": "repair_15", "state": "open", "progress": 0},
		{"id": "round_5", "state": "open", "progress": 0}, {"id": "melee_20", "state": "open", "progress": 0},
		{"id": "escape", "state": "open", "progress": 0}]
	check(Save.accept_contract("kills_75") and Save.accept_contract("repair_15") and Save.accept_contract("round_5"), "3 Auftraege angenommen")
	check(not Save.accept_contract("melee_20"), "Vierter Auftrag wird abgelehnt (hoechstens %d)" % HubData.MAX_ACTIVE_CONTRACTS)
	await new_game()
	check(game.hud.contract_rows.size() == 3, "Level zeigt die 3 aktiven Auftraege")
	var done_names: Array[String] = []
	var on_done := func(def: Dictionary) -> void: done_names.append(def["name"])
	Save.contract_done.connect(on_done)
	for i in 15:
		game.on_plank_repaired()
	check(done_names == ["Handwerker"] and Save.has_claimable(), "Auftrag «Handwerker» nach 15 Brettern erfuellt")
	game.player.invuln = 1e9
	for i in 400:
		await wait(0.1)
		for z in get_tree().get_nodes_in_group("zombies"):
			if z.state != Zombie.St.RISE:
				z.hit(100000.0, Vector2.RIGHT, false)
		if game.kills >= 10:
			break
	var kills_c: Dictionary = Save.contracts()[0]
	check(kills_c["progress"] == game.kills and game.kills >= 10, "Kills zaehlen fuer «Kammerjaeger» (%d/75)" % kills_c["progress"])
	var round_c: Dictionary = Save.contracts()[2]
	check(round_c["progress"] == game.round_num, "Runde zaehlt fuer «Aufwaermen» (%d/5)" % round_c["progress"])
	game.hud._leave_run()
	check(game.hud.leave_button.text.begins_with("Sicher"), "Verlassen der Partie fragt nach")
	Save.contract_done.disconnect(on_done)
	Save.abort_run()
	await new_game()
	check(Save.contracts()[0]["progress"] >= 10 and Save.contracts()[2]["progress"] == 0, "Neue Partie: Kills bleiben, Runden-Auftrag beginnt neu")
	var before_claim := Save.scrap()
	check(Save.claim_contract("repair_15") == 100 and Save.scrap() == before_claim + 100 and Save.contracts().size() == 4, "Belohnung abgeholt (+100 Schrott)")
	Save.cancel_contract("round_5")
	check(Save.active_count() == 1, "Auftrag abgebrochen")
	game.player.take_damage(99999.0)
	check(game.over and Save.contracts().size() == HubData.CONTRACT_OFFERS and Save.data["board_news"], "Nach der Partie ist das Brett wieder aufgefuellt")
	var still := false
	for c: Dictionary in Save.contracts():
		if c["id"] == "round_5":
			still = true
	check(not still, "Abgebrochener Auftrag wurde ausgetauscht")
	check(Save.back_from_run, "Nach der Partie steht man beim Wagen")
	get_tree().paused = false
	game.queue_free()
	game = null
	await get_tree().process_frame

	# --- Dorf-Szene und Fenster
	var village: Node = load("res://scenes/village.tscn").instantiate()
	add_child(village)
	await wait(0.3)
	check(village.size == Vector2i(36, 24), "Dorf-Karte 36x24 geladen")
	check(village.spots.size() == 4 and village.tags.size() == 4 and village.zombies.size() == 6,
		"Dorf-Szene: 4 Orte, 4 Schilder, 6 Kulissen-Zombies")
	check(village.entities.has_node("Haus") and village.entities.has_node("Laden") and village.floor_map.tile_set.get_terrains_count(0) == 3,
		"Haus und Laden stehen im Dorf, Boden-Tileset hat 3 Terrains")
	var kanten: TileMapLayer = village.get_node_or_null("Kanten")
	check(kanten != null and kanten.get_used_cells().size() > 0 and kanten.tile_set == village.floor_map.tile_set,
		"Bordsteine liegen auf der Ebene Kanten (gleiches Tileset wie der Boden)")
	check(village.player.position == village.start_after_run and not Save.back_from_run, "Spieler startet nach der Partie beim Wagen")
	check(village.ui.alert_label.visible, "Ausrufezeichen ueber dem Auftragsbrett")
	for it: Dictionary in village.spots:
		village.player.global_position = it["pos"]
		await wait(0.1)
		check(village.nearest.get("kind", "") == it["kind"] and village.ui.prompt_label.text == it["prompt"], "Hinweis bei %s: %s" % [it["kind"], it["prompt"]])
	for kind in ["house", "shop", "board", "car", "settings"]:
		village.ui.open(kind)
		await wait(0.1)
		check(village.ui.window_open() and not village.player.input_enabled, "Fenster «%s» oeffnet und haelt die Figur an" % kind)
		village.ui.close()
		await wait(0.1)
	check(not village.ui.window_open() and village.player.input_enabled, "Fenster schliessen, Figur laeuft wieder")
	check(not village.ui.alert_label.visible, "Ausrufezeichen weg, nachdem das Brett angeschaut wurde")
	# Navi: Ziel waehlen
	village.ui.open("car")
	village.ui._navi_pick("tankstelle")
	await wait(0.1)
	check(village.ui.navi_dest == "tankstelle" and village.ui.window_open(), "Navi: Tankstelle angewaehlt")
	village.ui._navi_go()
	check(not Fade.busy, "Navi: Losfahren zu einem Ziel ohne Level geht nicht")
	village.ui._navi_pick("vorstadt")
	check(Save.dest_playable("vorstadt"), "Navi: Vorstadt ist befahrbar")
	village.ui.close()
	# Spieler kommt zu Fuss vom Platz durchs Tor zum Wagen (keine unsichtbare Wand im Weg)
	var space: PhysicsDirectSpaceState2D = village.get_world_2d().direct_space_state
	var blocked := 0
	var stops: Array[Vector2] = [village.start, Vector2(288, 280), Vector2(288, 352), village.start_after_run,
		Vector2(104, 180), Vector2(104, 216), Vector2(200, 216), Vector2(480, 216), Vector2(480, 184)]
	for pt in stops:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = pt
		q.collision_mask = G.L_WORLD
		if not space.intersect_point(q).is_empty():
			blocked += 1
	check(blocked == 0, "Wege im Dorf sind frei (%d von %d Punkten blockiert)" % [blocked, stops.size()])
	village.queue_free()
	await get_tree().process_frame

	# --- Objekt-Bibliothek: jede Szene laedt und hat ein Bild
	var broken: Array[String] = []
	var total := 0
	for path in _scenes_in("res://scenes/props"):
		total += 1
		var inst: Node = load(path).instantiate()
		# Bild = Sprite mit Textur, Animation oder bemalte Kachel-Ebene (Haus, Laden); kein Sprite ohne Bild
		var shows := false
		for n in inst.find_children("*", "", true, false):
			if n is Sprite2D and n.texture == null:
				shows = false
				break
			if n is Sprite2D or (n is AnimatedSprite2D and n.sprite_frames != null) \
					or (n is TileMapLayer and not n.get_used_cells().is_empty()):
				shows = true
		if not shows:
			broken.append(path)
		inst.free()
	check(total > 300 and broken.is_empty(), "Objekt-Bibliothek: %d Szenen laden (%s)" % [total, ", ".join(broken) if broken else "alle mit Bild"])


func _scenes_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scenes_in(dir + "/" + d))
	return out


# ------------------------------------------------------------------ Speicherplaetze und Startbildschirm

func run_slots() -> void:
	check(Save.slot == 1 and Save.slot_info(1)["exists"], "Tests laufen auf Platz 1")
	check(not Save.slot_info(2)["exists"] and not Save.slot_info(3)["exists"], "Platz 2 und 3 sind leer")
	Save.data["scrap"] = 777
	Save.write()
	Save.select_slot(2, "  Kevin  ")
	check(Save.slot == 2 and Save.data["name"] == "Kevin" and Save.scrap() == 0 and Save.data["games"] == 0, "Neuer Platz 2 mit Namen, beginnt bei null")
	check(Save.slot_info(2)["exists"] and Save.slot_info(2)["name"] == "Kevin", "Platz 2 ist angelegt")
	Save.add_scrap(50)
	Save.buy_weapon("pistol")
	Save.write()
	Save.select_slot(3)
	check(Save.data["name"] == "Spielstand 3" and Save.scrap() == 0, "Platz 3 ohne Namen heisst «Spielstand 3»")
	Save.select_slot(1)
	check(Save.scrap() == 777 and Save.data["games"] >= 2, "Platz 1 hat seinen eigenen Stand behalten (%d Schrott)" % Save.scrap())
	Save.select_slot(2)
	check(Save.scrap() == 50 and Save.data["name"] == "Kevin", "Platz 2 hat seinen eigenen Stand behalten")
	Save.rename_slot(3, "Zweitkonto")
	check(Save.slot_info(3)["name"] == "Zweitkonto", "Anderen Platz umbenennen")
	Save.rename_slot(2, "Kev")
	check(Save.data["name"] == "Kev" and Save.slot_info(2)["name"] == "Kev", "Aktuellen Platz umbenennen")
	check(Save.slot_info(2)["played_at"].length() == 19, "Zeitpunkt des letzten Speicherns vermerkt")

	# Automatisch speichern: nach einer Runde steht der Auftragsfortschritt in der Datei
	Save.data["contracts"] = [{"id": "kills_200", "state": "open", "progress": 0}]
	Save.accept_contract("kills_200")
	await new_game()
	game.player.invuln = 1e9
	for i in 400:
		await wait(0.1)
		for z in get_tree().get_nodes_in_group("zombies"):
			if z.state != Zombie.St.RISE:
				z.hit(100000.0, Vector2.RIGHT, false)
		if game.round_num >= 2:
			break
	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(Save.slot_path(2)))
	var disk_progress := int(on_disk["contracts"][0]["progress"])
	check(game.round_num >= 2 and disk_progress >= 6, "Nach Runde 1 automatisch gespeichert (%d Kills in der Datei)" % disk_progress)
	game.queue_free()
	game = null
	await get_tree().process_frame

	# Startbildschirm
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await wait(0.2)
	check(menu.slots_box.get_child_count() == Save.SLOTS and menu.name_edits[2].text == "Kev", "Startbildschirm zeigt 3 Plaetze mit Namen")
	menu._delete(3)
	check(Save.slot_info(3)["exists"], "Loeschen fragt zuerst nach")
	menu._delete(3)
	await wait(0.1)
	check(not Save.slot_info(3)["exists"] and menu.name_edits[3].text == "", "Platz 3 geloescht")
	menu.name_edits[3].text = "Neu"
	Save.select_slot(3, menu.name_edits[3].text)
	check(Save.slot == 3 and Save.data["name"] == "Neu" and Save.scrap() == 0, "Neues Spiel auf Platz 3 mit Namen")
	menu.queue_free()
	await get_tree().process_frame
	Save.delete_slot(3)
	check(not Save.active and not Save.slot_info(3)["exists"], "Geloeschter aktueller Platz wird nicht wieder angelegt")
	Save.write()
	check(not Save.slot_info(3)["exists"], "Ohne gewaehlten Platz wird nichts gespeichert")
