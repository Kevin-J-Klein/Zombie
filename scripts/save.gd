extends Node
## Autoload "Save": Spielstand, der ueber mehrere Partien bestehen bleibt.
## Es gibt SLOTS Speicherplaetze (user://save_1.json ...). Jeder enthaelt Name, Schrott, Rekorde,
## gekaufte Startwaffen, Auftraege und freigeschaltete Ziele. Gespeichert wird automatisch bei jeder
## Aenderung, nach jeder Runde, am Ende einer Partie und beim Schliessen des Spiels.
## Die Einstellungen (Lautstaerke, Vollbild) gelten fuer alle Plaetze: user://settings.json.
## Alle anderen Skripte fragen nur hier nach.

signal changed                      ## irgendetwas am Spielstand hat sich geaendert
signal contract_done(def: Dictionary)   ## ein aktiver Auftrag wurde gerade erfuellt

const SLOTS := 3
const OLD_PATH := "user://save.json"          # Spielstand aus der Zeit vor den Speicherplaetzen
const SETTINGS_PATH := "user://settings.json"

var slot := 1                       # gewaehlter Speicherplatz (1 bis SLOTS)
var active := false                 # erst nach der Wahl eines Platzes wird gespeichert
var slot_prefix := "user://save_"   # Tests benutzen eigene Dateien
var test_mode := false
var path := ""
var data := {}
var settings := {"volume": 0.8, "fullscreen": false, "last_slot": 1}

## Nur fuer die laufende Sitzung
var current_dest := HubData.START_DEST    # im Navi gewaehltes Ziel
var back_from_run := false                # Dorf: Spieler steht nach einer Partie beim Wagen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_migrate_old_save()
	slot = clampi(int(settings["last_slot"]), 1, SLOTS)
	path = slot_path(slot)
	load_file()
	apply_settings()


## Beim Schliessen des Fensters noch einmal speichern.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		write()


# ------------------------------------------------------------------ Speicherplaetze

func slot_path(n: int) -> String:
	return "%s%d.json" % [slot_prefix, n]


func default_name(n: int) -> String:
	return "Spielstand %d" % n


func _read_slot(n: int) -> Dictionary:
	var p := slot_path(n)
	if not FileAccess.file_exists(p):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return parsed if parsed is Dictionary else {}


## Kurzinfo fuer den Startbildschirm, ohne den Platz zu laden.
func slot_info(n: int) -> Dictionary:
	var d := _read_slot(n)
	if d.is_empty():
		return {"exists": false, "name": ""}
	return {"exists": true, "name": str(d.get("name", default_name(n))), "scrap": int(d.get("scrap", 0)),
		"best_round": int(d.get("best_round", 0)), "games": int(d.get("games", 0)),
		"played_at": str(d.get("played_at", ""))}


## Platz waehlen (und anlegen, falls er leer ist). Ab jetzt wird dorthin gespeichert.
func select_slot(n: int, slot_name := "") -> void:
	slot = clampi(n, 1, SLOTS)
	path = slot_path(slot)
	var is_new := not FileAccess.file_exists(path)
	current_dest = HubData.START_DEST
	back_from_run = false
	load_file()
	slot_name = slot_name.strip_edges()
	if slot_name != "":
		data["name"] = slot_name
	elif str(data["name"]) == "":
		data["name"] = default_name(slot)
	if is_new:
		data["created"] = Time.get_datetime_string_from_system(false, true)
	active = true
	if int(settings["last_slot"]) != slot:
		settings["last_slot"] = slot
		_save_settings()
	write()
	changed.emit()


func rename_slot(n: int, slot_name: String) -> void:
	slot_name = slot_name.strip_edges()
	if slot_name == "":
		slot_name = default_name(n)
	if n == slot and active:
		data["name"] = slot_name
		write()
		changed.emit()
		return
	var d := _read_slot(n)
	if d.is_empty() or d.get("name", "") == slot_name:
		return
	d["name"] = slot_name
	var f := FileAccess.open(slot_path(n), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "\t"))


