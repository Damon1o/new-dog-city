"""Themed shop interiors for New Dog City: floor / wall tiles and props for the gas station,
pizzeria, cafe and corner shop (scripts/data/rooms.gd). Pure stdlib, seeded.
Run: python tools/gen_interiors.py   (then godot --headless --import for the .import files)

Props are drawn at 1x and placed at scale 2.0 like shelf / counter. Walls are 32x96 so one tile
covers the whole back wall (game.gd WALL_H) without repeating vertically."""
import os, random
import gen_buildings as gb
from gen_buildings import T, rect, dot, shade
from gen_props import blank, ellipse, shadow, ball, cyl, selout, text2, glow, blend

gb.OUT = os.path.join(os.path.dirname(__file__), "..", "assets")
write_png = gb.write_png
GLASS = (170, 215, 230, 255)
CHROME = (180, 186, 194, 255)

def fill(w, h, c):
    return [[c] * w for _ in range(h)]

def speckle(px, rng, n, d):
    for _ in range(n):
        i, j = rng.randrange(len(px[0])), rng.randrange(len(px))
        px[j][i] = shade(px[j][i], rng.choice(d))

def counter_body(px, y, w, top, front):
    """Shop counter front from row y down: lit top edge, panel line, kick plate."""
    rect(px, 0, y, w, len(px) - y, front)
    rect(px, 0, y, w, 4, top)
    rect(px, 0, y + 4, w, 1, shade(top, -40))
    rect(px, 3, y + 9, w - 6, 1, shade(front, -25))
    rect(px, 0, len(px) - 3, w, 3, shade(front, -45))

def register(px, x, y):
    rect(px, x, y + 3, 14, 7, (70, 74, 80, 255))
    rect(px, x + 1, y + 4, 12, 1, (110, 114, 120, 255))
    rect(px, x + 3, y, 9, 4, (40, 44, 48, 255))
    rect(px, x + 4, y + 1, 7, 2, (120, 220, 140, 255))
    for k in range(3):
        dot(px, x + 3 + k * 3, y + 7, (200, 200, 200, 255))

# ---------- floors (32x32) and walls (32x96) ----------
def gas_floor():
    px = fill(32, 32, (214, 214, 208, 255))
    rect(px, 0, 0, 16, 16, (186, 192, 198, 255)); rect(px, 16, 16, 16, 16, (186, 192, 198, 255))
    speckle(px, random.Random(3), 60, (-18, 14))
    rect(px, 0, 0, 32, 1, (160, 162, 160, 255)); rect(px, 0, 0, 1, 32, (160, 162, 160, 255))
    return px

def gas_wall():
    px = fill(32, 96, (236, 238, 236, 255))
    for j in range(0, 60, 8):  # white tiles
        rect(px, 0, j, 32, 1, (205, 210, 210, 255))
    for i in range(0, 32, 8):
        rect(px, i, 0, 1, 60, (205, 210, 210, 255))
    rect(px, 0, 60, 32, 6, (40, 110, 200, 255)); rect(px, 0, 66, 32, 3, (230, 60, 50, 255))  # brand stripe
    rect(px, 0, 69, 32, 27, (120, 128, 136, 255)); rect(px, 0, 69, 32, 1, (150, 156, 162, 255))
    rect(px, 0, 92, 32, 4, (80, 86, 92, 255))
    return px

def pizza_floor():
    px = fill(32, 32, (238, 234, 222, 255))
    for j in range(0, 32, 8):
        for i in range(0, 32, 8):
            if (i + j) // 8 % 2:
                rect(px, i, j, 8, 8, (34, 32, 34, 255))
    speckle(px, random.Random(5), 30, (-10, 10))
    return px

