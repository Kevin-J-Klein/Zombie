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
  Ausholen, reissen Bretter schneller ab. Kill gibt 140 Bonuspunkte. Werte im Inspektor von
  `scenes/zombies/zombie_panzer.tscn` (siehe «Zombie-Arten»).
- Mit Punkten kaufst du Türen, Waffen an der Wand, Sachen im Shop-Terminal (Startraum),
  die Mystery-Box (Markt), Perks und Waffen-Upgrades.
- Perk-Automaten und die Upgrade-Werkbank brauchen Strom. Der Schalter ist im Lagerraum des Markts.
- **Haupt-Quest:** Strom einschalten → 3 Funkteile finden → Funkgerät im Markt reparieren →
  90 Sekunden durchhalten → zum Landeplatz im Garten laufen.
- **Neben-Easter-Egg:** Drei versteckte Glückspilze abschiessen.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `scripts/globals.gd` | Autoload `G`: Waffen, Perks, Preise, Rundenformeln, Tastenbelegung |
| `scenes/vorstadt.tscn` | Das Level «Vorstadt» – wird im Godot-Editor gebaut (siehe «Ein Level im Editor bauen») |
| `scripts/level.gd` | Liest Karte und Objekte aus der Level-Szene, baut Kacheln, Kollision, Wegfindung; Vorschau im Editor |
| `scripts/level_object.gd` | Editor-Knoten im Level: Tür, Wandkauf, Perk, Shop, Box, Kiste, Startpunkt … |
| `art/karte.tres`, `art/karte.png` | Tileset zum Malen der Level-Karte (Wand, Fenster, Hecke, Bodenarten, Spawn) |
| `scripts/game.gd` | Runden, Spawns, Punkte, Power-ups, Shop, Quest |
| `scripts/player.gd`, `scripts/zombie.gd` | Spieler und Zombie (`scenes/player.tscn`, Zombie-Arten in `scenes/zombies/`) |
| `scripts/figur_vorschau.gd` | Figur (Knoten `Body`): zeigt Spieler/Zombie auch im Editor an |
| `scripts/interactable.gd` | Wandkauf, Shop, Box, Werkbank, Strom, Funkgerät, Perks |
| `scripts/hud.gd` | Anzeige und Menüs im Level |
| `scripts/save.gd` | Autoload `Save`: 3 Speicherplätze (Schrott, Rekorde, Startwaffen, Aufträge, Ziele), Einstellungen |
| `scripts/main_menu.gd` | Startbildschirm: Spielstand wählen, benennen, löschen |
| `scripts/hub_data.gd` | Werte für Schrott, Startwaffen-Preise, Aufträge und Navi-Ziele |
| `scripts/fade.gd` | Autoload `Fade`: Überblenden zwischen Dorf und Level |
| `scenes/village.tscn` | Das Dorf – wird im Godot-Editor gebaut (siehe «Das Dorf im Editor bauen») |
| `scripts/village.gd`, `scripts/village_player.gd` | Liest das Dorf aus der Szene, Spielfigur im Dorf |
| `scripts/village_spot.gd`, `village_tag.gd`, `zombie_zone.gd` | Editor-Knoten im Dorf: Ort zum Benutzen, Namensschild, Zombie-Bereich |
| `scenes/props/` | Objekt-Bibliothek: jedes Pack-Objekt als Szene zum Hineinziehen |
| `scripts/village_ui.gd`, `scripts/navi_map.gd` | Fenster im Dorf: Haus, Shop, Auftragsbrett, Navi, Einstellungen |
| `art/asset_pack/` | Das Asset-Pack – alle Grafiken des Spiels (nur lokal, nicht auf GitHub, siehe «Grafik») |
| `art/kacheln.tres` | TileSet mit allen Tile-Sheets aus `art/asset_pack/Tiles` (Boden, Dächer, Mauern …) |
| `scripts/pack.gd` | Lädt Pack-Grafiken; setzt im Speicher zusammen, was das Spiel umgebaut braucht |
| `scripts/sheet_anims.gd` | Macht aus den Figuren-Animationen von `pack.gd` SpriteFrames |
| `tests/smoke_test.tscn` | Automatischer Durchlauf aller Systeme |

## Das Dorf im Editor bauen

`scenes/village.tscn` im Godot-Editor öffnen. Alles, was man dort sieht, ist auch so im Spiel.

- **Boden malen:** Knoten `Boden` wählen, unten öffnet sich das TileMap-Fenster. Das Tileset
  `art/kacheln.tres` enthält jedes Tile-Sheet aus `art/asset_pack/Tiles` (Liste links: Hintergrund
  grün/dunkelgrün/gelb, Dächer, Gebäude, Mauern, Zäune …).
  - *Tiles:* eine Kachel anklicken und malen. Mehrere Kacheln markieren und den Würfel
    (Zufall) einschalten, dann werden sie gemischt – gut für Gras und Pflaster.
  - *Terrains:* «Gras», «Pflaster» oder «Asphalt» wählen und malen; Varianten werden zufällig
    gemischt.
