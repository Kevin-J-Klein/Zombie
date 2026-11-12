@tool
extends Control
## Startbildschirm: einen von drei Speicherplaetzen waehlen (und benennen), dann geht es ins Dorf.
## Das Dorf ist das eigentliche Hauptmenue.
##
## Aufgebaut im Editor (scenes/main_menu.tscn): Hintergrund, Zombie-Reihe (Deko-Figuren),
## Titel, die drei Karten (scenes/slot_card.tscn) und der Beenden-Knopf. Dieses Skript fuellt
## nur die Karten mit den Spielstaenden. Den Pack-Stil der Knoepfe und Panels setzt es als
## Theme - im Editor als Vorschau (wird vor dem Speichern entfernt).

var slots_box: HBoxContainer
var cards: Array[SlotCard] = []
var name_edits := {}        # Platz -> LineEdit
var delete_armed := 0       # Platz, bei dem "Loeschen" schon einmal gedrueckt wurde


func _ready() -> void:
	theme = UiStil.theme()
	if Engine.is_editor_hint():
		return
	get_tree().paused = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	slots_box = %Plaetze
	for c in slots_box.get_children():
		if c is SlotCard:
			cards.append(c)
			c.play_pressed.connect(_play)
			c.delete_pressed.connect(_delete)
	%Beenden.pressed.connect(get_tree().quit)
	_rebuild()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		theme = null
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		theme = UiStil.theme()


func _rebuild() -> void:
	name_edits.clear()
	for i in cards.size():
		var n := i + 1
		var card := cards[i]
		card.visible = n <= Save.SLOTS
		if n > Save.SLOTS:
			continue
		var info := Save.slot_info(n)
		card.show_slot(n, info, int(Save.setting("last_slot")) == n, delete_armed == n)
		name_edits[n] = card.name_edit


func _play(n: int) -> void:
	if Fade.busy:
		return
	var edit: LineEdit = name_edits[n]
	Save.select_slot(n, edit.text)
	Fade.to_village()


## Loeschen fragt einmal nach: erst der zweite Klick loescht.
func _delete(n: int) -> void:
	if delete_armed != n:
		delete_armed = n
	else:
		delete_armed = 0
		Save.delete_slot(n)
	_rebuild()
