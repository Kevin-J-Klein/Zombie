class_name Zombie
extends CharacterBody2D
## Zombie: steigt aus dem Boden, laeuft per Wegfindung zum Spieler, reisst
## Barrikaden ab und greift im Nahkampf an.
##
## Jede Zombie-Art ist eine eigene Szene in scenes/zombies/, geerbt von zombie.tscn
## (normaler Zombie). Was eine Art ausmacht, steht im Inspektor der Wurzel (Werte unten);
## die Figur waehlt man am Knoten «Body» (Gruppe), Koerper und Trefferzone an «Shape» und
## «Hurtbox/HurtShape». Welche Arten es gibt, listet game.gd (ZOMBIE_ARTEN).

enum St { RISE, CHASE, TEAR, WINDUP, DEAD }

const RISE_TIME := 0.8
const ATTACK_RANGE := 14.0

@export_group("Art")
## Name fuer Anzeigen und Tests
@export var art_name := "Zombie"
## Meldung, wenn diese Art zum ersten Mal in einer Partie auftaucht (leer = keine)
@export var ankuendigung := ""
@export var ankuendigung_text := ""
## Auftrags-Ereignis beim Kill (z. B. "tank_kill" fuer Auftraege in hub_data.gd; leer = keins)
@export var auftrag_kill := ""

@export_group("Werte")
## Leben = Rundenleben (G.zombie_health) mal diesen Faktor
@export var leben_faktor := 1.0
## Tempo wird zwischen min und max ausgewuerfelt ...
@export var tempo_min := 24.0
@export var tempo_max := 34.0
## ... plus pro Runde so viel dazu (hoechstens 10 Runden lang)
@export var tempo_pro_runde := 1.0
@export var schaden := 45.0
## Sekunden vom Ausholen bis zum Treffer (Zeit zum Ausweichen)
@export var ausholen := 0.3
## Sekunden pro abgerissenes Brett
@export var bretter_zeit := 1.3
## Zusaetzliche Punkte fuer den Kill
@export var kill_bonus := 0
## Bei welchem Tempo die Lauf-Animation normal schnell laeuft (Schritte passend zum Tempo)
@export var schritt_tempo := 30.0

@export_group("Spawn")
## Ab dieser Runde kann die Art auftauchen
@export var ab_runde := 1
## Anteil in der ersten Runde (0-1), pro Runde mehr, hoechstens anteil_max.
## Die Arten werden in der Reihenfolge von ZOMBIE_ARTEN (game.gd) ausgewuerfelt;
## die letzte (normaler Zombie) nimmt den Rest.
@export_range(0.0, 1.0, 0.01) var anteil_start := 1.0
@export_range(0.0, 1.0, 0.01) var anteil_pro_runde := 0.0
@export_range(0.0, 1.0, 0.01) var anteil_max := 1.0

var game: Node
var level: Level
var player: Player

var hp := 150.0
var speed := 30.0

var state := St.RISE
var state_t := RISE_TIME
var path := PackedVector2Array()
var path_i := 0
var repath_t := 0.0
var attack_cd := 0.0
var lost_t := 0.0
var tear_window: Barricade
var anim_t := 0.0
var facing := "down"                 # side = rechts, left, up, down (wie die Pack-Animationen)
var foot_y := -9.0                   # Sprite-Versatz, damit die Fuesse auf dem Ursprung stehen
var held_t := 0.0                    # festgehalten (z. B. von Lamars Bulldoggen): steht still, greift nicht an

@onready var body: FigurVorschau = $Body
@onready var hurtbox: Area2D = $Hurtbox


## Anteil dieser Art an den Zombies einer Runde (0-1), siehe Gruppe «Spawn».
func chance(round_num: int) -> float:
	if round_num < ab_runde:
		return 0.0
	return minf(anteil_start + anteil_pro_runde * (round_num - ab_runde), anteil_max)


func setup(p_game: Node, round_num: int) -> void:
	game = p_game
	level = game.level
	player = game.player
	hp = G.zombie_health(round_num) * leben_faktor
	speed = randf_range(tempo_min, tempo_max) + tempo_pro_runde * minf(round_num, 10.0)


func _ready() -> void:
	anim_t = randf() * 10.0
	var group: String = body.gruppe
	body.sprite_frames = SheetAnims.frames(group)
	body.offset = Vector2.ZERO
	foot_y = SheetAnims.foot_offset(group)
	body.position.y = foot_y * 0.05
	body.play(&"idle_down")
	body.frame = randi() % body.sprite_frames.get_frame_count(&"idle_down")
	body.scale.y = 0.05


## Blickrichtung aus einem Richtungsvektor bestimmen.
func _face(v: Vector2) -> void:
	if v.length_squared() < 0.01:
		return
	if absf(v.x) >= absf(v.y):
		facing = "side" if v.x > 0.0 else "left"
	else:
		facing = "down" if v.y > 0.0 else "up"


func _play(anim: String, restart := false) -> void:
	var a := StringName(anim + "_" + facing)
	if restart or body.animation != a:
		body.play(a)
		if restart:
			body.frame = 0


