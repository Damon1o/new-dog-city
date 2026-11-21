"""Boss sprites for New Dog City: King of Raccoons, Pideon Queen, Rat Meister, Fat Cat and the
Boss Hedgehog. Pure stdlib, reuses gen_props' helpers. Run: python tools/gen_bosses.py

Every sprite faces right (boss.gd flips it toward the dog) and is drawn untinted; boss.gd shows
it at ART_SCALE and keeps the small critter PNGs for shots."""
import math
from gen_props import blank, ball, ellipse, shadow, selout, glow, write_png, K
from gen_buildings import rect, dot, shade

GOLD, GOLD_D = (240, 196, 60, 255), (178, 128, 30, 255)
RUBY, EMERALD = (214, 40, 60, 255), (60, 200, 110, 255)

def tri(px, a, b, c, col):
    """Filled triangle by barycentric test (pixel centres)."""
    xs, ys = [p[0] for p in (a, b, c)], [p[1] for p in (a, b, c)]
    def side(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    for j in range(int(min(ys)), int(max(ys)) + 1):
        for i in range(int(min(xs)), int(max(xs)) + 1):
            p = (i + 0.5, j + 0.5)
            s1, s2, s3 = side(a, b, p), side(b, c, p), side(c, a, p)
            if (s1 >= 0 and s2 >= 0 and s3 >= 0) or (s1 <= 0 and s2 <= 0 and s3 <= 0):
                dot(px, i, j, col)

def line(px, x0, y0, x1, y1, col):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for k in range(n + 1):
        t = k / n
        dot(px, round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), col)