def pizza_wall():
    brick = (160, 62, 44, 255)
    px = fill(32, 96, brick)
    rng = random.Random(8)
    for row in range(0, 62, 6):  # brick courses
        off = 0 if row // 6 % 2 else 8
        rect(px, 0, row, 32, 1, (205, 190, 170, 255))
        for i in range(-16, 32, 16):
            rect(px, i + off + 1, row + 1, 15, 5, shade(brick, rng.randint(-20, 14)))
            rect(px, i + off, row, 1, 6, (205, 190, 170, 255))
    rect(px, 0, 62, 32, 4, (240, 220, 160, 255)); rect(px, 0, 66, 32, 2, (40, 120, 60, 255))  # cream + green rail
    rect(px, 0, 68, 32, 28, (230, 222, 200, 255))
    for i in range(0, 32, 8):  # beadboard
        rect(px, i, 68, 1, 28, (200, 190, 168, 255))
    rect(px, 0, 92, 32, 4, (90, 60, 40, 255))
    return px

def cafe_floor():
    oak = (150, 104, 70, 255)
    px = fill(32, 32, oak)
    rng = random.Random(11)
    for j in range(0, 32, 8):  # planks, staggered joints
        tone = rng.randint(-16, 16)
        rect(px, 0, j, 32, 8, shade(oak, tone))
        rect(px, 0, j, 32, 1, (96, 64, 42, 255))
        rect(px, (j * 3 + 5) % 32, j, 1, 8, (96, 64, 42, 255))
        for _ in range(4):  # grain
            rect(px, rng.randrange(32), j + rng.randint(2, 6), rng.randint(3, 7), 1, shade(oak, tone - 14))
    return px

def cafe_wall():
    px = fill(32, 96, (62, 112, 98, 255))
    for j in range(0, 58, 6):
        rect(px, 0, j, 32, 1, (68, 120, 105, 255))
    rect(px, 0, 58, 32, 3, (190, 160, 110, 255))  # picture rail
    rect(px, 0, 61, 32, 35, (110, 74, 50, 255))
    for i in range(0, 32, 16):  # wainscot panels
        rect(px, i + 2, 65, 12, 24, (124, 86, 58, 255))
        rect(px, i + 2, 65, 12, 1, (148, 108, 76, 255)); rect(px, i + 2, 88, 12, 1, (84, 56, 38, 255))
    rect(px, 0, 92, 32, 4, (70, 46, 32, 255))
    return px

def store_floor():
    px = fill(32, 32, (226, 222, 212, 255))
    speckle(px, random.Random(13), 70, (-14, -8, 8))
    rect(px, 0, 0, 32, 1, (196, 192, 182, 255)); rect(px, 0, 0, 1, 32, (196, 192, 182, 255))
    return px

def store_wall():
    px = fill(32, 96, (232, 214, 150, 255))
    for j in range(8, 56, 6):  # pegboard
        for i in range(3, 32, 6):
            dot(px, i, j, (196, 176, 116, 255))
    rect(px, 0, 58, 32, 5, (220, 80, 70, 255))
    rect(px, 0, 63, 32, 33, (90, 150, 130, 255)); rect(px, 0, 63, 32, 1, (120, 180, 160, 255))
    rect(px, 0, 92, 32, 4, (60, 100, 86, 255))
    return px

