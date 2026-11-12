class_name Powerup
extends Node2D
## Power-up, das ein getoeteter Zombie fallen laesst.

var game: Node
var kind := ""
var life := 25.0
var t := 0.0
var sprite: Sprite2D


func setup(p_game: Node, p_kind: String) -> void:
	game = p_game
	kind = p_kind
	sprite = Sprite2D.new()
	sprite.texture = Pack.file(G.POWERUPS[kind]["tex"])
	add_child(sprite)


func _process(delta: float) -> void:
	t += delta
	life -= delta
	sprite.position.y = -6.0 + sin(t * 5.0) * 2.0
	sprite.visible = life > 6.0 or int(t * 8.0) % 2 == 0
	if life <= 0.0:
		queue_free()
	elif is_instance_valid(game.player) and game.player.global_position.distance_to(global_position) < 12.0:
		game.apply_powerup(kind)
		queue_free()
