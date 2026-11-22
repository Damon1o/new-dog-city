"""Building exteriors for New Dog City: 48 procedural NYC designs + custom shop / airport fronts.
Pure stdlib, seeded, so reruns give identical PNGs. Run: python tools/gen_buildings.py
Writes assets/bld/<kind>_<n>.png (kind = apartment | office | shop) and assets/bld/<custom>.png."""
import os, random, struct, zlib

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "bld")
VARIANTS = 16  # per generic kind; city_builder.gd VARIANTS must match
T = (0, 0, 0, 0)

def write_png(name, px):
    h, w = len(px), len(px[0])
    raw = b"".join(b"\x00" + b"".join(struct.pack("4B", *p) for p in row) for row in px)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(png)

def blank(w, h):
    return [[T] * w for _ in range(h)]

def rect(px, x, y, w, h, c):
    for j in range(max(0, y), min(len(px), y + h)):
        for i in range(max(0, x), min(len(px[0]), x + w)):
            px[j][i] = c

def dot(px, x, y, c):
    if 0 <= y < len(px) and 0 <= x < len(px[0]):
        px[y][x] = c

def shade(c, d):
    return tuple(max(0, min(255, v + d)) for v in c[:3]) + (255,)

def outline(px, x, y, w, h, c):
    rect(px, x, y, w, 1, c); rect(px, x, y + h - 1, w, 1, c)
    rect(px, x, y, 1, h, c); rect(px, x + w - 1, y, 1, h, c)

# 3x5 pixel font for signs
FONT = {
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
    "E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
    "I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
    "M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
    "R": "110101110101101", "S": "011100010001110", "T": "111010010010010", "U": "101101101101111",
    "W": "101101111111101", "Y": "101101010010010", "Z": "111001010100111", " ": "000000000000000",
    "0": "111101101101111", "1": "010110010010111", "2": "110001010100111", "3": "110001010001110",
    "4": "101101111001001", "5": "111100110001110", "6": "011100111101111", "7": "111001010010010",
    "8": "111101111101111", "9": "111101111001110", ".": "000000000000010", "$": "011110010011110",
}

