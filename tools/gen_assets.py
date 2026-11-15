"""Generate all pixel-art PNG assets for New Dog City. Pure stdlib."""
import os, struct, zlib

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

def write_png(name, pixels):
    """pixels: list of rows, each row list of (r,g,b,a)."""
    h, w = len(pixels), len(pixels[0])
    raw = b"".join(b"\x00" + b"".join(struct.pack("4B", *px) for px in row) for row in pixels)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    path = os.path.join(OUT, name)
    with open(path, "wb") as f:
        f.write(png)
    print(f"{name}: {w}x{h}")

T = (0, 0, 0, 0)  # transparent

def grid(rows, pal):
    return [[pal[c] for c in row] for row in rows]

# ---------- creatures (hand-drawn grids) ----------
# Dog: near-white base so Godot modulate tints it per skin.
DOG_PAL = {".": T, "W": (235, 235, 235, 255), "G": (170, 170, 170, 255),
           "K": (25, 25, 25, 255), "P": (240, 150, 160, 255)}
DOG = [
    "....WW..........",
    "...WWWW.....WW..",
    "...WKWW....WWW..",
    "..WWWWWWWWWWW...",
    "..KWWWWWWWWW....",
    "..WWWWWWWWWW....",
    "..PWWWWWWWWWW...",
    "...WWWWWWWWWWW..",
    "...WW..WW..WW...",
    "...GG..GG..GG...",
]
RAT_PAL = {".": T, "B": (130, 115, 105, 255), "D": (90, 78, 70, 255),
           "K": (20, 20, 20, 255), "P": (225, 170, 170, 255)}
RAT = [
    "..........BB..",
    ".BBBBBBBBBBKB.",
    "BBBBBBBBBBBBP.",
    "PBBBBBBBBBB...",
    "..DD..DD......",
]
PIGEON_PAL = {".": T, "B": (120, 130, 145, 255), "D": (85, 95, 110, 255),
              "G": (90, 180, 120, 255), "K": (20, 20, 20, 255), "O": (220, 140, 60, 255)}
PIGEON = [
    "....BB......",
    "...BKBO.....",
    "...GGB......",
    "..BBBBBB....",
    ".BBBBBBBBB..",
    ".DBBBBBBBB..",
    "..DDBBBB....",
    "....OO......",
]
SQUIRREL_PAL = {".": T, "R": (165, 105, 60, 255), "D": (120, 70, 40, 255),
                "K": (20, 20, 20, 255), "C": (230, 210, 190, 255)}
SQUIRREL = [
    "..........DD..",
    ".........DRRD.",
    "..RR.....DRRD.",
    ".RKR.....DRD..",
    ".RRRRRRRRDRD..",
    ".RRCCRRRRRD...",
    "..RRRRRRRR....",
    "...RR..RR.....",
]
RACCOON_PAL = {".": T, "G": (140, 140, 145, 255), "D": (95, 95, 100, 255),
               "K": (30, 30, 35, 255), "W": (220, 220, 220, 255)}
RACCOON = [
    "...GG......GG...",
    "..GGGG....GGGG..",
    "..KKWKGGGGKWKK..",
    "..KWKWGGGGWKWK..",
    "..GGGGGGGGGGGG..",
    ".GGGGGKKGGGGGG..",
    ".GGGGGGGGGGGGGD.",
    ".GGGGGGGGGGGGKD.",
    "..GG..GG..GG.KD.",
    "..DD..DD..DD....",
]
STEAM_PAL = {".": T, "w": (255, 255, 255, 90), "W": (255, 255, 255, 150)}
STEAM = [
    "....wWWw........",
    "...wWWWWw.......",
    "..wWWWWWWw..ww..",
    "..wWWWWWw..wWWw.",
    "...wWWWWWwwWWw..",
    "..wWWWWWWWWWw...",
    ".wWWWWWWWWWWWw..",
    ".wWWWWWWWWWWw...",
    "..wWWWWWWWWw....",
    "...wwWWWWww.....",
    ".....wwww.......",
]
TREAT_PAL = {".": T, "B": (200, 140, 70, 255), "D": (150, 95, 45, 255)}
TREAT = [
    ".BB....BB.",
    "BBBBBBBBBB",
    "BBBDDDDBBB",
    "BBBBBBBBBB",
    ".BB....BB.",
]