- **Randsteine und andere Auflagen:** Knoten `Kanten` (liegt über `Boden`, gleiches Tileset).
  Die Randsteine um den Platz sind Gras-Kacheln mit durchsichtigem Rand aus «Hintergrund grün»
  (rechts oben im Sheet, der Ring um das leere Feld) – das Pflaster darunter liegt auf `Boden`.
  Passendes Stück anklicken und an den Rand des Platzes setzen.
- **Objekte hinstellen:** im Dateisystem-Fenster `scenes/props/` öffnen (Ordner `dorf`, `natur`,
  `strasse`, `fahrzeuge`, `container`, `gebaeude`, `barrikaden`, `aufsammeln`). Zuerst den Knoten
  `Objekte` in der Szene wählen, dann die Szene in die Ansicht ziehen. Der Punkt des Objekts ist
  sein Fuss – nach ihm wird sortiert, wer vor wem steht. Ctrl+D kopiert ein Objekt.
  Objekte unter `Objekte` (oder in Untergruppen wie `Randbaeume`) gehören nach y sortiert.
- **Festen Bereich anpassen:** Jedes Objekt hat einen Kasten `Solid/Shape`, durch den man nicht
  läuft. Wirkt er falsch, die Szene in `scenes/props/` öffnen und den Kasten anpassen – das gilt
  dann für alle Exemplare. Objekte ohne Kasten (Blumen, Gras) sind begehbar.
- **Orte zum Benutzen** (`Orte`): gelber Kreis = wie nah man mit E herankommen muss. Im Inspektor
  stehen Art (`house`, `shop`, `board`, `car`), Reichweite und Hinweistext.
- **Namensschilder** (`Schilder`), **Startpunkte** (`Start`, `StartNachPartie`) und die
  **Zombie-Bereiche** hinter dem Zaun (`Zombies`, rotes Rechteck) einfach verschieben.
- **Unsichtbare Wände** (`Grenzen`): die blauen Kästen; damit läuft man nicht in den Wald oder
  auf die Strasse neben dem Wagen.
- **Mehr Objekte:** jedes Bild aus `art/asset_pack/` lässt sich auch direkt in die Ansicht ziehen
  (wird ein Sprite2D). Für ein Objekt mit Fusspunkt und festem Bereich eine ähnliche Szene in
  `scenes/props/` duplizieren (Rechtsklick → Duplizieren) und das Bild austauschen.
- **Haus, Laden, Auftragsbrett, Händler** (`scenes/props/dorf/`) sind aus Pack-Teilen gebaut:
  Mauern und Dach als Kachel-Ebene `Mauern_und_Dach`, Fenster, Türen, Automaten als einzelne Bilder.
  Szene öffnen, umbauen – das gilt für alle Exemplare.

## Ein Level im Editor bauen

`scenes/vorstadt.tscn` im Godot-Editor öffnen. Man sieht das Level so, wie es im Spiel aussieht.
Die Szene hat zwei Teile unter `Level`:

- **`Karte` malen** (TileMapLayer mit `art/karte.tres`): Knoten wählen, unten im TileMap-Fenster
  eine Kachel anklicken und malen. Die Kacheln sind Kartentypen, nicht fertige Grafik:

  | Kachel | Bedeutung |
  |---|---|
  | Wand (Backstein) | Mauer; Mauerkrone und Vorderseite setzt das Spiel selbst passend zusammen |
  | Fenster | Zombie-Eingang mit Barrikade. Direkt dahinter (aussen) gehört ein Zombie-Spawn |
  | Hecke / Wald | nicht begehbar, Bäume kommen von selbst dazu. Unbemalte Felder sind auch Hecke |
  | Holzboden, Fliesen, Asphalt, Gras, Erde | begehbarer Boden |
  | Landeplatz (gelbes H) | Ziel der Flucht; die Markierung wird mittig über alle Felder gelegt |
  | Zombie-Spawn (roter Kopf) | hier tauchen Zombies auf; aktiv, sobald der Bereich am Fenster offen ist |
  | Waldboden | begehbare Lücke in der Hecke |

  Über der Karte zeigt der Editor eine Vorschau mit der echten Grafik; sie wird beim Malen sofort
  neu gezeichnet. Spawns sind darin rot umrahmt. Wer die gemalten Kartentypen selbst sehen will,
  wählt den Knoten `Level` und setzt im Inspektor **Karte zeigen**. Die Karte beginnt oben links
  bei (0, 0); malt nicht in negative Koordinaten.
