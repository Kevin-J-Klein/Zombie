class_name Player
extends CharacterBody2D
## Spieler: Bewegung (WASD), Zielen mit der Maus, Schiessen, Nachladen,
## Nahkampf, Sprinten und Benutzen (E).

const WALK_SPEED := 68.0
const SPRINT_SPEED := 108.0
const REGEN_DELAY := 4.0
const REGEN_RATE := 45.0
const MELEE_DAMAGE := 150.0
const AIM_HEIGHT := Vector2(0, -8)   # Brusthoehe: von hier aus wird gezielt und gezeichnet

var game: Node

var max_hp := 150.0
var hp := 150.0
var armor := 0.0
var max_stamina := 100.0
var stamina := 100.0
var exhausted := false

var weapons: Array[Dictionary] = []   # {"id", "mag", "reserve", "level"}
var current := 0
var fire_cd := 0.0
var reload_t := 0.0
var reload_total := 1.0
var melee_cd := 0.0
var muzzle_t := 0.0

var since_damage := 99.0
var invuln := 0.0
var dead := false
var input_enabled := true
var aim_dir := Vector2.RIGHT
var walk_time := 0.0
var prompt_text := ""
var nearest: Node = null

@onready var body: Sprite2D = $Body
@onready var gun: Sprite2D = $Gun
@onready var muzzle: Sprite2D = $Gun/Muzzle
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	give_weapon("pistol")


func _physics_process(delta: float) -> void:
	if dead:
		return
	fire_cd -= delta
	melee_cd -= delta
	invuln -= delta
	since_damage += delta
	if muzzle_t > 0.0:
		muzzle_t -= delta
		muzzle.visible = muzzle_t > 0.0

	# --- Bewegung
	var dir := Vector2.ZERO
	if input_enabled:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sprinting := input_enabled and dir != Vector2.ZERO and Input.is_action_pressed("sprint") and not exhausted
	var speed := WALK_SPEED
	if sprinting:
		speed = SPRINT_SPEED * (1.08 if game.has_perk("stamina") else 1.0)
		stamina -= delta * (14.0 if game.has_perk("stamina") else 28.0)
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
	else:
		stamina = minf(max_stamina, stamina + delta * 20.0)
		if exhausted and stamina > max_stamina * 0.3:
			exhausted = false
	velocity = dir * speed
	move_and_slide()

	# --- Lebensregeneration wie im Vorbild: kurz nicht getroffen werden
	if since_damage > REGEN_DELAY and hp < max_hp:
		hp = minf(max_hp, hp + REGEN_RATE * delta)

	# --- Zielen
	var mouse := get_global_mouse_position()
	var aim_from := global_position + AIM_HEIGHT
	if mouse.distance_to(aim_from) > 2.0:
		aim_dir = (mouse - aim_from).normalized()
	gun.rotation = aim_dir.angle()
	gun.flip_v = aim_dir.x < 0.0
	body.flip_h = aim_dir.x < 0.0
	# Waffe hinter dem Koerper zeichnen, wenn nach oben gezielt wird
	var want_index := 0 if aim_dir.y < -0.35 else 1
	if gun.get_index() != want_index:
		move_child(gun, want_index)
	if dir != Vector2.ZERO:
		walk_time += delta * (16.0 if sprinting else 11.0)
		body.position.y = -10.0 - absf(sin(walk_time)) * 1.5
	else:
		body.position.y = -10.0
	camera.offset = ((mouse - global_position) * 0.12).limit_length(26.0)

	_update_interaction(delta)
	if input_enabled:
		_handle_weapons(delta)


# ------------------------------------------------------------------ Benutzen

func _update_interaction(delta: float) -> void:
	nearest = null
	prompt_text = ""
	var best := 1e9
	for n in get_tree().get_nodes_in_group("interact"):
		var d: float = n.interact_distance(global_position)
		if d < n.reach and d < best:
			var text: String = n.prompt(self)
			if text != "":
				best = d
				nearest = n
				prompt_text = text
	if nearest != null and input_enabled:
		if Input.is_action_just_pressed("interact"):
			nearest.interact(self)
		if Input.is_action_pressed("interact") and nearest.has_method("hold_interact"):
			nearest.hold_interact(self, delta)


# ------------------------------------------------------------------ Waffen

func weapon() -> Dictionary:
	return weapons[current]


func has_weapon(id: String) -> bool:
	for w in weapons:
		if w["id"] == id:
			return true
	return false


func mag_size(w: Dictionary) -> int:
	return int(G.WEAPONS[w["id"]]["mag"] * (1.0 + 0.5 * w["level"]))


func reserve_size(w: Dictionary) -> int:
	return int(G.WEAPONS[w["id"]]["reserve"] * (1.0 + 0.5 * w["level"]))


func damage_of(w: Dictionary) -> float:
	return G.WEAPONS[w["id"]]["damage"] * pow(2.0, w["level"])


func give_weapon(id: String) -> void:
	for i in weapons.size():
		if weapons[i]["id"] == id:
			refill(id)
			_select(i)
			return
	var w := {"id": id, "mag": 0, "reserve": 0, "level": 0}
	w["mag"] = mag_size(w)
	w["reserve"] = reserve_size(w)
	if weapons.size() < 2:
		weapons.append(w)
		_select(weapons.size() - 1)
	else:
		weapons[current] = w
		_select(current)


