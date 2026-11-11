class_name Zombie
extends CharacterBody2D
## Zombie: steigt aus dem Boden, laeuft per Wegfindung zum Spieler, reisst
## Barrikaden ab und greift im Nahkampf an.

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

var state := St.RISE
var state_t := RISE_TIME
var path := PackedVector2Array()
var path_i := 0
var repath_t := 0.0
var attack_cd := 0.0
var lost_t := 0.0
var tear_window: Barricade
var anim_t := 0.0

@onready var body: Sprite2D = $Body
@onready var hurtbox: Area2D = $Hurtbox


func setup(p_game: Node, round_num: int) -> void:
	game = p_game
	level = game.level
	player = game.player
	hp = G.zombie_health(round_num)
	runner = round_num >= 3 and randf() < minf(0.15 * (round_num - 2), 0.8)
	if runner:
		speed = randf_range(56.0, 66.0)
	else:
		speed = randf_range(24.0, 34.0) + minf(round_num, 10.0)


func _ready() -> void:
	anim_t = randf() * 10.0
	if runner:
		body.texture = preload("res://art/zombie_runner.png")
	body.scale.y = 0.05


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
			body.position.y = -10.0 * k
			if state_t <= 0.0:
				body.scale.y = 1.0
				state = St.CHASE
		St.CHASE:
			_chase(delta)
		St.TEAR:
			body.position.x = sin(anim_t * 20.0) * 0.8
			if not is_instance_valid(tear_window) or tear_window.planks <= 0:
				body.position.x = 0.0
				state = St.CHASE
			else:
				state_t -= delta
				if state_t <= 0.0:
					tear_window.remove_plank()
					state_t = TEAR_TIME
		St.WINDUP:
			state_t -= delta
			body.position.y = -10.0 - sin((1.0 - state_t / 0.3) * PI) * 3.0
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
		if attack_cd <= 0.0:
			state = St.WINDUP
			state_t = 0.3
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
		state_t = TEAR_TIME
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
	if absf(dir.x) > 0.1:
		body.flip_h = dir.x < 0.0
	body.position.y = -10.0 - absf(sin(anim_t * (14.0 if runner else 8.0))) * 1.2
	body.rotation = sin(anim_t * (7.0 if runner else 4.0)) * 0.08


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
	body.modulate = Color(0.75, 0.75, 0.75)
	body.position = Vector2(0, -3)
	body.scale.y = 1.0
	var tw := create_tween()
	tw.tween_property(body, "rotation", (PI * 0.5) * (-1.0 if body.flip_h else 1.0), 0.18)
	tw.tween_interval(3.0)
	tw.tween_property(body, "modulate:a", 0.0, 1.5)
	tw.tween_callback(queue_free)
