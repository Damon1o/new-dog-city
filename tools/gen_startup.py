"""Good Boy AI office art (scripts/systems/startup.gd): desks, servers, perks, floors per office tier.
Pure stdlib, seeded. Run: python tools/gen_startup.py  (writes assets/su_*.png)"""
import math, random
import gen_props as gp
from gen_props import blank, rect, dot, shade, rgba, ball, cyl, selout, text2, glow, shadow, ellipse, write_png, T

def desk():
    """48x40 dev desk: wood top, glowing monitor with code, keyboard, mug."""
    px = blank(48, 40)
    shadow(px, 24, 37, 22, 3)
    wood = (150, 104, 64, 255)
    rect(px, 2, 22, 44, 6, wood); rect(px, 2, 22, 44, 1, shade(wood, 30)); rect(px, 2, 27, 44, 1, shade(wood, -40))
    rect(px, 4, 28, 3, 9, shade(wood, -30)); rect(px, 41, 28, 3, 9, shade(wood, -30))
    rect(px, 30, 28, 11, 8, shade(wood, -15)); rect(px, 31, 31, 9, 1, shade(wood, -45))  # drawer
    dot(px, 35, 33, (220, 200, 120, 255))
    rect(px, 12, 2, 24, 17, (40, 42, 50, 255))  # monitor
    rect(px, 14, 4, 20, 13, (18, 30, 44, 255))
    rng = random.Random(4)
    for j in range(5, 16, 2):  # code lines
        rect(px, 15 + rng.randrange(0, 3), j, rng.randrange(5, 15), 1,
             rgba(rng.choice([(110, 220, 140), (120, 180, 255), (250, 200, 90), (230, 120, 200)])))
    rect(px, 22, 19, 4, 3, (60, 62, 70, 255))
    rect(px, 14, 23, 18, 2, (200, 204, 212, 255)); rect(px, 15, 23, 16, 1, (232, 236, 240, 255))  # keyboard
    rect(px, 37, 18, 5, 5, (230, 230, 236, 255)); dot(px, 42, 20, (230, 230, 236, 255))  # mug
    rect(px, 38, 18, 3, 1, (90, 56, 30, 255))
    selout(px, -50)
    glow(px, 24, 10, 16, (90, 160, 255), 0.18)
    return px

def server_rack():
    """32x56 server rack with status LEDs."""
    px = blank(32, 56)
    shadow(px, 16, 53, 15, 3)
    steel = (52, 56, 66, 255)
    rect(px, 3, 2, 26, 50, steel); rect(px, 3, 2, 26, 2, shade(steel, 40)); rect(px, 27, 2, 2, 50, shade(steel, -25))
    rng = random.Random(9)
    for j in range(6, 48, 6):
        rect(px, 6, j, 20, 4, (28, 30, 36, 255)); rect(px, 6, j, 20, 1, (70, 76, 88, 255))
        for i in range(8, 20, 3):
            dot(px, i, j + 2, (40, 44, 52, 255))
        dot(px, 22, j + 2, rgba(rng.choice([(90, 255, 120), (90, 255, 120), (255, 190, 60), (80, 170, 255)])))
        dot(px, 24, j + 2, (90, 255, 120, 255))
    selout(px, -40)
    return px

def espresso():
    """32x36 chrome espresso machine with a cup."""
    px = blank(32, 36)
    shadow(px, 16, 33, 14, 3)
    cyl(px, 4, 6, 24, 22, (180, 186, 196, 255), 50, -60)
    rect(px, 4, 4, 24, 3, (60, 60, 66, 255))
    rect(px, 8, 10, 16, 5, (40, 40, 46, 255)); dot(px, 10, 12, (255, 80, 60, 255)); dot(px, 13, 12, (90, 255, 120, 255))
    rect(px, 12, 17, 8, 3, (70, 70, 76, 255)); rect(px, 15, 20, 2, 2, (70, 70, 76, 255))
    rect(px, 12, 24, 8, 5, (245, 245, 240, 255)); rect(px, 13, 24, 6, 1, (110, 70, 40, 255))
    rect(px, 2, 28, 28, 3, (60, 60, 66, 255))
    selout(px, -50)
    return px

def ball_pit():
    """64x36 ball pit: padded ring full of coloured balls."""
    px = blank(64, 36)
    shadow(px, 32, 31, 30, 4)
    ellipse(px, 32, 22, 30, 12, (70, 120, 220, 255))
    ellipse(px, 32, 20, 26, 9, (40, 70, 140, 255))
    rng = random.Random(3)
    cols = [(240, 70, 70), (250, 210, 60), (70, 200, 110), (80, 160, 250), (240, 130, 220)]
    for _ in range(38):
        a, r = rng.uniform(0, 6.283), rng.uniform(0, 1)
        ball(px, 32 + math.cos(a) * 23 * r, 19 + math.sin(a) * 7 * r, 2.4, rgba(rng.choice(cols)))
    selout(px, -45)
    return px