func delete_slot(n: int) -> void:
	if FileAccess.file_exists(slot_path(n)):
		DirAccess.remove_absolute(slot_path(n))
	if n == slot:
		active = false
		load_file()


## Wird eine Szene direkt gestartet (Editor, Tests), ohne dass ein Platz gewaehlt wurde,
## gilt der zuletzt benutzte Platz.
func ensure_active() -> void:
	if not active:
		select_slot(slot)


## Den alten einzelnen Spielstand (save.json) auf Platz 1 uebernehmen.
func _migrate_old_save() -> void:
	if not FileAccess.file_exists(OLD_PATH):
		return
	for n in range(1, SLOTS + 1):
		if FileAccess.file_exists(slot_path(n)):
			return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OLD_PATH))
	if parsed is Dictionary and parsed.get("settings") is Dictionary:
		_merge(settings, parsed["settings"])
		_save_settings()
	DirAccess.rename_absolute(OLD_PATH, slot_path(1))


# ------------------------------------------------------------------ Laden / Speichern

func _defaults() -> Dictionary:
	return {
		"version": 1,
		"name": "", "created": "", "played_at": "",
		"scrap": 0, "scrap_total": 0, "games": 0,
		"best_round": 0, "most_kills": 0, "fastest_escape": 0.0,
		"eggs": {"gnomes": false, "escape": false},
		"weapons": ["pistol"], "start_weapon": "pistol", "character": "player",
		"dest": {},
		"contracts": [], "board_news": true,
	}


func load_file() -> void:
	data = _defaults()
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_merge(data, parsed)
	data.erase("settings")   # stand frueher im Spielstand, gilt jetzt fuer alle Plaetze
	# JSON kennt nur Kommazahlen: Zaehler wieder zu ganzen Zahlen machen
	for key in ["scrap", "scrap_total", "games", "best_round", "most_kills"]:
		data[key] = int(data[key])
	var kept: Array = []
	for c: Dictionary in data["contracts"]:
		if HubData.CONTRACTS.has(c.get("id", "")):
			c["progress"] = int(c.get("progress", 0))
			kept.append(c)
	data["contracts"] = kept
	if not HubData.START_WEAPONS.has(data["start_weapon"]) or not data["weapons"].has(data["start_weapon"]):
		data["start_weapon"] = "pistol"
	if not HubData.CHARACTERS.has(data["character"]):
		data["character"] = "player"
	_fill_offers()


func _merge(into: Dictionary, from: Dictionary) -> void:
	for key: String in from:
		if into.has(key) and into[key] is Dictionary and from[key] is Dictionary:
			_merge(into[key], from[key])
		else:
			into[key] = from[key]


func write() -> void:
	if not active:
		return
	data["played_at"] = Time.get_datetime_string_from_system(false, true)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Spielstand konnte nicht gespeichert werden: %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))


## Fuer Tests: eigene, leere Speicherplaetze (user://test_save_N.json), damit die echten
## Spielstaende und Einstellungen nicht veraendert werden.
func use_test_file() -> void:
	test_mode = true
	slot_prefix = "user://test_save_"
	for n in range(1, SLOTS + 1):
		if FileAccess.file_exists(slot_path(n)):
			DirAccess.remove_absolute(slot_path(n))
	select_slot(1)


# ------------------------------------------------------------------ Schrott und Startwaffen

func scrap() -> int:
	return data["scrap"]


func add_scrap(n: int) -> void:
	data["scrap"] += n
	data["scrap_total"] += n
	changed.emit()


func owns(weapon_id: String) -> bool:
	return data["weapons"].has(weapon_id)


func buy_weapon(weapon_id: String) -> bool:
	var cost: int = HubData.START_WEAPONS[weapon_id]
	if owns(weapon_id) or data["scrap"] < cost:
		return false
	data["scrap"] -= cost
	data["weapons"].append(weapon_id)
	write()
	changed.emit()
	return true


