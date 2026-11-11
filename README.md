# Zombie Game

Top-down Zombie-Wellen-Survival im Pixel-Look, gebaut mit Godot 4 (GDScript).
Vorbild für den Spielablauf sind die Zombie-Modi von Call of Duty: Runden, Punkte,
Wandkäufe, Mystery-Box, Perks, Strom, Upgrade-Werkbank und eine Quest, mit der man
das Level durchspielt.

## Starten

1. Godot 4.3 oder neuer installieren (getestet mit 4.7.2, Standard-Version ohne .NET).
2. In Godot «Importieren» wählen und `project.godot` in diesem Ordner öffnen.
3. F5 drücken.

## Steuerung

| Taste | Aktion |
|---|---|
| WASD / Pfeiltasten | bewegen |
| Maus | zielen |
| Linksklick | schiessen |
| R | nachladen |
| Rechtsklick / V | Messer |
| Shift | sprinten |
| E | benutzen / kaufen (halten: Barrikade reparieren) |
| Q / 1 / 2 / Mausrad | Waffe wechseln |
| Esc / P | Pause |

## Spielablauf

- Zombies kommen durch die verbarrikadierten Fenster. Treffer geben 10 Punkte, Kills 60 (Messer 130).
- Mit Punkten kaufst du Türen, Waffen an der Wand, Sachen im Shop-Terminal (Startraum),
  die Mystery-Box (Markt), Perks und Waffen-Upgrades.
- Perk-Automaten und die Upgrade-Werkbank brauchen Strom. Der Schalter ist im Lagerraum des Markts.
- **Haupt-Quest:** Strom einschalten → 3 Funkteile finden → Funkgerät im Markt reparieren →
  90 Sekunden durchhalten → zum Landeplatz im Garten laufen.
- **Neben-Easter-Egg:** Drei versteckte Gartenzwerge abschiessen.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `scripts/globals.gd` | Autoload `G`: Waffen, Perks, Preise, Rundenformeln, Tastenbelegung |
| `scripts/level_data.gd` | Die Karte als Text plus Türpreise und Wandkäufe |
| `scripts/level.gd` | Baut aus der Karte Kacheln, Kollision, Wegfindung und Objekte |
| `scripts/game.gd` | Runden, Spawns, Punkte, Power-ups, Shop, Quest |
| `scripts/player.gd`, `scripts/zombie.gd` | Spieler und Zombie (Szenen in `scenes/`) |
| `scripts/interactable.gd` | Wandkauf, Shop, Box, Werkbank, Strom, Funkgerät, Perks |
| `scripts/hud.gd` | Anzeige und Menüs |
| `art/` | Platzhalter-Grafiken, erzeugt von `tools/make_placeholder_art.py` |
| `tests/smoke_test.tscn` | Automatischer Durchlauf aller Systeme |

## Anpassen

- **Karte:** `scripts/level_data.gd` bearbeiten, die Legende steht oben in der Datei.
- **Balance:** Werte in `scripts/globals.gd` (Schaden, Preise, Zombies pro Runde).
- **Grafik:** Eigene PNGs unter demselben Namen in `art/` ablegen. Figuren sind 16×22 Pixel,
  Kacheln 16×16 (`tiles.png`: 10 Kacheltypen nebeneinander, 4 Varianten untereinander).

## Test

```
godot --headless --path . res://tests/smoke_test.tscn
```
