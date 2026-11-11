extends Node2D
## Spielleitung: Runden, Zombie-Spawns, Punkte, Strom, Perks, Power-ups,
## Shop und die Quest (Easter Egg), mit der man das Level durchspielt.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie.tscn")
const BLOOD := [preload("res://art/blood_0.png"), preload("res://art/blood_1.png"), preload("res://art/blood_2.png")]
const MAX_DECALS := 140

var level: Level
var player: Player
var hud: Hud

var points := G.START_POINTS
var total_points := 0
var kills := 0
var time_played := 0.0

var round_num := 0
var in_round := false
var to_spawn := 0
var spawn_t := 0.0
var intermission_t := 4.0
var powerups_this_round := 0

var power_on := false
var perks: Array[String] = []
var insta_kill_t := 0.0
var double_points_t := 0.0

# Quest
var parts := 0
var radio_fixed := false
var defend_t := 0.0
var extraction_open := false
var gnomes := 0

var menu_open := false
var shop_block_t := 0.0
var over := false
var won := false


func _ready() -> void:
	randomize()
	level = Level.new()
	level.name = "Level"
	add_child(level)
	level.build(self)

	player = PLAYER_SCENE.instantiate()
	player.game = self
	player.position = level.player_start
	level.entities.add_child(player)
	var b := level.bounds()
	player.camera.limit_left = int(b.position.x)
	player.camera.limit_top = int(b.position.y)
	player.camera.limit_right = int(b.end.x)
	player.camera.limit_bottom = int(b.end.y)
	player.camera.reset_smoothing()

	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(self)

	level.refresh_spawns(player.global_position)
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	announce("Überlebe die Zombies!", "WASD bewegen  ·  Maus zielen  ·  Linksklick schiessen  ·  E benutzen")


func _process(delta: float) -> void:
	if over:
		return
	time_played += delta
	shop_block_t -= delta
	insta_kill_t = maxf(0.0, insta_kill_t - delta)
	double_points_t = maxf(0.0, double_points_t - delta)

	if in_round:
		spawn_t -= delta
		var alive := zombie_count()
		var defending := defend_t > 0.0
		if (to_spawn > 0 or defending) and alive < G.MAX_ZOMBIES_ALIVE and spawn_t <= 0.0 \
				and not level.active_spawns.is_empty():
			_spawn_zombie()
			if to_spawn > 0:
				to_spawn -= 1
			spawn_t = maxf(0.3, 2.0 - round_num * 0.15) * (0.5 if defending else 1.0)
		if to_spawn == 0 and alive == 0 and not defending:
			_end_round()
	else:
		intermission_t -= delta
		if intermission_t <= 0.0:
			_start_round()

	if defend_t > 0.0:
		defend_t -= delta
		if defend_t <= 0.0:
			_open_extraction()
	if extraction_open and level.is_extraction(player.global_position):
		_finish(true)


# ------------------------------------------------------------------ Runden

func zombie_count() -> int:
	return get_tree().get_nodes_in_group("zombies").size()


func _start_round() -> void:
	round_num += 1
	in_round = true
	to_spawn = G.zombies_for_round(round_num)
	spawn_t = 1.0
	powerups_this_round = 0
	hud.show_round(round_num)


func _end_round() -> void:
	in_round = false
	intermission_t = 6.0
	announce("Runde %d überstanden" % round_num)


func _spawn_zombie() -> void:
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	z.setup(self, round_num)
	z.position = level.random_spawn() + Vector2(randf_range(-3, 3), randf_range(-3, 3))
	level.entities.add_child(z)


func on_zombie_killed(z: Zombie, melee: bool, award: bool) -> void:
	kills += 1
	if not award:
		return
	add_points(130 if melee else 60)
	# Power-ups nur dort fallen lassen, wo der Spieler auch hinkommt
	if powerups_this_round < 4 and randf() < 0.045 and level.reached.has(level.to_cell(z.global_position)):
		powerups_this_round += 1
		var p := Powerup.new()
		p.setup(self, G.POWERUPS.keys().pick_random())
		p.position = z.global_position
		level.entities.add_child(p)


