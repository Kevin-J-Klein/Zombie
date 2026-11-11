class_name Zombie
extends CharacterBody2D
## Zombie: steigt aus dem Boden, laeuft per Wegfindung zum Spieler, reisst
## Barrikaden ab und greift im Nahkampf an. Drei Arten: normal, Renner (Axt-Zombie)
## und ab Runde G.TANK_FROM_ROUND der langsame, zaehe Panzer-Zombie.

enum St { RISE, CHASE, TEAR, WINDUP, DEAD }

const RISE_TIME := 0.8
const TEAR_TIME := 1.3
const ATTACK_RANGE := 14.0

var game: Node
var level: Level
var player: Player

var hp := 150.0
var speed := 30.0
var damage := 45.0
var runner := false
var tank := false

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

@onready var body: AnimatedSprite2D = $Body
@onready var hurtbox: Area2D = $Hurtbox


func setup(p_game: Node, round_num: int, force_tank := false) -> void:
	game = p_game
	level = game.level
	player = game.player
	hp = G.zombie_health(round_num)
	tank = force_tank or randf() < G.tank_chance(round_num)
	if tank:
		hp *= G.TANK_HP_MULT
		speed = G.TANK_SPEED + randf_range(-2.0, 2.0)
		damage = G.TANK_DAMAGE
		return
	runner = round_num >= 3 and randf() < minf(0.15 * (round_num - 2), 0.8)
	if runner:
		speed = randf_range(56.0, 66.0)
	else:
		speed = randf_range(24.0, 34.0) + minf(round_num, 10.0)


func _ready() -> void:
	anim_t = randf() * 10.0
	# Normale Zombies: Zombie_Small, Renner: der hagere Axt-Zombie, Panzer: Zombie_Big
	var group := "zombie_big" if tank else ("zombie_axe" if runner else "zombie_small")
	if tank:
		# Breiterer Koerper und groessere Trefferzone (eigene Shapes: die der Szene teilen sich alle Zombies)
		var feet := CircleShape2D.new()
		feet.radius = 5.0
		$Shape.shape = feet
		var hurt := RectangleShape2D.new()
		hurt.size = Vector2(15, 21)
		$Hurtbox/HurtShape.shape = hurt
		$Hurtbox/HurtShape.position = Vector2(0, -9)
	body.sprite_frames = SheetAnims.frames(group)
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
					player.take_damage(damage)
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
			state_t = G.TANK_WINDUP if tank else 0.3
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
	body.speed_scale = speed / (48.0 if runner else (22.0 if tank else 30.0))


func _tear_time() -> float:
	return G.TANK_TEAR_TIME if tank else TEAR_TIME


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
