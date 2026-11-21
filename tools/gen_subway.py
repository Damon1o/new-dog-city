"""Subway station art for New Dog City: tiled wall with mosaic band, concrete platform, tactile
edge strip, ballast track with third rail, stainless train car, I-beam column, stair mouth,
route map, wall ads and a bench. Pure stdlib, seeded. Run: python tools/gen_subway.py

Replaces the flat-rect train / track / stairs / map_board in gen_assets.py.
Tiles (subway_wall, subway_floor, platform_edge, track) paint 1:1 in world pixels.
Sprites are 2x the old pixel size; rooms.gd / interior.gd halve their scale so world size,
colliders and TRAIN_HALF are unchanged. Shared station_wall / platform / pillar stay as they
were because other rooms tint them."""
import random
import gen_props as gp
from gen_buildings import rect, dot, shade, outline, text

write_png = gp.write_png
K = (22, 20, 24, 255)
TILE = (232, 230, 220, 255)
GROUT = (178, 176, 166, 255)
GREEN = (38, 98, 72, 255)
MAROON = (128, 46, 42, 255)
STEEL = (174, 180, 190, 255)

def noise(px, x, y, w, h, c, seed, n, d=12):
    rnd = random.Random(seed)
    for _ in range(n):
        dot(px, x + rnd.randrange(w), y + rnd.randrange(h), shade(c, rnd.randint(-d, d)))

# ---------- tiles ----------
def subway_wall():
    """64x96: ceiling beam + fluorescent tube, white subway tile, mosaic band, green wainscot.
    The HUD bar hides about the top 55-70 px in play, so tile, band and wainscot sit low."""
    px = gp.blank(64, 96)
    rect(px, 0, 0, 64, 8, (52, 54, 58, 255))
    rect(px, 0, 7, 64, 1, (30, 30, 34, 255))
    rect(px, 12, 2, 40, 3, (250, 248, 225, 255))
    rect(px, 10, 1, 44, 1, (90, 92, 96, 255))
    for j in range(8, 72):                                    # running-bond subway tile, 8x4
        for i in range(64):
            row = (j - 8) // 4
            edge = (j - 8) % 4 == 3 or (i + (row % 2) * 4) % 8 == 7
            px[j][i] = GROUT if edge else shade(TILE, 6 if (j - 8) % 4 == 0 else -((i * 7 + row * 3) % 5))
    rect(px, 0, 8, 64, 1, (250, 250, 236, 255))               # light spill
    noise(px, 0, 10, 64, 60, (205, 200, 180, 255), 3, 30, 18)  # grime speckle
    B = 72                                                    # mosaic band, rows B..B+13
    rect(px, 0, B, 64, 14, MAROON)
    rect(px, 0, B, 64, 2, (196, 156, 72, 255))
    rect(px, 0, B + 12, 64, 2, (196, 156, 72, 255))
    for i in range(0, 64, 8):                                 # diamonds in the band
        for k in range(4):
            rect(px, i + 3 - k, B + 3 + k, 1 + k * 2, 1, (214, 196, 150, 255))
            rect(px, i + 3 - k, B + 10 - k, 1 + k * 2, 1, (214, 196, 150, 255))
        dot(px, i + 3, B + 6, MAROON); dot(px, i + 3, B + 7, MAROON)
    for j in range(B + 14, 96):                               # green glazed wainscot
        for i in range(64):
            edge = (j - B - 14) % 5 == 4 or i % 8 == 7
            px[j][i] = shade(GREEN, -30) if edge else shade(GREEN, 18 if i % 8 < 2 else ((i + j) % 3) * 3)
    rect(px, 0, B + 14, 64, 1, shade(GREEN, 40))
    return px