# ------------------------------------------------------------------ Punkte

func add_points(n: int) -> void:
	if double_points_t > 0.0:
		n *= 2
	points += n
	total_points += n


func try_spend(cost: int) -> bool:
	if points >= cost:
		points -= cost
		return true
	announce("Nicht genug Punkte (%d fehlen)" % (cost - points))
	return false


# ------------------------------------------------------------------ Strom, Perks, Power-ups

func set_power() -> void:
	power_on = true
	announce("Strom eingeschaltet!", "Perk-Automaten und Upgrade-Werkbank sind jetzt aktiv")


func has_perk(id: String) -> bool:
	return perks.has(id)


func give_perk(id: String) -> void:
	if perks.has(id):
		return
	perks.append(id)
	match id:
		"health":
			player.set_max_hp(250.0)
			player.hp = player.max_hp
		"stamina":
			player.max_stamina = 200.0
	announce("Perk: %s" % G.PERKS[id]["name"], G.PERKS[id]["desc"])


func remove_perk(id: String) -> void:
	perks.erase(id)


func apply_powerup(kind: String) -> void:
	announce(G.POWERUPS[kind]["name"] + "!")
	match kind:
		"max_ammo":
			player.refill_all()
		"insta_kill":
			insta_kill_t = 30.0
		"double_points":
			double_points_t = 30.0
		"nuke":
			for z in get_tree().get_nodes_in_group("zombies"):
				z.die(false, false)
			add_points(400)
			hud.flash(Color(1, 1, 1, 0.8))


func splash(pos: Vector2, radius: float, amount: float) -> void:
	fx_ring(pos + Player.AIM_HEIGHT, radius, Color("#9dff9a"))
	for area in get_tree().get_nodes_in_group("hurtbox"):
		var target: Node2D = area.get_parent()
		if target.global_position.distance_to(pos) <= radius:
			target.hit(amount, (target.global_position - pos).normalized(), false)


# ------------------------------------------------------------------ Shop

func open_shop() -> void:
	if shop_block_t > 0.0:
		return
	menu_open = true
	player.input_enabled = false
	hud.open_shop()


func close_shop() -> void:
	menu_open = false
	shop_block_t = 0.25
	player.input_enabled = true
	hud.close_shop()


func shop_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var w := player.weapon()
	items.append({"id": "ammo", "label": "Munition auffüllen (%s)" % G.weapon_name(w["id"], w["level"]),
		"cost": 250 * (w["level"] + 1), "enabled": not player.ammo_full(w["id"])})
	items.append({"id": "armor", "label": "Panzerung (fängt Schaden ab)", "cost": G.COST_ARMOR,
		"enabled": player.armor < 100.0})
	for id in G.SHOP_WEAPONS:
		var owned := player.has_weapon(id)
		items.append({"id": id, "label": G.WEAPONS[id]["name"] + ("  (im Besitz)" if owned else ""),
			"cost": G.WEAPONS[id]["cost"], "enabled": not owned})
	return items


func buy_shop_item(id: String) -> void:
	for it in shop_items():
		if it["id"] != id or not it["enabled"]:
			continue
		if not try_spend(it["cost"]):
			return
		match id:
			"ammo":
				player.refill(player.weapon()["id"])
			"armor":
				player.armor = 100.0
			_:
				player.give_weapon(id)


# ------------------------------------------------------------------ Quest / Easter Eggs

func objective_text() -> String:
	if won:
		return ""
	if not power_on:
		return "Finde den Stromschalter und schalte den Strom ein"
	if parts < 3:
		return "Finde 3 Funkteile (%d/3)" % parts
	if not radio_fixed:
		return "Repariere das Funkgerät im Markt"
	if defend_t > 0.0:
		return "Halte durch! Helikopter in %d:%02d" % [int(defend_t) / 60, int(defend_t) % 60]
	return "Lauf zum Landeplatz im Garten!"


func collect_part() -> void:
	parts += 1
	announce("Funkteil gefunden (%d/3)" % parts)


