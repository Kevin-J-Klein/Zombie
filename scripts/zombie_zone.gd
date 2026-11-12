@tool
class_name ZombieZone
extends Node2D
## Bereich, in dem Zombies als Kulisse hin und her schlurfen (z. B. hinter dem Dorfzaun).
## Linke obere Ecke = Position; im Editor zeigt das rote Rechteck den Bereich.

@export var width := 160.0:
	set(value):
		width = value
		queue_redraw()
@export var count := 3:
	set(value):
		count = value
		queue_redraw()
@export var row_gap := 24.0:                 ## Abstand der Reihen nach unten
	set(value):
		row_gap = value
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(0.0, -4.0, width, maxf(1.0, count - 1) * row_gap + 14.0)
	draw_rect(r, Color(0.9, 0.2, 0.2, 0.15))
	draw_rect(r, Color(0.9, 0.2, 0.2, 0.8), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(2.0, -6.0), "Zombies x%d" % count,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.4, 0.4))
