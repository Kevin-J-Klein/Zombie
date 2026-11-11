class_name Door
extends Node2D
## Kaufbare Tuer. Besteht aus einer oder mehreren Kacheln mit gleichem Buchstaben.

const LevelData := preload("res://scripts/level_data.gd")

var game: Node
var level: Node
var id := ""
var cost := 0
var title := ""
var cells: Array[Vector2i] = []
var reach := 30.0


func setup(p_game: Node, p_level: Node, p_id: String, p_cells: Array) -> void:
	game = p_game
	level = p_level
	id = p_id
	cells.assign(p_cells)
	cost = LevelData.DOORS[id]["cost"]
	title = LevelData.DOORS[id]["name"]
	name = "Tuer_" + id
	add_to_group("interact")
	position = level.cell_center(cells[0])
	var body := StaticBody2D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	add_child(body)
	for c in cells:
		var local: Vector2 = level.cell_center(c) - position
		var s := Sprite2D.new()
		s.texture = preload("res://art/door.png")
		s.position = local
		add_child(s)
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(G.TILE, G.TILE)
		shape.shape = r
		shape.position = local
		body.add_child(shape)


func interact_distance(pos: Vector2) -> float:
	var best := 1e9
	for c in cells:
		best = minf(best, level.cell_center(c).distance_to(pos))
	return best


func prompt(_player: Node) -> String:
	return "[E]  %s öffnen  –  %d Punkte" % [title, cost]


func interact(_player: Node) -> void:
	if game.try_spend(cost):
		open()


func open() -> void:
	remove_from_group("interact")
	level.on_door_opened(self)
	game.announce("%s geöffnet" % title)
	queue_free()