func fix_radio() -> void:
	radio_fixed = true
	defend_t = G.DEFEND_SECONDS
	announce("Funkspruch abgesetzt!", "Der Lärm lockt Zombies an – halte durch, bis der Helikopter kommt")


func _open_extraction() -> void:
	defend_t = 0.0
	extraction_open = true
	if level.doors.has("d"):
		level.doors["d"].open()
	announce("Der Helikopter ist da!", "Lauf zum Landeplatz im Garten")


func gnome_shot(pos: Vector2) -> void:
	gnomes += 1
	fx_ring(pos, 10.0, Color("#ffd84a"))
	if gnomes < 3:
		announce("Gartenzwerg erwischt (%d/3)" % gnomes)
		return
	add_points(1000)
	var missing: Array[String] = []
	for id in G.PERKS:
		if not perks.has(id):
			missing.append(id)
	if missing.is_empty():
		announce("Alle Gartenzwerge erwischt!", "+1000 Punkte")
	else:
		var gift: String = missing.pick_random()
		give_perk(gift)
		announce("Alle Gartenzwerge erwischt!", "+1000 Punkte und Gratis-Perk: %s" % G.PERKS[gift]["name"])


# ------------------------------------------------------------------ Spieler-Ereignisse

func on_player_hurt() -> void:
	hud.flash(Color(0.8, 0.0, 0.0, 0.35))
	if menu_open:
		close_shop()


func on_player_down() -> void:
	if has_perk("revive"):
		remove_perk("revive")
		player.hp = player.max_hp * 0.6
		player.invuln = 3.0
		for z in get_tree().get_nodes_in_group("zombies"):
			if z.global_position.distance_to(player.global_position) < 60.0:
				z.die(false, false)
		fx_ring(player.global_position, 60.0, Color("#4aa8e0"))
		announce("Zweite Chance verbraucht!")
		return
	_finish(false)


func _finish(victory: bool) -> void:
	if over:
		return
	over = true
	won = victory
	player.dead = not victory
	player.input_enabled = false
	G.last_result = {"won": victory, "round": round_num, "kills": kills, "points": total_points, "time": time_played}
	hud.show_end(victory)


func announce(text: String, sub := "") -> void:
	if hud != null:
		hud.announce(text, sub)


# ------------------------------------------------------------------ Effekte

func fx_tracer(from: Vector2, to: Vector2, color: Color) -> void:
	var l := Line2D.new()
	l.points = PackedVector2Array([from, to])
	l.width = 1.0
	l.default_color = color
	level.fx.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.08)
	tw.tween_callback(l.queue_free)


func fx_slash(pos: Vector2, dir: Vector2) -> void:
	var l := Line2D.new()
	var pts := PackedVector2Array()
	for i in 7:
		pts.append(pos + dir.rotated(deg_to_rad(-60.0 + i * 20.0)) * 16.0)
	l.points = pts
	l.width = 2.0
	l.default_color = Color(1, 1, 1, 0.9)
	level.fx.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.15)
	tw.tween_callback(l.queue_free)


func fx_ring(pos: Vector2, radius: float, color: Color) -> void:
	var l := Line2D.new()
	var pts := PackedVector2Array()
	for i in 25:
		pts.append(Vector2.RIGHT.rotated(TAU * i / 24.0) * radius)
	l.points = pts
	l.position = pos
	l.width = 2.0
	l.default_color = color
	l.scale = Vector2(0.2, 0.2)
	level.fx.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


func fx_blood(pos: Vector2, dir: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 7
	p.lifetime = 0.3
	p.direction = dir
	p.spread = 35.0
	p.gravity = Vector2(0, 160)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color("#b0141a")
	level.fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.6, false).timeout.connect(p.queue_free)

	var s := Sprite2D.new()
	s.texture = BLOOD.pick_random()
	s.position = pos + Vector2(0, 8) + dir * randf_range(2.0, 10.0)
	s.rotation = randf() * TAU
	s.modulate.a = 0.85
	level.decals.add_child(s)
	if level.decals.get_child_count() > MAX_DECALS:
		for c in level.decals.get_children():
			if c is Sprite2D and not c.is_queued_for_deletion():
				c.queue_free()
				break
