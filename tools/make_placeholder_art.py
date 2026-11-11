#!/usr/bin/env python3
"""Erzeugt alle Platzhalter-Grafiken fuer das Zombie-Spiel (reines Python, keine Abhaengigkeiten).

Aufruf:  python3 tools/make_placeholder_art.py
Die PNGs landen in art/. Echte Grafiken koennen spaeter einfach unter demselben
Dateinamen abgelegt werden - der Code muss dafuer nicht angepasst werden.
"""
import os, random, struct, zlib

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
os.makedirs(OUT, exist_ok=True)
T = (0, 0, 0, 0)


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def write_png(name, px):
    h, w = len(px), len(px[0])
    raw = b"".join(b"\x00" + bytes(c for p in row for c in p) for row in px)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(data)


def blank(w, h, c=T):
    return [[c for _ in range(w)] for _ in range(h)]


def ascii_sprite(name, rows, pal):
    w = max(len(r) for r in rows)
    px = []
    for r in rows:
        assert len(r) == w, (name, r, len(r), w)
        px.append([T if ch == "." else hexc(pal[ch]) for ch in r])
    write_png(name, px)


def shade(c, d):
    return (max(0, min(255, c[0] + d)), max(0, min(255, c[1] + d)), max(0, min(255, c[2] + d)), c[3])