## Gewaehlter Charakter (Schluessel in HubData.CHARACTERS)
func character() -> String:
	return data["character"]


func set_character(id: String) -> void:
	if HubData.CHARACTERS.has(id) and data["character"] != id:
		data["character"] = id
		write()
		changed.emit()


func start_weapon() -> String:
	return data["start_weapon"]


func set_start_weapon(weapon_id: String) -> void:
	if owns(weapon_id):
		data["start_weapon"] = weapon_id
		write()
		changed.emit()


# ------------------------------------------------------------------ Ziele (Navi)

func dest_stats(dest_id: String) -> Dictionary:
	var d: Dictionary = data["dest"].get(dest_id, {})
	return {"best_round": int(d.get("best_round", 0)), "escapes": int(d.get("escapes", 0))}


func dest_unlocked(dest_id: String) -> bool:
	var u: Dictionary = HubData.DESTINATIONS[dest_id]["unlock"]
	if u.is_empty():
		return true
	var s := dest_stats(u["dest"])
	if u.has("escapes"):
		return s["escapes"] >= int(u["escapes"])
	return s["best_round"] >= int(u["round"])


## Kann man dorthin fahren? (freigeschaltet und das Level gibt es schon)
func dest_playable(dest_id: String) -> bool:
	return dest_unlocked(dest_id) and HubData.DESTINATIONS[dest_id]["scene"] != ""


# ------------------------------------------------------------------ Auftraege

func contracts() -> Array:
	return data["contracts"]


func active_count() -> int:
	var n := 0
	for c: Dictionary in data["contracts"]:
		if c["state"] == "active" or c["state"] == "done":
			n += 1
	return n


## Auftraege, die gerade laufen (fuer die Anzeige im Level)
func active_contracts() -> Array:
	var out: Array = []
	for c: Dictionary in data["contracts"]:
		if c["state"] == "active" or c["state"] == "done":
			out.append(c)
	return out


func has_claimable() -> bool:
	for c: Dictionary in data["contracts"]:
		if c["state"] == "done":
			return true
	return false


func _find(id: String) -> Dictionary:
	for c: Dictionary in data["contracts"]:
		if c["id"] == id:
			return c
	return {}


func accept_contract(id: String) -> bool:
	var c := _find(id)
	if c.is_empty() or c["state"] != "open" or active_count() >= HubData.MAX_ACTIVE_CONTRACTS:
		return false
	c["state"] = "active"
	c["progress"] = 0
	write()
	changed.emit()
	return true


## Abbrechen: der Auftrag bleibt bis zur naechsten Partie am Brett, der Fortschritt ist weg.
func cancel_contract(id: String) -> void:
	var c := _find(id)
	if c.is_empty() or c["state"] != "active":
		return
	c["state"] = "open"
	c["progress"] = 0
	c["swap"] = true
	write()
	changed.emit()


## Belohnung abholen. Gibt den Schrott zurueck (0 = nichts abzuholen).
func claim_contract(id: String) -> int:
	var c := _find(id)
	if c.is_empty() or c["state"] != "done":
		return 0
	var reward: int = HubData.CONTRACTS[id]["reward"]
	data["contracts"].erase(c)
	data["scrap"] += reward
	data["scrap_total"] += reward
	write()
	changed.emit()
	return reward


## Fuellt das Brett wieder auf CONTRACT_OFFERS Auftraege auf (zufaellig, keine doppelten).
func _fill_offers() -> void:
	var list: Array = data["contracts"]
	var pool: Array = []
	for id: String in HubData.CONTRACTS:
		if _find(id).is_empty():
			pool.append(id)
	pool.shuffle()
	var added := false
	while list.size() < HubData.CONTRACT_OFFERS and not pool.is_empty():
		list.append({"id": pool.pop_back(), "state": "open", "progress": 0})
		added = true
	if added:
		data["board_news"] = true


