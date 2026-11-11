#!/usr/bin/env python3
"""Uebernimmt die Grafiken aus dem Asset-Pack (art/asset_pack) ins Spiel.

Aufruf:  python3 tools/import_asset_pack.py          (braucht Pillow:  pip3 install pillow)

Das Spiel liest nie direkt aus art/asset_pack, sondern nur aus art/pack/. Dieses Skript
schneidet, sortiert und kombiniert die Pack-Grafiken dafuer. Wird der Pack aktualisiert,
einfach erneut ausfuehren.

Erzeugt in art/pack/:
  tiles.png        Boden, gleiche Anordnung wie art/tiles.png (10 Typen x 4 Varianten)
  walls.png        Waende als Autotile. Spalte = Nachbarmaske (N=1, O=2, S=4, W=8),
                   Zeile 0 = Wand von oben, 1 = Wand mit Vorderseite, 2 = Fenster
  anims.json       Alle Animationen (Datei, Zellgroesse, Frames, Bildrate) fuer SheetAnims
  player/ zombie/  Animationen als Streifen mit gleich grossen Zellen, Fuesse unten mittig
  guns/            Waffen (mit Haenden) und Hotbar-Symbole, je Waffe eingefaerbt
  props/           Kisten, Faesser, Baeume, Automaten, Tueren ...
  ui/              HUD- und Menue-Grafiken, schon 3x vergroessert (fuer scharfe Pixel)
  village/         Das Dorf (Hauptmenue): Pflaster-Kacheln, Haus, Shop, Auftragsbrett, Wagen, Deko
"""
import colorsys
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
PACK = os.path.join(ROOT, "art", "asset_pack")
OUT = os.path.join(ROOT, "art", "pack")
T = 16
UI_SCALE = 3

ANIMS = {}  # wird zu anims.json


# ------------------------------------------------------------------ Hilfen

def load(rel):
    return Image.open(os.path.join(PACK, rel)).convert("RGBA")


def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    return rel


def crop_tile(img, tx, ty):
    return img.crop((tx * T, ty * T, tx * T + T, ty * T + T))


def frames_of(rel, n):
    """Teilt ein Pack-Sheet ('...-SheetN.png') in seine N gleich breiten Frames."""
    img = load(rel)
    w = img.width // n
    assert w * n == img.width, (rel, img.width, n)
    return [img.crop((i * w, 0, i * w + w, img.height)) for i in range(n)]


def bbox(img):
    return img.getchannel("A").getbbox()


def upscale(img, s=UI_SCALE):
    return img.resize((img.width * s, img.height * s), Image.NEAREST)


def anchor(frame):
    """Ankerpunkt einer Figur: Kopfmitte (x) und Fusslinie (y).
    Die Pack-Sheets sind unterschiedlich breit zugeschnitten; ueber die Kopfmitte
    stehen Laufen, Angriff und Tod trotzdem an derselben Stelle."""
    a = frame.getchannel("A")
    box = a.getbbox()
    top, bottom = box[1], box[3]
    xs = [x for y in range(top, min(top + 5, bottom)) for x in range(frame.width) if a.getpixel((x, y)) > 0]
    return sum(xs) / len(xs), bottom


def character(name, sheets, fps, loop):
    """sheets: anim -> (pack-datei, frames). Alle Animationen einer Figur bekommen
    dieselbe Zellgroesse; Kopfmitte liegt auf der Zellmitte, Fuesse auf der Unterkante."""
    placed = {}
    left = right = up = 0.0
    for anim, (rel, n) in sheets.items():
        fr = frames_of(rel, n)
        ax, ay = anchor(fr[0])
        placed[anim] = (fr, ax, ay)
        for f in fr:
            b = bbox(f)
            if b is None:
                continue
            left = max(left, ax - b[0])
            right = max(right, b[2] - ax)
            up = max(up, ay - b[1])
    half = int(max(left, right) + 1.5)
    cw, ch = half * 2, int(up + 1)
    cw += cw % 2
    ch += ch % 2
    for anim, (fr, ax, ay) in placed.items():
        strip = Image.new("RGBA", (cw * len(fr), ch), (0, 0, 0, 0))
        ox, oy = round(half - ax), ch - ay
        for i, f in enumerate(fr):
            strip.alpha_composite(f, (i * cw + ox, oy))
        rel = save(strip, "%s/%s.png" % (name, anim))
        kind = anim.split("_")[0]
        ANIMS.setdefault(name, {})[anim] = {
            "file": "res://art/pack/" + rel, "w": cw, "h": ch, "frames": len(fr),
            "fps": fps.get(kind, 8.0), "loop": loop.get(kind, True)}