def rect(px, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= y < len(px) and 0 <= x < len(px[0]):
                px[y][x] = c


def frame(px, x0, y0, x1, y1, c):
    for x in range(x0, x1 + 1):
        px[y0][x] = c
        px[y1][x] = c
    for y in range(y0, y1 + 1):
        px[y][x0] = c
        px[y][x1] = c


def disc(px, cx, cy, r, c):
    for y in range(len(px)):
        for x in range(len(px[0])):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                px[y][x] = c


# ---------------------------------------------------------------- Tiles
TS = 16
TILE_TYPES = ["wood", "kitchen", "asphalt", "grass", "dirt", "wall_top", "wall_front", "hedge", "window", "helipad"]
VARIANTS = 4


def tile(kind, rnd):
    px = blank(TS, TS)
    for y in range(TS):
        for x in range(TS):
            n = rnd.randint(-5, 5)
            if kind == "wood":
                c = shade(hexc("#c9a57a"), n)
                if y % 4 == 3:
                    c = hexc("#a2805a")
                elif (x + (y // 4) * 5) % 11 == 0:
                    c = hexc("#b08e66")
            elif kind == "kitchen":
                light = ((x // 8) + (y // 8)) % 2 == 0
                c = shade(hexc("#d3dac8") if light else hexc("#bcc7b3"), n // 2)
                if x % 8 == 7 or y % 8 == 7:
                    c = hexc("#a3ad9c")
            elif kind == "asphalt":
                c = shade(hexc("#6d6972"), n)
                if rnd.random() < 0.02:
                    c = hexc("#55515a")
            elif kind == "grass":
                c = shade(hexc("#5f8f3e"), n)
                r = rnd.random()
                if r < 0.06:
                    c = hexc("#7fae4e")
                elif r < 0.12:
                    c = hexc("#4a7430")
            elif kind == "dirt":
                c = shade(hexc("#b08a55"), n)
                if rnd.random() < 0.05:
                    c = hexc("#94713f")
            elif kind == "wall_top":
                c = shade(hexc("#e9e2d2"), n // 2)
            elif kind == "wall_front":
                if y == 0:
                    c = hexc("#fbf6ea")
                elif y < 9:
                    c = shade(hexc("#e4dccb"), n // 2)
                elif y == 9:
                    c = hexc("#5e2f28")
                elif y == 15:
                    c = hexc("#4a241f")
                else:
                    c = shade(hexc("#8a4a3d"), n // 2)
            elif kind == "hedge":
                c = shade(hexc("#2f5a2a"), n)
                r = rnd.random()
                if r < 0.10:
                    c = hexc("#3f7436")
                elif r < 0.22:
                    c = hexc("#23451f")
            elif kind == "window":
                c = hexc("#26262c")
                if x in (0, 15) or y in (0, 15):
                    c = hexc("#7a5a3a")
            elif kind == "helipad":
                c = shade(hexc("#6d6972"), n)
                if (x + y) % 8 < 2:
                    c = hexc("#d8b33a")
            px[y][x] = c
    return px


def make_tiles():
    rnd = random.Random(7)
    atlas = blank(TS * len(TILE_TYPES), TS * VARIANTS)
    for ti, kind in enumerate(TILE_TYPES):
        for v in range(VARIANTS):
            t = tile(kind, rnd)
            for y in range(TS):
                for x in range(TS):
                    atlas[v * TS + y][ti * TS + x] = t[y][x]
    write_png("tiles.png", atlas)


# ---------------------------------------------------------------- Figuren
BODY = [
    "....oooooooo....",
    "...ohhhhhhhho...",
    "..ohhhhhhhhhho..",
    "..ohhhhhhhhhho..",
    "..ohhssssssHho..",
    "..ohsssssssso...",
    "..osseesseeso...",
    "..ossssssssso...",
    "...osssSSsso....",
    "....oossssoo....",
    "...orrrwwrrro...",
    "..orrrrwwrrrro..",
    ".orrRrrrrrrRrro.",
    ".orsRrrrrrrRsro.",
    ".ossRrrrrrrRsso.",
    "..ooRrrrrrrRoo..",
    "...obbbbbbbbo...",
    "...obbbBBbbbo...",
    "...obbboobbbo...",
    "...obbo..obbo...",
    "...okko..okko...",
    "...oooo..oooo...",
]

PLAYER_PAL = {"o": "#2b1d16", "h": "#7a4a21", "H": "#5c3616", "s": "#f0c090", "S": "#d09a6a", "e": "#2b1d16",
              "r": "#b8322a", "R": "#8a2020", "w": "#e8e0d0", "b": "#3f5a8a", "B": "#2e4368", "k": "#3a2a20"}
ZOMBIE_PAL = {"o": "#1f2a1c", "h": "#8b987c", "H": "#6f7c62", "s": "#a3b092", "S": "#7d8a6d", "e": "#e0486a",
              "r": "#6d5f80", "R": "#51465f", "w": "#8a2a2a", "b": "#3c3c48", "B": "#2c2c36", "k": "#2a2420"}
RUNNER_PAL = dict(ZOMBIE_PAL, r="#8a4a3a", R="#663428", s="#b3a58a", S="#8f8068", h="#9a8c74", H="#7a6e5a")


# ---------------------------------------------------------------- Waffen (Seitenansicht, zeigen nach rechts)
GUN_PAL = {"o": "#1e1e24", "m": "#8a8f98", "M": "#565b64", "k": "#6a4526", "y": "#7fe0ff", "g": "#3fae5a"}
GUNS = {
    "pistol": [
        "oooooooooo....",
        "ommmmmmmmo....",
        "oMMMoooooo....",
        "okko..........",
        "okko..........",
        "oooo..........",
    ],
    "smg": [
        "..ooooooooooo.",
        "oommmmmmmmmmo.",
        "oMMMMMoooooo..",
        "okkooMo.......",
        "okko.oMo......",
        "oooo..oo......",
    ],
    "shotgun": [
        "....oooooooooo",
        "ooooommmmmmmmo",
        "okkkoMMMMMMMMo",
        "okkkokkkkooooo",
        "oooo.oooo.....",
        "..............",
    ],
    "rifle": [
        "...oooooooooo.",
        "oooommmmmmmmoo",
        "okkoMMMMoooooo",
        "okkookoMo.....",
        "ooo.oko.oMo...",
        "....ooo..oo...",
    ],
    "lmg": [
        "..oooooooooooo",
        "ooommmmmmmmmmo",
        "okoMMMMMMooooo",
        "okookoMMMo....",
        "ooo.okoMMo....",
        "....oo.ooo....",
    ],
    "dmr": [
        "....ooo.......",
        "oooooMoooooooo",
        "okkommmmmmmmmo",
        "okkoMoooooooo.",
        "oooookko......",
        ".....ooo......",
    ],
    "raygun": [
        "..oooooooo....",
        ".oyyyyyyyyoooo",
        "ogggggggggyyyo",
        "okkoooooooooo.",
        "okko..........",
        "oooo..........",
    ],
}


def make_objects():
    ascii_sprite("player.png", BODY, PLAYER_PAL)
    ascii_sprite("zombie.png", BODY, ZOMBIE_PAL)
    ascii_sprite("zombie_runner.png", BODY, RUNNER_PAL)
    for name, rows in GUNS.items():
        ascii_sprite("gun_%s.png" % name, rows, GUN_PAL)

    o = hexc("#2b1d16")
    # Kiste
    px = blank(16, 16)
    rect(px, 0, 2, 15, 15, hexc("#a8763e"))
    rect(px, 0, 2, 15, 5, hexc("#c08a4c"))
    frame(px, 0, 2, 15, 15, o)
    for i in range(1, 9):
        px[5 + i][3 + i] = hexc("#7a5228")
        px[5 + i][12 - i] = hexc("#7a5228")
    write_png("crate.png", px)

    # Fass
    px = blank(12, 16)
    rect(px, 1, 1, 10, 14, hexc("#7a4038"))
    rect(px, 1, 1, 10, 3, hexc("#96564c"))
    for y in (5, 10):
        rect(px, 1, y, 10, y, hexc("#3a3a40"))
    frame(px, 1, 1, 10, 14, o)
    write_png("barrel.png", px)

    # Container
    px = blank(16, 16)
    rect(px, 0, 3, 15, 15, hexc("#3f6e5a"))
    rect(px, 0, 3, 15, 6, hexc("#55897a"))
    for x in (4, 8, 12):
        rect(px, x, 8, x, 13, hexc("#2e5444"))
    frame(px, 0, 3, 15, 15, o)
    write_png("container.png", px)

    # Baum
    px = blank(24, 32)
    rect(px, 10, 20, 13, 31, hexc("#6a4526"))
    rect(px, 10, 20, 10, 31, hexc("#4a2f18"))
    disc(px, 12, 12, 11, hexc("#2a4f25"))
    disc(px, 11, 11, 9, hexc("#3f7436"))
    disc(px, 9, 8, 4, hexc("#5a9448"))
    write_png("tree.png", px)

    # Automat (hell, wird im Spiel eingefaerbt)
    px = blank(16, 22)
    rect(px, 1, 1, 14, 21, hexc("#d8d8d8"))
    rect(px, 1, 1, 14, 3, hexc("#f4f4f4"))
    rect(px, 3, 5, 12, 11, hexc("#2a2a32"))
    rect(px, 4, 6, 11, 10, hexc("#ffffff"))
    rect(px, 3, 14, 12, 15, hexc("#9a9a9a"))
    rect(px, 6, 17, 9, 19, hexc("#2a2a32"))
    frame(px, 1, 1, 14, 21, o)
    write_png("machine.png", px)

    # Shop-Terminal
    px = blank(16, 22)
    rect(px, 1, 1, 14, 21, hexc("#4a5568"))
    rect(px, 1, 1, 14, 3, hexc("#66738a"))
    rect(px, 3, 5, 12, 12, hexc("#12301c"))
    for y in (6, 8, 10):
        rect(px, 4, y, 10, y, hexc("#4ee07a"))
    rect(px, 3, 15, 12, 18, hexc("#2d3544"))
    for x in (4, 7, 10):
        px[16][x] = hexc("#e0c04e")
    frame(px, 1, 1, 14, 21, o)
    write_png("shop.png", px)

    # Upgrade-Werkbank
    px = blank(16, 22)
    rect(px, 1, 6, 14, 21, hexc("#5a3f7a"))
    rect(px, 1, 6, 14, 8, hexc("#7a58a6"))
    rect(px, 4, 1, 11, 6, hexc("#3a2850"))
    rect(px, 6, 2, 9, 4, hexc("#c08aff"))
    rect(px, 3, 12, 12, 16, hexc("#241a33"))
    rect(px, 5, 13, 10, 15, hexc("#e0b0ff"))
    frame(px, 1, 6, 14, 21, o)
    write_png("upgrade.png", px)

    # Mystery-Box
    px = blank(20, 14)
    rect(px, 0, 3, 19, 13, hexc("#8a5a2a"))
    rect(px, 0, 3, 19, 6, hexc("#b07a3a"))
    rect(px, 0, 7, 19, 7, o)
    frame(px, 0, 3, 19, 13, o)
    q = ["yyy", "..y", ".y.", "...", ".y."]
    for j, row in enumerate(q):
        for i, ch in enumerate(row):
            if ch == "y":
                px[8 + j][8 + i] = hexc("#ffd84a")
    write_png("box.png", px)

    # Stromschalter
    px = blank(12, 18)
    rect(px, 1, 1, 10, 17, hexc("#8a8f98"))
    rect(px, 1, 1, 10, 3, hexc("#b0b5be"))
    rect(px, 3, 5, 8, 14, hexc("#2a2a32"))
    frame(px, 1, 1, 10, 17, o)
    write_png("switch_base.png", px)
    px = blank(12, 18)
    rect(px, 5, 6, 6, 10, hexc("#e0483a"))
    rect(px, 4, 5, 7, 6, hexc("#ff7a6a"))
    write_png("switch_off.png", px)
    px = blank(12, 18)
    rect(px, 5, 9, 6, 13, hexc("#3fae5a"))
    rect(px, 4, 13, 7, 14, hexc("#7fe09a"))
    write_png("switch_on.png", px)

    # Funkgeraet
    px = blank(16, 16)
    rect(px, 1, 6, 14, 15, hexc("#5a6a4a"))
    rect(px, 1, 6, 14, 8, hexc("#74866a"))
    rect(px, 3, 10, 7, 13, hexc("#22281c"))
    disc(px, 11, 11, 2, hexc("#c8c8b0"))
    rect(px, 12, 0, 12, 6, hexc("#c8c8c8"))
    frame(px, 1, 6, 14, 15, o)
    write_png("radio.png", px)

    # Funkteil (Zahnrad)
    px = blank(10, 10)
    disc(px, 4.5, 4.5, 4, hexc("#e0c04e"))
    disc(px, 4.5, 4.5, 1.6, hexc("#2b1d16"))
    for (x, y) in ((4, 0), (5, 0), (4, 9), (5, 9), (0, 4), (0, 5), (9, 4), (9, 5)):
        px[y][x] = hexc("#fff0a0")
    write_png("part.png", px)

    # Gartenzwerg
    ascii_sprite("gnome.png", [
        "....rr....",
        "...rrrr...",
        "..rrrrrr..",
        "..osssso..",
        "..oesseo..",
        "..owwwwo..",
        ".obwwwwbo.",
        ".obbwwbbo.",
        ".obbbbbbo.",
        "..obbbbo..",
        "..okooko..",
        "..oo..oo..",
    ], {"r": "#d8342a", "o": "#2b1d16", "s": "#f0c090", "e": "#2b1d16", "w": "#f4f4f4", "b": "#3f6ab8", "k": "#3a2a20"})

    # Tuer
    px = blank(16, 16)
    rect(px, 0, 0, 15, 15, hexc("#7a5230"))
    for x in (5, 10):
        rect(px, x, 1, x, 14, hexc("#5c3c20"))
    rect(px, 1, 4, 14, 4, hexc("#9aa0a8"))
    rect(px, 1, 11, 14, 11, hexc("#9aa0a8"))
    rect(px, 7, 7, 8, 8, hexc("#e0c04e"))
    frame(px, 0, 0, 15, 15, o)
    write_png("door.png", px)

    # Power-ups
    pal = {"o": "#2b1d16", "y": "#ffd84a", "w": "#ffffff", "r": "#e0483a", "g": "#3fae5a", "k": "#3a3a40", "b": "#4a90e0"}
    ascii_sprite("pu_max_ammo.png", [
        "............",
        "..o..o..o...",
        ".oyooyooyo..",
        ".oyooyooyo..",
        ".oyooyooyo..",
        ".oyooyooyo..",
        ".okookooko..",
        ".okookooko..",
        ".okookooko..",
        ".ooooooooo..",
        "............",
        "............",
    ], pal)
    ascii_sprite("pu_insta_kill.png", [
        "...oooooo...",
        "..owwwwwwo..",
        ".owwwwwwwwo.",
        ".owoowwoowo.",
        ".owoowwoowo.",
        ".owwwoowwwo.",
        "..owwwwwwo..",
        "..owowowoo..",
        "..owowowo...",
        "...ooooo....",
        "............",
        "............",
    ], pal)
    ascii_sprite("pu_double_points.png", [
        "............",
        ".ooo...o..o.",
        "oyyyo.oyooyo",
        "ooooyooyooyo",
        "..oyo..oyyo.",
        ".oyo...oyyo.",
        "oyooo.oyooyo",
        "oyyyyooyooyo",
        "ooooo..o..o.",
        "............",
        "............",
        "............",
    ], pal)
    ascii_sprite("pu_nuke.png", [
        "......oo....",
        ".....oyyo...",
        "....oooo....",
        "...okkkko...",
        "..okkkkkko..",
        ".okkwkkkkko.",
        ".okwkkkkkko.",
        ".okkkkkkkko.",
        "..okkkkkko..",
        "...okkkko...",
        "....oooo....",
        "............",
    ], pal)

    # Perk-Symbol (weiss, wird eingefaerbt)
    ascii_sprite("perk_icon.png", [
        "....oooo....",
        "....owwo....",
        "....owwo....",
        "...owwwwo...",
        "..owwwwwwo..",
        "..owwwwwwo..",
        "..owwwwwwo..",
        "..owwwwwwo..",
        "..owwwwwwo..",
        "..owwwwwwo..",
        "...oooooo...",
        "............",
    ], {"o": "#2b1d16", "w": "#ffffff"})

    # Blut
    rnd = random.Random(3)
    for i in range(3):
        px = blank(10, 10)
        for _ in range(26):
            x = int(rnd.gauss(5, 1.8))
            y = int(rnd.gauss(5, 1.8))
            if 0 <= x < 10 and 0 <= y < 10:
                px[y][x] = hexc("#b0141a") if rnd.random() < 0.7 else hexc("#7a0c10")
        write_png("blood_%d.png" % i, px)

    # Muendungsfeuer
    ascii_sprite("muzzle.png", [
        "...y....",
        "..yyy.y.",
        ".yywwyy.",
        "yywwwwyy",
        ".yywwyy.",
        "..yyy.y.",
        "...y....",
        "........",
    ], {"y": "#ffb030", "w": "#fff6c0"})

    # Weisser Pixel + Icon
    write_png("white.png", [[(255, 255, 255, 255)]])
    px = blank(64, 64, hexc("#2b1d16"))
    rect(px, 4, 4, 59, 59, hexc("#b8322a"))
    big = [[T] * 16 for _ in range(22)]
    for y, row in enumerate(BODY):
        for x, ch in enumerate(row):
            if ch != ".":
                c = hexc(ZOMBIE_PAL[ch])
                for dy in range(2):
                    for dx in range(2):
                        px[10 + y * 2 + dy][16 + x * 2 + dx] = c
    write_png("icon.png", px)


if __name__ == "__main__":
    make_tiles()
    make_objects()
    print("Grafiken erzeugt in", os.path.normpath(OUT))
