@tool
class_name UiStil
extends RefCounted
## Oberflaechen-Stil aus den Pack-Grafiken (Panels, Knoepfe). Statische Funktionen, damit sie
## auch im Editor laufen (G ist ein Autoload und existiert dort nicht).
## theme() fasst alles als Theme zusammen: an einen Wurzel-Knoten gehaengt, bekommen alle
## Knoepfe und PanelContainer darunter den Pack-Stil.

const UI_INK := Color("#2c1d35")         # dunkler Text auf den hellen Knoepfen
const UI_INK_OFF := Color("#4f4452")


static func tex_style(ui_name: String, margin: float, content := -1.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Pack.tex("ui/" + ui_name)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(margin if content < 0.0 else content)
	return sb


## Grosses Panel (Shop, Pause, Ende, Punkte) im Stil des Pack-Inventars
static func pack_panel() -> StyleBoxTexture:
	return tex_style("panel", 18.0, 20.0)


static func button_box(ui_name: String, bottom: float, pressed := false) -> StyleBoxTexture:
	var sb := tex_style(ui_name, 15.0)
	sb.texture_margin_bottom = bottom
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0 if pressed else 6.0
	sb.content_margin_bottom = 8.0 if pressed else 14.0
	return sb


## Theme mit Pack-Knoepfen und Pack-Panel (fuer ganze Menues)
static func theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", button_box("button", 18.0))
	t.set_stylebox("hover", "Button", button_box("button_hover", 18.0))
	t.set_stylebox("pressed", "Button", button_box("button_pressed", 12.0, true))
	var off := button_box("button", 18.0)
	off.modulate_color = Color(0.8, 0.76, 0.76)
	t.set_stylebox("disabled", "Button", off)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", UI_INK)
	t.set_color("font_disabled_color", "Button", UI_INK_OFF)
	t.set_stylebox("panel", "PanelContainer", pack_panel())
	return t
