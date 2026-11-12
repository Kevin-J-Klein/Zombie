#!/usr/bin/env python3
"""Erzeugt die Grafiken der Spielfiguren, die nicht direkt im Asset-Pack stecken.

    python3 tools/make_character_art.py        (im Projektordner ausfuehren)

- art/characters/<skin>/   Spielfigur umgefaerbt (gleiche Dateinamen und Raster wie im Pack,
                           damit alle Animationen des Players passen)
- art/characters/bulldog/  Lamars Bulldoggen Tank und Biscuit (Seitenansicht, nach rechts)
- art/weapons/             Uzi (in der Hand und als Hotbar-Symbol)

Danach Godot einmal oeffnen (oder --import), damit die neuen PNGs importiert werden.
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "art", "asset_pack", "Character", "Main")
OUT = os.path.join(ROOT, "art")

# Farben der Pack-Figur
HAIR_L = (112, 79, 72)
HAIR_D = (69, 44, 52)
SKIN = (230, 194, 176)
SKIN_S = (186, 134, 143)
JACKET = (64, 67, 81)
ZIP = (114, 133, 145)
PANTS = (67, 115, 91)
PANTS_L = (158, 175, 173)
OUTLINE = (44, 29, 53)

# Gleiche Sheets wie PLAYER_SHEETS in scripts/pack.gd
SHEETS = [
    ("Idle", "Character_down_idle_no-hands-Sheet6.png", "down"),
    ("Idle", "Character_up_idle_no-hands-Sheet6.png", "up"),
    ("Idle", "Character_side_idle_no-hands-Sheet6.png", "side"),
    ("Idle", "Character_side-left_idle_no-hands-Sheet6.png", "left"),
    ("Run", "Character_down_run_no-hands-Sheet6.png", "down"),
    ("Run", "Character_up_run_no-hands-Sheet6.png", "up"),
    ("Run", "Character_side_run_no-hands-Sheet6.png", "side"),
    ("Run", "Character_side-left_run_no-hands-Sheet6.png", "left"),
    ("Death", "Character_side_death1_NoHands-Sheet6.png", "dead_side"),
    ("Death", "Character_side-left_death1_NoHands-Sheet6.png", "dead_left"),
]

# Figuren: Farbtausch + Extras. Die Haende an den Waffen faerbt pack.gd (SKINS) gleich um.
SKINS = {
    "lamar": {
        "colors": {HAIR_L: (58, 42, 36), HAIR_D: (36, 26, 26), SKIN: (190, 128, 86), SKIN_S: (140, 88, 60),
                   JACKET: (236, 233, 224), ZIP: (47, 138, 78), PANTS: (58, 58, 62), PANTS_L: (96, 96, 104)},
        "bandana": ((47, 138, 78), (28, 92, 52)),
    },
}


def frames_of(img, n):
    w = img.width // n
    return [img.crop((i * w, 0, (i + 1) * w, img.height)) for i in range(n)]


def skin_frame(f, skin, facing):
    o = f.copy()
    px = o.load()
    w, h = o.size
    hair = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] and px[x, y][:3] in (HAIR_L, HAIR_D)]
    skin_rows = [y for y in range(h) for x in range(w) if px[x, y][3] and px[x, y][:3] == SKIN]
    band = []
    if skin.get("bandana") and hair and not facing.startswith("dead"):
        top = min(y for _, y in hair)
        band = [min(skin_rows) - 2, min(skin_rows) - 1] if skin_rows else [top + 2, top + 3]
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if not p[3]:
                continue
            c = p[:3]
            if band and c in (HAIR_L, HAIR_D) and y in band:
                g, gd = skin["bandana"]
                px[x, y] = (g if y == band[0] and (c == HAIR_L or facing == "up") else gd) + (255,)
            elif c in skin["colors"]:
                px[x, y] = skin["colors"][c] + (255,)
    if band:
        g, gd = skin["bandana"]
        hx = [x for x, y in hair if y in band]
        if facing in ("side", "left"):
            kx, tail = (min(hx) - 1, -1) if facing == "side" else (max(hx) + 1, 1)
            if 0 <= kx < w:
                px[kx, band[0]] = g + (255,)
                px[kx, band[1]] = gd + (255,)
                if 0 <= kx + tail < w and band[1] + 1 < h and px[kx + tail, band[1] + 1][3] == 0:
                    px[kx + tail, band[1] + 1] = gd + (255,)
        elif facing == "up":
            px[(min(hx) + max(hx)) // 2, band[1] + 1] = gd + (255,)
    return o


def make_skin(name, skin):
    d = os.path.join(OUT, "characters", name)
    os.makedirs(d, exist_ok=True)
    for folder, fn, facing in SHEETS:
        img = Image.open(os.path.join(PACK, folder, fn)).convert("RGBA")
        fr = [skin_frame(f, skin, facing) for f in frames_of(img, 6)]
        out = Image.new("RGBA", img.size, (0, 0, 0, 0))
        for i, f in enumerate(fr):
            out.paste(f, (i * f.width, 0))
        out.save(os.path.join(d, fn))


# ------------------------------------------------------------------ Bulldoggen

# 15x10, nach rechts. o Umriss, F Fell, S Schatten, E Ohr/Flecken, W Brust, C Halsband, K Auge/Nase, T Zahn
DOG_HEAD = [
    "........o...o..",
    ".......oEo.oEo.",
    "......oFFFFFFFo",
    ".ooooCFFFFFKFFo",
    "oFEFFCFFSSSSSKo",
    "oFFFFCWFSoooSSo",
    "oSFFFWWWSSTSTo.",
    ".oSSSWWWSoooo..",
]
DOG_BITE_HEAD = [
    "........o...o..",
    ".......oEo.oEo.",
    "......oFFFFFFFo",
    ".ooooCFFFFFKFFo",
    "oFEFFCFFSSSSSKo",
    "oFFFFCWFSoT.T..",
    "oSFFFWWWSo.....",
    ".oSSSWWWSoTTTo.",
]
DOG_LEGS = {
    "stand": [".oSo..oSSo.....", ".oo...ooo......"],
    "run1": ["oSo....oSSo....", "oo......ooo...."],
    "run2": ["..oSo.oSSo.....", "..oo..ooo......"],
    "run3": [".oSo..oSSo.....", ".oo...ooo......"],
    "run4": ["...oSooSSo.....", "...ooooo......."],
}
DOGS = {
    "tank": {"F": (201, 162, 122), "S": (168, 130, 90), "E": (122, 90, 58)},
    "biscuit": {"F": (232, 226, 214), "S": (200, 190, 175), "E": (138, 106, 74)},
}
DOG_FIXED = {"o": OUTLINE, "W": (242, 239, 230), "C": (47, 138, 78), "K": (26, 27, 29), "T": (242, 239, 230)}


def dog_frame(colors, head, legs, bob=0):
    rows = head + DOG_LEGS[legs]
    img = Image.new("RGBA", (15, 11), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            c = colors.get(ch) or DOG_FIXED[ch]
            yy = y + 1 - bob
            if 0 <= yy < 11:
                px[x, yy] = c + (255,)
    return img


def strip(frames):
    out = Image.new("RGBA", (frames[0].width * len(frames), frames[0].height), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * f.width, 0))
    return out


def make_dogs():
    d = os.path.join(OUT, "characters", "bulldog")
    os.makedirs(d, exist_ok=True)
    for name, colors in DOGS.items():
        strip([dog_frame(colors, DOG_HEAD, "stand"), dog_frame(colors, DOG_HEAD, "stand", 1)]).save(
            os.path.join(d, "%s_idle-Sheet2.png" % name))
        strip([dog_frame(colors, DOG_HEAD, "run%d" % i, 1 if i % 2 == 0 else 0) for i in range(1, 5)]).save(
            os.path.join(d, "%s_run-Sheet4.png" % name))
        strip([dog_frame(colors, DOG_HEAD, "stand"), dog_frame(colors, DOG_BITE_HEAD, "stand"),
               dog_frame(colors, DOG_BITE_HEAD, "stand")]).save(os.path.join(d, "%s_bite-Sheet3.png" % name))


# ------------------------------------------------------------------ Uzi

# 14x9, nach rechts. b Umriss, a dunkles Metall, g Metall, c hell, l Glanz, h/i Hand (Pack-Hautfarben)
UZI_HELD = [
    "..............",
    "...bbbbbbbb...",
    "bb.bacccccab.bb",
    "babbggggggggaab",
    ".bbbaaaaaaabbb.",
    "...bhhbaab.....",
    "...bhibaab.....",
    "....bbbaab.....",
    ".......bb......",
]
UZI_COLORS = {"b": OUTLINE, "a": (71, 64, 89), "g": (94, 93, 107), "c": (120, 118, 133), "l": (163, 164, 166),
              "h": SKIN, "i": SKIN_S}


def make_uzi():
    d = os.path.join(OUT, "weapons")
    os.makedirs(d, exist_ok=True)
    w = max(len(r) for r in UZI_HELD)
    held = Image.new("RGBA", (w, len(UZI_HELD)), (0, 0, 0, 0))
    icon = Image.new("RGBA", (w, len(UZI_HELD)), (0, 0, 0, 0))
    for y, row in enumerate(UZI_HELD):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            held.putpixel((x, y), UZI_COLORS[ch] + (255,))
            # Symbol ohne Hand, mit Glanz oben
            ic = {"h": "a", "i": "a", "c": "l"}.get(ch, ch)
            icon.putpixel((x, y), UZI_COLORS[ic] + (255,))
    held.save(os.path.join(d, "uzi_side.png"))
    icon.save(os.path.join(d, "icon_uzi.png"))


if __name__ == "__main__":
    for n, s in SKINS.items():
        make_skin(n, s)
    make_dogs()
    make_uzi()
    print("fertig")
