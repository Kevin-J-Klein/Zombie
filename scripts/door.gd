class_name Door
extends Node2D
## Kaufbare Tuer ueber eine oder mehrere Kacheln. Im Editor ein LevelObject der Art «Tür».

var game: Node
var level: Node
var id := ""
var cost := 0
var title := ""
var cells: Array[Vector2i] = []
var reach := 30.0
var opens_on_escape := false             # geht auf, wenn der Helikopter kommt


func setup(p_game: Node, p_level: Node, p_title: String, p_cells: Array, p_cost: int, vertical: bool) -> void:
	game = p_game
	level = p_level
	id = p_title
	title = p_title
	cost = p_cost
	cells.assign(p_cells)
	name = "Tuer_" + p_title
	add_to_group("interact")
	position = level.cell_center(cells[0])
	var body := StaticBody2D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	add_child(body)
	# Holztor aus dem Pack: liegt die Tuer in einer senkrechten Wand, die schmalen Bretter
	for c in cells:
		var local: Vector2 = level.cell_center(c) - position
		var s := Sprite2D.new()
		s.texture = Pack.file(LevelObject.TUER_SENKRECHT if vertical else LevelObject.TUER_WAAGRECHT)
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
