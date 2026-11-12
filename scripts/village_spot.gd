@tool
class_name VillageSpot
extends Node2D
## Ein Ort im Dorf, den man mit E benutzt (Haus, Haendler, Auftragsbrett, Wagen).
## Im Editor einfach verschieben; der gelbe Kreis zeigt, wie nah man herankommen muss.
## kind bestimmt, welches Fenster aufgeht (siehe village_ui.gd).

@export_enum("house", "shop", "board", "car") var kind := "house":
	set(value):
		kind = value
		queue_redraw()
@export var reach := 20.0:
	set(value):
		reach = value
		queue_redraw()
@export var prompt := "[E]  Benutzen"


func as_dict() -> Dictionary:
	return {"kind": kind, "pos": global_position, "reach": reach, "prompt": prompt}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Color(1.0, 0.8, 0.2)
	draw_circle(Vector2.ZERO, reach, Color(c, 0.15))
	draw_arc(Vector2.ZERO, reach, 0.0, TAU, 40, c, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-reach, -reach - 2.0), "E: " + kind,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
