@tool
class_name FigurVorschau
extends AnimatedSprite2D
## Figur (Spieler, Zombie). Im Spiel setzen player.gd / zombie.gd die Animationen;
## mit «im_spiel_abspielen» spielt die Figur selbst (Deko, z. B. im Startmenue).
## Im Editor zeigt dieses Skript die Figur als Vorschau an (sonst waere der Knoten leer und
## Godot warnt, dass SpriteFrames fehlen). Die Vorschau wird vor dem Speichern entfernt,
## damit keine erzeugten Bilder in der Szene landen.

## Welche Figur-Animationen die Vorschau zeigt (siehe SheetAnims / pack.gd)
@export_enum("player", "zombie_small", "zombie_axe", "zombie_big") var gruppe := "player":
	set(value):
		gruppe = value
		if is_inside_tree():
			_vorschau()
## Deko: Figur spielt auch im Spiel selbst eine Animation ab (sonst macht das player.gd / zombie.gd)
@export var im_spiel_abspielen := false
## Animation fuer Vorschau und Deko, z. B. walk_down (leer = idle_down)
@export var anim := "":
	set(value):
		anim = value
		if is_inside_tree():
			_vorschau()
## Startbild der Animation (damit nebeneinanderstehende Figuren nicht im Gleichschritt laufen)
@export var start_bild := 0
## Fuesse auf den Ursprung setzen (Versatz nach Figurgroesse)
@export var fuss_versatz := true


func _ready() -> void:
	_vorschau()


func _vorschau() -> void:
	if not Engine.is_editor_hint() and not im_spiel_abspielen:
		return
	sprite_frames = SheetAnims.frames(gruppe)
	offset.y = SheetAnims.foot_offset(gruppe) if fuss_versatz else 0.0
	var a := StringName(anim if anim != "" else "idle_down")
	if not sprite_frames.has_animation(a):
		a = sprite_frames.get_animation_names()[0]
	play(a)
	frame = start_bild % sprite_frames.get_frame_count(a)


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		sprite_frames = null
		offset = Vector2.ZERO
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_vorschau()