def crown(px, x, y, w, gem=RUBY):
    rect(px, x, y + 3, w, 3, GOLD)
    rect(px, x, y + 5, w, 1, GOLD_D)
    for k in range(3):
        cx = x + 1 + k * (w - 3) // 2
        tri(px, (cx - 1, y + 3), (cx + 2, y + 3), (cx + 0.5, y - 1), GOLD)
    dot(px, x + w // 2, y + 4, gem)

def eye(px, x, y, iris=(250, 250, 250, 255), pupil=K):
    rect(px, x, y, 2, 2, iris)
    dot(px, x + 1, y + 1, pupil)

def finish(px):
    selout(px, -50)
    return px

def raccoon():
    px = blank(56, 46)
    shadow(px, 28, 42, 22, 3.5)
    G, D, W = (146, 146, 154, 255), (70, 70, 78, 255), (230, 230, 232, 255)
    for k in range(6):  # ringed tail curling up behind
        t = k / 5
        ellipse(px, 13 - 7 * t, 30 - 14 * t, 5.5 - t, 4.5 - t, D if k % 2 else G)
    ellipse(px, 20, 27, 14, 10, (150, 28, 48, 255))  # royal cape
    for i in range(8, 33):
        if px[36][i][3]:
            dot(px, i, 36, GOLD)
    ball(px, 26, 31, 13, G, 9)
    ellipse(px, 29, 34, 7, 5, W)  # belly
    for x in (17, 23, 30, 36):
        rect(px, x, 38, 3, 4, D)
    ball(px, 39, 22, 9, G, 8)
    tri(px, (32, 16), (36, 15), (33, 9), G)
    tri(px, (40, 14), (44, 15), (42, 8), G)
    ellipse(px, 41, 21, 7, 2.6, (40, 40, 46, 255))  # bandit mask
    eye(px, 38, 20); eye(px, 43, 20)
    ellipse(px, 45, 26, 4, 2.5, W)
    rect(px, 48, 25, 2, 2, K)
    finish(px)
    crown(px, 34, 4, 10)
    glow(px, 39, 6, 6, GOLD, 0.25)
    return px

def pigeon():
    px = blank(50, 46)
    shadow(px, 24, 42, 17, 3)
    B, D = (128, 138, 156, 255), (84, 94, 112, 255)
    tri(px, (4, 26), (14, 22), (12, 34), D)  # tail fan
    tri(px, (2, 32), (14, 26), (13, 36), shade(D, -14))
    ball(px, 23, 29, 14, B, 11)
    ellipse(px, 19, 29, 9, 6, D)  # wing
    for k in range(3):
        line(px, 12 + k * 4, 33, 18 + k * 4, 26, shade(D, -18))
    ellipse(px, 31, 21, 6, 6, (80, 180, 130, 255))  # iridescent neck
    ellipse(px, 32, 23, 5, 3, (150, 90, 180, 255))
    ball(px, 33, 14, 7, B)
    tri(px, (39, 13), (45, 15), (39, 17), (232, 150, 64, 255))
    eye(px, 35, 12, (240, 120, 40, 255))
    for x in (20, 27):
        line(px, x, 39, x - 1, 43, (232, 150, 64, 255))
        line(px, x - 1, 43, x - 3, 43, (232, 150, 64, 255))
    line(px, 14, 24, 32, 36, (236, 120, 190, 255))  # royal sash
    line(px, 14, 25, 32, 37, (236, 120, 190, 255))
    finish(px)
    rect(px, 29, 6, 8, 2, GOLD)  # tiara
    tri(px, (31, 6), (35, 6), (33, 1), GOLD)
    dot(px, 33, 5, (236, 120, 190, 255))
    glow(px, 33, 4, 5, (255, 200, 240), 0.3)
    return px

def rat():
    px = blank(58, 40)
    shadow(px, 27, 36, 20, 3)
    B, H = (132, 116, 106, 255), (224, 160, 164, 255)
    for k in range(12):  # long pink tail
        y0, y1 = 29 + 4 * math.sin(k / 2), 29 + 4 * math.sin((k + 1) / 2)
        line(px, 12 - k, y0, 11 - k, y1, H)
        line(px, 12 - k, y0 + 1, 11 - k, y1 + 1, H)
    ball(px, 25, 27, 14, B, 9)
    ellipse(px, 23, 26, 12, 7, (64, 120, 64, 255))  # green tailcoat
    ellipse(px, 28, 30, 6, 4, (226, 220, 206, 255))  # shirt front
    for x in (16, 22, 29, 34):
        rect(px, x, 33, 3, 3, shade(B, -30))
    ball(px, 40, 23, 8, B, 7)
    tri(px, (45, 19), (53, 24), (45, 28), B)  # snout
    dot(px, 53, 24, H); dot(px, 52, 24, H)
    ellipse(px, 36, 15, 4, 4, B)
    ellipse(px, 36, 15, 2.4, 2.4, H)
    eye(px, 42, 20, (230, 40, 40, 255))
    finish(px)
    for d in (-1, 1):  # whiskers
        line(px, 50, 24, 56, 24 + 2 * d, (220, 220, 220, 255))
    for a in range(16):  # gold monocle
        dot(px, round(43 + 3 * math.cos(a / 16 * math.tau)), round(21 + 3 * math.sin(a / 16 * math.tau)), GOLD)
    line(px, 43, 24, 41, 31, GOLD_D)
    rect(px, 36, 2, 9, 9, (34, 32, 38, 255))  # top hat
    rect(px, 36, 8, 9, 2, (180, 40, 50, 255))
    rect(px, 33, 11, 15, 2, (24, 22, 28, 255))
    return px

def fat_cat():
    px = blank(52, 52)
    shadow(px, 26, 48, 21, 3.5)
    O, D = (230, 144, 62, 255), (186, 104, 44, 255)
    N = (40, 48, 82, 255)
    tri(px, (40, 34), (48, 22), (50, 26), O)  # tail
    ball(px, 26, 34, 17, N, 14)  # navy suit
    tri(px, (20, 21), (32, 21), (26, 40), (240, 236, 228, 255))  # shirt
    tri(px, (25, 23), (27, 23), (26, 36), RUBY)  # tie
    for k in range(13):  # gold chain
        a = math.pi * (0.15 + 0.7 * k / 12)
        dot(px, round(26 + 12 * math.cos(a)), round(30 + 7 * math.sin(a)), GOLD)
    for x in (13, 33):
        ellipse(px, x + 3, 45, 5, 3, O)
    ball(px, 26, 15, 11, O, 10)
    tri(px, (16, 10), (21, 6), (19, 1), O)
    tri(px, (31, 6), (36, 10), (33, 1), O)
    dot(px, 19, 5, (240, 150, 160, 255)); dot(px, 33, 5, (240, 150, 160, 255))
    for x in (21, 26, 31):  # forehead stripes
        line(px, x, 6, x, 9, D)
    ellipse(px, 26, 19, 6, 4, (248, 238, 222, 255))
    eye(px, 21, 13, EMERALD); eye(px, 29, 13, EMERALD)
    dot(px, 26, 18, (240, 150, 160, 255))
    finish(px)
    for d in (-1, 1):
        line(px, 26 + 6 * d, 19, 26 + 13 * d, 18, (250, 250, 250, 255))
    glow(px, 26, 30, 10, GOLD, 0.15)
    return px

def hedgehog():
    px = blank(60, 50)
    shadow(px, 30, 46, 24, 3.5)
    S, T = (70, 48, 30, 255), (226, 214, 180, 255)
    for k in range(17):  # spines over the back, cream tips
        a = math.radians(100 + k * 12)
        d = (math.cos(a), math.sin(a))
        o = (-d[1] * 3.5, d[0] * 3.5)
        base = (27 + d[0] * 10, 28 + d[1] * 8)
        tip = (27 + d[0] * 24, 28 + d[1] * 20)
        tri(px, (base[0] + o[0], base[1] + o[1]), (base[0] - o[0], base[1] - o[1]), tip, S)
        dot(px, int(tip[0] - d[0]), int(tip[1] - d[1]), T)
    ball(px, 28, 30, 16, (120, 82, 50, 255), 13)
    ellipse(px, 40, 32, 10, 8, (218, 184, 140, 255))  # face
    ellipse(px, 33, 38, 8, 5, (218, 184, 140, 255))  # belly
    for x in (22, 34):
        ellipse(px, x, 43, 4, 2.5, (90, 60, 40, 255))
    ellipse(px, 36, 21, 3, 3, (150, 110, 80, 255))  # ear
    rect(px, 48, 30, 3, 3, K)  # nose
    eye(px, 42, 27, K, (230, 40, 40, 255))
    line(px, 40, 24, 45, 26, K)  # angry brow
    finish(px)
    return px

if __name__ == "__main__":
    for name, fn in [("raccoon", raccoon), ("pigeon", pigeon), ("rat", rat), ("cat", fat_cat), ("hedgehog", hedgehog)]:
        write_png(f"boss_{name}.png", fn())
    print("bosses done")