# ---------- structures (programmatic) ----------
def blank(w, h, color=T):
    return [[color for _ in range(w)] for _ in range(h)]

def rect(px, x, y, w, h, c):
    for j in range(y, y + h):
        for i in range(x, x + w):
            px[j][i] = c

def road_tile():
    px = blank(32, 32, (55, 55, 60, 255))
    for j in range(32):
        for i in range(32):
            if (i * 7 + j * 13) % 11 == 0:
                px[j][i] = (62, 62, 68, 255)
    return px

def road_dash_tile():
    px = road_tile()
    rect(px, 14, 4, 4, 10, (210, 180, 60, 255))
    rect(px, 14, 20, 4, 10, (210, 180, 60, 255))
    return px

def sidewalk_tile():
    px = blank(32, 32, (150, 148, 145, 255))
    for i in range(32):
        px[0][i] = (120, 118, 115, 255)
        px[31][i] = (120, 118, 115, 255)
    for j in range(32):
        px[j][0] = (120, 118, 115, 255)
    for j in range(32):
        for i in range(32):
            if (i * 5 + j * 3) % 17 == 0:
                px[j][i] = (138, 136, 133, 255)
    return px

def grass_tile():
    px = blank(32, 32, (70, 120, 60, 255))
    for j in range(32):
        for i in range(32):
            if (i * 11 + j * 7) % 13 == 0:
                px[j][i] = (85, 140, 70, 255)
            elif (i * 3 + j * 17) % 19 == 0:
                px[j][i] = (60, 105, 52, 255)
    return px

def building(w, h, body, win):
    px = blank(w, h, body)
    dark = tuple(max(0, c - 35) for c in body[:3]) + (255,)
    rect(px, 0, 0, w, 3, dark)
    rect(px, 0, 0, 2, h, dark)
    rect(px, w - 2, 0, 2, h, dark)
    rect(px, 0, h - 2, w, 2, dark)
    for j in range(8, h - 8, 10):
        for i in range(6, w - 8, 9):
            rect(px, i, j, 5, 6, win)
    return px

def empire():
    # tapered art-deco tower with spire
    px = blank(64, 160, T)
    body = (175, 165, 150, 255); win = (90, 110, 140, 255)
    dark = (140, 132, 120, 255)
    tiers = [(0, 64, 60, 160), (8, 48, 34, 60), (16, 32, 16, 34)]
    for x, w, y0, y1 in tiers:
        rect(px, x, y0, w, y1 - y0, body)
        rect(px, x, y0, w, 2, dark)
        rect(px, x, y0, 2, y1 - y0, dark)
        rect(px, x + w - 2, y0, 2, y1 - y0, dark)
        for j in range(y0 + 5, y1 - 4, 8):
            for i in range(x + 4, x + w - 5, 7):
                rect(px, i, j, 4, 5, win)
    rect(px, 30, 2, 4, 14, (120, 120, 125, 255))  # spire
    rect(px, 31, 0, 2, 4, (200, 60, 60, 255))     # beacon
    return px