def subway_floor():
    """64x64 concrete slabs with joints, damp stains and gum spots."""
    px = gp.blank(64, 64)
    base = (132, 130, 126, 255)
    rnd = random.Random(11)
    for j in range(64):
        for i in range(64):
            px[j][i] = shade(base, rnd.randint(-5, 5) + (-3 if (i // 32 + j // 32) % 2 else 2))
    for k in (0, 32):
        rect(px, 0, k, 64, 1, (100, 98, 95, 255)); rect(px, k, 0, 1, 64, (100, 98, 95, 255))
        rect(px, 1, k + 1, 63, 1, (146, 144, 140, 255))
    for cx, cy, r in ((14, 46, 6), (49, 14, 4)):
        for j in range(cy - r, cy + r + 1):
            for i in range(cx - r - 2, cx + r + 3):
                if ((i - cx) / (r + 2)) ** 2 + ((j - cy) / r) ** 2 <= 1:
                    px[j][i] = shade(px[j][i], -10)
    for x, y in ((40, 50), (22, 20), (55, 40)):
        rect(px, x, y, 2, 2, (88, 86, 84, 255)); dot(px, x, y, (110, 108, 104, 255))
    return px

def platform_edge():
    """64x16: yellow tactile strip with domes, white nosing, dark lip over the pit."""
    px = gp.blank(64, 16)
    rect(px, 0, 0, 64, 12, (222, 186, 52, 255))
    rect(px, 0, 0, 64, 1, (246, 214, 90, 255))
    for j in range(2, 11, 4):
        for i in range((j // 4 % 2) * 2, 64, 4):
            dot(px, i + 1, j, (250, 226, 120, 255)); dot(px, i + 1, j + 1, (172, 140, 30, 255))
            dot(px, i, j + 1, (236, 204, 80, 255))
    rect(px, 0, 12, 64, 2, (196, 194, 188, 255))
    rect(px, 0, 14, 64, 2, (60, 58, 56, 255))
    return px

def track():
    """64x128: pit wall, third-rail cover board, ballast, ties, two running rails, far trough."""
    px = gp.blank(64, 128)
    rnd = random.Random(5)
    rect(px, 0, 0, 64, 14, (64, 62, 60, 255))
    rect(px, 0, 12, 64, 2, (36, 34, 34, 255))
    for j in range(14, 128):
        for i in range(64):
            px[j][i] = shade((54, 50, 46, 255), rnd.randint(-10, 10) + (8 if (i * 13 + j * 7) % 23 == 0 else 0))
    for i in range(0, 64, 16):
        rect(px, i + 3, 30, 10, 84, (74, 52, 36, 255))
        rect(px, i + 3, 30, 10, 2, (98, 72, 50, 255))
        rect(px, i + 12, 30, 1, 84, (50, 34, 24, 255))
        for k in range(3):
            dot(px, i + 5 + k * 3, 40 + k * 23, (60, 42, 30, 255))
    for y in (46, 92):
        rect(px, 0, y - 1, 64, 1, (40, 38, 38, 255))
        rect(px, 0, y, 64, 2, (206, 210, 216, 255))
        rect(px, 0, y + 2, 64, 3, (112, 106, 100, 255))
        rect(px, 0, y + 5, 64, 1, (30, 28, 28, 255))
        for i in range(0, 64, 16):
            rect(px, i + 4, y + 6, 8, 2, (66, 62, 58, 255))
    rect(px, 0, 18, 64, 6, (196, 170, 90, 255))
    rect(px, 0, 18, 64, 1, (228, 204, 120, 255))
    rect(px, 0, 24, 64, 3, (70, 68, 66, 255))
    for i in range(6, 64, 32):
        rect(px, i, 27, 3, 3, (90, 88, 84, 255))
    rect(px, 0, 116, 64, 12, (38, 36, 36, 255))
    noise(px, 0, 116, 64, 12, (50, 48, 46, 255), 9, 40)
    return px

# ---------- sprites ----------
def train_car():
    """192x72 stainless car: roof, ribbed panel, stripe, two door pairs, lit windows with dog riders, bogies."""
    px = gp.blank(192, 72)
    rnd = random.Random(21)
    rect(px, 2, 0, 188, 6, (110, 114, 122, 255))
    rect(px, 2, 0, 188, 1, (150, 154, 162, 255))
    rect(px, 2, 6, 188, 50, STEEL)
    for j in range(6, 56):
        for i in range(2, 190):
            if j < 9:
                px[j][i] = shade(px[j][i], 22)
            elif (i * 3 + j) % 17 == 0:
                px[j][i] = shade(px[j][i], -6)
    for i in range(4, 189, 3):
        rect(px, i, 38, 1, 17, shade(STEEL, -20))
        rect(px, i + 1, 38, 1, 17, shade(STEEL, 14))
    rect(px, 2, 34, 188, 3, (60, 70, 160, 255))
    rect(px, 2, 34, 188, 1, (110, 120, 210, 255))
    for wx in (10, 70, 104, 164):
        rect(px, wx - 1, 11, 22, 19, (70, 74, 82, 255))
        for p in (0, 11):
            rect(px, wx + p, 12, 10, 17, (232, 220, 160, 255))
            rect(px, wx + p, 12, 10, 3, (250, 244, 205, 255))
            if rnd.random() < 0.7:
                hx = wx + p + rnd.randint(2, 5)
                c = rnd.choice([(150, 110, 70), (90, 70, 60), (200, 180, 150), (60, 60, 66)]) + (255,)
                gp.ellipse(px, hx + 1.5, 23, 3.2, 3.0, c)
                rect(px, hx - 1, 25, 6, 4, c)
                dot(px, hx - 1, 20, c); dot(px, hx + 4, 20, c)
            rect(px, wx + p + 8, 13, 1, 6, (255, 252, 230, 255))
    for dx in (42, 132):
        rect(px, dx - 1, 8, 22, 48, (40, 40, 46, 255))
        for leaf in (0, 11):
            x = dx + leaf
            rect(px, x, 9, 10, 46, shade(STEEL, 10))
            rect(px, x + 2, 13, 6, 18, (70, 80, 94, 255))
            rect(px, x + 2, 13, 6, 4, (236, 226, 170, 255))
            rect(px, x + 2, 17, 6, 14, (214, 204, 150, 255))
            rect(px, x + (9 if leaf == 0 else 0), 9, 1, 46, (30, 30, 34, 255))
        rect(px, dx + 6, 5, 8, 2, (240, 90, 60, 255))
    gp.ellipse(px, 96, 22, 6, 6, (238, 52, 46, 255))
    gp.ring(px, 96, 22, 6, 6, (255, 255, 255, 255), 0.3)
    text(px, "2", 96, 20, (255, 255, 255, 255))
    rect(px, 0, 0, 2, 58, (30, 30, 34, 255)); rect(px, 190, 0, 2, 58, (30, 30, 34, 255))
    rect(px, 2, 56, 188, 4, (52, 52, 58, 255))
    rect(px, 8, 60, 176, 6, (34, 34, 38, 255))
    for i in range(44, 150, 14):
        rect(px, i, 60, 8, 5, (60, 60, 66, 255))
    for bx in (24, 168):
        rect(px, bx - 16, 62, 32, 4, (46, 46, 50, 255))
        for wx in (bx - 9, bx + 9):
            gp.ellipse(px, wx, 66, 5.5, 5.5, (26, 26, 28, 255))
            gp.ellipse(px, wx, 66, 3, 3, (92, 92, 98, 255))
            dot(px, wx, 66, (160, 160, 168, 255))
    rect(px, 0, 52, 2, 6, (80, 80, 86, 255)); rect(px, 190, 52, 2, 6, (80, 80, 86, 255))
    return px

def column():
    """24x80 green I-beam column with rivets and a station-number plate (old pillar 12x40 @2.5)."""
    px = gp.blank(24, 80)
    gp.cyl(px, 6, 6, 12, 68, GREEN, hi=36, lo=-40)
    rect(px, 3, 6, 3, 68, shade(GREEN, 10)); rect(px, 18, 6, 3, 68, shade(GREEN, -30))
    rect(px, 3, 6, 1, 68, shade(GREEN, 40))
    for y in range(12, 72, 8):
        dot(px, 4, y, shade(GREEN, 55)); dot(px, 19, y, shade(GREEN, -10))
    rect(px, 0, 0, 24, 6, shade(GREEN, -10)); rect(px, 0, 0, 24, 1, shade(GREEN, 40))
    rect(px, 1, 74, 22, 6, shade(GREEN, -25)); rect(px, 1, 74, 22, 1, shade(GREEN, 20))
    for x in (3, 20):
        dot(px, x, 3, shade(GREEN, 60)); dot(px, x, 77, shade(GREEN, 10))
    rect(px, 5, 30, 14, 9, (240, 240, 236, 255))
    outline(px, 5, 30, 14, 9, (24, 24, 28, 255))
    text(px, "72", 12, 32, (24, 24, 28, 255))
    gp.selout(px)
    return px

def stairs():
    """96x64 stair mouth: green tiled sides, steel handrails, steps lit from the street above."""
    px = gp.blank(96, 64)
    rect(px, 0, 0, 96, 64, (40, 40, 46, 255))
    for k in range(9):
        g = 190 - k * 18
        y = 10 + k * 6
        rect(px, 12, y, 72, 6, (g, g, g + 4, 255))
        rect(px, 12, y, 72, 1, (min(255, g + 24), min(255, g + 22), min(255, g + 10), 255))
        rect(px, 12, y + 5, 72, 1, (max(0, g - 30),) * 3 + (255,))
    for x in (0, 84):
        rect(px, x, 0, 12, 64, GREEN)
        for j in range(0, 64, 8):
            rect(px, x, j + 7, 12, 1, shade(GREEN, -30))
        rect(px, x, 0, 12, 1, shade(GREEN, 40))
    rect(px, 10, 6, 2, 58, (200, 204, 210, 255)); rect(px, 84, 6, 2, 58, (200, 204, 210, 255))
    rect(px, 12, 0, 72, 9, (24, 24, 28, 255))
    text(px, "STREET", 48, 2, (250, 250, 240, 255))
    gp.selout(px, -40)
    return px

def map_board():
    """64x48 framed route map: rivers, park, colored lines, stations, red YOU ARE HERE dot."""
    px = gp.blank(64, 48)
    rect(px, 0, 0, 64, 48, (34, 34, 40, 255))
    rect(px, 1, 1, 62, 1, (90, 90, 98, 255))
    rect(px, 3, 3, 58, 42, (238, 236, 226, 255))
    rect(px, 3, 3, 58, 7, (24, 24, 28, 255))
    text(px, "SUBWAY", 32, 4, (250, 250, 250, 255))
    for j in range(10, 45):
        rect(px, 3, j, 5 + (j % 7 > 3), 1, (140, 186, 222, 255))
        rect(px, 55 - (j % 5 > 2), j, 6 + (j % 5 > 2), 1, (140, 186, 222, 255))
    rect(px, 20, 18, 26, 18, (200, 222, 180, 255))
    lines = [((10, 24), (52, 24), (238, 52, 46)), ((28, 12), (28, 42), (40, 110, 210)),
             ((14, 38), (50, 14), (60, 168, 90)), ((10, 32), (52, 32), (250, 180, 40))]
    for (x0, y0), (x1, y1), c in lines:
        n = max(abs(x1 - x0), abs(y1 - y0))
        for s in range(n + 1):
            rect(px, round(x0 + (x1 - x0) * s / n), round(y0 + (y1 - y0) * s / n), 2, 2, c + (255,))
    for x, y in ((16, 24), (42, 24), (28, 16), (28, 38), (20, 32), (46, 32), (39, 21)):
        rect(px, x - 1, y - 1, 4, 4, (255, 255, 255, 255)); rect(px, x, y, 2, 2, K)
    gp.ellipse(px, 29, 25, 3.5, 3.5, (238, 52, 46, 255)); rect(px, 28, 24, 2, 2, (255, 255, 255, 255))
    return px

ADS = [((40, 70, 140), (250, 210, 60), "TREATS"), ((170, 40, 60), (250, 245, 235), "WOOF"),
       ((30, 120, 90), (250, 240, 200), "PARK")]

def ad(k):
    """48x32 framed wall ad (three designs: bone, dog, park)."""
    bg, fg, word = ADS[k]
    fg = fg + (255,)
    px = gp.blank(48, 32)
    rect(px, 0, 0, 48, 32, (60, 58, 56, 255))
    for j in range(2, 30):
        rect(px, 2, j, 44, 1, shade(bg + (255,), 18 - j))
    text(px, word, 24, 5, fg)
    if k == 0:
        rect(px, 14, 18, 20, 4, fg)
        for x in (13, 34):
            gp.ellipse(px, x, 17.5, 2.5, 2.5, fg); gp.ellipse(px, x, 22.5, 2.5, 2.5, fg)
    elif k == 1:
        gp.ellipse(px, 24, 21, 7, 6, (200, 150, 90, 255))
        gp.ellipse(px, 17, 17, 2.5, 4, (150, 100, 60, 255)); gp.ellipse(px, 31, 17, 2.5, 4, (150, 100, 60, 255))
        dot(px, 21, 20, K); dot(px, 27, 20, K); rect(px, 23, 23, 3, 2, K)
    else:
        gp.ellipse(px, 36, 15, 3, 3, (250, 210, 80, 255))
        rect(px, 17, 21, 3, 8, (110, 70, 40, 255)); gp.ellipse(px, 18.5, 18, 7, 5, (90, 180, 90, 255))
    rect(px, 40, 24, 6, 6, (236, 234, 226, 255))              # torn corner
    rect(px, 2, 30, 44, 1, (30, 28, 28, 255))
    return px

def bench():
    """64x24 wooden platform bench on cast-iron legs, with a soft ground shadow."""
    px = gp.blank(64, 24)
    for y in (2, 8):
        rect(px, 2, y, 60, 4, (150, 100, 60, 255)); rect(px, 2, y, 60, 1, (186, 132, 84, 255))
    rect(px, 0, 13, 64, 4, (160, 108, 64, 255)); rect(px, 0, 13, 64, 1, (196, 142, 92, 255))
    for x in (6, 30, 54):
        rect(px, x, 1, 4, 20, (40, 40, 46, 255)); rect(px, x, 1, 1, 20, (80, 80, 90, 255))
    gp.selout(px)
    gp.shadow(px, 32, 21, 30, 3)
    return px

if __name__ == "__main__":
    write_png("subway_wall.png", subway_wall())
    write_png("subway_floor.png", subway_floor())
    write_png("platform_edge.png", platform_edge())
    write_png("track.png", track())
    write_png("train.png", train_car())
    write_png("subway_column.png", column())
    write_png("stairs.png", stairs())
    write_png("map_board.png", map_board())
    for k in range(3):
        write_png("subway_ad_%d.png" % k, ad(k))
    write_png("bench.png", bench())
    print("done")