# ---------- gas station ----------
def cooler():
    """48x60 drinks fridge: lit sign, two glass doors, rows of bottles."""
    px = blank(48, 60)
    shadow(px, 24, 58, 23, 2)
    rect(px, 0, 0, 48, 58, (60, 66, 74, 255))
    rect(px, 1, 1, 46, 8, (30, 130, 220, 255)); text2(px, "COLD", 24, 2, (240, 250, 255, 255), 1)
    rng = random.Random(21)
    drinks = [(230, 60, 50), (60, 180, 80), (250, 200, 50), (60, 120, 230), (240, 240, 240), (240, 130, 40)]
    for d in range(2):
        x0 = 3 + d * 22
        rect(px, x0, 11, 20, 43, (150, 200, 215, 255))
        for s in range(4):
            y = 14 + s * 10
            rect(px, x0, y + 8, 20, 1, (110, 120, 130, 255))  # wire shelf
            c = rng.choice(drinks) + (255,)
            h = 7 if s % 2 else 5
            for i in range(x0 + 1, x0 + 19, 3):
                rect(px, i, y + 8 - h, 2, h, c)
                dot(px, i, y + 8 - h, shade(c, 60))
        for j in range(11, 54):  # glass sheen
            blend(px, x0 + 3 + (j - 11) // 4, j, (255, 255, 255), 0.25)
        rect(px, x0 + 17, 26, 2, 10, CHROME)  # handle
    rect(px, 0, 55, 48, 3, (40, 44, 50, 255))
    selout(px, -40)
    return px

def snack_rack():
    """40x40 wire rack of chip bags."""
    px = blank(40, 40)
    shadow(px, 20, 38, 19, 2)
    rng = random.Random(22)
    bags = [(240, 200, 40), (220, 50, 50), (60, 110, 220), (60, 170, 70), (240, 120, 30), (160, 60, 200)]
    rect(px, 2, 2, 2, 36, (90, 94, 100, 255)); rect(px, 36, 2, 2, 36, (90, 94, 100, 255))
    rect(px, 2, 1, 36, 3, (230, 60, 50, 255))
    for s in range(3):
        y = 6 + s * 11
        for i in range(5, 34, 7):
            c = rng.choice(bags) + (255,)
            rect(px, i, y, 6, 9, c)
            rect(px, i, y, 6, 1, shade(c, 50)); rect(px, i + 5, y + 1, 1, 8, shade(c, -40))
            rect(px, i + 1, y + 3, 4, 3, shade(c, 70))  # label
        rect(px, 2, y + 9, 36, 1, (150, 156, 164, 255))
    selout(px, -40)
    return px

def gas_counter():
    """64x48 counter: register, lottery case, slushie machine with two tanks."""
    px = blank(64, 48)
    counter_body(px, 22, 64, (200, 205, 210, 255), (70, 110, 170, 255))
    register(px, 44, 12)
    rect(px, 26, 14, 14, 8, (240, 200, 60, 255)); rect(px, 27, 15, 12, 6, GLASS)  # lottery case
    for k, c in enumerate([(230, 60, 50, 255), (60, 170, 80, 255), (250, 220, 60, 255)]):
        rect(px, 28 + k * 4, 16, 3, 4, c)
    rect(px, 2, 18, 20, 4, (60, 64, 70, 255))  # slushie base
    for t, c in enumerate([(70, 140, 250, 255), (240, 60, 80, 255)]):
        x = 3 + t * 10
        rect(px, x, 2, 8, 16, (210, 230, 240, 255))
        rect(px, x + 1, 6, 6, 12, c)
        for j in range(6, 18, 3):
            dot(px, x + 2 + (j // 3) % 4, j, shade(c, 60))
        rect(px, x, 1, 8, 2, (60, 64, 70, 255))
        rect(px, x + 3, 18, 2, 3, (40, 40, 40, 255))
    selout(px, -40)
    return px

def price_board():
    """48x20 wall sign with fuel prices (hung, no collider)."""
    px = blank(48, 20)
    rect(px, 0, 0, 48, 20, (30, 32, 36, 255))
    rect(px, 1, 1, 46, 18, (20, 22, 26, 255))
    text2(px, "GAS", 12, 3, (250, 220, 70, 255), 1)
    text2(px, "$3.99", 34, 3, (255, 90, 70, 255), 1)
    text2(px, "DIESEL", 14, 11, (250, 220, 70, 255), 1)
    text2(px, "$4.29", 38, 11, (255, 90, 70, 255), 1)
    return px

# ---------- pizzeria ----------
def pizza_oven():
    """64x64 brick dome oven with fire in the mouth and a steel flue."""
    px = blank(64, 64)
    shadow(px, 32, 62, 30, 2)
    rng = random.Random(31)
    brick = (170, 70, 48, 255)
    ellipse(px, 32, 40, 28, 26, brick)
    for j in range(14, 40, 4):  # bricks on the dome
        for i in range(0, 64, 8):
            x = i + (j // 4 % 2) * 4
            tone = shade(brick, rng.randint(-24, 12))
            for a in range(x, x + 7):
                for b in range(j, j + 3):
                    if 0 <= a < 64 and px[b][a][3] == 255:
                        px[b][a] = tone
    rect(px, 28, 0, 8, 16, (150, 156, 164, 255)); rect(px, 29, 0, 2, 16, (200, 206, 214, 255))  # flue
    rect(px, 4, 40, 56, 24, (120, 116, 110, 255)); rect(px, 4, 40, 56, 2, (160, 156, 150, 255))  # stone base
    for j in range(46, 62, 6):
        rect(px, 4, j, 56, 1, (96, 92, 88, 255))
    ellipse(px, 32, 34, 14, 10, (30, 20, 16, 255))  # mouth
    for k, c in enumerate([(250, 210, 80), (250, 150, 40), (220, 70, 30)]):
        ellipse(px, 32, 37 - k, 10 - k * 3, 4 - k, c + (255,))
    glow(px, 32, 36, 18, (255, 180, 60), 0.35)
    rect(px, 16, 40, 32, 3, (200, 196, 190, 255))  # stone lip
    selout(px, -40)
    return px

def pizza_counter():
    """64x44 glass display of whole pies, register on top."""
    px = blank(64, 44)
    counter_body(px, 20, 64, (230, 222, 200, 255), (200, 50, 40, 255))
    for i in range(0, 64, 8):  # white stripes on the red front
        rect(px, i, 30, 4, 11, (240, 236, 226, 255))
    rect(px, 2, 4, 44, 16, GLASS); rect(px, 2, 4, 44, 1, (230, 245, 250, 255))
    for n, top in enumerate([(220, 60, 40), (240, 200, 90), (220, 60, 40)]):
        cx = 10 + n * 14
        ellipse(px, cx, 15, 6, 3, (220, 160, 80, 255))
        ellipse(px, cx, 15, 5, 2, top + (255,))
        for k in range(3):
            dot(px, cx - 3 + k * 3, 15 - k % 2, (150, 30, 30, 255))
    for j in range(4, 20):
        blend(px, 6 + (j - 4) // 3, j, (255, 255, 255), 0.35)
    register(px, 48, 10)
    selout(px, -40)
    return px

def pizza_table():
    """40x36 table in a checked cloth, two chairs, a slice and a shaker."""
    px = blank(40, 36)
    shadow(px, 20, 34, 19, 2)
    for x in (2, 32):  # chairs
        rect(px, x, 6, 6, 26, (110, 70, 44, 255)); rect(px, x + 1, 7, 4, 3, (140, 96, 62, 255))
    rect(px, 8, 10, 24, 12, (240, 240, 236, 255))
    for j in range(10, 22, 3):
        for i in range(8, 32, 3):
            if (i // 3 + j // 3) % 2:
                rect(px, i, j, 3, 3, (210, 50, 44, 255))
    rect(px, 8, 22, 24, 8, (190, 40, 36, 255))  # cloth drop
    for i in range(8, 32, 6):
        rect(px, i, 22, 3, 8, (236, 232, 226, 255))
    rect(px, 11, 30, 2, 4, (60, 40, 30, 255)); rect(px, 27, 30, 2, 4, (60, 40, 30, 255))
    rect(px, 12, 12, 7, 1, (200, 140, 70, 255))  # slice: crust then cheese wedge
    for k in range(5):
        rect(px, 13 + k // 2, 13 + k, 6 - k, 1, (240, 190, 80, 255))
    dot(px, 14, 14, (180, 40, 30, 255))
    rect(px, 25, 11, 3, 5, (230, 230, 225, 255)); rect(px, 25, 10, 3, 1, (160, 166, 172, 255))
    selout(px, -40)
    return px

def pizza_sign():
    """48x18 neon wall sign (hung, no collider)."""
    px = blank(48, 18)
    rect(px, 0, 0, 48, 18, (40, 20, 16, 255))
    glow(px, 24, 9, 22, (255, 90, 60), 0.25)
    text2(px, "PIZZA", 24, 4, (255, 120, 80, 255), 2)
    return px

# ---------- cafe ----------
def espresso_counter():
    """64x48 wood bar: chrome espresso machine, cups, register."""
    px = blank(64, 48)
    counter_body(px, 22, 64, (200, 168, 120, 255), (110, 74, 50, 255))
    for i in range(4, 60, 8):  # slatted front
        rect(px, i, 28, 1, 15, (90, 60, 40, 255))
    cyl(px, 6, 6, 24, 14, CHROME)
    rect(px, 6, 4, 24, 3, (60, 64, 70, 255))
    for k in range(2):  # group heads + cups
        rect(px, 11 + k * 10, 14, 4, 3, (60, 64, 70, 255)); rect(px, 12 + k * 10, 18, 3, 4, (245, 242, 235, 255))
    dot(px, 10, 9, (230, 60, 50, 255)); dot(px, 26, 9, (90, 210, 110, 255))
    rect(px, 8, 1, 3, 3, (240, 240, 240, 255)); rect(px, 12, 1, 3, 3, (240, 240, 240, 255))  # cups on top
    for k in range(3):
        rect(px, 32 + k * 4, 17, 3, 5, (240, 236, 226, 255))
    register(px, 46, 12)
    selout(px, -40)
    return px

def pastry_case():
    """48x40 glass case: croissants, donuts, cupcakes."""
    px = blank(48, 40)
    shadow(px, 24, 38, 23, 2)
    rect(px, 0, 26, 48, 12, (110, 74, 50, 255)); rect(px, 0, 26, 48, 2, (160, 120, 80, 255))
    rect(px, 1, 2, 46, 24, GLASS); rect(px, 0, 1, 48, 2, (200, 168, 120, 255))
    rect(px, 1, 14, 46, 1, (200, 230, 240, 255))
    for i in range(4, 44, 10):  # top shelf croissants
        ellipse(px, i + 3, 10, 4, 2, (220, 150, 60, 255)); dot(px, i + 2, 9, (250, 200, 110, 255))
    for i in range(4, 44, 10):  # bottom: donut / cupcake
        if i // 10 % 2:
            ellipse(px, i + 3, 22, 4, 2, (240, 130, 170, 255)); dot(px, i + 3, 22, (190, 220, 235, 255))
        else:
            rect(px, i + 1, 21, 5, 3, (190, 130, 80, 255)); ellipse(px, i + 3, 20, 3, 2, (250, 245, 235, 255))
    for j in range(2, 26):
        blend(px, 4 + (j - 2) // 3, j, (255, 255, 255), 0.3)
    selout(px, -40)
    return px

def cafe_table():
    """32x32 round bistro table, two chairs, two mugs."""
    px = blank(32, 32)
    shadow(px, 16, 30, 15, 2)
    for x in (0, 26):
        rect(px, x, 8, 6, 20, (60, 50, 44, 255)); rect(px, x + 1, 9, 4, 3, (90, 76, 66, 255))
        rect(px, x + 1, 28, 1, 3, (40, 34, 30, 255)); rect(px, x + 4, 28, 1, 3, (40, 34, 30, 255))
    rect(px, 15, 16, 2, 13, (50, 50, 54, 255)); rect(px, 11, 29, 10, 2, (50, 50, 54, 255))
    ellipse(px, 16, 13, 10, 5, (170, 120, 80, 255)); ellipse(px, 16, 12, 9, 4, (200, 150, 100, 255))
    for x in (11, 19):
        rect(px, x, 9, 3, 3, (245, 242, 235, 255)); dot(px, x + 1, 9, (110, 70, 40, 255))
    selout(px, -40)
    return px

def plant():
    """16x32 potted plant."""
    px = blank(16, 32)
    shadow(px, 8, 31, 7, 1)
    rect(px, 3, 22, 10, 9, (190, 100, 60, 255)); rect(px, 2, 21, 12, 2, (210, 120, 74, 255))
    rect(px, 10, 23, 2, 7, (160, 80, 48, 255))
    rng = random.Random(41)
    for _ in range(9):
        ball(px, rng.randint(3, 12), rng.randint(4, 18), rng.randint(2, 4), (70, 150, 70, 255))
    selout(px, -40)
    return px

def chalk_menu():
    """48x24 chalkboard menu (hung, no collider)."""
    px = blank(48, 24)
    rect(px, 0, 0, 48, 24, (120, 84, 56, 255))
    rect(px, 2, 2, 44, 20, (38, 46, 42, 255))
    text2(px, "COFFEE", 24, 4, (240, 240, 230, 255), 1)
    for k, w in enumerate([30, 24, 34]):
        rect(px, 7, 12 + k * 3, w, 1, (180, 190, 184, 255))
        dot(px, 42, 12 + k * 3, (250, 220, 120, 255))
    return px

# ---------- corner shop ----------
def gondola():
    """48x40 metal shelving with boxes, jars and price tags."""
    px = blank(48, 40)
    shadow(px, 24, 38, 23, 2)
    rect(px, 0, 0, 48, 38, (170, 176, 184, 255)); rect(px, 1, 1, 46, 36, (140, 146, 154, 255))
    rng = random.Random(51)
    goods = [(220, 60, 50), (250, 200, 60), (70, 130, 210), (80, 170, 100), (240, 240, 235), (240, 140, 50), (170, 90, 200)]
    for s in range(3):
        y = 3 + s * 12
        for i in range(3, 45, 6):
            c = rng.choice(goods) + (255,)
            h = rng.randint(6, 9)
            rect(px, i, y + 9 - h, 5, h, c)
            if rng.random() < 0.4:  # jar lid
                rect(px, i, y + 9 - h, 5, 2, (230, 230, 230, 255))
            else:  # box side + label
                rect(px, i + 4, y + 10 - h, 1, h - 1, shade(c, -40))
                rect(px, i + 1, y + 11 - h, 3, 2, shade(c, 70))
        rect(px, 1, y + 9, 46, 2, (210, 214, 220, 255))
        for i in range(4, 46, 12):
            rect(px, i, y + 9, 4, 2, (250, 230, 80, 255))  # price tags
    selout(px, -40)
    return px

def shop_counter():
    """64x44 counter: register, candy rack, newspaper stack."""
    px = blank(64, 44)
    counter_body(px, 20, 64, (230, 220, 190, 255), (90, 150, 130, 255))
    register(px, 44, 10)
    rect(px, 24, 8, 14, 12, (200, 60, 50, 255))  # candy rack
    for j in range(10, 20, 4):
        for i in range(25, 37, 3):
            rect(px, i, j, 2, 3, [(250, 220, 60, 255), (80, 170, 230, 255), (250, 250, 250, 255)][(i + j) % 3])
    for k in range(4):  # papers
        rect(px, 4, 19 - k, 14, 1, (230, 228, 220, 255) if k % 2 else (200, 198, 190, 255))
    rect(px, 5, 16, 6, 1, (60, 60, 60, 255))
    selout(px, -40)
    return px

def sale_sign():
    """40x18 wall banner (hung, no collider)."""
    px = blank(40, 18)
    rect(px, 0, 0, 40, 18, (240, 220, 80, 255)); rect(px, 1, 1, 38, 16, (220, 60, 50, 255))
    text2(px, "SALE", 20, 4, (255, 245, 200, 255), 2)
    return px

ALL = {"gas_floor": gas_floor, "gas_wall": gas_wall, "pizza_floor": pizza_floor, "pizza_wall": pizza_wall,
       "cafe_floor": cafe_floor, "cafe_wall": cafe_wall, "store_floor": store_floor, "store_wall": store_wall,
       "cooler": cooler, "snack_rack": snack_rack, "gas_counter": gas_counter, "price_board": price_board,
       "pizza_oven": pizza_oven, "pizza_counter": pizza_counter, "pizza_table": pizza_table, "pizza_sign": pizza_sign,
       "espresso_counter": espresso_counter, "pastry_case": pastry_case, "cafe_table": cafe_table, "plant": plant,
       "chalk_menu": chalk_menu, "gondola": gondola, "shop_counter": shop_counter, "sale_sign": sale_sign}

if __name__ == "__main__":
    for name, fn in ALL.items():
        write_png(f"{name}.png", fn())
    print("interiors done")