## Nach einer Partie: abgebrochene Auftraege austauschen, leere Plaetze auffuellen.
func _refresh_offers() -> void:
	var list: Array = data["contracts"]
	for c: Dictionary in list.duplicate():
		if c.get("swap", false) and c["state"] == "open":
			list.erase(c)
	_fill_offers()


func board_seen() -> void:
	if data["board_news"]:
		data["board_news"] = false
		write()
		changed.emit()


## Zeigt das Auftragsbrett ein Ausrufezeichen? (neue Auftraege oder Belohnung abholbar)
func board_alert() -> bool:
	return data["board_news"] or has_claimable()


## Ereignis aus dem Level. kind siehe HubData.CONTRACTS. Zaehlende Auftraege bekommen
## amount dazu, bei "in einer Partie"-Auftraegen ist amount der erreichte Stand.
func contract_event(kind: String, amount := 1) -> void:
	for c: Dictionary in data["contracts"]:
		if c["state"] != "active":
			continue
		var def: Dictionary = HubData.CONTRACTS[c["id"]]
		if def["kind"] != kind:
			continue
		var target: int = def["target"]
		if def["run"]:
			c["progress"] = mini(target, maxi(c["progress"], amount))
		else:
			c["progress"] = mini(target, c["progress"] + amount)
		if c["progress"] >= target:
			c["state"] = "done"
			write()
			contract_done.emit(def)


# ------------------------------------------------------------------ Partie

## Beim Start einer Partie: "in einer Partie"-Auftraege beginnen wieder bei 0.
func begin_run() -> void:
	ensure_active()
	for c: Dictionary in data["contracts"]:
		if c["state"] == "active" and HubData.CONTRACTS[c["id"]]["run"]:
			c["progress"] = 0


## Partie vorzeitig verlassen: kein Schrott, gezaehlter Auftragsfortschritt bleibt.
func abort_run() -> void:
	back_from_run = true
	write()


## Ende einer Partie. result = G.last_result (won, round, kills, points, time), gnomes = alle Zwerge erwischt.
## Rechnet den Schrott aus, traegt Rekorde ein und gibt {"scrap": n, "records": [Texte]} zurueck.
func finish_run(result: Dictionary, gnomes: bool) -> Dictionary:
	var dest: Dictionary = HubData.DESTINATIONS[current_dest]
	var won: bool = result["won"]
	var round_num: int = result["round"]
	var kills: int = result["kills"]
	var base := round_num * HubData.SCRAP_PER_ROUND + kills * HubData.SCRAP_PER_KILL
	if won:
		base += HubData.SCRAP_ESCAPE_BONUS
	var earned := int(round(base * float(dest["bonus"])))

	var records: Array[String] = []
	if round_num > data["best_round"]:
		data["best_round"] = round_num
		records.append("Beste Runde")
	if kills > data["most_kills"]:
		data["most_kills"] = kills
		records.append("Meiste Kills")
	if won and (data["fastest_escape"] <= 0.0 or result["time"] < data["fastest_escape"]):
		data["fastest_escape"] = result["time"]
		records.append("Schnellste Flucht")

	var stats := dest_stats(current_dest)
	stats["best_round"] = maxi(stats["best_round"], round_num)
	if won:
		stats["escapes"] += 1
		data["eggs"]["escape"] = true
	data["dest"][current_dest] = stats
	if gnomes:
		data["eggs"]["gnomes"] = true

	data["games"] += 1
	data["scrap"] += earned
	data["scrap_total"] += earned
	_refresh_offers()
	back_from_run = true
	write()
	changed.emit()
	return {"scrap": earned, "records": records}


# ------------------------------------------------------------------ Einstellungen

func setting(key: String) -> Variant:
	return settings[key]


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	_save_settings()


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if parsed is Dictionary:
			_merge(settings, parsed)


func _save_settings() -> void:
	if test_mode:
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(settings, "\t"))


func apply_settings() -> void:
	var vol: float = settings["volume"]
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.0001)))
	AudioServer.set_bus_mute(0, vol <= 0.001)
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
