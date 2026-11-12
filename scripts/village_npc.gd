@tool
class_name VillageNpc
extends Node2D
## Bewohner im Dorf: ein Charakter, den man gerade nicht spielt, schlendert hier herum.
## Mit E ansprechen = zu diesem Charakter wechseln (village.gd); er begruesst einen dann.
## Welcher Charakter hier steht, verteilt village.gd (alle ausser dem gewaehlten, Reihenfolge
## wie in HubData.CHARACTERS). Linke obere Ecke = Position; das blaue Rechteck ist der Bereich,
## in dem er herumlaeuft (im Editor verschieben/aufziehen).

@export var width := 120.0:
	set(value):
		width = value
		queue_redraw()
@export var height := 24.0:
	set(value):
		height = value
		queue_redraw()
## Wie nah man fuer E herankommen muss
@export var reach := 18.0

const SPEED := 30.0

var charakter := ""          # Schluessel in HubData.CHARACTERS ("" = niemand hier)
var display_name := ""
var anrede := ""
var area := Rect2()
var target := Vector2.ZERO
var wait_t := 0.0
var face := "down"
var body: AnimatedSprite2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	area = Rect2(global_position, Vector2(width, height))
	body = AnimatedSprite2D.new()
	add_child(body)
	global_position = area.get_center()
	target = global_position
	wait_t = randf_range(0.5, 2.0)


## Charakter setzen (village.gd); "" = unsichtbar
func set_charakter(id: String) -> void:
	charakter = id
	visible = id != ""
	if id == "":
		return
	var def: Dictionary = HubData.CHARACTERS[id]
	display_name = def["name"]
	anrede = def.get("anrede", def["name"])
	body.sprite_frames = SheetAnims.frames(def["figur"])
	body.position.y = SheetAnims.foot_offset(def["figur"])
	body.play(StringName("idle_" + face))


## Steht still und schaut zu pos (wenn der Spieler in der Naehe ist)
func look_at_player(pos: Vector2) -> void:
	_set_face(pos - global_position)
	target = global_position
	wait_t = maxf(wait_t, 1.0)
	_play("idle")


func prompt() -> String:
	return "[E]  Mit %s reden (Charakter wechseln)" % anrede


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or charakter == "":
		return
	if wait_t > 0.0:
		wait_t -= delta
		if wait_t <= 0.0:
			target = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		return
	var to := target - global_position
	if to.length() < 1.5:
		wait_t = randf_range(1.5, 4.0)
		_play("idle")
		return
	var step := to.normalized() * SPEED * delta
	global_position += step if step.length() < to.length() else to
	_set_face(to)
	_play("run")


func _set_face(v: Vector2) -> void:
	if v.length_squared() < 0.01:
		return
	if absf(v.x) >= absf(v.y):
		face = "side" if v.x > 0.0 else "left"
	else:
		face = "down" if v.y > 0.0 else "up"


func _play(kind: String) -> void:
	var a := StringName(kind + "_" + face)
	if body.animation != a:
		body.play(a)
	body.speed_scale = 0.6 if kind == "run" else 1.0


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(Vector2.ZERO, Vector2(width, height))
	draw_rect(r, Color(0.3, 0.6, 1.0, 0.15))
	draw_rect(r, Color(0.3, 0.6, 1.0, 0.8), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(2.0, -3.0), "Bewohner (Charakter wechseln)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.75, 1.0))
