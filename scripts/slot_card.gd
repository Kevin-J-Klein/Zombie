class_name SlotCard
extends PanelContainer
## Karte eines Speicherplatzes im Startmenue (scenes/slot_card.tscn). Aussehen im Editor
## anpassen; main_menu.gd fuellt beim Start Name und Werte ein und blendet «Leer» oder die
## Werte ein. Was im Editor als Text steht, ist nur Platzhalter.

signal play_pressed(slot: int)
signal delete_pressed(slot: int)

var slot := 1
var exists := false

@onready var title_label: Label = %Platz
@onready var last_label: Label = %Zuletzt
@onready var name_edit: LineEdit = %Name
@onready var stats: VBoxContainer = %Werte
@onready var empty_label: Label = %Leer
@onready var play_button: Button = %Spielen
@onready var delete_button: Button = %Loeschen


func _ready() -> void:
	name_edit.text_submitted.connect(func(_t: String) -> void: play_pressed.emit(slot))
	name_edit.focus_exited.connect(func() -> void:
		if exists:
			Save.rename_slot(slot, name_edit.text))
	play_button.pressed.connect(func() -> void: play_pressed.emit(slot))
	delete_button.pressed.connect(func() -> void: delete_pressed.emit(slot))


## Zeigt Platz n mit den Daten aus Save.slot_info(n).
func show_slot(n: int, info: Dictionary, last_played: bool, delete_armed: bool) -> void:
	slot = n
	exists = info["exists"]
	title_label.text = "PLATZ %d" % n
	last_label.visible = exists and last_played
	name_edit.text = info["name"]
	stats.visible = exists
	empty_label.visible = not exists
	if exists:
		_set_stat("Schrott", HubData.num(info["scrap"]))
		_set_stat("BesteRunde", str(info["best_round"]) if info["best_round"] > 0 else "–")
		_set_stat("Partien", str(info["games"]))
		_set_stat("Datum", _date_text(info["played_at"]))
	play_button.text = "Spielen" if exists else "Neues Spiel"
	delete_button.visible = exists
	delete_button.text = "Wirklich löschen?" if delete_armed else "Löschen"


func _set_stat(row: String, value: String) -> void:
	(stats.get_node(row + "/Wert") as Label).text = value


## "2026-11-11 16:40:12" -> "11.11.2026 16:40"
static func _date_text(stamp: String) -> String:
	if stamp.length() < 16:
		return "–"
	return "%s.%s.%s %s" % [stamp.substr(8, 2), stamp.substr(5, 2), stamp.substr(0, 4), stamp.substr(11, 5)]
