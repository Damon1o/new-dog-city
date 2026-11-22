"""Street props, landmarks, dogs and critters for New Dog City (replaces the flat-rect versions
that lived in gen_assets.py). Pure stdlib, seeded. Run: python tools/gen_props.py

Props and landmarks are drawn at 2x the old pixel size; city_builder.gd halves their scale so
world size and collision boxes are unchanged. Dogs and critters keep their exact frame sizes
because wardrobe hats / collars are placed in dog-frame pixels (scripts/data/wardrobe.gd)."""
import math, os, random
import gen_buildings as gb
from gen_buildings import T, rect, dot, shade, FONT

gb.OUT = os.path.join(os.path.dirname(__file__), "..", "assets")  # gb.write_png writes to gb.OUT
write_png = gb.write_png
K = (22, 20, 24, 255)

# ---------- helpers ----------
def blank(w, h):
    return [[T] * w for _ in range(h)]

def rgba(c, a=255):
    return tuple(c[:3]) + (a,)

def blend(px, x, y, c, a):
    """Alpha-blend colour c (opacity a 0..1) over pixel x,y."""
    if not (0 <= y < len(px) and 0 <= x < len(px[0])):
        return
    o = px[y][x]
    if o[3] == 0:
        px[y][x] = rgba(c, int(255 * a))
        return
    px[y][x] = tuple(int(o[k] + (c[k] - o[k]) * a) for k in range(3)) + (max(o[3], int(255 * a)),)

def ellipse(px, cx, cy, rx, ry, c):
    for j in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for i in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((i + 0.5 - cx) / rx) ** 2 + ((j + 0.5 - cy) / ry) ** 2 <= 1.0:
                dot(px, i, j, c)

def ring(px, cx, cy, rx, ry, c, t=0.12):
    for j in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for i in range(int(cx - rx) - 1, int(cx + rx) + 2):
            d = ((i + 0.5 - cx) / rx) ** 2 + ((j + 0.5 - cy) / ry) ** 2
            if 1.0 - t <= d <= 1.0:
                dot(px, i, j, c)

def shadow(px, cx, cy, rx, ry, a=0.28):
    """Soft ground shadow, only on empty pixels so it never darkens the sprite itself."""
    for j in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for i in range(int(cx - rx) - 1, int(cx + rx) + 2):
            d = ((i + 0.5 - cx) / rx) ** 2 + ((j + 0.5 - cy) / ry) ** 2
            if d <= 1.0 and 0 <= j < len(px) and 0 <= i < len(px[0]) and px[j][i][3] == 0:
                px[j][i] = (10, 14, 12, int(255 * a * (1.0 - d * 0.6)))

def ball(px, cx, cy, r, base, ry=None):
    """Sphere lit from the top-left: 5 tones with an ordered-dither seam between them."""
    ry = ry or r
    for j in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for i in range(int(cx - r) - 1, int(cx + r) + 2):
            nx, ny = (i + 0.5 - cx) / r, (j + 0.5 - cy) / ry
            if nx * nx + ny * ny > 1.0:
                continue
            light = -0.6 * nx - 0.75 * ny + ((i + j) % 2) * 0.12
            d = 34 if light > 0.75 else 16 if light > 0.25 else 0 if light > -0.25 else -18 if light > -0.7 else -34
            dot(px, i, j, shade(base, d))

def cyl(px, x, y, w, h, base, hi=40, lo=-45):
    """Vertical cylinder: bright band left of centre, dark right edge."""
    for i in range(w):
        t = (i + 0.5) / w
        d = hi if 0.18 < t < 0.34 else int(hi * 0.4) if t <= 0.18 else 0 if t < 0.62 else lo // 2 if t < 0.85 else lo
        rect(px, x + i, y, 1, h, shade(base, d))

def selout(px, d=-60):
    """Selective outline: opaque pixels touching transparency get a darker take on their own colour."""
    h, w = len(px), len(px[0])
    edge = []
    for j in range(h):
        for i in range(w):
            if px[j][i][3] < 200:
                continue
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, b = i + di, j + dj
                if not (0 <= a < w and 0 <= b < h) or px[b][a][3] < 120:
                    edge.append((i, j))
                    break
    for i, j in edge:
        px[j][i] = shade(px[j][i], d)

