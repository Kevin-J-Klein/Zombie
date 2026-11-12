@tool
class_name SheetAnims
extends RefCounted
## Baut aus den Pack-Animationen (Pack.anims) SpriteFrames fuer AnimatedSprite2D.
## Jede Animation ist ein Streifen gleich grosser Zellen; die Fuesse stehen unten in der
## Mitte der Zelle.

static var _frames := {}


## SpriteFrames einer Gruppe ("player", "zombie_small", "zombie_axe", "fx"), zwischengespeichert.
static func frames(group: String) -> SpriteFrames:
	if _frames.has(group):
		return _frames[group]
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var anims := Pack.anims(group)
	for anim_name: String in anims:
		var a: Dictionary = anims[anim_name]
		var tex: Texture2D = a["tex"]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, a["fps"])
		sf.set_animation_loop(anim_name, a["loop"])
		for i in int(a["frames"]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * a["w"], 0, a["w"], a["h"])
			sf.add_frame(anim_name, at)
	_frames[group] = sf
	return sf


## Gibt die zwischengespeicherten SpriteFrames frei. Wird beim Beenden von G aufgerufen,
## damit keine Texturen den Grafik-Server ueberleben (sonst Fehlermeldungen beim Schliessen).
static func clear() -> void:
	_frames.clear()


## Versatz fuer einen zentrierten Sprite, damit die Fuesse auf dem Ursprung stehen.
static func foot_offset(group: String) -> float:
	return -float(Pack.anims(group).values()[0]["h"]) * 0.5


## Halte-Daten einer Waffe: grip, muzzle, angle, bullet (Bilder: G.weapon_tex / G.weapon_icon).
static func weapon(id: String) -> Dictionary:
	return Pack.weapon(id)


## Laesst eine Animation einmal abspielen (z. B. Treffer-Spritzer) und raeumt danach auf.
static func one_shot(parent: Node, group: String, anim: String, pos: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(group)
	s.position = pos
	parent.add_child(s)
	s.play(anim)
	s.animation_finished.connect(s.queue_free)
	return s