- **`Objekte` hinstellen** (LevelObject-Knoten, nach Gruppen sortiert: Türen, Wandkäufe,
  Automaten, Quest, Hindernisse): ein vorhandenes Objekt wählen, Ctrl+D, verschieben. Im Inspektor
  bestimmt **Art**, was es ist; darunter erscheinen nur die passenden Felder:
  - *Tür:* Name, Preis, Grösse in Kacheln (ab der Kachel des Punkts nach rechts/unten),
    «bei Flucht offen» (geht auf, wenn der Helikopter kommt). Unter eine Tür gehört Boden.
  - *Wandkauf:* Waffe. Gehört auf eine Wand-Kachel und ist nur von unten erreichbar.
  - *Perk:* welcher Automat. *Kiste, Fass, Mülltonne, Baum:* Bild-Variante.
  - *Startpunkt, Shop, Mystery-Box, Werkbank, Stromschalter, Funkgerät, Funkteil (3 Stück),
    Glückspilz (3 Stück).*

  Massgebend ist immer die Kachel, auf der der Punkt liegt; der Editor zeichnet das Objekt
  eingerastet so, wie es im Spiel steht. Die Quest braucht Strom, Funkgerät, 3 Funkteile und einen
  Landeplatz.
- **Neues Level:** `vorstadt.tscn` im Dateisystem duplizieren, umbauen und in
  `scripts/hub_data.gd` beim Ziel unter `scene` eintragen (z. B. `res://scenes/tankstelle.tscn`).

## Zombie-Arten

Jede Art ist eine Szene in `scenes/zombies/`: `zombie.tscn` (normal, Basis), `zombie_renner.tscn`,
`zombie_panzer.tscn`. Renner und Panzer sind **geerbte Szenen** – sie übernehmen alles von
`zombie.tscn` und ändern nur ihre Werte. Eine Änderung an der Basis gilt für alle Arten.

- **Werte** (Wurzel-Knoten, Inspektor): Leben-Faktor, Tempo, Schaden, Ausholzeit, Zeit pro Brett,
  Kill-Bonus, Ankündigung beim ersten Auftauchen, Auftrags-Ereignis.
- **Spawn** (gleiche Stelle): ab Runde, Anteil am Anfang, pro Runde mehr, höchstens.
- **Figur:** Knoten `Body`, Feld «Gruppe» (`zombie_small`, `zombie_axe`, `zombie_big`).
- **Körper / Trefferzone:** Knoten `Shape` und `Hurtbox/HurtShape` – direkt im Editor ziehen.
- **Neue Art:** Rechtsklick auf `scenes/zombies/zombie.tscn` → «Neue geerbte Szene», Werte setzen,
  in `scenes/zombies/` speichern und in `scripts/game.gd` in `ZOMBIE_ARTEN` eintragen. Die Arten
  werden in dieser Reihenfolge ausgewürfelt, der letzte Eintrag (normaler Zombie) nimmt den Rest.

## Anpassen

- **Level:** wird im Godot-Editor gebaut, siehe «Ein Level im Editor bauen».
- **Balance:** Werte in `scripts/globals.gd` (Schaden, Preise, Zombies pro Runde).
- **Dorf:** wird im Godot-Editor gebaut, siehe unten. Schrott-Formel, Preise der Startwaffen,
  Aufträge und Navi-Ziele in `scripts/hub_data.gd`. Ein neues Level wird dort als Ziel eingetragen
  (`scene` = Szene des Levels, `unlock` = Bedingung zum Freischalten).
- **Grafik:** Alle Grafiken kommen direkt aus dem Asset-Pack in `art/asset_pack/` (dazu gehören
  auch die Blutflecken in `Enemies/Blood/`). Der Pack ist **nicht auf GitHub** (er darf nicht
  öffentlich verteilt werden): Wer das Projekt klont, legt seine Kopie des Packs nach
  `art/asset_pack/`. Auf GitHub liegen davon nur die `.import`-Dateien, damit alle dieselben
  Godot-IDs haben. Szenen zeigen direkt auf Pack-Dateien; was umgebaut werden muss, setzt
  `scripts/pack.gd` beim Start im Speicher zusammen (Boden- und Wand-Atlas der Level, eingefärbte
  Waffen und Automaten, 3× vergrösserte Oberfläche, Figuren-Streifen) – welche Pack-Datei wofür
  benutzt wird, steht dort. Kacheln sind 16×16. Figuren laufen in 4 Richtungen; normale Zombies
  sind `Zombie_Small`, Renner der Axt-Zombie. Wofür der Pack kein eigenes Bild hat, steht ein
  ähnliches Pack-Bild: Stromschalter = Metalltür, Funkteil = Antenne, Glückspilze (Easter Egg) =
  Pilz, Sofort-Kill = Schläger, Doppelte Punkte = Chipstüte, Bombe = rotes Fass, Perk-Symbol =
  Dose. Nur Landeplatz-Markierung und die kleinen Dorf-Symbole (Totenkopf, Schloss, Zahnrad)
  zeichnet `pack.gd` selbst.

## Test

Der Test benutzt eigene Spielstände (`user://test_save_N.json`), die echten bleiben unberührt.

```
godot --headless --path . res://tests/smoke_test.tscn
```
