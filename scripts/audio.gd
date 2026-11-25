extends Node
## Autoload «Audio»: spielt Soundeffekte und Musik ab.
##
## Soundeffekte:  Audio.sfx("player/hitHurt")
##   -> sucht res://audio/sfx/player/hitHurt.wav (oder .ogg)
##   Mit Position (Sound wird mit Abstand leiser): Audio.sfx("zombies/stoehnen", global_position)
## Musik:         Audio.musik("dorf")  -> res://audio/musik/dorf.ogg (oder .wav), mit Ueberblenden
##                Audio.musik("")      -> Musik ausblenden
##
## Busse: Master > Musik, SFX (werden beim Start angelegt, falls es sie noch nicht gibt).

const SFX_DIR := "res://audio/sfx/"
const MUSIK_DIR := "res://audio/musik/"
const ENDUNGEN := ["wav", "ogg", "mp3"]
const POOL_GROESSE := 16          ## so viele Soundeffekte gleichzeitig
const MIN_ABSTAND := 0.06         ## gleicher Sound hoechstens alle 0,06 s (kein Aufstauen)
const TONHOEHE := 0.06            ## zufaellige Tonhoehe +-6 %, damit es nicht monoton klingt
const UEBERBLENDEN := 1.0         ## Sekunden

var _cache := {}                  # Name -> AudioStream (oder null, wenn nicht gefunden)
var _zuletzt := {}                # Name -> Zeitpunkt (ms)
var _pool: Array[AudioStreamPlayer] = []
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _naechster := 0
var _naechster_2d := 0
var _musik_a: AudioStreamPlayer
var _musik_b: AudioStreamPlayer
var _musik_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # auch in der Pause
	_bus_anlegen("Musik")
	_bus_anlegen("SFX")
	for i in POOL_GROESSE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = "SFX"
		p2.max_distance = 900.0
		add_child(p2)
		_pool_2d.append(p2)
	_musik_a = _musik_player()
	_musik_b = _musik_player()


## Spielt einen Soundeffekt. Ohne Position ueberall gleich laut (Spieler, Menue),
## mit Position wird er mit dem Abstand zur Kamera leiser.
func sfx(name: String, position: Variant = null, lautstaerke_db := 0.0) -> void:
	var stream := _laden(SFX_DIR, name)
	if stream == null:
		return
	var jetzt := Time.get_ticks_msec()
	if jetzt - int(_zuletzt.get(name, -100000)) < int(MIN_ABSTAND * 1000.0):
		return
	_zuletzt[name] = jetzt
	var tonhoehe := randf_range(1.0 - TONHOEHE, 1.0 + TONHOEHE)
	if position is Vector2:
		var p2 := _pool_2d[_naechster_2d]
		_naechster_2d = (_naechster_2d + 1) % _pool_2d.size()
		p2.stream = stream
		p2.global_position = position
		p2.volume_db = lautstaerke_db
		p2.pitch_scale = tonhoehe
		p2.play()
	else:
		var p := _pool[_naechster]
		_naechster = (_naechster + 1) % _pool.size()
		p.stream = stream
		p.volume_db = lautstaerke_db
		p.pitch_scale = tonhoehe
		p.play()


## Wechselt die Musik mit Ueberblenden. Gleicher Name = nichts tun. "" = ausblenden.
func musik(name: String) -> void:
	if name == _musik_name:
		return
	_musik_name = name
	var alt := _musik_a if _musik_a.playing else _musik_b
	var neu := _musik_b if alt == _musik_a else _musik_a
	if alt.playing:
		var t := create_tween()
		t.tween_property(alt, "volume_db", -40.0, UEBERBLENDEN)
		t.tween_callback(alt.stop)
	if name == "":
		return
	var stream := _laden(MUSIK_DIR, name)
	if stream == null:
		return
	neu.stream = stream
	neu.volume_db = -40.0
	neu.play()
	create_tween().tween_property(neu, "volume_db", 0.0, UEBERBLENDEN)


# ------------------------------------------------------------------ intern

func _laden(dir: String, name: String) -> AudioStream:
	var key := dir + name
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStream = null
	for e in ENDUNGEN:
		var pfad := "%s%s.%s" % [dir, name, e]
		if ResourceLoader.exists(pfad):
			stream = load(pfad) as AudioStream
			break
	if stream == null:
		push_warning("Audio: Datei nicht gefunden: %s%s (.wav/.ogg)" % [dir, name])
	_cache[key] = stream
	return stream


func _bus_anlegen(name: String) -> void:
	if AudioServer.get_bus_index(name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, "Master")


func _musik_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Musik"
	add_child(p)
	return p
