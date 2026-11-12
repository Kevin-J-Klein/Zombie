class_name VillagePlayer
extends CharacterBody2D
## Spielfigur im Dorf: gleiche Figur und Steuerung wie im Level (WASD, Shift),
## aber ohne Waffen und ohne Kampf.

const WALK_SPEED := 68.0
const SPRINT_SPEED := 108.0

var input_enabled := true
var face := "down"
var body: AnimatedSprite2D
var camera: Camera2D


func _init() -> void:
	collision_layer = 0
	collision_mask = G.L_WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	body = AnimatedSprite2D.new()
	add_child(body)
	_apply_figur()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.5
	shape.shape = circle
	add_child(shape)
	camera = Camera2D.new()
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)


func _ready() -> void:
	body.play(&"idle_down")
	# Charakter im Haus gewechselt -> Figur im Dorf sofort tauschen
	Save.changed.connect(_apply_figur)


## Figur des gewaehlten Charakters (HubData.CHARACTERS) anzeigen
func _apply_figur() -> void:
	var figur: String = HubData.CHARACTERS.get(Save.character(), {}).get("figur", "player")
	var anim := body.animation
	body.sprite_frames = SheetAnims.frames(figur)
	body.position.y = SheetAnims.foot_offset(figur)
	if is_inside_tree() and body.sprite_frames.has_animation(anim):
		body.play(anim)


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if input_enabled:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sprinting := dir != Vector2.ZERO and Input.is_action_pressed("sprint")
	velocity = dir * (SPRINT_SPEED if sprinting else WALK_SPEED)
	move_and_slide()
	if dir != Vector2.ZERO:
		if absf(dir.x) >= absf(dir.y):
			face = "side" if dir.x > 0.0 else "left"
		else:
			face = "down" if dir.y > 0.0 else "up"
	var anim := StringName(("run_" if dir != Vector2.ZERO else "idle_") + face)
	if body.animation != anim:
		body.play(anim)
	body.speed_scale = 1.4 if sprinting else 1.0
