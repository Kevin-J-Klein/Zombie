class_name Player
extends CharacterBody2D
## Spieler: Bewegung (WASD), Zielen mit der Maus, Schiessen, Nachladen,
## Nahkampf, Sprinten, Benutzen (E) und Spezialfaehigkeit (X).
##
## Charaktere (z. B. Lamar) sind geerbte Szenen von player.tscn mit eigenem Skript
## (extends Player). Was einen Charakter ausmacht, steht im Inspektor (Gruppe «Charakter»);
## die Spezialfaehigkeit ueberschreibt _use_ability().

const WALK_SPEED := 68.0
const SPRINT_SPEED := 108.0
const REGEN_DELAY := 4.0
const REGEN_RATE := 45.0
const MELEE_DAMAGE := 150.0
const AIM_HEIGHT := Vector2(0, -6)   # Brusthoehe: von hier aus wird gezielt und gezeichnet
const GUN_REACH := 2.0               # Hand ein Stueck vor dem Koerper, damit der Schaft nicht hinten heraussteht

@export_group("Charakter")
## Animationen der Figur (Pack.anims / SheetAnims): "player" oder ein Skin aus Pack.SKINS
@export var figur := "player"
## Waffe, mit der dieser Charakter G.FAV_WEAPON_BONUS mehr Schaden macht (leer = keine)
@export var lieblingswaffe := ""
## Name der Spezialfaehigkeit fuer HUD und Meldungen (leer = keine Faehigkeit)
@export var faehigkeit_name := ""
## Nach dem Einsetzen so viele Runden warten, bis die Faehigkeit wieder bereit ist
@export var faehigkeit_runden := 5

var game: Node
var faehigkeit_ab_runde := 1         # ab dieser Runde ist die Spezialfaehigkeit (wieder) bereit

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
var gun_length := 10.0               # Abstand Hand -> Muendung (fuer Mündungsfeuer und Leuchtspur)
var prompt_text := ""
var nearest: Node = null

@onready var body: AnimatedSprite2D = $Body
@onready var gun: Node2D = $Gun                 # Drehpunkt in der Hand, zeigt immer zur Maus
@onready var gun_sprite: Sprite2D = $Gun/Sprite
@onready var muzzle: Sprite2D = $Gun/Muzzle
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	body.sprite_frames = SheetAnims.frames(figur)
	body.position.y = SheetAnims.foot_offset(figur)
	body.play(&"idle_down")
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
	gun.position = AIM_HEIGHT + aim_dir * GUN_REACH
	# Nach links gespiegelt (um den Drehpunkt, damit die Hand am Griff bleibt)
	gun.scale.y = -1.0 if aim_dir.x < 0.0 else 1.0
	# Waffe hinter dem Koerper zeichnen, wenn nach oben gezielt wird
	var want_index := 0 if aim_dir.y < -0.35 else 1
	if gun.get_index() != want_index:
		move_child(gun, want_index)
	var anim := StringName(("run_" if dir != Vector2.ZERO else "idle_") + facing())
	if body.animation != anim:
		body.play(anim)
	body.speed_scale = 1.4 if sprinting else 1.0
	camera.offset = ((mouse - global_position) * 0.12).limit_length(26.0)

	_update_interaction(delta)
	if input_enabled:
		_handle_weapons(delta)
		if Input.is_action_just_pressed("ability"):
			try_ability()


## Blickrichtung der Figur (passend zu den Pack-Animationen): side = rechts, left, up, down.
func facing() -> String:
	if absf(aim_dir.x) >= absf(aim_dir.y) * 0.8:
		return "side" if aim_dir.x >= 0.0 else "left"
	return "down" if aim_dir.y > 0.0 else "up"


## Sterbe-Animation; laeuft auch weiter, wenn das Spiel fuer den End-Bildschirm pausiert.
func play_death() -> void:
	gun.visible = false
	body.speed_scale = 1.0
	body.process_mode = Node.PROCESS_MODE_ALWAYS
	body.play(&"death_left" if aim_dir.x < 0.0 else &"death_side")


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
	var dmg: float = G.WEAPONS[w["id"]]["damage"] * pow(2.0, w["level"])
	if w["id"] == lieblingswaffe:
		dmg *= G.FAV_WEAPON_BONUS
	return dmg


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
	var info := SheetAnims.weapon(w["id"])
	var grip := Vector2(info["grip"][0], info["grip"][1])
	gun_sprite.texture = G.weapon_tex(w["id"], figur)
	gun_sprite.offset = -grip
	# Schraeg gezeichnete Waffen (Pistole) so drehen, dass der Lauf zur Maus zeigt
	gun_sprite.rotation = deg_to_rad(info["angle"])
	gun_sprite.modulate = Color.WHITE if w["level"] == 0 else Color(1.15, 0.85, 1.35)
	var tip := (Vector2(info["muzzle"][0], info["muzzle"][1]) - grip).rotated(gun_sprite.rotation)
	gun_length = tip.length()
	muzzle.position = Vector2(gun_length, 0)


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
	var draw_from: Vector2 = gun.global_position + aim_dir * (gun_length + 1.0)
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


# ------------------------------------------------------------------ Spezialfaehigkeit

func has_ability() -> bool:
	return faehigkeit_name != ""


## Bereit ab der ersten Runde, danach wieder faehigkeit_runden Runden nach dem Einsetzen.
func ability_ready() -> bool:
	return has_ability() and not dead and game.round_num > 0 and game.round_num >= faehigkeit_ab_runde


func try_ability() -> bool:
	if not ability_ready() or not _use_ability():
		return false
	faehigkeit_ab_runde = game.round_num + faehigkeit_runden
	return true


## Text fuers HUD, z. B. "Bulldoggen [X] bereit" (leer = Charakter ohne Faehigkeit)
func ability_text() -> String:
	if not has_ability():
		return ""
	if ability_ready():
		return "%s [X] bereit" % faehigkeit_name
	return "%s ab Runde %d" % [faehigkeit_name, maxi(faehigkeit_ab_runde, 1)]


## Ueberschreiben: setzt die Faehigkeit ein; true = hat geklappt (dann beginnt die Wartezeit).
func _use_ability() -> bool:
	return false


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