def whiteboard():
    """64x48 whiteboard on legs: user-growth chart going up and to the right."""
    px = blank(64, 48)
    shadow(px, 32, 45, 26, 3)
    rect(px, 8, 30, 2, 15, (110, 114, 124, 255)); rect(px, 54, 30, 2, 15, (110, 114, 124, 255))
    rect(px, 2, 2, 60, 32, (176, 180, 190, 255)); rect(px, 4, 4, 56, 28, (246, 248, 250, 255))
    for i in range(3):
        rect(px, 14 + i * 10, 26 - (i + 1) * 4, 6, (i + 1) * 4 + 2, (120, 170, 255, 255))
    rect(px, 8, 8, 1, 21, (60, 60, 70, 255)); rect(px, 8, 28, 48, 1, (60, 60, 70, 255))
    pts = [(10, 26), (18, 25), (26, 23), (34, 20), (42, 15), (50, 9), (54, 6)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        for t in range(9):
            dot(px, round(x0 + (x1 - x0) * t / 8), round(y0 + (y1 - y0) * t / 8), (40, 170, 90, 255))
    rect(px, 52, 5, 4, 1, (40, 170, 90, 255)); rect(px, 55, 5, 1, 4, (40, 170, 90, 255))
    rect(px, 4, 33, 56, 2, (150, 154, 164, 255))
    dot(px, 20, 33, (230, 60, 60, 255)); dot(px, 22, 33, (60, 90, 230, 255))
    selout(px, -40)
    return px

def neon():
    """112x22 neon 'GOOD BOY AI' wall sign with a soft tube halo."""
    px = blank(112, 22)
    rect(px, 0, 0, 112, 22, (24, 20, 36, 255))
    text2(px, "GOOD BOY AI", 56, 6, (255, 120, 220, 255), 2)
    tube = [(i, j) for j in range(22) for i in range(112) if px[j][i][:3] == (255, 120, 220)]
    for i, j in tube:
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = i + di, j + dj
            if 0 <= a < 112 and 0 <= b < 22 and px[b][a][:3] == (24, 20, 36):
                px[b][a] = (90, 40, 90, 255)
    for i in range(112):
        px[0][i] = px[21][i] = (70, 60, 100, 255)
    return px

def bell():
    """28x40 IPO bell on a wooden stand."""
    px = blank(28, 40)
    shadow(px, 14, 37, 12, 3)
    rect(px, 13, 18, 2, 18, (120, 84, 50, 255)); rect(px, 6, 34, 16, 3, (120, 84, 50, 255))
    ball(px, 14, 9, 6, (230, 190, 70, 255))
    cyl(px, 7, 9, 14, 9, (230, 190, 70, 255), 50, -50)
    rect(px, 5, 17, 18, 2, (200, 160, 50, 255)); dot(px, 14, 20, (120, 84, 50, 255))
    selout(px, -50)
    return px

def plant():
    """24x40 office monstera in a white pot."""
    px = blank(24, 40)
    shadow(px, 12, 37, 9, 2)
    cyl(px, 6, 26, 12, 11, (236, 236, 232, 255), 20, -50)
    for cx, cy, r in [(12, 14, 6), (6, 18, 5), (18, 18, 5), (9, 8, 4), (16, 9, 4), (12, 22, 5)]:
        ball(px, cx, cy, r, (60, 150, 80, 255))
    selout(px, -50)
    return px

def floor(name, base, kind):
    """32x32 tiling floor: polished concrete / wood planks / carpet / marble."""
    px = blank(32, 32)
    rng = random.Random(name)
    for j in range(32):
        for i in range(32):
            d = rng.randrange(-6, 7)
            if kind == "wood":
                d += -26 if j % 8 == 7 else (8 if j % 8 == 0 else 0)
                d -= 30 if i == (j // 8 * 13) % 32 and j % 8 != 7 else 0
            elif kind == "carpet":
                d += 6 if (i // 4 + j // 4) % 2 else -6
            elif kind == "marble":
                d += 16 if abs((i + j * 0.6) % 19 - 9) < 0.7 else 0
                d -= 22 if i % 16 == 0 or j % 16 == 0 else 0
            else:
                d -= 18 if i == 0 or j == 0 else 0
            px[j][i] = shade(base, d)
    return px

def wall(name, base, kind):
    """32x32 tiling back wall: brick (garage/loft) or glass panes (SoMa/campus)."""
    px = blank(32, 32)
    rng = random.Random(name)
    for j in range(32):
        for i in range(32):
            d = rng.randrange(-5, 6)
            if kind == "brick":
                d += -40 if j % 8 == 7 or (i + (8 if (j // 8) % 2 else 0)) % 16 == 15 else 0
            else:
                d += -50 if i % 16 == 0 or j == 31 else (30 if (i % 16 + j) % 22 < 3 else 0)
            px[j][i] = shade(base, d)
    return px

def founder_desk():
    """64x36 CEO desk (drawn at 2x like the counter it replaces): walnut top, two monitors, paw laptop, CEO plate."""
    px = blank(64, 36)
    shadow(px, 32, 33, 31, 3)
    wood = (110, 70, 44, 255)
    rect(px, 1, 16, 62, 15, wood); rect(px, 1, 16, 62, 2, shade(wood, 34)); rect(px, 1, 30, 62, 1, shade(wood, -40))
    for x in (8, 32, 56):  # panel grooves
        rect(px, x, 20, 1, 9, shade(wood, -28))
    rect(px, 24, 22, 16, 5, (60, 38, 24, 255)); text2(px, "CEO", 32, 23, (240, 200, 90, 255), 1)
    for mx in (6, 40):  # monitors
        rect(px, mx, 2, 18, 12, (36, 38, 46, 255)); rect(px, mx + 1, 3, 16, 9, (20, 34, 52, 255))
        rect(px, mx + 7, 14, 4, 2, (60, 62, 70, 255))
    for j, c in [(4, (110, 220, 140)), (6, (120, 180, 255)), (8, (250, 200, 90)), (10, (110, 220, 140))]:
        rect(px, 8, j, 6 + j % 5, 1, rgba(c))
    for i, h in enumerate([2, 4, 3, 6, 8]):  # growth chart on the right screen
        rect(px, 43 + i * 3, 11 - h, 2, h, (90, 230, 130, 255))
    rect(px, 26, 10, 12, 6, (190, 194, 204, 255)); rect(px, 27, 11, 10, 4, (230, 232, 238, 255))  # laptop
    dot(px, 31, 12, (200, 120, 60, 255)); dot(px, 33, 12, (200, 120, 60, 255)); rect(px, 31, 13, 3, 1, (200, 120, 60, 255))
    rect(px, 58, 11, 3, 5, (240, 200, 70, 255)); rect(px, 57, 10, 5, 1, (240, 200, 70, 255))  # trophy
    selout(px, -50)
    return px

def treat_bar():
    """48x40 treat bar: glass jars of biscuits, bones and kibble on a counter."""
    px = blank(48, 40)
    shadow(px, 24, 37, 22, 3)
    rect(px, 2, 22, 44, 14, (220, 120, 60, 255)); rect(px, 2, 22, 44, 2, (250, 170, 100, 255))
    for i in range(4, 44, 6):
        rect(px, i, 26, 3, 9, (200, 100, 50, 255))
    rng = random.Random(5)
    for k, (x, fill) in enumerate([(5, (200, 150, 90)), (17, (240, 230, 210)), (29, (150, 90, 50)), (39, (230, 180, 80))]):
        w = 10 if k < 3 else 7
        rect(px, x, 8, w, 14, (200, 230, 240, 255)); rect(px, x + 1, 6, w - 2, 2, (180, 60, 60, 255))
        for _ in range(14):
            dot(px, x + 1 + rng.randrange(w - 2), 11 + rng.randrange(10), shade(rgba(fill), rng.randrange(-30, 20)))
        rect(px, x + 1, 9, 1, 12, (240, 250, 255, 255))
    text2(px, "TREATS", 24, 0, (250, 230, 120, 255), 1)
    selout(px, -50)
    return px

if __name__ == "__main__":
    for name, fn in [("su_desk", desk), ("su_server", server_rack), ("su_espresso", espresso),
                     ("su_ballpit", ball_pit), ("su_board", whiteboard), ("su_neon", neon), ("su_bell", bell),
                     ("su_plant", plant), ("su_founder", founder_desk), ("su_treatbar", treat_bar)]:
        write_png(f"{name}.png", fn())
    for n, (base, kind) in enumerate([((128, 130, 136, 255), "concrete"), ((170, 118, 74, 255), "wood"),
                                      ((70, 90, 130, 255), "carpet"), ((226, 224, 218, 255), "marble")]):
        write_png(f"su_floor_{n}.png", floor(f"f{n}", base, kind))
    for n, (base, kind) in enumerate([((150, 80, 64, 255), "brick"), ((176, 96, 70, 255), "brick"),
                                      ((120, 170, 210, 255), "glass"), ((150, 200, 230, 255), "glass")]):
        write_png(f"su_wall_{n}.png", wall(f"w{n}", base, kind))
    print("startup art done")
