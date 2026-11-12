extends Player
## Lamar «Endzone» Brooks (Gangster). Lieblingswaffe Uzi.
## Spezialfaehigkeit «Bulldoggen»: Tank und Biscuit stuermen herbei und beschuetzen ihn
## (siehe bulldog.gd). Werte im Inspektor der Szene scenes/charaktere/lamar.tscn.

const BULLDOG_SCENE := preload("res://scenes/charaktere/bulldog.tscn")

@export_group("Bulldoggen")
## So lange bleiben die Hunde (Sekunden)
@export var hunde_dauer := 20.0
## Schaden pro Biss = Leben eines Zombies dieser Runde mal diesen Anteil
@export var biss_anteil := 0.35


func _use_ability() -> bool:
	var rassen := ["tank", "biscuit"]
	for i in rassen.size():
		var dog: Bulldog = BULLDOG_SCENE.instantiate()
		dog.rasse = rassen[i]
		dog.herrchen = self
		dog.game = game
		dog.dauer = hunde_dauer
		dog.biss_anteil = biss_anteil
		dog.seite = -1.0 if i == 0 else 1.0
		dog.position = position + Vector2(dog.seite * 10.0, 4.0)
		get_parent().add_child(dog)
	game.announce("Tank! Biscuit! Fass!", "Die Bulldoggen beschützen dich %d Sekunden" % int(hunde_dauer))
	return true