def text2(px, s, cx, y, c, k=2):
    """gen_buildings' 3x5 font at k x scale."""
    x = cx - (len(s) * 4 * k - k) // 2
    for ch in s:
        for n, b in enumerate(FONT[ch]):
            if b == "1":
                rect(px, x + (n % 3) * k, y + (n // 3) * k, k, k, c)
        x += 4 * k

def glow(px, cx, cy, r, c, a=0.35):
    for j in range(int(cy - r), int(cy + r) + 1):
        for i in range(int(cx - r), int(cx + r) + 1):
            d = math.hypot(i + 0.5 - cx, j + 0.5 - cy) / r
            if d < 1.0:
                blend(px, i, j, c, a * (1.0 - d) ** 2)

# ---------- street props (2x) ----------
def tree():
    """48x64 street tree: lit leaf clusters, highlights, bark, flared roots."""
    rng = random.Random(11)
    px = blank(48, 64)
    shadow(px, 24, 60, 19, 4)
    bark = (96, 64, 42, 255)
    cyl(px, 20, 34, 8, 26, bark, 30, -35)
    for j in range(36, 59, 3):  # bark furrows
        dot(px, 21 + (j * 7) % 5, j, shade(bark, -35)); dot(px, 22 + (j * 7) % 5, j + 1, shade(bark, -35))
    rect(px, 18, 57, 12, 3, shade(bark, -10)); dot(px, 17, 59, shade(bark, -20)); dot(px, 30, 59, shade(bark, -30))
    rect(px, 19, 55, 2, 2, bark); rect(px, 27, 55, 2, 2, shade(bark, -25))
    rect(px, 27, 38, 6, 2, bark); rect(px, 31, 36, 2, 2, bark)  # branch stub reaching the canopy
    leaf = (66, 132, 58, 255)
    for cx, cy, r, d in [(24, 32, 12, -22), (12, 27, 10, -14), (36, 27, 10, -18), (17, 17, 11, 0),
                         (32, 16, 11, -6), (24, 9, 9, 8), (24, 23, 12, 4), (10, 18, 7, 6), (39, 19, 7, -4)]:
        ball(px, cx, cy, r, shade(leaf, d))
    for _ in range(70):  # leaf texture: light flecks up-left, dark flecks down-right
        i, j = rng.randrange(2, 46), rng.randrange(1, 42)
        if px[j][i][3] == 255 and px[j][i] != bark:
            lit = (i + j) < 40
            dot(px, i, j, shade(px[j][i], 26 if lit else -24))
            if lit and rng.random() < 0.4:
                dot(px, i + 1, j, shade(px[j][i], 10))
    selout(px, -50)
    return px

def fountain():
    """80x56 two-tier park fountain: stone basin, rippled pool, upper bowl, falling water."""
    rng = random.Random(3)
    px = blank(80, 56)
    cx = 40
    shadow(px, cx, 50, 39, 6, 0.3)
    stone, stone_lt, stone_dk = (156, 152, 146, 255), (196, 192, 184, 255), (112, 108, 104, 255)
    ellipse(px, cx, 44, 37, 9, stone_dk)
    rect(px, 3, 34, 74, 10, stone)
    for i in range(3, 77):  # wall shading, light from the left
        t = (i - 3) / 74
        rect(px, i, 34, 1, 11 + int(4 * math.sin(math.pi * t)), shade(stone, int(22 - 50 * t)))
    for i in range(10, 74, 9):  # block joints follow the curve
        rect(px, i, 36 + int(5 * math.sin(math.pi * (i - 3) / 74)) // 2, 1, 7, stone_dk)
    rect(px, 3, 39, 74, 1, shade(stone, -18))
    ellipse(px, cx, 34, 37, 9, stone_lt)
    ellipse(px, cx, 34.5, 33, 7, (52, 104, 160, 255))
    ellipse(px, cx, 34, 31, 5.8, (74, 140, 205, 255))
    ring(px, cx, 34, 22, 4, (120, 178, 230, 255), 0.2)
    ring(px, cx, 34, 13, 2.5, (150, 200, 240, 255), 0.3)
    for i, j in [(16, 32), (58, 35), (26, 37), (52, 31), (12, 35), (66, 33)]:  # glints
        dot(px, i, j, (235, 248, 255, 255)); dot(px, i + 1, j, (190, 225, 250, 255))
    # pedestal + upper bowl
    cyl(px, 36, 15, 8, 20, stone, 36, -40)
    rect(px, 34, 30, 12, 3, stone_dk); rect(px, 35, 29, 10, 1, stone)
    ellipse(px, cx, 18, 13, 3.5, stone_dk)
    ellipse(px, cx, 15, 14, 4, stone_lt)
    ellipse(px, cx, 15.3, 11, 2.6, (74, 140, 205, 255))
    rect(px, 38, 6, 4, 10, (160, 210, 245, 200)); rect(px, 39, 3, 2, 3, (200, 232, 255, 220))
    for k in range(9):  # top spray
        a = -math.pi / 2 + (k - 4) * 0.35
        dot(px, int(cx + math.cos(a) * 4), int(4 + math.sin(a) * 3), (220, 240, 255, 220))
    for side in (-1, 1):  # water curtains from the bowl lip into the pool
        for k in range(14):
            t = k / 13
            x = cx + side * (13 + t * 7)
            y = 16 + t * t * 18
            blend(px, int(x), int(y), (170, 215, 250), 0.85)
            blend(px, int(x) - side, int(y), (120, 180, 235), 0.5)
        for _ in range(5):
            blend(px, cx + side * rng.randint(18, 23), rng.randint(31, 35), (235, 248, 255), 0.9)
    selout(px, -45)
    return px

def hydrant():
    """20x28 NYC hydrant: cylinder-shaded barrel, bonnet, side caps, pumper nozzle, chain."""
    px = blank(20, 28)
    shadow(px, 10, 26, 9, 2.5)
    red = (204, 46, 40, 255)
    rect(px, 3, 23, 14, 3, shade(red, -40)); rect(px, 4, 22, 12, 1, shade(red, -15))
    cyl(px, 5, 9, 10, 14, red, 46, -55)
    for j in (12, 19):
        rect(px, 5, j, 10, 1, shade(red, -30))
    ellipse(px, 10, 9, 6.5, 2.5, shade(red, -30))
    ball(px, 10, 7, 4.5, red, 3.5)
    cyl(px, 8, 1, 4, 4, shade(red, -20), 30, -30)  # operating nut
    for x0 in (1, 15):  # side outlets with caps
        cyl(px, x0, 13, 4, 5, red, 30, -40)
        rect(px, x0 if x0 == 1 else x0 + 3, 12, 1, 7, shade(red, -55))
    ellipse(px, 10, 16, 3, 3, shade(red, -45)); ellipse(px, 10, 15.6, 2, 2, shade(red, -10))
    dot(px, 9, 15, shade(red, 40))
    for k in range(4):  # chain loop to the side cap
        dot(px, 13 + k // 2, 18 + k, (190, 190, 180, 255))
    dot(px, 7, 10, (255, 160, 150, 255)); dot(px, 7, 11, (240, 120, 110, 255))
    selout(px, -50)
    return px

def trashcan():
    """32x40 galvanised can, lid ajar, fish bone poking out (raccoons live here)."""
    px = blank(32, 40)
    shadow(px, 16, 37, 15, 3)
    steel = (134, 140, 146, 255)
    cyl(px, 5, 11, 22, 26, steel, 42, -48)
    for j in (17, 25, 32):  # ribs
        cyl(px, 4, j, 24, 2, shade(steel, 10), 50, -55)
    rect(px, 5, 36, 22, 1, shade(steel, -50))
    rect(px, 2, 15, 3, 4, shade(steel, -40)); rect(px, 27, 15, 3, 4, shade(steel, -50))  # side handles
    for k in range(6):  # fish bone
        dot(px, 9 + k, 9 - k // 2, (230, 226, 210, 255))
    for k in range(3):
        dot(px, 10 + k * 2, 6, (210, 206, 190, 255)); dot(px, 10 + k * 2, 10, (210, 206, 190, 255))
    rect(px, 15, 4, 2, 3, (230, 226, 210, 255))
    for j in range(5):  # tilted lid
        y = 7 + j // 2
        rect(px, 3 + j, y - (j > 2), 26, 1, shade(steel, 30 - j * 14))
    ellipse(px, 17, 7, 13, 3, shade(steel, 24))
    ring(px, 17, 7, 13, 3, shade(steel, -20), 0.3)
    rect(px, 14, 2, 6, 2, shade(steel, -30)); rect(px, 15, 2, 4, 1, shade(steel, 20))  # lid handle
    dot(px, 22, 26, shade(steel, -35)); dot(px, 23, 27, shade(steel, -25))  # dent
    selout(px, -45)
    return px

def manhole():
    """48x48 cast-iron cover lying flat on the road: rim, waffle pattern, NYC band, rust."""
    rng = random.Random(9)
    px = blank(48, 48)
    iron = (72, 68, 64, 255)
    c = 23.5
    for j in range(48):
        for i in range(48):
            d = math.hypot(i - c, j - c)
            if d > 23.5:
                continue
            lit = int(14 * (-(i - c) - (j - c)) / 24)
            if d > 21.5:
                px[j][i] = shade(iron, -28 + lit)
            elif d > 20.5:
                px[j][i] = shade(iron, 18 + lit)
            else:
                waffle = (i // 3 + j // 3) % 2 == 0 and abs(j - c) > 4
                px[j][i] = shade(iron, lit + (10 if waffle else -6))
                if waffle and (i % 3 == 0 or j % 3 == 0):
                    px[j][i] = shade(iron, lit + 22)
    rect(px, 6, 20, 36, 8, shade(iron, -16))
    text2(px, "NYC", 24, 21, shade(iron, 26), 1)
    gb.text(px, "NYC", 24, 21, shade(iron, 30))
    for _ in range(40):  # rust
        i, j = rng.randrange(4, 44), rng.randrange(4, 44)
        if px[j][i][3]:
            dot(px, i, j, (120, 72, 46, 255) if rng.random() < 0.6 else (96, 60, 42, 255))
    rect(px, 21, 10, 6, 2, (34, 32, 30, 255)); rect(px, 21, 36, 6, 2, (34, 32, 30, 255))  # pick holes
    return px

def water_bowl():
    """28x16 red dog bowl with DOG lettering and a lit water surface."""
    px = blank(28, 16)
    shadow(px, 14, 14, 13, 2.5)
    red = (196, 58, 48, 255)
    ellipse(px, 14, 10, 12.5, 4.5, shade(red, -40))
    cyl(px, 2, 6, 24, 5, red, 40, -45)
    ellipse(px, 14, 5.5, 13, 3.5, shade(red, 30))
    ellipse(px, 14, 5.5, 10.5, 2.5, (58, 120, 190, 255))
    ellipse(px, 13, 5, 8, 1.6, (100, 165, 225, 255))
    dot(px, 9, 5, (235, 248, 255, 255)); dot(px, 10, 5, (200, 230, 250, 255))
    gb.text(px, "DOG", 14, 8, (245, 235, 220, 255))
    selout(px, -40)
    return px

def subway():
    """96x80 subway entrance: green railings, globe lamps, SUBWAY sign, stairs into the dark."""
    px = blank(96, 80)
    green, green_dk = (44, 104, 70, 255), (26, 66, 44, 255)
    tile = (214, 216, 206, 255)
    rect(px, 12, 32, 72, 48, (20, 20, 26, 255))  # stairwell
    for k in range(8):  # steps, lit at the top, fading into the dark
        y = 34 + k * 6
        g = 150 - k * 17
        rect(px, 14, y, 68, 4, (g, g, g + 6, 255))
        rect(px, 14, y, 68, 1, (min(255, g + 30), min(255, g + 30), min(255, g + 36), 255))
        rect(px, 14, y + 4, 68, 2, (max(0, g - 60), max(0, g - 60), max(0, g - 54), 255))
    rect(px, 12, 32, 3, 48, tile); rect(px, 81, 32, 3, 48, shade(tile, -40))  # tiled side walls
    for j in range(33, 80, 4):
        dot(px, 13, j, shade(tile, -30)); dot(px, 82, j, shade(tile, -70))
    for x0, x1 in ((6, 12), (84, 90)):  # side railings
        rect(px, x0, 26, x1 - x0, 2, green)
        for i in range(x0, x1, 3):
            rect(px, i, 26, 1, 54, green_dk)
        rect(px, x0, 50, x1 - x0, 1, green); rect(px, x0, 74, x1 - x0, 1, green)
    rect(px, 6, 24, 84, 3, green); rect(px, 6, 24, 84, 1, shade(green, 40))  # back rail
    for i in range(8, 89, 4):
        rect(px, i, 27, 1, 6, green_dk)
    rect(px, 6, 32, 84, 2, green)
    rect(px, 18, 6, 60, 18, green_dk)  # sign
    rect(px, 19, 7, 58, 16, green); rect(px, 19, 7, 58, 1, shade(green, 35))
    text2(px, "SUBWAY", 48, 9, (245, 245, 240, 255))
    for k, col in enumerate([(238, 53, 46), (0, 147, 60), (0, 57, 166), (252, 204, 10)]):  # line bullets
        ellipse(px, 36 + k * 8, 21, 2.5, 2.5, col + (255,))
    for lx in (7, 89):  # lamp posts with green globes
        cyl(px, lx - 1, 6, 3, 20, green, 30, -30)
        glow(px, lx, 4, 9, (150, 255, 170), 0.35)
        ball(px, lx, 4, 4, (90, 210, 120, 255))
        dot(px, lx - 1, 2, (230, 255, 230, 255))
    selout(px, -40)
    return px

def bodega():
    """192x128 corner bodega: brick, DELI GROCERY sign, striped awning, stocked window with
    a cat, neon OPEN, glass door (door centre x=150 matches city_builder's +54 at scale 1)."""
    rng = random.Random(21)
    w, h = 192, 128
    px = blank(w, h)
    brick = (132, 70, 54, 255)
    gb.bricks(px, 0, 4, w, h - 4, brick, rng)
    rect(px, 0, 0, w, 4, (96, 58, 46, 255)); rect(px, 0, 4, w, 2, (180, 160, 140, 255))  # cornice
    for i in range(0, w, 6):
        dot(px, i + 2, 6, (90, 54, 44, 255))
    # sign band
    rect(px, 6, 10, 180, 24, (20, 60, 38, 255))
    rect(px, 8, 12, 176, 20, (36, 112, 66, 255)); rect(px, 8, 12, 176, 2, (70, 150, 96, 255))
    text2(px, "DELI GROCERY", 84, 16, (250, 226, 104, 255))
    rect(px, 154, 14, 26, 16, (210, 40, 40, 255)); gb.text(px, "24", 167, 16, (255, 255, 255, 255))
    gb.text(px, "HR", 167, 23, (255, 255, 255, 255))
    for i in range(10, 182, 8):
        dot(px, i, 13, (255, 250, 210, 255))  # marquee bulbs
    # awning
    for i in range(4, 188):
        col = (206, 52, 48, 255) if (i // 8) % 2 == 0 else (244, 238, 226, 255)
        for j in range(12):
            dot(px, i, 36 + j, shade(col, -int(j * 2.5)))
        if (i - 4) % 8 in (2, 3, 4, 5):
            dot(px, i, 48, shade(col, -40))
    rect(px, 2, 35, 188, 2, (110, 34, 30, 255))
    for i in range(4, 188, 8):
        blend(px, i + 4, 50, (0, 0, 0), 0.35); blend(px, i + 4, 51, (0, 0, 0), 0.2)
    # window with shelves of goods
    frame = (52, 46, 44, 255)
    rect(px, 6, 54, 120, 62, frame)
    rect(px, 9, 57, 114, 56, (34, 44, 56, 255))
    goods = [(220, 60, 50), (250, 205, 70), (70, 130, 210), (90, 180, 100), (240, 240, 235), (236, 136, 50), (170, 90, 170)]
    for sy in (66, 80, 94, 108):
        rect(px, 9, sy, 114, 2, (120, 96, 70, 255))
        x = 10
        while x < 120:
            gw, gh = rng.randint(3, 5), rng.randint(5, 10)
            c = rng.choice(goods)
            rect(px, x, sy - gh, gw, gh, c + (255,)); rect(px, x, sy - gh, gw, 1, shade(c, 40))
            rect(px, x + gw - 1, sy - gh, 1, gh, shade(c, -40))
            x += gw + rng.randint(0, 2)
    rect(px, 64, 57, 2, 56, frame)  # mullion
    for d in range(0, 160, 34):  # glass reflection streaks
        for k in range(46):
            for t in range(4 if d % 68 == 0 else 2):
                x, y = 9 + d - k + t, 57 + k
                if 9 <= x < 123 and 57 <= y < 113 and x != 64 and x != 65:
                    blend(px, x, y, (220, 240, 255), 0.18)
    rect(px, 18, 60, 30, 13, (30, 14, 18, 255))  # neon OPEN
    glow(px, 33, 66, 20, (255, 60, 90), 0.4)
    text2(px, "OPEN", 33, 62, (255, 92, 120, 255), 1)
    gb.text(px, "OPEN", 33, 63, (255, 120, 150, 255))
    rect(px, 84, 59, 30, 9, (250, 214, 40, 255)); gb.text(px, "LOTTO", 99, 61, (200, 30, 30, 255))
    rect(px, 96, 98, 20, 12, (240, 240, 235, 255)); gb.text(px, "ATM", 106, 101, (30, 80, 170, 255))
    cat = [  # bodega cat sitting in the window, facing out
        "..O.....O..", ".OOO...OOO.", ".OKOOOOOKO.", ".OOOPPPOOO.", "..OOOOOOO..",
        "..OWWWWWO..", ".OOWWWWWOO.", ".OOOOOOOOO.", ".OOOOOOOOOO", "..OO.OO.OO.",
    ]
    pal = {"O": (230, 140, 60, 255), "W": (248, 238, 222, 255), "K": K, "P": (240, 150, 160, 255)}
    for j, row in enumerate(cat):
        for i, ch in enumerate(row):
            if ch in pal:
                rect(px, 22 + i * 2, 90 + j * 2, 2, 2, pal[ch])
    rect(px, 6, 114, 120, 10, (86, 62, 48, 255)); rect(px, 6, 114, 120, 1, (120, 90, 70, 255))  # kick plate
    # flower buckets between window and door
    for k, c in enumerate([(240, 90, 130), (250, 220, 80), (190, 110, 220)]):
        bx = 128 + k * 6
        rect(px, bx, 114, 5, 10, (70, 90, 110, 255))
        for _ in range(6):
            dot(px, bx + rng.randint(0, 4), rng.randint(104, 113), c + (255,))
        rect(px, bx + 2, 108, 1, 6, (60, 130, 60, 255))
    # door, centred on x=150
    rect(px, 134, 52, 32, 72, frame)
    rect(px, 137, 55, 26, 69, (40, 52, 66, 255))
    rect(px, 139, 57, 22, 44, (70, 100, 130, 255))
    for k in range(30):
        blend(px, 158 - k // 2, 58 + k, (220, 240, 255), 0.25)
    rect(px, 139, 78, 22, 3, (200, 200, 205, 255))  # push bar
    gb.text(px, "PUSH", 150, 84, (230, 230, 230, 255))
    rect(px, 139, 104, 22, 18, (52, 60, 72, 255))
    rect(px, 168, 60, 18, 24, (240, 230, 200, 255))  # menu poster on the pier
    gb.text(px, "HERO", 177, 62, (200, 40, 40, 255))
    for j in range(69, 82, 3):
        rect(px, 170, j, 14, 1, (120, 110, 100, 255))
    rect(px, 0, 124, w, 4, (150, 146, 140, 255)); rect(px, 0, 124, w, 1, (190, 186, 180, 255))  # step
    return px

# ---------- landmarks (2x) ----------
def lit_window(rng, p=0.3):
    return (248, 214, 120, 255) if rng.random() < p else (60, 78, 104, 255) if rng.random() < 0.7 else (84, 106, 136, 255)

def tower_tier(px, rng, x, y, w, h, stone, colw=5, roww=6):
    """One setback of an art-deco tower: lit left face, shaded right face, pier-and-spandrel windows."""
    face = int(w * 0.72)
    rect(px, x, y, face, h, stone)
    rect(px, x + face, y, w - face, h, shade(stone, -38))
    rect(px, x, y, w, 2, shade(stone, 30)); rect(px, x, y + 2, w, 1, shade(stone, -30))
    for side, x0, x1 in ((0, x + 3, x + face - 2), (1, x + face + 2, x + w - 2)):
        for i in range(x0, x1 - 1, colw):
            for j in range(y + 5, y + h - 3, roww):
                c = lit_window(rng)
                rect(px, i, j, 2, roww - 2, c if not side else shade(c, -25))
            rect(px, i + 2, y + 4, 1, h - 6, shade(stone, 14 if not side else -28))  # pier highlight

def empire():
    rng = random.Random(350)
    px = blank(128, 320)
    stone = (198, 188, 168, 255)
    tower_tier(px, rng, 4, 238, 120, 80, shade(stone, -8))
    tower_tier(px, rng, 14, 206, 100, 32, stone)
    tower_tier(px, rng, 24, 76, 80, 130, stone)
    tower_tier(px, rng, 34, 56, 60, 20, shade(stone, 6))
    tower_tier(px, rng, 42, 42, 44, 14, shade(stone, 10))
    rect(px, 48, 28, 32, 14, shade(stone, 4))  # crown with deco fins
    for i in range(49, 80, 3):
        rect(px, i, 28, 1, 14, shade(stone, -40 if i > 70 else 26))
    rect(px, 46, 26, 36, 2, shade(stone, 30))
    glow(px, 64, 34, 20, (255, 230, 160), 0.25)  # floodlit top
    cyl(px, 58, 12, 12, 14, (176, 182, 190, 255), 40, -45)  # mooring mast
    for j in (15, 19, 23):
        rect(px, 58, j, 12, 1, (120, 126, 136, 255))
    rect(px, 60, 10, 8, 2, (150, 156, 166, 255))
    rect(px, 63, 1, 2, 10, (190, 196, 204, 255))  # antenna
    dot(px, 63, 0, (255, 70, 60, 255)); dot(px, 64, 0, (255, 70, 60, 255))
    glow(px, 64, 1, 5, (255, 60, 60), 0.6)
    rect(px, 46, 284, 36, 34, (60, 50, 40, 255))  # entrance portal
    rect(px, 48, 286, 32, 4, (214, 176, 80, 255)); gb.text(px, "350", 64, 292, (214, 176, 80, 255))
    for i in range(50, 79, 7):
        rect(px, i, 299, 5, 19, (120, 150, 180, 255)); rect(px, i, 299, 1, 19, (180, 210, 230, 255))
    rect(px, 0, 316, 128, 4, (110, 106, 100, 255))
    selout(px, -45)
    return px

def chrysler():
    rng = random.Random(405)
    px = blank(128, 320)
    white, steel = (214, 214, 210, 255), (186, 194, 206, 255)
    tower_tier(px, rng, 10, 250, 108, 68, shade(white, -16))
    tower_tier(px, rng, 26, 128, 76, 122, white)
    for x in (26, 99):  # dark brick corner bands
        for j in range(140, 250, 12):
            rect(px, x, j, 3, 2, (70, 70, 80, 255))
    for x, flip in ((24, -1), (102, 1)):  # eagle gargoyles
        rect(px, x - (4 if flip < 0 else 0), 130, 6, 2, steel); dot(px, x + flip * 5, 129, steel)
    for k in range(7):  # terraced crown: arches shrink upward, sunburst windows on each
        r = 28 - k * 3.6
        by = 130 - k * 11
        for j in range(int(by - r * 1.15) - 1, int(by) + 1):
            for i in range(int(64 - r) - 1, int(64 + r) + 2):
                nx, ny = (i + 0.5 - 64) / r, (j + 0.5 - by) / (r * 1.15)
                if nx * nx + ny * ny <= 1.0 and j <= by:
                    d = int(40 * (-nx)) - 10 + ((i + j) % 2) * 6
                    dot(px, i, j, shade(steel, d))
        for a in range(7):
            ang = math.pi * (a + 0.5) / 7
            for t in (0.62, 0.72, 0.8):
                x = int(64 - math.cos(ang) * r * t)
                y = int(by - math.sin(ang) * r * 1.15 * t)
                dot(px, x, y, (40, 46, 60, 255) if t < 0.8 else (250, 230, 160, 255))
        for i in range(int(64 - r), int(64 + r) + 1):
            dot(px, i, int(by), shade(steel, -50))
    for j in range(0, 62):  # needle
        hw = max(0, (j - 2) // 14)
        rect(px, 64 - hw, j, 1, 1, (236, 240, 246, 255))
        rect(px, 64 - hw + 1, j, max(1, hw * 2), 1, (160, 168, 180, 255))
    glow(px, 64, 90, 26, (255, 240, 200), 0.18)
    rect(px, 50, 286, 28, 32, (40, 36, 34, 255))  # entrance
    rect(px, 52, 288, 24, 8, (200, 160, 90, 255))
    for i in range(53, 76, 6):
        rect(px, i, 298, 4, 20, (110, 140, 170, 255)); rect(px, i, 298, 1, 20, (170, 200, 220, 255))
    rect(px, 0, 316, 128, 4, (110, 106, 100, 255))
    selout(px, -45)
    return px

def transamerica():
    """SF: white four-sided pyramid with its two 'wings' and the lit spire."""
    rng = random.Random(600)
    px = blank(128, 320)
    white = (226, 226, 220, 255)
    top, base = 18, 300
    for j in range(top, base):
        f = (j - top) / (base - top)
        hw = int(6 + f * 48)
        for i in range(64 - hw, 64 + hw):
            lit = i < 64 + hw // 3
            c = white if lit else shade(white, -40)
            if (j - top) % 7 in (4, 5) and (i - (64 - hw)) % 5 in (1, 2) and abs(i - 64) < hw - 2:
                c = lit_window(rng, 0.25) if lit else shade(lit_window(rng, 0.25), -25)
            dot(px, i, j, c)
    for side in (-1, 1):  # elevator / stair wings near the top
        x = 64 + side * 9 - (4 if side < 0 else 0)
        rect(px, x, 60, 4, 70, shade(white, 10 if side < 0 else -46))
    for j in range(0, top + 1):  # aluminium spire
        rect(px, 63, j, 2, 1, (210, 216, 224, 255))
    glow(px, 64, 4, 6, (255, 250, 220), 0.5)
    rect(px, 38, 290, 52, 10, shade(white, -20))  # podium
    rect(px, 52, 292, 24, 8, (60, 70, 84, 255))
    rect(px, 0, 316, 128, 4, (110, 106, 100, 255))
    for j in range(300, 316):
        rect(px, 24, j, 80, 1, shade(white, -10 - (j - 300)))
    selout(px, -45)
    return px

def coit_tower():
    """SF: fluted concrete column on a green hill, open arcade at the top."""
    px = blank(128, 320)
    conc = (222, 212, 192, 255)
    for j in range(250, 320):  # Telegraph Hill
        hw = int(30 + (j - 250) * 0.5)
        for i in range(64 - hw, 64 + hw):
            dot(px, i, j, shade((86, 142, 76, 255), ((i * 7 + j * 3) % 9) - 4 - (8 if i > 64 + hw // 3 else 0)))
    for i, x in enumerate(range(46, 82, 4)):  # flutes
        rect(px, x, 70, 4, 184, shade(conc, 18 - i * 6))
        rect(px, x + 3, 70, 1, 184, shade(conc, -30 - i * 3))
    rect(px, 42, 52, 44, 20, shade(conc, 8))  # crown with arcade windows
    for x in range(46, 82, 7):
        rect(px, x, 56, 4, 11, (52, 60, 76, 255))
        rect(px, x, 56, 4, 2, (240, 210, 140, 255))
    rect(px, 40, 50, 48, 3, shade(conc, 24))
    rect(px, 46, 44, 36, 6, shade(conc, 4))
    glow(px, 64, 60, 24, (255, 232, 170), 0.2)
    rect(px, 54, 230, 20, 24, (60, 52, 44, 255))  # door
    rect(px, 56, 232, 16, 3, (200, 170, 100, 255))
    selout(px, -45)
    return px

# ---------- dogs (16x10 frames x2; head must stay at x9-14, y0-4 for hats / collars) ----------
# W body, H highlight, D shade, S saddle, M mask/ears, B belly, K black, P pink
DOGS = {
    "husky": (["..........M..M..",
               "...D......MMMM..",
               "..DWD....MMKMWW.",
               "..DW.....WWWWWWK",
               "...DWSSSSSWWWWW.",
               "....SSSSSSSWWWP.",
               "....HWWWWWWWWW..",
               "....DBBBBBBBBD.."],
              ((236, 236, 242), (120, 126, 142), (110, 116, 132), (252, 252, 252))),
    "pug": (["..........M..M..",
             "..........WWWW..",
             "...DD....WWKWKM.",
             "..D..D...WMMMMK.",
             "...DDWWWWWMMMM..",
             "....WHHHHWWWWP..",
             "....WWWWWWWWWW..",
             "....DBBBBBBBBD.."],
            ((222, 184, 135), (222, 184, 135), (52, 42, 38), (236, 208, 168))),
    "chihuahua": ([".........M...M..",
                   ".........MM.MM..",
                   "..........WWKWW.",
                   "...D......WWWWWK",
                   "..D.WHHHHWWWWP..",
                   "..DWWWWWWWWWW...",
                   "....WWWWWWWWW...",
                   "....DBBBBBBBD..."],
                  ((206, 152, 96), (206, 152, 96), (170, 116, 66), (238, 216, 180))),
    "great_dane": (["..........MM....",
                    ".........MWWW...",
                    ".........WWKWW..",
                    "..D.....WWWWWWMK",
                    "...DWWWWWWWWWMM.",
                    "...WHHHHHHWWW...",
                    "...WWWWWWWWWW...",
                    "...DBBBBBBBBD..."],
                   ((122, 128, 140), (122, 128, 140), (88, 94, 106), (150, 156, 168))),
    "mastiff": (["..........MM....",
                 ".........MWWWW..",
                 "..D......WWKWWM.",
                 "..DD.....WMMMMMK",
                 "...DWWWWWWMMMMM.",
                 "...WHHHHHHWWWWP.",
                 "...WWWWWWWWWWW..",
                 "...DBBBBBBBBBD.."],
                ((206, 166, 116), (206, 166, 116), (62, 48, 42), (224, 190, 146))),
}
DOG_LEGS = {  # near legs W / paws G, far legs D; frame 0 planted, frame 1 mid-stride
    "default": (["....WD....WD....", "....GG....GG...."], [".....W.D..D.W...", "....G...GG...G.."]),
    "great_dane": (["...WD.....WD....", "...GG.....GG...."], ["....W.D...D.W...", "...G...G.G...G.."]),
}

def dog_sheet(rows, colors, legs):
    body, saddle, mask, belly = colors
    pal = {".": T, "W": rgba(body), "H": shade(body, 22), "D": shade(body, -34), "S": rgba(saddle),
           "M": rgba(mask), "B": rgba(belly), "G": shade(body, -55), "K": K, "P": (240, 140, 150, 255)}
    frames = []
    for leg in legs:
        grid = rows + list(leg)
        px = [[pal[c] for c in row] for row in grid]
        selout(px, -48)
        for j, row in enumerate(grid):  # keep eye and nose pure black after the outline pass
            for i, c in enumerate(row):
                if c == "K":
                    px[j][i] = K
        frames.append(px)
    return [a + b for a, b in zip(*frames)]

# ---------- critters (same sizes as before; shaded and outlined) ----------
CRITTERS = {
    "rat": ({".": T, "B": (134, 118, 108, 255), "H": (160, 146, 136, 255), "D": (92, 80, 72, 255),
             "K": K, "P": (228, 168, 170, 255)},
            ["..........HP..",
             ".HHHHHHHHHBKB.",
             "BBBBBBBBBBBBBP",
             "P.DBBBBBBBD...",
             "..DD..DD......"]),
    "pigeon": ({".": T, "B": (124, 134, 150, 255), "H": (156, 166, 182, 255), "D": (86, 96, 112, 255),
                "G": (90, 184, 130, 255), "V": (150, 90, 170, 255), "K": K, "O": (226, 142, 64, 255)},
               ["....HB......",
                "...BKBO.....",
                "...GVB......",
                "..BHHHHB....",
                ".BBBBBBBDD..",
                ".DBBBBBBBD..",
                "..DDBBBD....",
                "....OO......"]),
    "squirrel": ({".": T, "R": (168, 106, 60, 255), "H": (200, 140, 86, 255), "D": (118, 70, 40, 255),
                  "K": K, "C": (234, 214, 192, 255)},
                 ["..DD..........",
                  ".DRRD.........",
                  ".DRHD.....RR..",
                  "..DRD.....RKR.",
                  "..DRDHHHHRRRR.",
                  "...DRRRRRCCRR.",
                  "....RRRRRRRR..",
                  ".....RR..RR..."]),
    "raccoon": ({".": T, "G": (142, 142, 148, 255), "H": (176, 176, 182, 255), "D": (96, 96, 102, 255),
                 "K": (32, 32, 38, 255), "W": (226, 226, 226, 255), "R": (60, 60, 66, 255)},
                ["...........GG.G.",
                 "..........GHHHG.",
                 "R.........KKWKKW",
                 "WR....GGGGGWWWK.",
                 "RW.GHHHHHHGGW...",
                 "WRGGGGGGGGGGG...",
                 ".WRGGGGGGGGGG...",
                 "..RGGGGGGGGGD...",
                 "...GD.GD.GD.GD..",
                 "...DD.DD.DD.DD.."]),
    "cat": ({".": T, "O": (228, 142, 62, 255), "H": (246, 176, 96, 255), "D": (186, 104, 44, 255),
             "W": (248, 238, 222, 255), "K": K, "P": (240, 150, 160, 255)},
            ["O...O....",
             "OHHHO....",
             "OKOKO....",
             "OOPOO....",
             ".OHHHHO..",
             ".OWWODOD.",
             ".OWWOOOOD",
             ".DO.DOO.D"]),
}
DRAWN_LEFT = {"pigeon", "cat"}  # mirrored so every critter faces right; game code sets flip_h when moving left

def critter(name):
    pal, rows = CRITTERS[name]
    px = [[pal[c] for c in row] for row in rows]
    selout(px, -36)
    for j, row in enumerate(rows):
        for i, c in enumerate(row):
            if c == "K":
                px[j][i] = pal["K"]
    if name in DRAWN_LEFT:
        px = [r[::-1] for r in px]
    return px

if __name__ == "__main__":
    for name, fn in [("tree", tree), ("fountain", fountain), ("hydrant", hydrant), ("trashcan", trashcan),
                     ("manhole", manhole), ("water_bowl", water_bowl), ("subway", subway), ("bodega", bodega),
                     ("empire_state", empire), ("chrysler", chrysler),
                     ("transamerica", transamerica), ("coit_tower", coit_tower)]:
        write_png(f"{name}.png", fn())
    for breed, (rows, colors) in DOGS.items():
        write_png(f"dog_{breed}.png", dog_sheet(rows, colors, DOG_LEGS.get(breed, DOG_LEGS["default"])))
    for name in CRITTERS:
        write_png(f"{name}.png", critter(name))
    print("props done")