func _physics_process(delta: float) -> void:
	if state == St.DEAD:
		return
	anim_t += delta
	attack_cd -= delta
	if held_t > 0.0 and state != St.RISE:
		held_t -= delta
		velocity = Vector2.ZERO
		body.speed_scale = 1.0
		_play("idle")
		return
	match state:
		St.RISE:
			state_t -= delta
			var k := clampf(1.0 - state_t / RISE_TIME, 0.05, 1.0)
			body.scale.y = k
			body.position.y = foot_y * k
			if state_t <= 0.0:
				body.scale.y = 1.0
				body.position.y = foot_y
				state = St.CHASE
		St.CHASE:
			_chase(delta)
		St.TEAR:
			if not is_instance_valid(tear_window) or tear_window.planks <= 0:
				state = St.CHASE
			else:
				# An den Brettern zerren: Angriffs-Animation immer wieder abspielen
				_face(tear_window.global_position - global_position)
				body.speed_scale = 1.0
				if not body.is_playing() or not String(body.animation).begins_with("attack"):
					_play("attack", true)
				state_t -= delta
				if state_t <= 0.0:
					tear_window.remove_plank()
					state_t = _tear_time()
		St.WINDUP:
			state_t -= delta
			if state_t <= 0.0:
				if global_position.distance_to(player.global_position) < ATTACK_RANGE + 7.0:
					player.take_damage(schaden)
				attack_cd = 0.8
				state = St.CHASE


func _chase(delta: float) -> void:
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist < ATTACK_RANGE and not player.dead:
		velocity = Vector2.ZERO
		_face(to_player)
		if attack_cd <= 0.0:
			state = St.WINDUP
			state_t = ausholen
			body.speed_scale = 1.0
			_play("attack", true)
		elif not String(body.animation).begins_with("attack") or not body.is_playing():
			_play("idle")
		return

	repath_t -= delta
	if repath_t <= 0.0:
		repath_t = randf_range(0.35, 0.6)
		path = level.find_path(global_position, player.global_position)
		path_i = 1

	var target := player.global_position
	if path.size() > 2 and path_i < path.size() - 1:
		target = path[path_i]
		if global_position.distance_to(target) < 4.0:
			path_i += 1
		lost_t = 0.0
	elif path.is_empty() and dist > 40.0:
		# Kein Weg zum Spieler (sollte nicht vorkommen): nach kurzer Zeit neu spawnen
		lost_t += delta
		if lost_t > 6.0 and not level.active_spawns.is_empty():
			lost_t = 0.0
			global_position = level.random_spawn()
			return

	var dir := (target - global_position).normalized()

	# Fenster mit Brettern? Dann erst abreissen.
	var win: Barricade = level.windows.get(level.to_cell(global_position + dir * 9.0))
	if win == null:
		win = level.windows.get(level.to_cell(global_position))
	if win != null and win.planks > 0:
		tear_window = win
		state = St.TEAR
		state_t = _tear_time()
		velocity = Vector2.ZERO
		return

	# Abstand zu anderen Zombies halten
	var push := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("zombies"):
		if o == self:
			continue
		var off: Vector2 = global_position - o.global_position
		var l := off.length()
		if l < 9.0 and l > 0.01:
			push += off / l * (9.0 - l) * 6.0

	velocity = dir * speed + push
	move_and_slide()
	_face(dir)
	_play("walk")
	# Schrittfrequenz passend zum Tempo
	body.speed_scale = speed / schritt_tempo


## Haelt den Zombie fuer sec Sekunden fest (bricht ein Ausholen ab).
func hold(sec: float) -> void:
	if state == St.DEAD or state == St.RISE:
		return
	if state == St.WINDUP:
		state = St.CHASE
		attack_cd = maxf(attack_cd, 0.3)
	held_t = maxf(held_t, sec)


func _tear_time() -> float:
	return bretter_zeit


func hit(amount: float, dir: Vector2, melee: bool) -> void:
	if state == St.DEAD:
		return
	if game.insta_kill_t > 0.0:
		amount = hp
	hp -= amount
	game.fx_blood(global_position + Vector2(0, -8), dir)
	if hp <= 0.0:
		die(melee, true)
	else:
		game.add_points(10)
		body.modulate = Color(3.0, 3.0, 3.0)
		var tw := create_tween()
		tw.tween_property(body, "modulate", Color.WHITE, 0.12)


func die(melee: bool, award: bool) -> void:
	if state == St.DEAD:
		return
	state = St.DEAD
	remove_from_group("zombies")
	hurtbox.collision_layer = 0
	velocity = Vector2.ZERO
	game.on_zombie_killed(self, melee, award)
	body.scale = Vector2.ONE
	body.position = Vector2(0, foot_y)
	body.speed_scale = 1.0
	# Sterbe-Animationen gibt es nur seitlich: zum Spieler hin umfallen
	var left := player.global_position.x < global_position.x if is_instance_valid(player) else facing == "left"
	body.play(&"death_left" if left else &"death_side")
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color(0.8, 0.8, 0.8), 0.4)
	tw.tween_interval(3.0)
	tw.tween_property(body, "modulate:a", 0.0, 1.5)
	tw.tween_callback(queue_free)
