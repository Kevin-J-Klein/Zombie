extends CanvasLayer
## Autoload "Fade": Szenenwechsel mit kurzem Ueberblenden (Dorf <-> Level).
## Optional wird kurz ein Titel eingeblendet, z. B. der Name des Ziels.

const VILLAGE := "res://scenes/village.tscn"
const TITLE := "res://scenes/main_menu.tscn"

var busy := false
var rect: ColorRect
var label: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.color = Color(0.05, 0.03, 0.06, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", G.UI_TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	add_child(label)


func to_village() -> void:
	go(VILLAGE)


func go(scene_path: String, title := "") -> void:
	if busy:
		return
	busy = true
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 1.0, 0.3)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
	if title != "":
		label.text = title
		tw = create_tween()
		tw.tween_property(label, "modulate:a", 1.0, 0.25)
		tw.tween_interval(0.9)
		tw.tween_property(label, "modulate:a", 0.0, 0.25)
		await tw.finished
	else:
		await get_tree().process_frame
		await get_tree().process_frame
	tw = create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.35)
	await tw.finished
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
