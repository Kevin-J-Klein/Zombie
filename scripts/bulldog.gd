class_name Bulldog
extends CharacterBody2D
## Lamars Bulldogge (Tank oder Biscuit). Bleibt bei Lamar, stuermt auf Zombies in seiner
## Naehe los, beisst zu und haelt sie dabei kurz fest. Nach «dauer» Sekunden laeuft sie davon.
## Die Hunde koennen nicht sterben und blockieren den Spieler nicht.
## Grafik: art/characters/bulldog/ (tools/make_character_art.py), Blickrichtung rechts.

enum St { FOLLOW, CHASE, BITE, LEAVE }

const SPEED := 125.0
const GUARD_RADIUS := 90.0      # greift nur Zombies an, die so nah bei Lamar sind
const BITE_RANGE := 11.0
const BITE_TIME := 0.6          # Sekunden pro Biss
const HOLD_TIME := 0.8          # so lange haelt ein Biss den Zombie fest
const LEAVE_TIME := 1.2

## Welcher Hund (Grafik)
@export_enum("tank", "biscuit") var rasse := "tank"
## So lange bleibt der Hund (Sekunden)
@export var dauer := 20.0
## Schaden pro Biss = Leben eines Zombies dieser Runde mal diesen Anteil
@export var biss_anteil := 0.35

var herrchen: Player
var game: Node
var seite := 1.0                # -1 = laeuft links neben Lamar, 1 = rechts
var state := St.FOLLOW
var state_t := 0.0
var target: Node2D
var path := PackedVector2Array()
var path_i := 0
var repath_t := 0.0

static var _frames := {}

@onready var body: AnimatedSprite2D = $Body


func _ready() -> void:
	add_to_group("bulldogs")
	body.sprite_frames = frames(rasse)
	body.play(&"run")


## SpriteFrames eines Hundes aus den Streifen idle (2), run (4), bite (3), zwischengespeichert.
static func frames(r: String) -> SpriteFrames:
	if _frames.has(r):
		return _frames[r]
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for a: Array in [["idle", 2, 4.0, true], ["run", 4, 12.0, true], ["bite", 3, 12.0, false]]:
		var tex: Texture2D = load("res://art/characters/bulldog/%s_%s-Sheet%d.png" % [r, a[0], a[1]])
		var w: int = tex.get_width() / a[1]
		sf.add_animation(a[0])
		sf.set_animation_speed(a[0], a[2])
		sf.set_animation_loop(a[0], a[3])
		for i in int(a[1]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * w, 0, w, tex.get_height())
			sf.add_frame(a[0], at)
	_frames[r] = sf
	return sf


static func clear() -> void:
	_frames.clear()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(herrchen):
		queue_free()
		return
	dauer -= delta
	if dauer <= 0.0 and state != St.LEAVE:
		state = St.LEAVE
		state_t = LEAVE_TIME
	match state:
		St.FOLLOW:
			target = _find_target()
			if target != null:
				state = St.CHASE
				repath_t = 0.0
			else:
				var spot := herrchen.global_position + Vector2(seite * 14.0, 6.0)
				if global_position.distance_to(spot) > 10.0:
					_move_to(spot, delta, SPEED * (1.0 if global_position.distance_to(spot) > 40.0 else 0.7))
				else:
					velocity = Vector2.ZERO
					_anim(&"idle")
		St.CHASE:
			if not _valid(target) or target.global_position.distance_to(herrchen.global_position) > GUARD_RADIUS * 1.5:
				state = St.FOLLOW
				return
			if global_position.distance_to(target.global_position) <= BITE_RANGE:
				_bite()
			else:
				_move_to(target.global_position, delta, SPEED)
		St.BITE:
			velocity = Vector2.ZERO
			state_t -= delta
			if _valid(target):
				body.flip_h = target.global_position.x < global_position.x
			if state_t <= 0.0:
				state = St.CHASE if _valid(target) else St.FOLLOW
		St.LEAVE:
			# weg von Lamar laufen und ausblenden
			var away := (global_position - herrchen.global_position).normalized()
			if away == Vector2.ZERO:
				away = Vector2(seite, 0.0)
			velocity = away * SPEED
			move_and_slide()
			body.flip_h = velocity.x < 0.0
			_anim(&"run")
			state_t -= delta
			body.modulate.a = clampf(state_t / LEAVE_TIME, 0.0, 1.0)
			if state_t <= 0.0:
				queue_free()


func _valid(z: Node2D) -> bool:
	return is_instance_valid(z) and z.is_in_group("zombies") and z.state != Zombie.St.DEAD


## Naechster Zombie in Lamars Naehe (schon aus dem Boden gestiegen)
func _find_target() -> Node2D:
	var best: Node2D = null
	var best_d := 1e9
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.state == Zombie.St.RISE or z.state == Zombie.St.DEAD:
			continue
		if z.global_position.distance_to(herrchen.global_position) > GUARD_RADIUS:
			continue
		var d := global_position.distance_to(z.global_position)
		if d < best_d:
			best_d = d
			best = z
	return best


func _bite() -> void:
	state = St.BITE
	state_t = BITE_TIME
	velocity = Vector2.ZERO
	body.play(&"bite")
	body.frame = 0
	var dir := (target.global_position - global_position).normalized()
	target.hold(HOLD_TIME)
	target.hit(G.zombie_health(maxi(game.round_num, 1)) * biss_anteil, dir, false)


## Laeuft zu pos; per Wegfindung des Levels (wie die Zombies), sonst direkt.
func _move_to(pos: Vector2, delta: float, speed: float) -> void:
	var goal := pos
	var level: Level = game.level if game != null else null
	if level != null:
		repath_t -= delta
		if repath_t <= 0.0:
			repath_t = 0.35
			path = level.find_path(global_position, pos)
			path_i = 1
		if path.size() > 2 and path_i < path.size() - 1:
			goal = path[path_i]
			if global_position.distance_to(goal) < 4.0:
				path_i += 1
	var dir := (goal - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	if absf(velocity.x) > 1.0:
		body.flip_h = velocity.x < 0.0
	_anim(&"run")


func _anim(a: StringName) -> void:
	if body.animation != a:
		body.play(a)