def chrysler():
    px = blank(64, 160, T)
    body = (150, 155, 165, 255); win = (80, 95, 120, 255)
    rect(px, 8, 56, 48, 104, body)
    for j in range(62, 154, 8):
        for i in range(12, 50, 7):
            rect(px, i, j, 4, 5, win)
    # crown arches
    crown = (200, 205, 215, 255)
    heights = [(40, 12), (30, 10), (20, 10), (12, 8)]
    for k, (w, h) in enumerate(heights):
        y = 52 - sum(hh for _, hh in heights[:k + 1])
        rect(px, 32 - w // 2, y, w, h, crown)
        for i in range(32 - w // 2 + 2, 32 + w // 2 - 2, 4):
            rect(px, i, y + 2, 2, h - 4, (110, 120, 135, 255))
    rect(px, 31, 0, 2, 12, (210, 215, 225, 255))  # needle
    return px

def bodega():
    px = blank(96, 64, (160, 120, 90, 255))
    rect(px, 0, 0, 96, 2, (120, 88, 62, 255))
    # awning stripes
    for i in range(0, 96, 12):
        rect(px, i, 14, 6, 10, (200, 60, 60, 255))
        rect(px, i + 6, 14, 6, 10, (240, 235, 225, 255))
    # sign
    rect(px, 8, 3, 80, 10, (40, 90, 60, 255))
    rect(px, 12, 5, 72, 6, (240, 220, 100, 255))
    # window + door
    rect(px, 10, 28, 46, 30, (120, 170, 200, 255))
    rect(px, 12, 30, 42, 26, (90, 140, 175, 255))
    rect(px, 64, 28, 22, 36, (70, 50, 35, 255))
    rect(px, 66, 30, 18, 32, (95, 70, 48, 255))
    rect(px, 80, 44, 3, 4, (220, 200, 90, 255))  # handle
    return px

def subway():
    px = blank(48, 40, T)
    rect(px, 0, 8, 48, 32, (60, 90, 70, 255))     # railing box
    rect(px, 4, 12, 40, 28, (30, 30, 35, 255))    # stairwell hole
    for k in range(5):                            # steps fading down
        g = 70 - k * 12
        rect(px, 6, 14 + k * 5, 36, 4, (g, g, g + 5, 255))
    rect(px, 8, 0, 32, 10, (25, 70, 40, 255))     # sign
    rect(px, 12, 2, 24, 6, (240, 240, 240, 255))
    rect(px, 14, 3, 8, 4, (25, 70, 40, 255))      # fake lettering blocks
    rect(px, 24, 3, 4, 4, (25, 70, 40, 255))
    rect(px, 30, 3, 4, 4, (25, 70, 40, 255))
    return px

def trashcan():
    px = blank(16, 20, T)
    rect(px, 2, 4, 12, 16, (110, 115, 120, 255))
    rect(px, 3, 5, 3, 14, (135, 140, 145, 255))
    rect(px, 1, 2, 14, 3, (90, 95, 100, 255))   # lid
    rect(px, 6, 0, 4, 2, (90, 95, 100, 255))    # handle
    for j in (8, 12, 16):
        rect(px, 2, j, 12, 1, (95, 100, 105, 255))
    return px

def manhole():
    px = blank(24, 24, T)
    c = 11.5
    for j in range(24):
        for i in range(24):
            d = ((i - c) ** 2 + (j - c) ** 2) ** 0.5
            if d <= 11:
                px[j][i] = (70, 65, 60, 255)
            if d <= 9:
                px[j][i] = (55, 50, 46, 255)
            if 6.5 <= d <= 7.5:
                px[j][i] = (75, 70, 64, 255)
    for k in range(3, 21, 4):
        px[k][11] = (75, 70, 64, 255)
        px[11][k] = (75, 70, 64, 255)
    return px

def water_bowl():
    px = blank(14, 8, T)
    rect(px, 1, 2, 12, 6, (90, 140, 200, 255))
    rect(px, 0, 1, 14, 2, (170, 60, 50, 255))
    rect(px, 3, 3, 8, 2, (140, 190, 235, 255))
    return px

def purina_bag():
    px = blank(12, 14, T)
    rect(px, 1, 1, 10, 13, (190, 60, 50, 255))
    rect(px, 2, 3, 8, 4, (240, 220, 100, 255))
    rect(px, 2, 9, 8, 3, (240, 240, 240, 255))
    return px

os.makedirs(OUT, exist_ok=True)
write_png("dog.png", grid(DOG, DOG_PAL))
write_png("rat.png", grid(RAT, RAT_PAL))
write_png("pigeon.png", grid(PIGEON, PIGEON_PAL))
write_png("squirrel.png", grid(SQUIRREL, SQUIRREL_PAL))
write_png("raccoon.png", grid(RACCOON, RACCOON_PAL))
write_png("steam.png", grid(STEAM, STEAM_PAL))
write_png("treat.png", grid(TREAT, TREAT_PAL))
write_png("road.png", road_tile())
write_png("road_dash.png", road_dash_tile())
write_png("sidewalk.png", sidewalk_tile())
write_png("grass.png", grass_tile())
write_png("building_a.png", building(64, 96, (140, 100, 90, 255), (95, 115, 145, 255)))
write_png("building_b.png", building(64, 112, (120, 125, 135, 255), (100, 120, 150, 255)))
write_png("empire_state.png", empire())
write_png("chrysler.png", chrysler())
write_png("bodega.png", bodega())
write_png("subway.png", subway())
write_png("trashcan.png", trashcan())
write_png("manhole.png", manhole())
write_png("water_bowl.png", water_bowl())
write_png("purina.png", purina_bag())
print("done")
