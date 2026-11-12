# Zombie Game

Top-down Zombie-Wellen-Survival im Pixel-Look, gebaut mit Godot 4 (GDScript).
Vorbild für den Spielablauf sind die Zombie-Modi von Call of Duty: Runden, Punkte,
Wandkäufe, Mystery-Box, Perks, Strom, Upgrade-Werkbank und eine Quest, mit der man
das Level durchspielt. Das Hauptmenü ist ein kleines Dorf: Dort gibt es das eigene Haus,
einen Shop, ein Auftragsbrett und den Wagen, mit dem man ins Level fährt.

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
| F11 | Vollbild an/aus (startet im Vollbild) |

## Das Dorf (Hauptmenü)

Nach der Wahl des Spielstands steht man im Dorf. Man läuft mit WASD herum und benutzt alles mit E.

- **Dein Haus:** Trophäenwand mit Rekorden und gefundenen Easter Eggs. Am Waffenständer wählt man die
  Startwaffe für die nächste Partie.
- **Händler vor dem Shop:** verkauft Startwaffen für Schrott.
- **Auftragsbrett:** höchstens 3 Aufträge gleichzeitig. Man erfüllt sie in den Zombie-Levels und holt die
  Belohnung am Brett ab. Nach jeder Partie kommen neue Aufträge dazu.
- **Wagen vor dem Tor:** Einsteigen öffnet das Navi. Dort wählt man das Ziel (= Level) und fährt los.
  Jedes Ziel hat einen festen Schwierigkeitsgrad; weitere Ziele werden freigeschaltet.
- **Zahnrad oder Esc:** Einstellungen (Lautstärke, Vollbild) und Spiel beenden.

**Schrott** ist die Währung, die über alle Partien erhalten bleibt. Es gibt ihn am Ende jeder Partie
(nach Runde und Kills, Bonus für die Flucht) und für erfüllte Aufträge. Die Punkte im Level verfallen
wie bisher. Wer eine Partie über die Pause verlässt, bekommt keinen Schrott.

**Spielstände:** Beim Start wählt man einen von drei Speicherplätzen und kann ihm einen Namen geben.
Gespeichert wird automatisch: bei jedem Kauf und Auftrag, nach jeder Runde, am Ende einer Partie und
beim Schliessen. Im Dorf kommt man über die Einstellungen («Spielstand wechseln») zurück zur Auswahl.
Die Dateien liegen in `user://save_1.json` bis `save_3.json`, die Einstellungen in `user://settings.json`
(Godot: «Projekt → Benutzerdaten-Ordner öffnen»).

## Spielablauf

- Zombies kommen durch die verbarrikadierten Fenster. Treffer geben 10 Punkte, Kills 60 (Messer 130).
- Ab Runde 4 tauchen Panzer-Zombies auf: langsam, viermal so viel Leben, harter Schlag mit langem
  Ausholen, reissen Bretter schneller ab. Kill gibt 140 Bonuspunkte. Werte in `scripts/globals.gd` (`TANK_…`).
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
| `scripts/hud.gd` | Anzeige und Menüs im Level |
| `scripts/save.gd` | Autoload `Save`: 3 Speicherplätze (Schrott, Rekorde, Startwaffen, Aufträge, Ziele), Einstellungen |
| `scripts/main_menu.gd` | Startbildschirm: Spielstand wählen, benennen, löschen |
| `scripts/hub_data.gd` | Werte für Schrott, Startwaffen-Preise, Aufträge und Navi-Ziele |
| `scripts/fade.gd` | Autoload `Fade`: Überblenden zwischen Dorf und Level |
| `scripts/village_data.gd` | Das Dorf als Textkarte plus Liste der Objekte |
| `scripts/village.gd`, `scripts/village_player.gd` | Baut das Dorf, Spielfigur im Dorf (Szene `scenes/village.tscn`) |
| `scripts/village_ui.gd`, `scripts/navi_map.gd` | Fenster im Dorf: Haus, Shop, Auftragsbrett, Navi, Einstellungen |
| `art/asset_pack/` | Das Asset-Pack (Quelle, wird von Godot ignoriert) |
| `art/pack/` | Spielfertige Grafiken aus dem Pack, erzeugt von `tools/import_asset_pack.py` |
| `scripts/sheet_anims.gd` | Baut die Animationen aus `art/pack/anims.json` |
| `art/` | Restliche Platzhalter-Grafiken, erzeugt von `tools/make_placeholder_art.py` |
| `tests/smoke_test.tscn` | Automatischer Durchlauf aller Systeme |

## Anpassen

- **Karte:** `scripts/level_data.gd` bearbeiten, die Legende steht oben in der Datei.
- **Balance:** Werte in `scripts/globals.gd` (Schaden, Preise, Zombies pro Runde).
- **Dorf:** Karte und Objekte in `scripts/village_data.gd`. Schrott-Formel, Preise der Startwaffen,
  Aufträge und Navi-Ziele in `scripts/hub_data.gd`. Ein neues Level wird dort als Ziel eingetragen
  (`scene` = Szene des Levels, `unlock` = Bedingung zum Freischalten).
- **Grafik:** Die Grafiken kommen aus dem Asset-Pack in `art/asset_pack/`. Nach einer Änderung am Pack
  `python3 tools/import_asset_pack.py` ausführen (braucht Pillow: `pip3 install pillow`). Das Skript
  schneidet und kombiniert die Pack-Grafiken nach `art/pack/` – welche Pack-Datei wofür benutzt wird,
  steht dort an einer Stelle. Kacheln sind 16×16 (`tiles.png`: 10 Bodentypen × 4 Varianten,
  `walls.png`: Wände je nach Nachbarwänden). Figuren laufen in 4 Richtungen; Normale Zombies sind
  `Zombie_Small`, Renner der Axt-Zombie. Wofür der Pack nichts hat (Stromschalter, Funkteile,
  Gartenzwerge, einige Power-ups, Blutflecken), bleiben die Platzhalter aus `art/`.
  `art/asset_pack/.gdignore` blendet den Pack im Godot-Editor aus; löschen, um ihn dort zu sehen.

## Test

Der Test benutzt eigene Spielstände (`user://test_save_N.json`), die echten bleiben unberührt.

```
godot --headless --path . res://tests/smoke_test.tscn
```
