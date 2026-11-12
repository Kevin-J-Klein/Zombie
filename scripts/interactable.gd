class_name Interactable
extends Node2D
## Alles, was man mit E benutzen kann (ausser Tueren und Fenstern):
## Wandkauf, Shop-Terminal, Mystery-Box, Upgrade-Werkbank, Stromschalter,
## Funkgeraet und Perk-Automaten. "kind" bestimmt das Verhalten.

var game: Node
var kind := ""
var weapon_id := ""
var perk_id := ""
var reach := 27.0
var sprite: Sprite2D

# Mystery-Box
enum Box { READY, ROLLING, OFFER }
var box_state := Box.READY
var box_t := 0.0
var box_weapon := ""
var box_show := ""
var box_tick := 0.0


func setup(p_game: Node, p_kind: String, tex: Texture2D, tint := Color.WHITE) -> void:
	game = p_game
	kind = p_kind
	name = p_kind
	add_to_group("interact")
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.modulate = tint
	sprite.position = Vector2(0, 8.0 - tex.get_height() * 0.5)
	add_child(sprite)
	if kind == "wallbuy":
		sprite.position = Vector2.ZERO
	set_process(kind == "box")


func interact_distance(pos: Vector2) -> float:
	# Wandkaeufe haengen an der Vorderseite der Wand: nur von unten (Sueden) erreichbar
	if kind == "wallbuy" and pos.y < global_position.y:
		return 1e9
	return global_position.distance_to(pos)


func prompt(player: Node) -> String:
	match kind:
		"wallbuy":
			var w: Dictionary = G.WEAPONS[weapon_id]
			if player.has_weapon(weapon_id):
				return "[E]  Munition für %s  –  %d Punkte" % [w["name"], _ammo_cost()]
			return "[E]  %s kaufen  –  %d Punkte" % [w["name"], w["cost"]]
		"shop":
			return "[E]  Shop öffnen"
		"box":
			match box_state:
				Box.READY:
					return "[E]  Mystery-Box  –  %d Punkte" % G.COST_BOX
				Box.ROLLING:
					return "Mystery-Box:  %s ..." % box_show
				Box.OFFER:
					return "[E]  %s nehmen" % G.WEAPONS[box_weapon]["name"]
		"upgrade":
			if not game.power_on:
				return "Upgrade-Werkbank  –  kein Strom"
			var cur: Dictionary = player.weapon()
			if cur["level"] >= G.MAX_WEAPON_LEVEL:
				return "%s ist voll aufgerüstet" % G.weapon_name(cur["id"], cur["level"])
			return "[E]  %s aufrüsten  –  %d Punkte" % [G.WEAPONS[cur["id"]]["name"], G.COST_UPGRADE[cur["level"]]]
		"power":
			return "" if game.power_on else "[E]  Strom einschalten"
		"radio":
			if game.radio_fixed:
				return ""
			if game.parts < 3:
				return "Funkgerät defekt  –  Funkteile fehlen (%d/3)" % game.parts
			if not game.power_on:
				return "Funkgerät  –  kein Strom"
			return "[E]  Funkgerät reparieren und Hilfe rufen"
		"perk":
			var p: Dictionary = G.PERKS[perk_id]
			if game.has_perk(perk_id):
				return ""
			if p["power"] and not game.power_on:
				return "%s  –  kein Strom" % p["name"]
			return "[E]  %s  –  %d Punkte  (%s)" % [p["name"], p["cost"], p["desc"]]
	return ""


func interact(player: Node) -> void:
	match kind:
		"wallbuy":
			if player.has_weapon(weapon_id):
				if player.ammo_full(weapon_id):
					game.announce("Munition ist schon voll")
				elif game.try_spend(_ammo_cost()):
					player.refill(weapon_id)
			elif game.try_spend(G.WEAPONS[weapon_id]["cost"]):
				player.give_weapon(weapon_id)
		"shop":
			game.open_shop()
		"box":
			if box_state == Box.READY:
				if game.try_spend(G.COST_BOX):
					box_state = Box.ROLLING
					box_t = 2.5
					box_weapon = _roll(player)
			elif box_state == Box.OFFER:
				player.give_weapon(box_weapon)
				box_state = Box.READY
				sprite.modulate = Color.WHITE
		"upgrade":
			if not game.power_on:
				return
			var cur: Dictionary = player.weapon()
			if cur["level"] < G.MAX_WEAPON_LEVEL and game.try_spend(G.COST_UPGRADE[cur["level"]]):
				player.upgrade_current()
				game.announce("%s aufgerüstet!" % G.weapon_name(cur["id"], cur["level"]))
		"power":
			if not game.power_on:
				sprite.modulate = Color(1.3, 1.25, 0.85)   # Stromkasten leuchtet, sobald der Strom an ist
				game.set_power()
		"radio":
			if not game.radio_fixed and game.parts >= 3 and game.power_on:
				game.fix_radio()
		"perk":
			var p: Dictionary = G.PERKS[perk_id]
			if game.has_perk(perk_id) or (p["power"] and not game.power_on):
				return
			if game.try_spend(p["cost"]):
				game.give_perk(perk_id)


func _ammo_cost() -> int:
	return int(G.WEAPONS[weapon_id]["cost"] / 2.0)


func _roll(player: Node) -> String:
	var pool: Array[String] = []
	for id in G.WEAPONS:
		if G.WEAPONS[id]["box"] and not player.has_weapon(id):
			pool.append(id)
	return pool[randi() % pool.size()]


func _process(delta: float) -> void:
	if box_state == Box.ROLLING:
		box_t -= delta
		box_tick -= delta
		if box_tick <= 0.0:
			box_tick = 0.1
			var ids: Array = G.WEAPONS.keys()
			box_show = G.WEAPONS[ids[randi() % ids.size()]]["name"]
			sprite.modulate = Color(1.3, 1.2, 0.8)
		if box_t <= 0.0:
			box_state = Box.OFFER
			box_t = 9.0
	elif box_state == Box.OFFER:
		box_t -= delta
		sprite.modulate = Color(1.0, 1.0, 1.0) if int(box_t * 4.0) % 2 == 0 else Color(1.4, 1.3, 0.7)
		if box_t <= 0.0:
			box_state = Box.READY
			sprite.modulate = Color.WHITE
