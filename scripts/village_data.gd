extends RefCounted
## Das Dorf (Hauptmenue) als Text. Jede Zeile ist eine Reihe von 16x16-Kacheln.
##
## Legende Boden:
##   ~  Gras      P  Dorfplatz (Pflaster)     p  Weg (Pflaster)
##   c  Randstein um den Platz (Richtung ergibt sich aus den P-Nachbarn)
##   :  Strasse   -  Strasse mit Mittelstrich
##
## Alles, was auf dem Boden steht, ist in OBJECTS aufgelistet (Position in Pixeln).

const MAP: Array[String] = [
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~cccccccccccc~~~~~~~~~~~~",
	"~~~~~~~~~~~~cPPPPPPPPPPc~~~~~p~~~~~~",
	"~~~~~~p~~~~~cPPPPPPPPPPc~~~~~p~~~~~~",
	"~~~~~~p~~~~~cPPPPPPPPPPc~~~~~p~~~~~~",
	"~~~~~~pppppppPPPPPPPPPPppppppp~~~~~~",
	"~~~~~~~~~~~~cPPPPPPPPPPc~~~~~~~~~~~~",
	"~~~~~~~~~~~~cPPPPPPPPPPc~~~~~~~~~~~~",
	"~~~~~~~~~~~~cccccppccccc~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~pp~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~pp~~~~~~~~~~~~~~~~~",
	"::::::::::::::::::::::::::::::::::::",
	"::::::::::::::::::::::::::::::::::::",
	"-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:",
	"::::::::::::::::::::::::::::::::::::",
	"::::::::::::::::::::::::::::::::::::",
]

## Wo der Spieler steht: beim Spielstart auf dem Platz, nach einer Partie neben dem Wagen.
const START := Vector2(288, 232)
const START_AFTER_RUN := Vector2(346, 352)

## Zaun mit Tor: Reihe (y der Unterkante) und die Kacheln, die als Tor offen bleiben.
const FENCE_Y := 302
const GATE_TILES := [17, 18]

## Auf der Strasse darf der Spieler nur in diesem Bereich herumlaufen (x von/bis).
## Links und rechts davon schlurfen die Zombies als Kulisse.
const ROAD_WALK := Vector2(204, 388)
const ZOMBIE_ZONES := [Vector2(8, 176), Vector2(412, 568)]

## Dinge zum Benutzen (E). kind bestimmt, welches Fenster aufgeht (siehe village_ui.gd).
const INTERACT := [
	{"kind": "house", "pos": Vector2(104, 176), "reach": 20.0, "prompt": "[E]  Haus betreten"},
	{"kind": "shop", "pos": Vector2(500, 186), "reach": 24.0, "prompt": "[E]  Mit dem Händler reden"},
	{"kind": "board", "pos": Vector2(288, 198), "reach": 24.0, "prompt": "[E]  Aufträge ansehen"},
	{"kind": "car", "pos": Vector2(346, 346), "reach": 26.0, "prompt": "[E]  Einsteigen"},
]

## Namensschilder ueber den Orten (Position in der Welt). alert = zeigt ein "!" bei Neuigkeiten am Brett
const TAGS := [
	{"text": "Dein Haus", "pos": Vector2(104, 40)},
	{"text": "Shop", "pos": Vector2(472, 56)},
	{"text": "Aufträge", "pos": Vector2(288, 150), "alert": true},
	{"text": "Wagen", "pos": Vector2(346, 314)},
]

## Objekte: tex = Datei in art/pack/village/, pos = Fusspunkt (Mitte unten),
##   sink  = so viele Pixel ragt das Bild unter den Fusspunkt (z. B. Tuerschwelle)
##   solid = [Breite, Hoehe] des festen Bereichs ueber dem Fusspunkt (fehlt = man laeuft hindurch)
##   anim  = Animationsgruppe aus anims.json statt eines Bildes
const OBJECTS := [
	{"tex": "house.png", "pos": Vector2(104, 170), "sink": 6, "solid": [108, 120]},
	{"tex": "shop.png", "pos": Vector2(472, 160), "sink": 2, "solid": [140, 94]},
	{"tex": "board.png", "pos": Vector2(288, 192), "solid": [26, 6]},
	{"tex": "bench.png", "pos": Vector2(232, 176), "solid": [30, 8]},
	{"tex": "bench.png", "pos": Vector2(344, 176), "solid": [30, 8]},
	{"tex": "lamp.png", "pos": Vector2(200, 160), "solid": [4, 4]},
	{"tex": "lamp.png", "pos": Vector2(376, 160), "solid": [4, 4]},
	{"tex": "lamp.png", "pos": Vector2(262, 296), "solid": [4, 4]},
	{"tex": "lamp.png", "pos": Vector2(314, 296), "solid": [4, 4]},
	{"anim": "trader", "pos": Vector2(500, 180), "solid": [8, 5]},
	{"tex": "barrel_red.png", "pos": Vector2(554, 172), "solid": [10, 6]},
	{"tex": "ammo_crate.png", "pos": Vector2(538, 176), "solid": [10, 5]},
	{"tex": "car.png", "pos": Vector2(346, 340), "solid": [36, 10]},
	{"tex": "cone.png", "pos": Vector2(320, 338)},
	{"tex": "flowers_0.png", "pos": Vector2(58, 182)},
	{"tex": "flowers_1.png", "pos": Vector2(150, 182)},
	{"tex": "bush_0.png", "pos": Vector2(170, 178), "solid": [10, 5]},
	{"tex": "pallet.png", "pos": Vector2(40, 240), "solid": [14, 8]},
	{"tex": "barrel.png", "pos": Vector2(62, 238), "solid": [10, 6]},
	{"tex": "tire.png", "pos": Vector2(120, 264)},
	{"tex": "bin.png", "pos": Vector2(152, 252), "solid": [24, 10]},
	{"tex": "bush_0.png", "pos": Vector2(96, 282), "solid": [10, 5]},
	{"tex": "flowers_2.png", "pos": Vector2(420, 250)},
	{"tex": "bush_1.png", "pos": Vector2(404, 274), "solid": [22, 5]},
	{"tex": "stump.png", "pos": Vector2(506, 262), "solid": [10, 5]},
	{"tex": "flowers_1.png", "pos": Vector2(470, 236)},
	{"tex": "tree_5.png", "pos": Vector2(188, 122), "solid": [8, 6]},
	{"tex": "tree_2.png", "pos": Vector2(236, 70), "solid": [6, 5]},
	{"tex": "tree_4.png", "pos": Vector2(330, 78), "solid": [8, 6]},
	{"tex": "tree_1.png", "pos": Vector2(378, 118), "solid": [6, 5]},
	{"tex": "tree_5.png", "pos": Vector2(540, 250), "solid": [8, 6]},
	{"tex": "tree_1.png", "pos": Vector2(36, 280), "solid": [6, 5]},
]
