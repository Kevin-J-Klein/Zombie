class_name Gnome
extends Node2D
## Versteckter Gartenzwerg (Neben-Easter-Egg): alle drei abschiessen gibt eine Belohnung.

var game: Node


func setup(p_game: Node) -> void:
	game = p_game
	var s := Sprite2D.new()
	s.texture = preload("res://art/gnome.png")
	s.position = Vector2(0, -3)
	add_child(s)
	var area := Area2D.new()
	area.collision_layer = G.L_HURT
	area.collision_mask = 0
	area.monitoring = false
	area.add_to_group("hurtbox")
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(9, 12)
	shape.shape = r
	shape.position = Vector2(0, -2)
	area.add_child(shape)
	add_child(area)


func hit(_damage: float, _dir: Vector2, _melee: bool) -> void:
	game.gnome_shot(global_position)
	queue_free()
