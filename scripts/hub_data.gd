class_name HubData
extends RefCounted
## Daten fuer alles, was ueber mehrere Partien bestehen bleibt: Schrott-Formel,
## Startwaffen im Dorf-Shop, Auftraege am Auftragsbrett und die Ziele im Navi.
## Zum Anpassen der Balance reicht es, die Werte hier zu aendern.

## Schrott am Ende einer Partie: Runde * SCRAP_PER_ROUND + Kills * SCRAP_PER_KILL (+ Bonus bei Flucht),
## das Ganze mal dem Schrott-Bonus des Ziels.
const SCRAP_PER_ROUND := 15
const SCRAP_PER_KILL := 1
const SCRAP_ESCAPE_BONUS := 200

## Startwaffen im Dorf-Shop: Waffe -> Preis in Schrott. Die Pistole besitzt man von Anfang an.
## Bewusst nur schwache bis mittlere Waffen, damit Wandkaeufe und Mystery-Box wichtig bleiben.
const START_WEAPONS := {"pistol": 0, "smg": 400, "shotgun": 600, "rifle": 1000, "dmr": 1500}
const WEAPON_BLURB := {
	"pistol": "Solide Startwaffe",
	"smg": "Hohe Feuerrate, wenig Schaden",
	"shotgun": "Stark auf kurze Distanz",
	"rifle": "Vielseitig, durchschlägt 2 Zombies",
	"dmr": "Viel Schaden pro Schuss, langsam",
}

## Auftraege. kind = welches Ereignis zaehlt (siehe Save.contract_event):
##   kill, melee_kill, tank_kill, repair            zaehlen ueber mehrere Partien zusammen
##   round, round_no_revive, points, escape, gnomes  muessen in EINER Partie erreicht werden (run = true)
const MAX_ACTIVE_CONTRACTS := 3
const CONTRACT_OFFERS := 5
const CONTRACTS := {
	"kills_75": {"name": "Kammerjäger", "text": "75 Zombies töten", "kind": "kill", "target": 75, "reward": 150, "run": false},
	"kills_200": {"name": "Grossputz", "text": "200 Zombies töten", "kind": "kill", "target": 200, "reward": 350, "run": false},
	"melee_20": {"name": "Nur Nahkampf", "text": "20 Zombies mit dem Messer töten", "kind": "melee_kill", "target": 20, "reward": 120, "run": false},
	"tanks_5": {"name": "Panzerknacker", "text": "5 Panzer-Zombies töten", "kind": "tank_kill", "target": 5, "reward": 200, "run": false},
	"repair_15": {"name": "Handwerker", "text": "15 Bretter an Barrikaden anbringen", "kind": "repair", "target": 15, "reward": 100, "run": false},
	"repair_40": {"name": "Zimmermann", "text": "40 Bretter an Barrikaden anbringen", "kind": "repair", "target": 40, "reward": 220, "run": false},
	"round_5": {"name": "Aufwärmen", "text": "Runde 5 erreichen", "kind": "round", "target": 5, "reward": 80, "run": true},
	"round_10": {"name": "Durchhalten", "text": "Runde 10 erreichen", "kind": "round", "target": 10, "reward": 200, "run": true},
	"round_8_no_revive": {"name": "Ohne Netz", "text": "Runde 8 erreichen ohne «Zweite Chance»", "kind": "round_no_revive", "target": 8, "reward": 250, "run": true},
	"points_8000": {"name": "Punktejäger", "text": "8000 Punkte in einer Partie verdienen", "kind": "points", "target": 8000, "reward": 180, "run": true},
	"escape": {"name": "Funker", "text": "Das Funkgerät reparieren und fliehen", "kind": "escape", "target": 1, "reward": 300, "run": true},
	"gnomes": {"name": "Pilzjagd", "text": "Alle 3 Glückspilze in einer Partie erwischen", "kind": "gnomes", "target": 3, "reward": 150, "run": true},
}

## Ziele im Navi. Jedes Ziel ist ein Level mit festem Schwierigkeitsgrad (skulls 1-4).
##   scene   Szene des Levels; "" = noch nicht gebaut
##   bonus   Schrott-Bonus (schwerere Ziele geben mehr)
##   unlock  {} = von Anfang an offen, sonst {"dest": Ziel, "escapes": n} oder {"dest": Ziel, "round": n}
##   pos     Lage auf der Navi-Karte (0-1)
const START_DEST := "vorstadt"
const DESTINATIONS := {
	"vorstadt": {"name": "Vorstadt", "scene": "res://scenes/game.tscn", "skulls": 1, "bonus": 1.0, "areas": 5,
		"mission": "Funkgerät reparieren und\nzum Landeplatz fliehen", "unlock": {}, "pos": Vector2(0.42, 0.26)},
	"tankstelle": {"name": "Tankstelle", "scene": "", "skulls": 2, "bonus": 1.5, "areas": 4,
		"mission": "Noch im Bau", "unlock": {"dest": "vorstadt", "escapes": 1}, "pos": Vector2(0.76, 0.46)},
	"spital": {"name": "Spital", "scene": "", "skulls": 3, "bonus": 2.0, "areas": 6,
		"mission": "Noch im Bau", "unlock": {"dest": "tankstelle", "round": 15}, "pos": Vector2(0.50, 0.66)},
	"militaerbasis": {"name": "Militärbasis", "scene": "", "skulls": 4, "bonus": 3.0, "areas": 7,
		"mission": "Noch im Bau", "unlock": {"dest": "spital", "escapes": 1}, "pos": Vector2(0.80, 0.84)},
}
## Strassen auf der Navi-Karte ("dorf" ist der Startpunkt)
const NAVI_HOME := Vector2(0.14, 0.34)
const NAVI_ROADS := [["dorf", "vorstadt"], ["vorstadt", "tankstelle"], ["vorstadt", "spital"],
	["tankstelle", "militaerbasis"], ["spital", "militaerbasis"]]


static func unlock_text(dest_id: String) -> String:
	var u: Dictionary = DESTINATIONS[dest_id]["unlock"]
	if u.is_empty():
		return ""
	var other: String = DESTINATIONS[u["dest"]]["name"]
	if u.has("escapes"):
		return "%s: Flucht schaffen" % other
	return "%s: Runde %d erreichen" % [other, int(u["round"])]


## Zahl mit Tausender-Apostroph (1'250)
static func num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "'" + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func time_text(sec: float) -> String:
	var t := int(sec)
	return "%d:%02d" % [t / 60, t % 60]
