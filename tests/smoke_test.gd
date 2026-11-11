extends Node
## Automatischer Durchlauf ohne Fenster:
##   godot --headless --path . res://tests/smoke_test.tscn
## Prueft Level-Aufbau, Zombie-Wegfindung, Schiessen, Runden, Kaeufe, Perks,
## Mystery-Box, Power-ups und die komplette Quest bis zum Sieg.

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
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await wait(0.3)


func nearest_zombie() -> Node2D:
	var best: Node2D = null
	for z in get_tree().get_nodes_in_group("zombies"):
		if best == null or z.global_position.distance_to(game.player.global_position) < best.global_position.distance_to(game.player.global_position):
			best = z
	return best


func _ready() -> void:
	Engine.time_scale = 8.0
	await run()
	print("SMOKE RESULT: %d Fehler" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func run() -> void:
	await new_game()
	var level: Level = game.level
	var p: Player = game.player

	check(level.size == Vector2i(60, 38), "Karte 60x38 geladen")
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

	# --- Tueren
	game.points = 500000
	var expected := {"a": 7, "b": 8, "c": 9, "d": 11, "e": 13}
	for id in ["a", "b", "c", "d", "e"]:
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
	level.objects["H"][0].interact(p)
	check(not game.has_perk("health"), "Perk ohne Strom nicht kaufbar")
	level.objects["V"][0].interact(p)
	check(game.has_perk("revive"), "Zweite Chance geht ohne Strom")
	level.objects["E"][0].interact(p)
	check(game.power_on, "Strom eingeschaltet")
	for ch in ["H", "F", "R", "T"]:
		level.objects[ch][0].interact(p)
	check(game.perks.size() == 5 and p.max_hp == 250.0, "Alle 5 Perks gekauft, Stahlhaut wirkt")
	for i in 4:
		level.objects["U"][0].interact(p)
	check(p.weapon()["level"] == 3, "Waffe 3x aufgeruestet (%s)" % G.weapon_name(p.weapon()["id"], p.weapon()["level"]))
	p.fire()

	# --- Mystery-Box
	var box: Interactable = level.objects["M"][0]
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
	level.objects["K"][0].interact(p)
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
