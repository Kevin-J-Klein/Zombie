class_name Barricade
extends Node2D
## Fenster mit Brettern. Zombies reissen die Bretter ab, der Spieler kann sie
## (E gedrueckt halten) wieder anbringen und bekommt dafuer Punkte.

const MAX_PLANKS := 5

var game: Node
var cell := Vector2i.ZERO
var planks := MAX_PLANKS
var repair_t := 0.0
var reach := 26.0


func setup(p_game: Node, p_cell: Vector2i) -> void:
	game = p_game
	cell = p_cell
	add_to_group("interact")
	var body := StaticBody2D.new()
	body.collision_layer = G.L_PLAYER_BLOCK
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(G.TILE, G.TILE)
	shape.shape = r
	body.add_child(shape)
	add_child(body)


func _draw() -> void:
	for i in planks:
		var y := -7.0 + i * 3.0
		var col := Color("#9a6a38") if i % 2 == 0 else Color("#b07e46")
		draw_rect(Rect2(-8, y, 16, 2), col)
		draw_rect(Rect2(-8, y + 2, 16, 1), Color("#4a2f18"))
		draw_rect(Rect2(-6, y, 1, 1), Color("#d8d8d8"))
		draw_rect(Rect2(5, y, 1, 1), Color("#d8d8d8"))


func remove_plank() -> void:
	planks = maxi(0, planks - 1)
	queue_redraw()


func interact_distance(pos: Vector2) -> float:
	return global_position.distance_to(pos)


func prompt(_player: Node) -> String:
	if planks < MAX_PLANKS:
		return "[E halten]  Barrikade reparieren  (+10)"
	return ""


func interact(_player: Node) -> void:
	pass


func hold_interact(_player: Node, delta: float) -> void:
	if planks >= MAX_PLANKS:
		repair_t = 0.0
		return
	repair_t += delta
	if repair_t >= 0.6:
		repair_t = 0.0
		planks += 1
		game.add_points(10)
		queue_redraw()
