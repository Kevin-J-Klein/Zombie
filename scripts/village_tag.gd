@tool
class_name VillageTag
extends Node2D
## Namensschild, das im Spiel ueber einem Ort schwebt (die Unterkante sitzt hier).
## alert = zeigt ein "!", wenn es am Auftragsbrett etwas Neues gibt.

@export var text := "Name":
	set(value):
		text = value
		queue_redraw()
@export var alert := false:
	set(value):
		alert = value
		queue_redraw()


func as_dict() -> Dictionary:
	return {"text": text, "pos": global_position, "alert": alert}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var font := ThemeDB.fallback_font
	var label := text + ("  !" if alert else "")
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_rect(Rect2(-w * 0.5 - 3.0, -11.0, w + 6.0, 11.0), Color(0.12, 0.08, 0.14, 0.8))
	draw_string(font, Vector2(-w * 0.5, -3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
