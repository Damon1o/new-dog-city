"""SF sights (data/cities.gd landmarks): Golden Gate Bridge, Painted Ladies, Lombard Street,
Ferry Building, Salesforce Tower. Same 2x pixel style as gen_props.py, which owns the helpers.
Run: python tools/gen_sf_sights.py  (writes assets/<name>.png only for these five)."""
import math, random
from gen_props import blank, glow, selout, lit_window, ellipse, write_png
from gen_buildings import rect, dot, shade

WATER = (64, 104, 140, 255)
GRASS = (86, 142, 76, 255)
DARK = (60, 70, 86, 255)
GLASS = (70, 92, 124, 255)
WARM = (248, 220, 140, 255)


def water(px, y0):
    for j in range(y0, len(px)):
        for i in range(len(px[0])):
            c = shade(WATER, -((j - y0) // 6) * 3)
            if (i + j * 3) % 23 == 0:
                c = (150, 186, 210, 255)  # wave glint
            dot(px, i, j, c)


def golden_gate():
    """International orange towers, sagging main cable, suspenders, deck over the bay."""
    px = blank(320, 240)
    orange = (196, 66, 42, 255)
    deck_y, top = 168, 18
    towers = (72, 248)
    water(px, 196)

    def cable_y(x):  # main span: parabola between tower tops; side spans fall to the anchorages
        if towers[0] <= x <= towers[1]:
            m = (towers[0] + towers[1]) / 2
            f = (x - m) / ((towers[1] - towers[0]) / 2)
            return top + 6 + (deck_y - 14 - top) * (1 - f * f)  # high at the towers, sags mid-span
        end, t = (0, towers[0]) if x < towers[0] else (319, towers[1])
        return top + 6 + (deck_y - 10 - top) * abs(x - t) / abs(end - t)
    for x in range(320):
        y = int(cable_y(x))
        rect(px, x, y, 1, 2, shade(orange, -10))
        if x % 6 == 0:  # suspenders
            rect(px, x, y + 2, 1, deck_y - y - 2, shade(orange, -30))
    for tx in towers:
        for leg in (-9, 6):
            rect(px, tx + leg, top, 4, 196 - top, orange)
            rect(px, tx + leg + 3, top, 1, 196 - top, shade(orange, -45))
        for by in (top + 6, top + 40, top + 76, top + 112):  # art-deco cross braces
            rect(px, tx - 9, by, 19, 5, shade(orange, 12))
            rect(px, tx - 5, by + 1, 11, 3, shade(orange, -50))
        rect(px, tx - 11, 192, 23, 6, (150, 146, 140, 255))  # pier footing
    rect(px, 0, deck_y, 320, 7, orange)
    rect(px, 0, deck_y + 7, 320, 3, shade(orange, -55))
    cars = [(220, 220, 230, 255), (60, 90, 160, 255), (200, 60, 50, 255)]
    for x in range(0, 320, 30):
        rect(px, x + 3, deck_y - 3, 5, 3, cars[(x // 30) % 3])
    for k in range(5):  # fog wisps drifting through the towers
        cx, cy = 30 + k * 66, 60 + (k % 2) * 40
        for j in range(cy - 6, cy + 6):
            for i in range(max(0, cx - 34), min(320, cx + 34)):
                if ((i - cx) / 34) ** 2 + ((j - cy) / 6) ** 2 < 1 and px[j][i][3] == 0 and (i + j) % 2 == 0:
                    px[j][i] = (236, 238, 242, 150)
    selout(px, -40)
    return px


def painted_ladies():
    """Alamo Square's row of pastel Victorians: gables, bay windows, white trim, lawn in front."""
    px = blank(320, 200)
    colors = [(178, 196, 220, 255), (236, 200, 170, 255), (190, 214, 182, 255), (232, 184, 196, 255), (238, 224, 160, 255)]
    trim = (246, 244, 236, 255)
    for k, c in enumerate(colors):
        x0, w, yb, yt = 8 + k * 61, 58, 168, 60
        rect(px, x0, yt, w, yb - yt, c)
        rect(px, x0 + w - 4, yt, 4, yb - yt, shade(c, -30))
        for j in range(30):  # gable roof
            hw = int(w / 2 * j / 30)
            rect(px, x0 + w // 2 - hw, yt - 30 + j, hw * 2, 1, shade(c, -55) if j < 3 else (92, 70, 80, 255))
        rect(px, x0 + w // 2 - 6, yt - 18, 12, 10, trim)  # attic window
        rect(px, x0 + w // 2 - 4, yt - 16, 8, 6, GLASS)
        rect(px, x0 - 1, yt - 2, w + 2, 3, trim)  # cornice
        for fy in (yt + 10, yt + 52):  # bay window, two floors
            rect(px, x0 + 6, fy, 26, 32, trim)
            for wx in (x0 + 8, x0 + 16, x0 + 24):
                rect(px, wx, fy + 3, 6, 24, GLASS)
                rect(px, wx, fy + 3, 6, 3, WARM if (k + wx + fy) % 3 == 0 else (110, 132, 160, 255))
        rect(px, x0 + 38, yt + 52, 14, 46, trim)  # front door with steps
        rect(px, x0 + 40, yt + 56, 10, 40, shade(c, -70))
        for s in range(4):
            rect(px, x0 + 34 + s, yb - 4 + s, 22 - s * 2, 1, (200, 196, 188, 255))
    for j in range(170, 200):
        for i in range(320):
            dot(px, i, j, shade(GRASS, ((i * 5 + j * 3) % 9) - 4))
    selout(px, -45)
    return px


def lombard():
    """The crookedest street: red-brick switchbacks down a hill, flower beds, houses up top."""
    px = blank(256, 240)
    for j in range(60, 240):  # hill
        for i in range(256):
            dot(px, i, j, shade(GRASS, ((i * 7 + j * 5) % 11) - 5))
    brick = (170, 74, 58, 255)
    flowers = [(230, 120, 170, 255), (200, 60, 80, 255), (150, 120, 210, 255)]
    x0, x1 = 60, 196
    for r in range(8):  # switchbacks
        y = 70 + r * 20
        rect(px, x0, y, x1 - x0, 10, brick)
        for i in range(x0, x1, 4):
            dot(px, i + (r % 2) * 2, y + 4, shade(brick, -30))
        if r < 7:
            rect(px, x1 - 10 if r % 2 == 0 else x0, y, 10, 30, brick)
        for i in range(x0 + 12, x1 - 12, 9):  # flower beds between the bends
            c = flowers[(i + r) % 3]
            rect(px, i, y + 12, 6, 5, c)
            rect(px, i + 1, y + 13, 3, 2, shade(c, 40))
    for k, c in enumerate([(232, 220, 196, 255), (196, 210, 226, 255), (236, 206, 180, 255), (210, 226, 200, 255)]):
        hx = 6 + k * 62  # houses along the top
        rect(px, hx, 20, 56, 44, c)
        rect(px, hx - 2, 16, 60, 5, shade(c, -50))
        for wx in range(hx + 6, hx + 52, 12):
            rect(px, wx, 28, 7, 10, GLASS)
            rect(px, wx, 44, 7, 10, WARM if (wx + k) % 3 == 0 else GLASS)
    selout(px, -40)
    return px


def ferry_building():
    """Embarcadero Ferry Building: long arcaded hall, clock tower with flag, bay behind."""
    px = blank(320, 260)
    stone = (226, 214, 188, 255)
    rng = random.Random(611)
    rect(px, 10, 150, 300, 94, stone)  # main hall
    rect(px, 10, 146, 300, 6, shade(stone, 18))
    rect(px, 300, 150, 10, 94, shade(stone, -35))
    for x in range(18, 296, 16):  # arches, two rows
        for y, h in ((160, 26), (196, 40)):
            rect(px, x, y + 4, 10, h - 4, lit_window(rng, 0.3) if y == 160 else DARK)
            rect(px, x + 1, y + 2, 8, 2, DARK)
            rect(px, x + 3, y, 4, 2, DARK)
    rect(px, 140, 210, 40, 34, (52, 58, 70, 255))  # grand entrance
    rect(px, 144, 214, 32, 3, (230, 200, 120, 255))
    tx, tw = 140, 40  # clock tower
    rect(px, tx, 40, tw, 110, stone)
    rect(px, tx + tw - 6, 40, 6, 110, shade(stone, -35))
    for y in range(84, 140, 14):
        rect(px, tx + 8, y, 6, 9, DARK)
        rect(px, tx + 26, y, 6, 9, DARK)
    ellipse(px, 160, 66, 11, 11, (248, 244, 228, 255))  # clock face
    rect(px, 160, 58, 1, 8, (40, 40, 44, 255))
    rect(px, 160, 66, 6, 1, (40, 40, 44, 255))
    rect(px, tx - 3, 36, tw + 6, 5, shade(stone, 20))
    for j in range(22):  # belfry and cap
        hw = 16 - j * 16 // 22
        rect(px, 160 - (16 - hw), 14 + j, (16 - hw) * 2 + 2, 1, shade(stone, -10 if j > 6 else 10))
    rect(px, 159, 0, 2, 16, (90, 90, 96, 255))  # flag pole + flag
    rect(px, 161, 1, 10, 6, (60, 90, 170, 255))
    glow(px, 160, 66, 18, (255, 240, 190), 0.25)
    water(px, 244)
    selout(px, -45)
    return px


def salesforce():
    """Salesforce Tower: tapering glass obelisk with a rounded, lit lattice crown."""
    px = blank(128, 320)
    glass = (150, 176, 196, 255)
    rng = random.Random(612)
    top, base = 30, 306
    for j in range(top, base):
        f = (j - top) / (base - top)
        hw = int(20 + f * 16)
        if j < top + 20:  # rounded crown
            hw = int(math.sqrt(max(0.0, 1 - ((top + 20 - j) / 20) ** 2)) * 20)
        for i in range(64 - hw, 64 + hw):
            lit = i < 64 + hw // 4
            c = glass if lit else shade(glass, -42)
            if (i - 64) % 6 == 0:  # vertical fins
                c = shade(c, 30)
            if j > top + 24 and j % 6 == 3 and rng.random() < 0.15:
                c = lit_window(rng, 0.8)
            dot(px, i, j, c)
    for j in range(top, top + 24):  # open lattice crown: the LED screen glows white
        for i in range(44, 84):
            if px[j][i][3] and (i + j) % 3 == 0:
                px[j][i] = (236, 244, 252, 255)
    glow(px, 64, top + 10, 26, (220, 236, 255), 0.35)
    rect(px, 24, 304, 80, 16, (120, 126, 136, 255))  # plaza
    rect(px, 52, 292, 24, 14, (50, 60, 74, 255))  # lobby doors
    rect(px, 52, 292, 24, 2, (230, 220, 170, 255))
    selout(px, -45)
    return px


if __name__ == "__main__":
    for name, fn in [("golden_gate", golden_gate), ("painted_ladies", painted_ladies), ("lombard", lombard),
                     ("ferry_building", ferry_building), ("salesforce", salesforce)]:
        write_png(f"{name}.png", fn())
    print("sf sights done")
