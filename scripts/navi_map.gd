class_name NaviMap
extends Control
## Karte im Navigationsgeraet: Dorf, Strassen und die Ziele als Punkte.
## Ein Klick auf einen Punkt waehlt das Ziel (Signal picked).

signal picked(dest_id: String)

const GRASS := Color("#4e7058")
const GRASS_DARK := Color("#3f5c48")
const WATER := Color("#466c8c")
const ROAD := Color("#c4bcaa")
const INK := Color("#18141c")
const ORANGE := Color("#e88040")
const CREAM := Color("#ece2c8")
const LOCKED := Color("#6e6876")
const LOCK_TEX := preload("res://art/pack/ui/lock.png")

var selected := ""


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _point(id: String) -> Vector2:
	var p: Vector2 = HubData.NAVI_HOME if id == "dorf" else HubData.DESTINATIONS[id]["pos"]
	return p * size


## Strassen laufen rechtwinklig: erst waagrecht, dann senkrecht.
func _route(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, Vector2(b.x, a.y), b])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GRASS)
	for blob in [Vector2(0.14, 0.12), Vector2(0.66, 0.14), Vector2(0.9, 0.28), Vector2(0.26, 0.56), Vector2(0.62, 0.9)]:
		draw_circle(blob * size, 22.0, GRASS_DARK)
		draw_circle(blob * size + Vector2(18, 6), 16.0, GRASS_DARK)
	var water := PackedVector2Array()
	for p in [Vector2(0, 0.72), Vector2(0.16, 0.68), Vector2(0.28, 0.78), Vector2(0.4, 0.86), Vector2(0.42, 1), Vector2(0, 1)]:
		water.append(p * size)
	draw_colored_polygon(water, WATER)

	for r: Array in HubData.NAVI_ROADS:
		var line := _route(_point(r[0]), _point(r[1]))
		draw_polyline(line, INK, 9.0)
		draw_polyline(line, ROAD, 5.0)
	if selected != "":
		var line := _route(_point("dorf"), _point(selected))
		for i in line.size() - 1:
			draw_dashed_line(line[i], line[i + 1], ORANGE, 3.0, 8.0)

	# Dorf: kleines Haus
	var h := _point("dorf")
	draw_rect(Rect2(h + Vector2(-11, -6), Vector2(22, 16)), INK)
	draw_rect(Rect2(h + Vector2(-9, -4), Vector2(18, 12)), CREAM)
	draw_colored_polygon(PackedVector2Array([h + Vector2(-15, -5), h + Vector2(0, -19), h + Vector2(15, -5)]), INK)
	draw_colored_polygon(PackedVector2Array([h + Vector2(-10, -7), h + Vector2(0, -16), h + Vector2(10, -7)]), Color("#b4463c"))
	_name("Dorf", h + Vector2(0, 28), CREAM)

	for id: String in HubData.DESTINATIONS:
		var p := _point(id)
		var open := Save.dest_unlocked(id)
		if id == selected:
			draw_arc(p, 19.0, 0.0, TAU, 32, ORANGE, 2.0)
		draw_circle(p, 12.0, INK)
		if not open:
			draw_circle(p, 10.0, LOCKED)
			draw_texture(LOCK_TEX, p - LOCK_TEX.get_size() * 0.5)
		elif id == selected:
			draw_circle(p, 10.0, ORANGE)
			draw_circle(p, 4.0, CREAM)
		else:
			draw_circle(p, 10.0, CREAM)
		_name(HubData.DESTINATIONS[id]["name"], p + Vector2(0, 34), CREAM if open else Color("#beb8c4"))


func _name(text: String, pos: Vector2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var fs := 16
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := pos - Vector2(w * 0.5, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id: String in HubData.DESTINATIONS:
			if event.position.distance_to(_point(id)) < 26.0:
				picked.emit(id)
				accept_event()
				return


func select(dest_id: String) -> void:
	selected = dest_id
	queue_redraw()