def text(px, s, cx, y, c):
    x = cx - (len(s) * 4 - 1) // 2
    for ch in s:
        for k, b in enumerate(FONT[ch]):
            if b == "1":
                dot(px, x + k % 3, y + k // 3, c)
        x += 4

# ---------- shared parts ----------
GLASS_DARK = (62, 78, 104, 255)
GLASS = (92, 120, 152, 255)
LIT = (240, 210, 120, 255)
LIT_DIM = (200, 160, 90, 255)
IRON = (38, 38, 44, 255)
CURB = (85, 80, 78, 255)

def window(px, x, y, w, h, frame, lit, rng):
    rect(px, x - 1, y - 1, w + 2, h + 2, frame)
    rect(px, x, y, w, h, (LIT if rng.random() < 0.5 else LIT_DIM) if lit else GLASS_DARK)
    if not lit:
        dot(px, x, y, GLASS); dot(px, x + 1, y, GLASS)  # glint
    if w >= 4:
        rect(px, x + w // 2, y, 1, h, frame)  # mullion
    rect(px, x - 1, y + h + 1, w + 2, 1, shade(frame, 30))  # sill

def bricks(px, x, y, w, h, c, rng):
    rect(px, x, y, w, h, c)
    mortar = shade(c, -22)
    for j in range(y + 3, y + h, 4):
        rect(px, x, j, w, 1, mortar)
    for j in range(y, y + h, 4):
        off = 0 if (j // 4) % 2 else 4
        for i in range(x + off, x + w, 8):
            rect(px, i, j, 1, 3, mortar)
    for _ in range(w * h // 40):  # weathered bricks
        dot(px, rng.randrange(x, x + w), rng.randrange(y, y + h), shade(c, rng.choice([-12, 10])))

def water_tower(px, cx, base):
    wood = (120, 82, 52, 255)
    rect(px, cx - 6, base - 18, 12, 12, wood)
    for i in range(cx - 6, cx + 6, 3):
        rect(px, i, base - 18, 1, 12, shade(wood, -25))
    rect(px, cx - 7, base - 15, 14, 1, IRON); rect(px, cx - 7, base - 10, 14, 1, IRON)
    for k in range(4):  # conical roof
        rect(px, cx - 6 + k * 2, base - 19 - k, 12 - k * 4, 1, shade(wood, -35))
    rect(px, cx - 5, base - 6, 1, 6, IRON); rect(px, cx + 4, base - 6, 1, 6, IRON)
    rect(px, cx - 5, base - 3, 10, 1, IRON)

def fire_escape(px, x, top, floor_h, floors, w):
    for f in range(floors):
        y = top + f * floor_h + floor_h - 3
        rect(px, x, y, w, 1, IRON)
        for i in range(x, x + w, 2):
            dot(px, i, y - 1, IRON); dot(px, i, y - 2, IRON)
        rect(px, x, y - 3, w, 1, IRON)
        if f < floors - 1:  # diagonal ladder down to the next landing
            for k in range(floor_h):
                dot(px, x + 2 + (k * (w - 4)) // floor_h, y + k, IRON)

def ac_unit(px, x, y):
    rect(px, x, y, 5, 3, (175, 175, 170, 255))
    rect(px, x, y + 2, 5, 1, (120, 120, 118, 255))

def door(px, cx, bottom, w, h, c, glass=False):
    rect(px, cx - w // 2 - 1, bottom - h - 1, w + 2, h + 1, shade(c, -40))
    rect(px, cx - w // 2, bottom - h, w, h, c)
    if glass:
        rect(px, cx - w // 2 + 1, bottom - h + 1, w - 2, h - 3, GLASS)
        rect(px, cx, bottom - h + 1, 1, h - 1, shade(c, -40))
    else:
        rect(px, cx - w // 2 + 1, bottom - h + 2, w - 2, h // 3, shade(c, 18))
    dot(px, cx + w // 2 - 2, bottom - h // 2, (220, 200, 90, 255))

def awning(px, x, y, w, c1, c2, stripe=True):
    for i in range(w):
        col = (c1 if (i // 4) % 2 == 0 else c2) if stripe else c1
        rect(px, x + i, y, 1, 5, col)
        dot(px, x + i, y + 5 + (i % 4 == 0), shade(col, -30))  # scalloped edge
    rect(px, x, y, w, 1, shade(c1, -45))

def cornice(px, x, y, w, c):
    rect(px, x - 2, y, w + 4, 3, shade(c, 25))
    rect(px, x - 2, y + 3, w + 4, 1, shade(c, -45))
    for i in range(x, x + w, 4):
        dot(px, i, y + 4, shade(c, -30))  # dentils

# ---------- generic kinds ----------
BRICK = [(140, 70, 55), (125, 85, 70), (160, 95, 70), (110, 60, 52), (150, 120, 95), (95, 75, 70), (170, 140, 110), (120, 100, 90)]

def apartment(n):
    """Walk-ups and brownstones: cornice, lintels, fire escape, stoop, water tower."""
    rng = random.Random(1000 + n)
    w = rng.choice([64, 68, 72, 76, 80])
    floors = rng.randint(4, 6)
    fh = 16
    body_h = floors * fh + 10
    h = body_h + 22
    px = blank(w, h)
    top = h - body_h
    c = BRICK[n % len(BRICK)] + (255,)
    if n % 3 == 2:  # brownstone: smooth stone
        c = rng.choice([(118, 78, 62), (132, 90, 70), (104, 70, 58)]) + (255,)
        rect(px, 0, top, w, body_h, c)
        for _ in range(w * body_h // 30):
            dot(px, rng.randrange(w), rng.randrange(top, h), shade(c, -8))
    else:
        bricks(px, 0, top, w, body_h, c, rng)
    trim = rng.choice([(205, 195, 175, 255), (190, 185, 180, 255), (90, 70, 60, 255)])
    cornice(px, 2, top, w - 4, trim)
    outline(px, 0, top, w, body_h, shade(c, -50))
    cols = (w - 8) // 12
    lit_p = rng.uniform(0.2, 0.6)
    for f in range(floors - 1):
        y = top + 8 + f * fh
        for k in range(cols):
            x = 6 + k * ((w - 12) // cols) + 2
            rect(px, x - 1, y - 2, 8, 1, trim)  # lintel
            window(px, x, y, 6, 8, shade(trim, -60), rng.random() < lit_p, rng)
            if rng.random() < 0.12:
                ac_unit(px, x, y + 7)
    if rng.random() < 0.6:
        fire_escape(px, w - 4 - min(26, w // 2), top + 4, fh, floors - 1, min(26, w // 2))
    gy = h - 2  # ground floor: stoop + door
    dc = rng.choice([(70, 45, 30, 255), (40, 60, 45, 255), (90, 30, 30, 255), (30, 40, 70, 255)])
    door(px, w // 2, gy - 6, 10, 14, dc)
    for s in range(3):
        rect(px, w // 2 - 7 - s * 2, gy - 6 + s * 2, 14 + s * 4, 2, shade((165, 155, 145, 255), -s * 10))
    rect(px, w // 2 - 9, gy - 14, 1, 8, IRON); rect(px, w // 2 + 8, gy - 14, 1, 8, IRON)
    for x in [6, w - 14]:
        window(px, x, gy - 14, 8, 7, shade(trim, -60), rng.random() < lit_p, rng)
    rect(px, 0, h - 2, w, 2, CURB)
    if rng.random() < 0.5:
        water_tower(px, rng.choice([12, w - 12]), top)
    elif rng.random() < 0.5:
        rect(px, 6, top - 5, 10, 5, (100, 100, 105, 255))  # stair bulkhead
        rect(px, 8, top - 4, 3, 4, IRON)
    return px

def office(n):
    """Four styles: glass curtain wall, art deco setback, limestone, dark steel."""
    rng = random.Random(2000 + n)
    style = n % 4
    w = rng.choice([64, 72, 80])
    h = rng.choice([118, 126, 134, 142])
    px = blank(w, h)
    lit_p = rng.uniform(0.25, 0.65)
    if style == 0:
        tint = rng.choice([(70, 110, 140), (80, 130, 125), (95, 105, 140)]) + (255,)
        top = 8
        rect(px, 2, top, w - 4, h - top, tint)
        for j in range(top + 2, h - 14, 5):
            rect(px, 2, j, w - 4, 1, shade(tint, -30))
        for i in range(2, w - 2, 6):
            rect(px, i, top, 1, h - top, (170, 180, 190, 255))
        for k in range(w + h):  # diagonal sky reflection band
            for d in range(6):
                x, y = k - d, h - 16 - k // 2
                if 2 < x < w - 2 and top < y < h - 14 and x % 6:
                    dot(px, x, y, shade(tint, 45))
        for j in range(top + 3, h - 14, 5):
            for i in range(3, w - 3, 6):
                if rng.random() < lit_p * 0.4:
                    rect(px, i, j, 5, 4, LIT_DIM)
        rect(px, 0, top - 2, w, 3, (150, 158, 168, 255))
        rect(px, w // 2 - 8, 0, 3, top - 2, (110, 110, 115, 255))  # antenna
        rect(px, w // 2 + 5, 3, 8, top - 5, (130, 130, 135, 255))  # HVAC
    elif style == 1:
        stone = rng.choice([(185, 175, 155), (170, 160, 140), (195, 185, 170)]) + (255,)
        tiers = [(0, w, 46, h), (8, w - 16, 22, 46), (16, w - 32, 6, 22)]
        for x, tw, y0, y1 in tiers:
            rect(px, x, y0, tw, y1 - y0, stone)
            outline(px, x, y0, tw, y1 - y0, shade(stone, -45))
            for i in range(x + 4, x + tw - 4, 6):
                rect(px, i, y0 + 3, 3, y1 - y0 - 6, GLASS_DARK)
                for j in range(y0 + 3, y1 - 3, 6):
                    rect(px, i, j + 4, 3, 1, shade(stone, -20))
                    if rng.random() < lit_p * 0.5:
                        rect(px, i, j, 3, 4, LIT)
            rect(px, x, y0, tw, 2, (205, 170, 90, 255))  # gold band
        rect(px, w // 2 - 1, 0, 2, 6, (205, 170, 90, 255))
    else:
        base_c = (200, 192, 175) if style == 2 else (58, 62, 72)
        c = shade(base_c + (255,), rng.randint(-15, 10))
        top = 10
        rect(px, 0, top, w, h - top, c)
        outline(px, 0, top, w, h - top, shade(c, -40))
        cornice(px, 2, top, w - 4, c)
        frame = shade(c, -55) if style == 2 else (150, 150, 160, 255)
        for j in range(top + 9, h - 22, 10):
            for i in range(5, w - 8, 9):
                window(px, i, j, 5, 6, frame, rng.random() < lit_p, rng)
        if style == 2:
            for i in range(4, w - 4, 12):  # entry columns
                rect(px, i, h - 22, 3, 20, shade(c, 20))
        rect(px, 8, top - 6, 12, 6, (115, 115, 120, 255))
        rect(px, w - 20, top - 4, 6, 4, (100, 100, 105, 255))
    rect(px, 0, h - 20, w, 2, (60, 60, 66, 255))  # lobby
    rect(px, 6, h - 16, w - 12, 12, (40, 46, 56, 255))
    for i in range(8, w - 8, 8):
        rect(px, i, h - 15, 6, 10, GLASS)
    door(px, w // 2, h - 2, 12, 13, (50, 55, 65, 255), glass=True)
    rect(px, 0, h - 2, w, 2, CURB)
    return px

SHOPS = ["DELI", "LAUNDRY", "BAGELS", "FLOWERS", "BOOKS", "BARBER", "PHARMACY", "TOYS",
         "SHOES", "PAWN", "NAILS", "HARDWARE", "BAKERY", "MARKET", "THRIFT", "TAILOR"]
AWN = [((200, 55, 50), (240, 235, 225)), ((40, 110, 70), (235, 230, 215)), ((40, 70, 140), (230, 230, 230)),
       ((215, 150, 40), (250, 240, 210)), ((120, 50, 110), (235, 220, 235)), ((30, 30, 35), (210, 60, 60))]

def shop(n):
    """Mixed use: lettered sign, awning, stocked window, apartments above."""
    rng = random.Random(3000 + n)
    w = rng.choice([72, 76, 80, 84])
    floors = rng.randint(2, 4)
    fh = 15
    store_h = 34
    h = floors * fh + store_h + 8
    px = blank(w, h)
    top = 8
    c = BRICK[(n * 3) % len(BRICK)] + (255,)
    bricks(px, 0, top, w, h - top, c, rng)
    trim = rng.choice([(210, 200, 185, 255), (170, 165, 160, 255)])
    cornice(px, 2, top, w - 4, trim)
    outline(px, 0, top, w, h - top, shade(c, -50))
    for f in range(floors):
        y = top + 7 + f * fh
        for x in range(6, w - 10, 13):
            window(px, x, y, 7, 7, shade(trim, -70), rng.random() < 0.4, rng)
    if rng.random() < 0.4:
        fire_escape(px, 4, top + 2, fh, floors, 24)
    sy = h - store_h
    a1, a2 = AWN[n % len(AWN)]
    sign_c = shade(a1 + (255,), -40)
    rect(px, 2, sy, w - 4, 9, sign_c)
    outline(px, 2, sy, w - 4, 9, shade(sign_c, -30))
    name = SHOPS[n % len(SHOPS)]
    text(px, name[: (w - 8) // 4], w // 2, sy + 2, (250, 240, 200, 255))
    awning(px, 2, sy + 9, w - 4, a1 + (255,), a2 + (255,), stripe=n % 2 == 0)
    gy = h - 2
    rect(px, 4, sy + 16, w - 26, gy - sy - 18, (60, 50, 45, 255))
    rect(px, 6, sy + 17, w - 30, gy - sy - 21, (230, 205, 140, 255) if rng.random() < 0.7 else GLASS)
    for _ in range(6):  # goods in the window
        rect(px, rng.randrange(7, w - 26), gy - 6 - rng.randrange(3), 3, 3,
             rng.choice([(200, 70, 60, 255), (80, 140, 80, 255), (90, 110, 170, 255), (220, 200, 90, 255)]))
    rect(px, 4, gy - 3, w - 26, 1, (40, 34, 30, 255))
    door(px, w - 12, gy, 12, gy - sy - 17, (60, 40, 30, 255), glass=True)
    if name == "BARBER":
        for k in range(10):
            dot(px, w - 21, sy + 17 + k, [(220, 50, 50, 255), (240, 240, 240, 255), (50, 70, 180, 255)][k % 3])
    rect(px, 0, h - 2, w, 2, CURB)
    return px

# ---------- custom fronts ----------
def pizza():
    rng = random.Random(7)
    w, h = 84, 96
    px = blank(w, h)
    c = (150, 60, 45, 255)
    bricks(px, 0, 26, w, h - 26, c, rng)
    cornice(px, 2, 26, w - 4, (220, 205, 180, 255))
    outline(px, 0, 26, w, h - 26, (90, 35, 28, 255))
    for x in range(8, w - 10, 14):
        window(px, x, 34, 7, 8, (70, 40, 30, 255), x % 28 == 8, rng)
    crust, cheese, sauce = (190, 120, 60, 255), (250, 205, 80, 255), (200, 50, 40, 255)
    for k in range(22):  # rooftop slice sign
        half = 15 - (k * 15) // 22
        rect(px, w // 2 - half, 2 + k, half * 2, 1, cheese)
    rect(px, w // 2 - 16, 0, 32, 3, crust)
    for ox, oy in [(-7, 6), (5, 5), (-1, 12), (2, 17)]:
        rect(px, w // 2 + ox - 1, oy, 3, 3, sauce)
    rect(px, w // 2 - 1, 24, 2, 3, IRON)
    third = (w - 4) // 3  # tricolore sign band
    rect(px, 2, 48, third, 11, (35, 125, 65, 255))
    rect(px, 2 + third, 48, third, 11, (240, 235, 225, 255))
    rect(px, 2 + 2 * third, 48, w - 4 - 2 * third, 11, (200, 50, 40, 255))
    rect(px, 14, 50, w - 28, 7, (40, 30, 25, 255))
    text(px, "PIZZA", w // 2, 51, cheese)
    awning(px, 2, 59, w - 4, (200, 50, 40, 255), (240, 235, 225, 255))
    rect(px, 4, 67, 44, 26, (60, 40, 30, 255))  # window with brick oven glow
    rect(px, 6, 68, 40, 23, (250, 170, 80, 255))
    rect(px, 14, 76, 22, 12, (120, 70, 50, 255))
    for k in range(5):
        rect(px, 17 + k, 80 - k // 2, 16 - k * 2, 1, (130, 80, 55, 255))
    rect(px, 19, 82, 12, 5, (255, 120, 40, 255))
    rect(px, 22, 83, 6, 3, (255, 220, 120, 255))
    text(px, "SLICE $1", 26, 70, (60, 30, 20, 255))
    door(px, 64, 94, 14, 27, (40, 90, 55, 255), glass=True)
    rect(px, 0, h - 2, w, 2, CURB)
    return px

def cafe():
    rng = random.Random(8)
    w, h = 84, 92
    px = blank(w, h)
    c = (55, 95, 85, 255)
    rect(px, 0, 14, w, h - 14, c)
    for j in range(16, h, 6):  # clapboard
        rect(px, 0, j, w, 1, shade(c, -15))
    cornice(px, 2, 14, w - 4, (230, 220, 200, 255))
    outline(px, 0, 14, w, h - 14, shade(c, -45))
    for x in range(8, w - 10, 16):
        window(px, x, 24, 9, 10, (230, 220, 200, 255), True, rng)
        rect(px, x - 1, 35, 11, 2, (120, 80, 55, 255))  # flower box
        for k in range(0, 10, 2):
            dot(px, x + k, 34, rng.choice([(220, 80, 110, 255), (240, 200, 80, 255), (90, 160, 90, 255)]))
    cup, steam = (245, 240, 230, 255), (230, 230, 235, 255)  # coffee cup sign on the roof
    rect(px, w // 2 - 7, 4, 14, 9, cup)
    rect(px, w // 2 - 6, 4, 12, 2, (110, 70, 45, 255))
    rect(px, w // 2 + 7, 6, 3, 1, cup); rect(px, w // 2 + 9, 6, 1, 4, cup); rect(px, w // 2 + 7, 9, 3, 1, cup)
    rect(px, w // 2 - 9, 13, 18, 1, (200, 195, 185, 255))
    for k in range(3):
        dot(px, w // 2 - 3 + k * 3, 2 - k % 2, steam); dot(px, w // 2 - 2 + k * 3, 1 + k % 2, steam)
    rect(px, 4, 44, w - 8, 10, (35, 60, 50, 255))
    text(px, "CAFE", w // 2, 46, (245, 225, 170, 255))
    awning(px, 2, 54, w - 4, (40, 110, 70, 255), (240, 235, 215, 255))
    rect(px, 4, 62, 46, 28, (90, 60, 40, 255))
    rect(px, 6, 63, 42, 25, (250, 215, 150, 255))
    rect(px, 6, 78, 42, 3, (140, 95, 60, 255))  # counter
    for k in range(4):
        rect(px, 10 + k * 10, 74, 4, 4, cup)
    rect(px, 8, 64, 16, 8, (40, 35, 30, 255))  # menu board
    rect(px, 10, 66, 12, 1, (240, 240, 230, 255)); rect(px, 10, 69, 9, 1, (240, 240, 230, 255))
    door(px, 64, 90, 14, 27, (110, 70, 45, 255), glass=True)
    rect(px, 70, 80, 12, 2, (200, 200, 205, 255)); rect(px, 75, 82, 2, 7, IRON)  # sidewalk table
    rect(px, 79, 83, 4, 1, IRON); rect(px, 82, 79, 1, 10, IRON)
    rect(px, 0, h - 2, w, 2, CURB)
    return px

def gas():
    rng = random.Random(9)
    w, h = 100, 84
    px = blank(w, h)
    mart = (205, 200, 190, 255)
    rect(px, 46, 36, 52, 46, mart)
    outline(px, 46, 36, 52, 46, (140, 135, 128, 255))
    rect(px, 46, 36, 52, 9, (200, 45, 40, 255))
    text(px, "MART", 72, 38, (250, 250, 250, 255))
    rect(px, 50, 50, 26, 18, (60, 60, 66, 255))
    rect(px, 51, 51, 24, 16, (240, 225, 160, 255))
    for k in range(4):
        rect(px, 53 + k * 6, 56, 4, 10, rng.choice([(200, 60, 60, 255), (60, 120, 200, 255), (230, 190, 60, 255)]))
    door(px, 86, 82, 12, 20, (60, 60, 66, 255), glass=True)
    rect(px, 2, 26, 64, 9, (245, 245, 245, 255))  # canopy
    rect(px, 2, 30, 64, 3, (200, 45, 40, 255))
    rect(px, 2, 35, 64, 1, (120, 120, 125, 255))
    rect(px, 3, 36, 62, 2, (255, 250, 200, 255))  # lights under it
    for x in [8, 56]:
        rect(px, x, 36, 3, 46, (180, 180, 185, 255))
        rect(px, x, 36, 1, 46, (140, 140, 145, 255))
    for cx in [22, 40]:  # pumps on an island
        rect(px, cx - 7, 76, 14, 6, (170, 170, 165, 255))
        rect(px, cx - 4, 56, 8, 20, (200, 45, 40, 255))
        rect(px, cx - 3, 58, 6, 5, (40, 50, 60, 255))
        dot(px, cx - 2, 60, (120, 230, 120, 255)); dot(px, cx, 60, (120, 230, 120, 255))
        rect(px, cx - 3, 65, 6, 8, (240, 240, 240, 255))
        rect(px, cx + 4, 62, 2, 1, IRON); rect(px, cx + 5, 62, 1, 9, IRON)
    rect(px, 84, 0, 14, 34, (40, 40, 46, 255))  # price pylon
    rect(px, 85, 1, 12, 7, (200, 45, 40, 255))
    text(px, "GAS", 91, 2, (250, 250, 250, 255))
    for k, p in enumerate(["3", "4", "5"]):
        rect(px, 86, 10 + k * 8, 10, 7, (20, 20, 24, 255))
        text(px, p + "9", 91, 11 + k * 8, (250, 200, 60, 255))
    rect(px, 90, 34, 2, 2, (100, 100, 105, 255))
    rect(px, 0, h - 2, w, 2, CURB)
    return px

def airport():
    w, h = 160, 112
    px = blank(w, h)
    rect(px, 10, 18, 10, 92, (190, 190, 195, 255))  # control tower
    rect(px, 10, 18, 2, 92, (150, 150, 158, 255))
    rect(px, 4, 6, 22, 12, GLASS)
    for i in range(5, 26, 4):
        rect(px, i, 7, 1, 10, (60, 75, 95, 255))
    rect(px, 3, 4, 24, 2, (120, 120, 130, 255))
    rect(px, 3, 18, 24, 2, (120, 120, 130, 255))
    rect(px, 14, 0, 2, 4, IRON); dot(px, 15, 0, (230, 60, 60, 255))
    for y in range(18, 52):  # swept plane tail fin rising behind the terminal roof
        t = (52 - y) / 34
        x0, x1 = 124 + int(t * 18), 150 + int(t * 3)
        rect(px, x0, y, x1 - x0, 1, (200, 45, 40, 255) if 28 <= y < 36 else (235, 235, 240, 255))
        dot(px, x0, y, (170, 170, 180, 255))
    top = 46  # terminal: curved glass roof
    for i in range(24, w - 2):
        t = (i - 24) / (w - 26)
        y = top + int(10 * (2 * t - 1) ** 2)
        rect(px, i, y, 1, 4, (225, 228, 232, 255))
        rect(px, i, y + 4, 1, h - 2 - (y + 4), GLASS)
    for i in range(28, w - 4, 8):
        rect(px, i, top + 8, 1, h - top - 32, (200, 205, 212, 255))
    for j in range(top + 18, h - 26, 8):
        rect(px, 24, j, w - 26, 1, (200, 205, 212, 255))
    for k in range(40):  # reflection streak
        dot(px, 40 + k * 2, top + 40 - k // 2, (150, 180, 210, 255))
        dot(px, 41 + k * 2, top + 40 - k // 2, (150, 180, 210, 255))
    rect(px, 22, h - 26, w - 22, 24, (175, 172, 165, 255))  # concrete base
    rect(px, 22, h - 26, w - 22, 2, (140, 138, 132, 255))
    rect(px, 36, h - 40, 90, 11, (30, 60, 130, 255))
    outline(px, 36, h - 40, 90, 11, (20, 40, 90, 255))
    text(px, "JFK AIRPORT", 81, h - 37, (250, 250, 250, 255))
    for x in range(30, w - 6, 22):
        door(px, x + 6, h - 4, 12, 16, (70, 80, 95, 255), glass=True)
    rect(px, 0, h - 2, w, 2, CURB)
    return px

def nyse():
    w, h = 96, 100
    px = blank(w, h)
    stone, dark = (215, 210, 195, 255), (150, 145, 130, 255)
    rect(px, 46, 0, 1, 14, IRON)  # flag
    rect(px, 47, 1, 12, 7, (200, 45, 40, 255))
    for k in range(0, 7, 2):
        rect(px, 47, 1 + k, 12, 1, (240, 240, 240, 255))
    rect(px, 47, 1, 5, 4, (40, 60, 130, 255))
    for k in range(10):  # pediment
        rect(px, w // 2 - 4 * k - 4, 14 + k, 8 * k + 8, 1, stone)
    rect(px, 2, 24, w - 4, 4, dark)
    rect(px, 4, 28, w - 8, 9, stone)
    text(px, "NYSE", w // 2, 30, (60, 55, 50, 255))
    rect(px, 2, 37, w - 4, 3, dark)
    rect(px, 6, 40, w - 12, 52, (70, 80, 100, 255))  # dark hall behind the columns
    for x in range(8, w - 10, 14):
        rect(px, x, 40, 7, 52, stone)
        rect(px, x + 5, 40, 2, 52, dark)
        rect(px, x - 1, 40, 9, 2, dark)
    door(px, w // 2, 92, 12, 18, (110, 80, 40, 255), glass=True)
    rect(px, 0, 92, w, 6, dark)  # steps
    rect(px, 0, 94, w, 1, stone)
    rect(px, 0, h - 2, w, 2, CURB)
    return px

def hq():
    """Hack Club HQ: tall brick tower, red sign band, glass lobby. Original art, no logo."""
    w, h = 84, 150
    px = blank(w, h)
    rng = random.Random(5006)
    brick, dark = (120, 58, 52, 255), (80, 38, 36, 255)
    red = (236, 55, 80, 255)
    rect(px, w // 2 - 1, 0, 2, 10, IRON)  # antenna
    rect(px, 4, 10, w - 8, h - 10, brick)
    bricks(px, 4, 10, w - 8, h - 30, brick, rng)
    rect(px, 2, 10, w - 4, 3, dark)  # roof cap
    rect(px, 4, 16, w - 8, 9, red)  # sign band
    text(px, "HACK CLUB", w // 2, 18, (255, 255, 255, 255))
    for j in range(32, h - 34, 14):  # 4 office floors + the tower above
        for i in range(10, w - 14, 14):
            window(px, i, j, 8, 8, dark, rng.random() < 0.55, rng)
    rect(px, 4, h - 30, w - 8, 3, red)  # lobby awning line
    rect(px, 8, h - 27, w - 16, 24, (60, 70, 90, 255))
    for x in range(10, w - 10, 12):
        rect(px, x, h - 25, 9, 19, GLASS)
    door(px, w // 2, h - 3, 14, 20, (40, 45, 55, 255), glass=True)
    rect(px, 0, h - 2, w, 2, CURB)
    return px

def startup():
    """SF: Good Boy AI startup garage. Pastel stucco, roll-up door half open, laptop glow."""
    w, h = 84, 96
    px = blank(w, h)
    stucco, trim = (236, 214, 222, 255), (150, 170, 210, 255)
    rect(px, 4, 14, w - 8, h - 14, stucco)
    rect(px, 2, 12, w - 4, 3, trim)  # roof line
    rect(px, 8, 20, w - 16, 9, (40, 60, 110, 255))  # sign
    text(px, "GOOD BOY AI", w // 2, 22, (255, 255, 255, 255))
    for i in (12, w - 24):  # bay windows
        rect(px, i, 34, 12, 14, trim)
        rect(px, i + 2, 36, 8, 10, GLASS)
    rect(px, 18, 56, w - 36, 38, (90, 96, 110, 255))  # garage bay
    for j in range(56, 72, 3):  # roll-up door, half open
        rect(px, 18, j, w - 36, 2, (176, 182, 196, 255))
    rect(px, 20, 74, w - 40, 20, (24, 28, 40, 255))  # dark inside
    rect(px, 36, 82, 12, 7, (120, 210, 255, 255))  # laptop glow
    rect(px, 34, 89, 16, 2, (70, 74, 84, 255))
    rect(px, 0, h - 2, w, 2, CURB)
    return px

if __name__ == "__main__":
    for n in range(VARIANTS):
        write_png(f"apartment_{n}.png", apartment(n))
        write_png(f"office_{n}.png", office(n))
        write_png(f"shop_{n}.png", shop(n))
    for name, fn in [("pizza", pizza), ("cafe", cafe), ("gas", gas), ("airport", airport), ("nyse", nyse), ("hq", hq), ("startup", startup)]:
        write_png(f"{name}.png", fn())
    print(f"wrote {VARIANTS * 3 + 6} buildings to {os.path.normpath(OUT)}")
