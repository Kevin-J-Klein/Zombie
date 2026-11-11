class_name SheetAnims
extends RefCounted
## Liest art/pack/anims.json (erzeugt von tools/import_asset_pack.py) und baut daraus
## SpriteFrames fuer AnimatedSprite2D. Jede Animation ist ein Streifen gleich grosser
## Zellen; die Fuesse stehen unten in der Mitte der Zelle.

const DATA_PATH := "res://art/pack/anims.json"

static var _data := {}
static var _frames := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var json: JSON = load(DATA_PATH)
		_data = json.data
	return _data


## SpriteFrames einer Gruppe ("player", "zombie_small", "zombie_axe", "fx"), zwischengespeichert.
static func frames(group: String) -> SpriteFrames:
	if _frames.has(group):
		return _frames[group]
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var anims: Dictionary = data()[group]
	for anim_name: String in anims:
		var a: Dictionary = anims[anim_name]
		var tex: Texture2D = load(a["file"])
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
	var anims: Dictionary = data()[group]
	return -float(anims.values()[0]["h"]) * 0.5


## Bilddaten einer Waffe: texture, icon, grip, muzzle, angle, bullet.
static func weapon(id: String) -> Dictionary:
	return data()["weapons"][id]


## Laesst eine Animation einmal abspielen (z. B. Treffer-Spritzer) und raeumt danach auf.
static func one_shot(parent: Node, group: String, anim: String, pos: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(group)
	s.position = pos
	parent.add_child(s)
	s.play(anim)
	s.animation_finished.connect(s.queue_free)
	return s