def recolor(img, hue_from, hue_to, sat=1.0, val=1.0, hue_tol=0.09, min_sat=0.2, max_val=1.0):
    """Faerbt alle Pixel um, deren Farbton nahe hue_from liegt (z. B. Holz -> Oliv).
    max_val laesst helle Pixel aus (z. B. die Haut der Haende an den Waffen)."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            d = min(abs(h - hue_from), 1 - abs(h - hue_from))
            if d <= hue_tol and s >= min_sat and v <= max_val:
                nr, ng, nb = colorsys.hsv_to_rgb(hue_to % 1.0, min(1.0, s * sat), min(1.0, v * val))
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def hue_of(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return colorsys.rgb_to_hsv(r, g, b)


# ------------------------------------------------------------------ Boden

def floors():
    bg = load("Tiles/Background_Green_TileSet.png")
    dark = load("Tiles/Background_Dark-Green_TileSet.png")
    atlas = Image.new("RGBA", (10 * T, 4 * T), (0, 0, 0, 0))

    def put(col, var, img):
        atlas.alpha_composite(img, (col * T, var * T))

    def win(img, x, y):
        return img.crop((x, y, x + T, y + T))

    # 0 "." Holzboden: Bretter
    wood = [crop_tile(bg, 3, 11), crop_tile(bg, 4, 11), crop_tile(bg, 5, 11),
            crop_tile(bg, 4, 11).transpose(Image.FLIP_LEFT_RIGHT)]
    # 1 "," Fliesen (Markt): Pflasterplatten (sauberer Ausschnitt, gespiegelt)
    p = win(bg, 100, 5)
    cobble = [p, p.transpose(Image.FLIP_LEFT_RIGHT), p.transpose(Image.FLIP_TOP_BOTTOM), p.transpose(Image.ROTATE_180)]
    # 2 ":" Asphalt: saubere Ausschnitte ohne Markierungen
    asphalt = [crop_tile(bg, 5, 9), win(bg, 66, 117), win(bg, 66, 117).transpose(Image.FLIP_LEFT_RIGHT),
               crop_tile(bg, 5, 9).transpose(Image.FLIP_TOP_BOTTOM)]
    # 3 "~" Gras
    grass = [crop_tile(bg, 0, 0), crop_tile(bg, 2, 0), crop_tile(bg, 0, 2), crop_tile(bg, 2, 2)]
    # 4 ";" Erde: ein sauberer Ausschnitt, gedreht/gespiegelt
    d = win(bg, 278, 24)
    dirt = [d, d.transpose(Image.FLIP_LEFT_RIGHT), d.transpose(Image.FLIP_TOP_BOTTOM), d.transpose(Image.ROTATE_180)]
    # 8 Waldboden ohne Buesch: Zombie-Spawns und Luecken in der Hecke
    ground = [crop_tile(dark, 0, 0), crop_tile(dark, 2, 0), crop_tile(dark, 0, 2), crop_tile(dark, 2, 2)]
    # 7 " " Wald (nicht begehbar): dunkles Gras mit Buesch
    bush = load("Objects/Nature/Dark-Green/Bush_1_Dark-Green.png")
    grass3 = load("Objects/Nature/Dark-Green/Grass_3_Dark-Green.png")
    woods = []
    for i in range(4):
        t = crop_tile(dark, [0, 2, 0, 2][i], [0, 0, 2, 2][i]).copy()
        b = bush if i % 2 == 0 else bush.transpose(Image.FLIP_LEFT_RIGHT)
        if i == 3:
            t.alpha_composite(grass3, (0, T - grass3.height))
        else:
            t.alpha_composite(b, ((T - b.width) // 2, T - b.height - [1, 2, 0][i]))
        woods.append(t)

    for v in range(4):
        put(0, v, wood[v])
        put(1, v, cobble[v])
        put(2, v, asphalt[v])
        put(3, v, grass[v])
        put(4, v, dirt[v])
        put(7, v, woods[v])
        put(8, v, ground[v])
        put(9, v, asphalt[v])
    return atlas


# ------------------------------------------------------------------ Waende

def walls():
    """Waende aus dem Gebaeude-Tileset. Jede Kachel wird aus vier 8x8-Vierteln des
    Dachrahmens zusammengesetzt, je nachdem, wo Nachbarwaende anschliessen."""
    bld = load("Tiles/Buildings/Buildings_beige_TileSet.png")
    fx, fy = 5 * T, 0               # Dachrahmen: 4x3 Kacheln
    frame = bld.crop((fx, fy, fx + 4 * T, fy + 3 * T))
    facade = bld.crop((4 * T, 3 * T, 10 * T, 3 * T + 41))
    win_img = load("Objects/Windows/Window_1_broken_wood.png")

    def q(x, y):
        return frame.crop((x, y, x + 8, y + 8))

    # Viertel-Quellen im Rahmen (TL, TR, BL, BR)
    CORNER = {"TL": q(0, 0), "TR": q(56, 0), "BL": q(0, 40), "BR": q(56, 40)}
    HORIZ = {"TL": q(16, 0), "TR": q(24, 0), "BL": q(16, 40), "BR": q(24, 40)}      # Kante oben/unten
    VERT = {"TL": q(0, 16), "TR": q(56, 16), "BL": q(0, 24), "BR": q(56, 24)}       # Kante links/rechts
    FILL = {"TL": q(16, 16), "TR": q(24, 16), "BL": q(16, 24), "BR": q(24, 24)}

    def quarter(key, v_conn, h_conn):
        if v_conn and h_conn:
            return FILL[key]
        if h_conn:
            return HORIZ[key]
        if v_conn:
            return VERT[key]
        return CORNER[key]

    def top(mask):
        n, e, s, w = mask & 1, mask & 2, mask & 4, mask & 8
        t = Image.new("RGBA", (T, T))
        t.alpha_composite(quarter("TL", n, w), (0, 0))
        t.alpha_composite(quarter("TR", n, e), (8, 0))
        t.alpha_composite(quarter("BL", s, w), (0, 8))
        t.alpha_composite(quarter("BR", s, e), (8, 8))
        return t

    def front(mask):
        """Oben 6 px Mauerkrone, darunter die Fassade: Gesims, Mauer, Sockel."""
        e, w = mask & 2, mask & 8
        t = top(mask & ~4).crop((0, 0, T, 6))
        img = Image.new("RGBA", (T, T))
        img.alpha_composite(t, (0, 0))
        # Fassadenstreifen: links/rechts mit Kante, wenn dort keine Wand anschliesst
        rows = [9, 10, 11, 12, 13, 16, 17, 35, 36, 38]
        x_src = []
        for x in range(T):
            if x < 2 and not w:
                x_src.append(x)                       # linke Kante der Fassade
            elif x >= T - 2 and not e:
                x_src.append(facade.width - T + x)    # rechte Kante
            else:
                x_src.append(16 + x)                  # Mitte
        for y_out, y_src in enumerate(rows):
            for x_out, xs in enumerate(x_src):
                img.putpixel((x_out, 6 + y_out), facade.getpixel((xs, y_src)))
        return img

    atlas = Image.new("RGBA", (16 * T, 3 * T), (0, 0, 0, 0))
    for m in range(16):
        atlas.alpha_composite(top(m), (m * T, 0))
        f = front(m)
        atlas.alpha_composite(f, (m * T, T))
        wi = f.copy()
        wi.alpha_composite(win_img, ((T - win_img.width) // 2, T - win_img.height))
        atlas.alpha_composite(wi, (m * T, 2 * T))
    return atlas


# ------------------------------------------------------------------ Figuren

def characters():
    m = "Character/Main/"
    character("player", {
        "idle_down": (m + "Idle/Character_down_idle_no-hands-Sheet6.png", 6),
        "idle_up": (m + "Idle/Character_up_idle_no-hands-Sheet6.png", 6),
        "idle_side": (m + "Idle/Character_side_idle_no-hands-Sheet6.png", 6),
        "idle_left": (m + "Idle/Character_side-left_idle_no-hands-Sheet6.png", 6),
        "run_down": (m + "Run/Character_down_run_no-hands-Sheet6.png", 6),
        "run_up": (m + "Run/Character_up_run_no-hands-Sheet6.png", 6),
        "run_side": (m + "Run/Character_side_run_no-hands-Sheet6.png", 6),
        "run_left": (m + "Run/Character_side-left_run_no-hands-Sheet6.png", 6),
        "death_side": (m + "Death/Character_side_death1_NoHands-Sheet6.png", 6),
        "death_left": (m + "Death/Character_side-left_death1_NoHands-Sheet6.png", 6),
    }, fps={"idle": 6.0, "run": 11.0, "death": 9.0}, loop={"death": False})

    zombies = (("small", "Enemies/Zombie_Small/Zombie_Small_"), ("axe", "Enemies/Zombie_Axe/Zombie_Axe_"),
               ("big", "Enemies/Zombie_Big/Zombie_Big_"))
    # Bildrate des Angriffs passend zur Ausholzeit im Spiel (0.3 s, Panzer 0.55 s)
    attack_fps = {"small": 14.0, "axe": 22.0, "big": 15.0}
    for kind, base in zombies:
        sheets = {}
        for f in sorted(os.listdir(os.path.join(PACK, os.path.dirname(base)))):
            if not f.endswith(".png") or "-Sheet" not in f:
                continue
            parts = f[len(os.path.basename(base)):-4].split("_")   # z. B. Side-left, First-Attack-Sheet4
            d = {"Down": "down", "Up": "up", "Side": "side", "Side-left": "left"}[parts[0]]
            what, n = parts[1].rsplit("-Sheet", 1)
            anim = {"walk": "walk", "Walk": "walk", "Idle": "idle", "First-Attack": "attack",
                    "First-Death": "death"}.get(what)
            if anim:
                sheets["%s_%s" % (anim, d)] = (os.path.dirname(base) + "/" + f, int(n))
        character("zombie_" + kind, sheets,
                  fps={"walk": 9.0, "idle": 6.0, "attack": attack_fps[kind], "death": 10.0},
                  loop={"attack": False, "death": False})

    # Treffer-Spritzer der Zombies
    for i in (1, 2):
        fr = frames_of("Enemies/Shot/shot_%d-Sheet3.png" % i, 3)
        w, h = fr[0].size
        strip = Image.new("RGBA", (w * 3, h))
        for j, f in enumerate(fr):
            strip.alpha_composite(f, (j * w, 0))
        rel = save(strip, "fx/shot_%d.png" % i)
        ANIMS.setdefault("fx", {})["shot_%d" % i] = {"file": "res://art/pack/" + rel, "w": w, "h": h,
                                                    "frames": 3, "fps": 18.0, "loop": False}


# ------------------------------------------------------------------ Waffen

WOOD_HUE = 0.0  # das Holz der Pack-Waffen ist rot-braun

# Spiel-Waffe -> (Pack-Waffe, Einfaerbung des Holzes)
WEAPONS = {
    "pistol": ("Pistol", None),
    "shotgun": ("Shotgun", None),
    "rifle": ("Gun", None),
    "smg": ("Gun", ("#4a4a58", 0.4, 0.8)),    # schwarzer Schaft
    "dmr": ("Gun", ("#c8a060", 1.0, 1.35)),   # heller Holzschaft
    "lmg": ("Gun", ("#6a7a3a", 1.0, 1.1)),    # oliv
    "raygun": ("Gun", ("#40e0a0", 1.4, 1.6)),  # leuchtend gruen
}


def guns():
    meta = {}
    for wid, (src, tint) in WEAPONS.items():
        g = frames_of("Character/Guns/%s/%s_side_idle-and-run-Sheet6.png" % (src, src), 6)[0]
        icon = load("UI/Inventory/Objects/Icon_%s.png" % src)
        if tint:
            h, s, v = hue_of(tint[0])
            g = recolor(g, WOOD_HUE, h, tint[1], tint[2], max_val=0.62)
            icon = recolor(icon, WOOD_HUE, h, tint[1], tint[2], max_val=0.62)
        save(g, "guns/gun_%s.png" % wid)
        save(icon, "guns/icon_%s.png" % wid)
        meta[wid] = {"texture": "res://art/pack/guns/gun_%s.png" % wid,
                     "icon": "res://art/pack/guns/icon_%s.png" % wid}
    # Griff (Drehpunkt in der Hand), Muendung und Grundwinkel je Pack-Waffe.
    # Die Pistole wird im Pack leicht schraeg nach oben gehalten -> Winkel ausgleichen.
    holds = {"Pistol": {"grip": [2, 6], "muzzle": [8, 2], "angle": 12.0},
             "Gun": {"grip": [6, 7], "muzzle": [16, 3], "angle": 0.0},
             "Shotgun": {"grip": [5, 6], "muzzle": [15, 2], "angle": 0.0}}
    for wid, (src, _) in WEAPONS.items():
        meta[wid].update(holds[src])
        meta[wid]["bullet"] = {"Pistol": "pistol", "Gun": "gun", "Shotgun": "shotgun"}[src]
    ANIMS["weapons"] = meta
    fire = frames_of("Character/Guns/Fire/Fire_side-Sheet3.png", 3)[0]
    save(fire, "guns/muzzle.png")


# ------------------------------------------------------------------ Objekte

def props():
    o = "Objects/"
    copies = {
        "crate_0.png": o + "Cardboard_1.png",
        "crate_1.png": o + "Cardboard_2.png",
        "crate_2.png": o + "Pallet_1.png",
        "barrel_0.png": o + "Barrel_rust_red_1.png",
        "barrel_1.png": o + "Barrel_blue_1.png",
        "barrel_2.png": o + "Barrel_rust_blue_1.png",
        "container_0.png": o + "Garbage-Bin_4.png",
        "container_1.png": o + "Trash-can_1.png",
        "tree_0.png": o + "Nature/Green/Tree_3_Normal_Green.png",
        "tree_1.png": o + "Nature/Green/Tree_10_Small-oak_Green.png",
        "woods_tree_0.png": o + "Nature/Dark-Green/Tree_1_Spruce_Dark-Green.png",
        "woods_tree_1.png": o + "Nature/Dark-Green/Tree_3_Normal_Dark-Green.png",
        "woods_tree_2.png": o + "Nature/Dark-Green/Tree_8_Birch_Dark-Green.png",
        "woods_tree_3.png": o + "Nature/Dark-Green/Tree_2_Spruce-Sparse_Dark-Green.png",
        "box.png": "UI/Inventory/Objects/Icon_Bullet-crate_Green.png",
        "upgrade.png": o + "Washing-machine.png",
        "radio.png": o + "Buildings/Antenna_1.png",
        "door_h.png": o + "Buildable/Wooden/Wooden-wall_Gate_Horizontal.png",
        "door_v.png": o + "Buildable/Wooden/Wooden-wall_Vertical.png",
        "pu_max_ammo.png": o + "Pickable/Ammo-crate_Green.png",
    }
    for dst, src in copies.items():
        save(load(src), "props/" + dst)
    # Shop: blauer Automat, grau umgefaerbt (damit er nicht wie der blaue Perk aussieht)
    save(recolor(load(o + "Vending-machine_Blue.png"), 0.62, 0.62, 0.12, 1.35, hue_tol=0.12, min_sat=0.1),
         "props/shop.png")
    save(helipad(), "props/helipad.png")
    # Perk-Automaten: roter Automat, rote Flaechen in die Perk-Farbe umgefaerbt
    vend = load(o + "Vending-machine_Red.png")
    perk_colors = {"revive": "#4aa8e0", "health": "#e0483a", "fire": "#e0a030",
                   "reload": "#4ec06a", "stamina": "#e0d040"}
    for perk, col in perk_colors.items():
        h, s, v = hue_of(col)
        save(recolor(vend, 0.98, h, 1.0, 1.05, hue_tol=0.06, min_sat=0.25), "props/perk_%s.png" % perk)


def helipad(cells=5):
    """Landeplatz-Markierung in der Farbe der Strassenmarkierungen des Packs:
    gestrichelter Rahmen und ein grosses H."""
    size = cells * T
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    paint, shade = (196, 195, 188, 255), (163, 164, 166, 255)

    def rect(x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                img.putpixel((x, y), c)

    m, dash = 4, 6
    for i in range(m, size - m, dash * 2):
        e = min(i + dash, size - m)
        rect(i, m, e, m + 2, paint)
        rect(i, size - m - 2, e, size - m, paint)
        rect(m, i, m + 2, e, paint)
        rect(size - m - 2, i, size - m, e, paint)
    c, hw, hh = size // 2, 12, 16
    rect(c - hw, c - hh, c - hw + 4, c + hh, paint)
    rect(c + hw - 4, c - hh, c + hw, c + hh, paint)
    rect(c - hw + 4, c - 2, c + hw - 4, c + 2, paint)
    for x0, x1 in ((c - hw, c - hw + 4), (c + hw - 4, c + hw)):
        rect(x0, c + hh, x1, c + hh + 1, shade)
    rect(c - hw + 4, c + 2, c + hw - 4, c + 3, shade)
    return img


# ------------------------------------------------------------------ Oberflaeche

def bar_under(frame):
    """Rahmen einer Leiste mit dunkel gefuellter Rinne (alles Transparente, das vom
    Bildrand aus nicht erreichbar ist). Wird unter die Fuellung gelegt."""
    out = frame.copy()
    w, h = out.size
    outside = set()
    todo = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while todo:
        x, y = todo.pop()
        if (x, y) in outside or not (0 <= x < w and 0 <= y < h) or out.getpixel((x, y))[3] > 0:
            continue
        outside.add((x, y))
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    for y in range(h):
        for x in range(w):
            if out.getpixel((x, y))[3] == 0 and (x, y) not in outside:
                out.putpixel((x, y), (44, 29, 53, 255))
    return out


def ui():
    u = "UI/"
    big = {
        "panel.png": u + "Inventory/Inventory_1.png",
        "cell.png": u + "Inventory/Inventory-Cell.png",
        "cell_chosen.png": u + "Inventory/Inventory-Chosen.png",
        "button.png": u + "Menu/Main Menu/Blank_Not-Pressed.png",
        "button_pressed.png": u + "Menu/Main Menu/Blank_Pressed.png",
        "hp_fill.png": u + "HP/HP.png",
        "bullet_pistol.png": u + "Bullet Indicators/Small/Pistol-Bullet_Small.png",
        "bullet_gun.png": u + "Bullet Indicators/Small/Gun-Bullet_Small.png",
        "bullet_shotgun.png": u + "Bullet Indicators/Small/Shotgun-Bullet_Small.png",
        "cursor.png": u + "Menu/Cursor.png",
    }
    for dst, src in big.items():
        save(upscale(load(src)), "ui/" + dst)
    # Leisten: Rahmen oben drueber, darunter dunkle Rinne, dazwischen die Fuellung
    hp = load(u + "HP/HP-Bar.png")
    save(upscale(hp), "ui/hp_over.png")
    save(upscale(bar_under(hp)), "ui/hp_under.png")
    # Panzerung: gleiche Leiste mit blauem Herz und blauer Fuellung
    armor = recolor(hp, 0.97, 0.58, 1.0, 1.1, hue_tol=0.08, min_sat=0.15)
    save(upscale(armor), "ui/armor_over.png")
    save(upscale(bar_under(armor)), "ui/armor_under.png")
    save(upscale(recolor(load(u + "HP/HP.png"), 0.97, 0.58, 1.0, 1.1, hue_tol=0.08)), "ui/armor_fill.png")
    # Ausdauer: Hunger-Leiste, Fuellung gruen
    st = load(u + "Hunger/Hunger-Bar.png")
    save(upscale(st), "ui/stamina_over.png")
    save(upscale(bar_under(st)), "ui/stamina_under.png")
    save(upscale(recolor(load(u + "Hunger/Hunger.png"), 0.03, 0.33, 1.6, 1.25, hue_tol=0.12, min_sat=0.1)),
         "ui/stamina_fill.png")
    # Hover-Zustand der Knoepfe: etwas heller
    b = load(u + "Menu/Main Menu/Blank_Not-Pressed.png")
    px = b.load()
    for y in range(b.height):
        for x in range(b.width):
            r, g, bb, a = px[x, y]
            px[x, y] = (min(255, r + 18), min(255, g + 18), min(255, bb + 14), a)
    save(upscale(b), "ui/button_hover.png")


# ------------------------------------------------------------------ Dorf (Hauptmenue)

def _paste(dst, src, x, y):
    dst.alpha_composite(src, (x, y))


def _facade(dst, color, x, y, w):
    """Hausfront: 3 Kachelreihen aus dem Gebaeude-Tileset, w Kacheln breit."""
    sheet = load("Tiles/Buildings/Buildings_%s_TileSet.png" % color)
    for j, row in enumerate((3, 4, 5)):
        for i in range(w):
            cx = 4 if i == 0 else (9 if i == w - 1 else (5, 6, 8)[i % 3])
            _paste(dst, crop_tile(sheet, cx, row), x + i * T, y + j * T)


def village_house():
    """Wohnhaus: rotes Ziegeldach (5 Reihen), weisse Front, Tuer und zwei Fenster."""
    w, roof_rows = 7, (0, 1, 2, 3, 4)
    img = Image.new("RGBA", (w * T, 8 * T), (0, 0, 0, 0))
    roof = load("Tiles/Roof_TileSet.png")
    for j, ry in enumerate(roof_rows):
        for i in range(w):
            cx = 8 + (0 if i == 0 else (2 if i == w - 1 else 1))
            _paste(img, crop_tile(roof, cx, ry), i * T, j * T)
    _facade(img, "white", 0, 5 * T, w)
    b = "Objects/Buildings/"
    _paste(img, load("Objects/Windows/Window_3_wood.png"), 14, 97)
    _paste(img, load("Objects/Windows/Window_4_wood.png"), 84, 97)
    _paste(img, load(b + "Door_1_Beige.png"), 48, 97)
    _paste(img, load(b + "Air-vent_1.png"), 80, 14)
    return img


def village_shop():
    """Laden: Flachdach, beige Front, Markise, Eingang und zwei Automaten."""
    w = 9
    img = Image.new("RGBA", (w * T, 6 * T + 2), (0, 0, 0, 0))
    sheet = load("Tiles/Buildings/Buildings_beige_TileSet.png")
    for j in range(3):
        for i in range(w):
            cx = 5 if i == 0 else (8 if i == w - 1 else 6)
            _paste(img, crop_tile(sheet, cx, j), i * T, j * T)
    _facade(img, "beige", 0, 3 * T, w)
    b = "Objects/Buildings/"
    _paste(img, load(b + "HVAC.png"), 16, 10)
    _paste(img, load(b + "Antenna_1.png"), 100, 4)
    _paste(img, load("Objects/Windows/Window_15_Beige.png"), 14, 66)
    _paste(img, load("Objects/Windows/Window_16_Beige.png"), 116, 66)
    _paste(img, load(b + "Enterance_Green.png"), 57, 69)
    _paste(img, load(b + "Awning_orange_3.png"), 40, 50)
    _paste(img, load("Objects/Vending-machine_Blue.png"), 30, 74)
    _paste(img, load("Objects/Vending-machine_Red.png"), 98, 74)
    return img


def village_board():
    """Auftragsbrett: im Pack gibt es keines, daher in den Pack-Farben gezeichnet."""
    img = Image.new("RGBA", (32, 34), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    dark, wood, wood2 = (42, 31, 45, 255), (128, 84, 64, 255), (96, 60, 48, 255)
    paper, paper2 = (240, 230, 200, 255), (214, 200, 170, 255)
    x, y = 2, 1
    for px in (x + 3, x + 24):
        d.rectangle([px - 1, y + 8, px + 2, y + 32], fill=dark)
        d.rectangle([px, y + 9, px + 1, y + 31], fill=wood2)
    d.rectangle([x - 2, y - 1, x + 29, y + 3], fill=dark)
    d.rectangle([x - 1, y, x + 28, y + 2], fill=(150, 60, 56, 255))
    d.rectangle([x, y + 4, x + 27, y + 22], fill=dark)
    d.rectangle([x + 1, y + 5, x + 26, y + 21], fill=wood)
    d.line([x + 1, y + 13, x + 26, y + 13], fill=wood2)
    for nx, ny, col in [(x + 3, y + 6, paper), (x + 11, y + 7, paper2), (x + 19, y + 6, paper),
                        (x + 6, y + 14, paper2), (x + 15, y + 14, paper)]:
        d.rectangle([nx, ny, nx + 5, ny + 5], fill=col)
        d.point((nx + 2, ny), fill=(200, 60, 50, 255))
        d.line([nx + 1, ny + 2, nx + 4, ny + 2], fill=(150, 140, 120, 255))
        d.line([nx + 1, ny + 4, nx + 3, ny + 4], fill=(150, 140, 120, 255))
    return img


def village_tiles():
    """Kacheln nur fuers Dorf (Gras und Asphalt kommen aus tiles.png):
    Zeile 0: Pflaster (4 Varianten), Asphalt mit Mittelstrich, 3x Gras mit Blumen/Bueschel
    Zeile 1: Randsteine um den Platz: NW, N, NO, W, O, SW, S, SO (auf Pflaster gelegt)"""
    bg = load("Tiles/Background_Green_TileSet.png")
    atlas = Image.new("RGBA", (8 * T, 2 * T), (0, 0, 0, 0))
    p = bg.crop((100, 5, 100 + T, 5 + T))   # sauberes Pflaster (wie die Fliesen im Level), gespiegelt fuer 4 Varianten
    paving = [p, p.transpose(Image.FLIP_LEFT_RIGHT), p.transpose(Image.FLIP_TOP_BOTTOM), p.transpose(Image.ROTATE_180)]
    for i, t in enumerate(paving):
        _paste(atlas, t, i * T, 0)
    road = crop_tile(bg, 5, 9).copy()
    ImageDraw.Draw(road).rectangle([2, 7, 13, 8], fill=(196, 190, 170, 255))
    _paste(atlas, road, 4 * T, 0)
    for i, c in enumerate([(3, 1), (4, 1), (5, 1)]):
        _paste(atlas, crop_tile(bg, *c), (5 + i) * T, 0)
    ring = [(11, 0), (12, 0), (13, 0), (11, 1), (13, 1), (11, 2), (12, 2), (13, 2)]
    for i, c in enumerate(ring):
        t = paving[0].copy()
        t.alpha_composite(crop_tile(bg, *c))
        _paste(atlas, t, i * T, T)
    return atlas


def village_trader():
    """Haendler: die Spielfigur (steht, Blick nach unten) mit Helm aus dem Pack."""
    body = frames_of("Character/Main/Idle/Character_down_idle-Sheet6.png", 6)
    helm = frames_of("Character/Helmet/Helmet_Up-and-Down_Idle-and-Run-Sheet6.png", 6)
    cw, ch = 14, 20
    strip = Image.new("RGBA", (cw * 6, ch), (0, 0, 0, 0))
    for i in range(6):
        _paste(strip, body[i], i * cw, ch - body[i].height)
        _paste(strip, helm[i], i * cw + 1, ch - body[i].height - 3)
    rel = save(strip, "village/trader_idle.png")
    ANIMS["trader"] = {"idle_down": {"file": "res://art/pack/" + rel, "w": cw, "h": ch, "frames": 6,
                                     "fps": 6.0, "loop": True}}


def _icon(draw_fn, size):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(img))
    return upscale(img)


def village_icons():
    """Kleine Symbole fuer die Dorf-Menues (3x vergroessert wie der Rest der Oberflaeche)."""
    save(upscale(load("Objects/Metal-Plates.png")), "ui/scrap.png")
    ink, bone, off, steel = (42, 31, 45, 255), (236, 226, 200, 255), (104, 96, 110, 255), (170, 165, 175, 255)

    def skull(col):
        def fn(d):
            d.rectangle([1, 0, 5, 0], fill=col)
            d.rectangle([0, 1, 6, 4], fill=col)
            d.rectangle([1, 5, 5, 6], fill=col)
            for p in [(2, 2), (4, 2), (2, 3), (4, 3), (3, 6)]:
                d.point(p, fill=ink)
        return fn

    def lock(d):
        d.rectangle([1, 0, 5, 3], fill=ink)
        d.rectangle([2, 1, 4, 3], fill=(0, 0, 0, 0))
        d.rectangle([0, 3, 6, 8], fill=ink)
        d.rectangle([1, 4, 5, 7], fill=steel)
        d.rectangle([3, 5, 3, 6], fill=ink)

    def gear(d):
        d.ellipse([2, 2, 10, 10], fill=bone)
        for x, y in [(6, 0), (6, 11), (0, 6), (11, 6), (1, 1), (10, 1), (1, 10), (10, 10)]:
            d.rectangle([x, y, x + 1, y + 1], fill=bone)
        d.rectangle([1, 5, 11, 6], fill=bone)
        d.rectangle([5, 1, 6, 11], fill=bone)
        d.ellipse([4, 4, 7, 7], fill=ink)

    save(_icon(skull(bone), (7, 7)), "ui/skull.png")
    save(_icon(skull(off), (7, 7)), "ui/skull_off.png")
    save(_icon(lock, (7, 9)), "ui/lock.png")
    save(_icon(gear, (13, 13)), "ui/gear.png")


def village():
    o = "Objects/"
    n = o + "Nature/Green/"
    f = o + "Nature/Flowers_Mashrooms_Other-nature-stuff/"
    w = o + "Buildable/Reinforced/Reinforced_wooden-wall_"
    save(village_tiles(), "village/tiles.png")
    save(village_house(), "village/house.png")
    save(village_shop(), "village/shop.png")
    save(village_board(), "village/board.png")
    village_trader()
    village_icons()
    copies = {
        "car.png": o + "Vehicles/Normal/Car_4/Car_4_Yellow.png",
        "fence.png": w + "Horizontal.png",
        "fence_post.png": w + "Vertical_For-gate.png",
        "lamp.png": o + "Street-Light_3_Down.png",
        "bench.png": o + "Bench_1_down.png",
        "bin.png": o + "Garbage-Bin_1.png",
        "pallet.png": o + "Pallet_1.png",
        "barrel.png": o + "Barrel_rust_blue_1.png",
        "barrel_red.png": o + "Barrel_red_1.png",
        "tire.png": o + "Tire_1.png",
        "cone.png": o + "Traffic-cone.png",
        "ammo_crate.png": o + "Pickable/Ammo-crate_Green.png",
        "bush_0.png": n + "Bush_1_Green.png",
        "bush_1.png": n + "Bush_2_Green.png",
        "tree_0.png": n + "Tree_5_Big_Green.png",
        "tree_1.png": n + "Tree_3_Normal_Green.png",
        "tree_2.png": n + "Tree_1_Spruce_Green.png",
        "tree_3.png": n + "Tree_6_Pine_Big_Green.png",
        "tree_4.png": n + "Tree_7_Birch_Green.png",
        "tree_5.png": n + "Tree_9_Small-oak_Green.png",
        "flowers_0.png": f + "Flowers_1_red.png",
        "flowers_1.png": f + "Flowers_2_yellow.png",
        "flowers_2.png": f + "Flowers_3_purple.png",
        "stump.png": f + "Stump_1.png",
    }
    for dst, src in copies.items():
        save(load(src), "village/" + dst)


def main():
    os.makedirs(OUT, exist_ok=True)
    save(floors(), "tiles.png")
    save(walls(), "walls.png")
    characters()
    guns()
    props()
    ui()
    village()
    with open(os.path.join(OUT, "anims.json"), "w") as f:
        json.dump(ANIMS, f, indent=1, sort_keys=True)
    print("Fertig: %d Animationen/Eintraege in art/pack/anims.json" % sum(len(v) for v in ANIMS.values()))


if __name__ == "__main__":
    main()