func ammo_full(id: String) -> bool:
	for w in weapons:
		if w["id"] == id:
			return w["mag"] >= mag_size(w) and w["reserve"] >= reserve_size(w)
	return true


func refill(id: String) -> void:
	for w in weapons:
		if w["id"] == id:
			w["mag"] = mag_size(w)
			w["reserve"] = reserve_size(w)


func refill_all() -> void:
	for w in weapons:
		w["reserve"] = reserve_size(w)


func upgrade_current() -> void:
	var w := weapon()
	w["level"] += 1
	w["mag"] = mag_size(w)
	w["reserve"] = reserve_size(w)
	_select(current)


func _select(i: int) -> void:
	current = i
	reload_t = 0.0
	fire_cd = maxf(fire_cd, 0.15)
	if is_node_ready():
		_update_gun_sprite()
	else:
		ready.connect(_update_gun_sprite, CONNECT_ONE_SHOT)


func _update_gun_sprite() -> void:
	var w := weapon()
	gun.texture = G.weapon_tex(w["id"])
	gun.modulate = Color.WHITE if w["level"] == 0 else Color(1.15, 0.85, 1.35)
	muzzle.position.x = gun.texture.get_width() + 6.0


func _handle_weapons(delta: float) -> void:
	if Input.is_action_just_pressed("swap") and weapons.size() > 1:
		_select((current + 1) % weapons.size())
	if Input.is_action_just_pressed("weapon_1") and weapons.size() > 0:
		_select(0)
	if Input.is_action_just_pressed("weapon_2") and weapons.size() > 1:
		_select(1)

	var w := weapon()
	var d: Dictionary = G.WEAPONS[w["id"]]

	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			var take: int = mini(mag_size(w) - w["mag"], w["reserve"])
			w["mag"] += take
			w["reserve"] -= take
	elif Input.is_action_just_pressed("reload") or (w["mag"] <= 0 and w["reserve"] > 0):
		start_reload()

	if Input.is_action_just_pressed("melee") and melee_cd <= 0.0:
		_melee()

	var wants_fire: bool = Input.is_action_pressed("shoot") if d["auto"] else Input.is_action_just_pressed("shoot")
	if wants_fire and fire_cd <= 0.0 and reload_t <= 0.0 and w["mag"] > 0:
		fire()


func start_reload() -> void:
	var w := weapon()
	if reload_t > 0.0 or w["mag"] >= mag_size(w) or w["reserve"] <= 0:
		return
	reload_total = G.WEAPONS[w["id"]]["reload"] * (0.5 if game.has_perk("reload") else 1.0)
	reload_t = reload_total


## Ein Schuss. Die Kugel wird als Strahl auf Bodenhoehe berechnet (gleiche Ebene
## wie die Kollision der Waende), gezeichnet wird sie auf Brusthoehe.
func fire() -> void:
	var w := weapon()
	var d: Dictionary = G.WEAPONS[w["id"]]
	w["mag"] -= 1
	fire_cd = d["rate"] * (0.67 if game.has_perk("fire") else 1.0)
	muzzle_t = 0.05
	muzzle.visible = true
	var space := get_world_2d().direct_space_state
	var dmg := damage_of(w)
	var draw_from: Vector2 = global_position + AIM_HEIGHT + aim_dir * (gun.texture.get_width() + 3.0)
	for i in int(d["pellets"]):
		var dir := aim_dir.rotated(deg_to_rad(randf_range(-d["spread"], d["spread"])))
		var from := global_position
		var to: Vector2 = from + dir * d["range"]
		var end := to
		var exclude: Array[RID] = []
		var left: int = d["pierce"] + (1 if w["level"] > 0 else 0)
		var shot_dmg := dmg
		while left > 0:
			var q := PhysicsRayQueryParameters2D.create(from, to, G.L_WORLD | G.L_HURT, exclude)
			q.collide_with_areas = true
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var col: Object = hit["collider"]
			end = hit["position"]
			if col is Area2D and col.is_in_group("hurtbox"):
				exclude.append(hit["rid"])
				if d["splash"] <= 0.0:
					col.get_parent().hit(shot_dmg, dir, false)
				left -= 1
				shot_dmg *= 0.75
				if left > 0:
					end = to
			else:
				break
		if d["splash"] > 0.0:
			game.splash(end, d["splash"], dmg)
		game.fx_tracer(draw_from, end + AIM_HEIGHT, Color("#9dff9a") if d["splash"] > 0.0 else Color("#ffe9a0"))


func _melee() -> void:
	melee_cd = 0.55
	game.fx_slash(global_position + AIM_HEIGHT, aim_dir)
	for z in get_tree().get_nodes_in_group("zombies"):
		var off: Vector2 = z.global_position - global_position
		if off.length() < 26.0 and (off.length() < 8.0 or off.normalized().dot(aim_dir) > 0.25):
			z.hit(MELEE_DAMAGE, aim_dir, true)


# ------------------------------------------------------------------ Schaden

func take_damage(amount: float) -> void:
	if dead or invuln > 0.0:
		return
	since_damage = 0.0
	if armor > 0.0:
		var absorbed := minf(armor, amount * 0.6)
		armor -= absorbed
		amount -= absorbed
	hp -= amount
	game.on_player_hurt()
	if hp <= 0.0:
		hp = 0.0
		game.on_player_down()


func set_max_hp(value: float) -> void:
	max_hp = value
	hp = minf(hp, max_hp)
