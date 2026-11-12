@tool
class_name FigurVorschau
extends AnimatedSprite2D
## Figur (Spieler, Zombie). Im Spiel setzen player.gd / zombie.gd die Animationen.
## Im Editor zeigt dieses Skript die Figur als Vorschau an (sonst waere der Knoten leer und
## Godot warnt, dass SpriteFrames fehlen). Die Vorschau wird vor dem Speichern entfernt,
## damit keine erzeugten Bilder in der Szene landen.

## Welche Figur-Animationen die Vorschau zeigt (siehe SheetAnims / pack.gd)
@export_enum("player", "zombie_small", "zombie_axe", "zombie_big") var gruppe := "player":
	set(value):
		gruppe = value
		if is_inside_tree():
			_vorschau()


func _ready() -> void:
	_vorschau()


func _vorschau() -> void:
	if not Engine.is_editor_hint():
		return
	sprite_frames = SheetAnims.frames(gruppe)
	offset.y = SheetAnims.foot_offset(gruppe)
	play(&"idle_down" if sprite_frames.has_animation(&"idle_down") else sprite_frames.get_animation_names()[0])


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		sprite_frames = null
		offset = Vector2.ZERO
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_vorschau()
