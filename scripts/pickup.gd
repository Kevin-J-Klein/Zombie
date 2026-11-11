class_name Pickup
extends Node2D
## Funkteil fuer die Quest. Wird beim Drueberlaufen eingesammelt.

var game: Node
var t := 0.0
var sprite: Sprite2D


func setup(p_game: Node) -> void:
	game = p_game
	sprite = Sprite2D.new()
	sprite.texture = preload("res://art/part.png")
	add_child(sprite)


func _process(delta: float) -> void:
	t += delta
	sprite.position.y = -3.0 + sin(t * 4.0) * 1.5
	if is_instance_valid(game.player) and game.player.global_position.distance_to(global_position) < 11.0:
		game.collect_part()
		queue_free()
