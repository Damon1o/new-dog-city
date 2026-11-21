"""Generate all pixel-art PNG assets for New Dog City. Pure stdlib."""
import os, random, struct, wave, zlib

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
    assert len({len(r) for r in rows}) == 1, f"ragged sprite grid: {rows}"
    return [[pal[c] for c in row] for row in rows]

# ---------- small sprites (dogs, critters and street props live in gen_props.py) ----------
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

def brownstone():
    px = building(80, 88, (125, 85, 70, 255), (225, 200, 120, 255))
    rect(px, 34, 70, 12, 18, (60, 40, 30, 255))  # door
    return px

# ---------- sound effects (stdlib wave) ----------
SR = 22050

def sweep(f0, f1, dur, noise=0.0, vol=0.6):
    """Square-wave pitch sweep with optional noise mix and linear fade-out."""
    n = int(SR * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        phase += (f0 + (f1 - f0) * t) / SR
        s = (1.0 if phase % 1 < 0.5 else -1.0) * (1 - noise) + random.uniform(-1, 1) * noise
        out.append(s * vol * (1 - t))
    return out

def write_wav(name, samples):
    os.makedirs(os.path.join(OUT, "sfx"), exist_ok=True)
    with wave.open(os.path.join(OUT, "sfx", name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(b"".join(struct.pack("<h", int(s * 32000)) for s in samples))
    print(f"sfx/{name}.wav: {len(samples) / SR:.2f}s")

def purina_bag():
    px = blank(12, 14, T)
    rect(px, 1, 1, 10, 13, (190, 60, 50, 255))
    rect(px, 2, 3, 8, 4, (240, 220, 100, 255))
    rect(px, 2, 9, 8, 3, (240, 240, 240, 255))
    return px

# ---------- interiors: bodega + subway station ----------
def shop_floor_tile():
    px = blank(32, 32, (228, 218, 195, 255))
    rect(px, 0, 0, 16, 16, (95, 140, 120, 255))
    rect(px, 16, 16, 16, 16, (95, 140, 120, 255))
    for k in range(32):
        px[k][0] = px[0][k] = px[k][16] = px[16][k] = (70, 100, 88, 255)
    return px

def shop_wall_tile():
    px = blank(32, 32, (210, 195, 150, 255))
    rect(px, 0, 15, 32, 1, (190, 175, 132, 255))
    rect(px, 0, 28, 32, 4, (120, 88, 62, 255))  # repeats as wainscot lines
    return px

def shelf():
    rnd = random.Random(7)
    px = blank(48, 40, (110, 80, 55, 255))
    goods = [(200, 60, 50), (240, 200, 70), (70, 130, 200), (90, 170, 100), (235, 235, 235), (230, 130, 50)]
    for row in range(3):
        y = 3 + row * 12
        rect(px, 2, y, 44, 9, (60, 42, 30, 255))
        for i in range(3, 45, 5):
            h = rnd.randint(5, 8)
            rect(px, i, y + 9 - h, 4, h, rnd.choice(goods) + (255,))
    return px

def counter():
    px = blank(64, 36, T)
    rect(px, 0, 8, 64, 28, (120, 85, 60, 255))
    rect(px, 0, 8, 64, 5, (165, 125, 85, 255))
    rect(px, 4, 18, 56, 2, (95, 66, 46, 255))
    rect(px, 42, 0, 16, 10, (90, 95, 100, 255))   # register
    rect(px, 44, 2, 8, 3, (120, 220, 140, 255))
    return px

def station_wall_tile():
    px = blank(32, 32, (226, 229, 226, 255))
    grout = (182, 187, 184, 255)
    for j in range(0, 32, 8):
        rect(px, 0, j, 32, 1, grout)
        for i in range((j // 8 % 2) * 8, 32, 16):
            rect(px, i, j, 1, 8, grout)
    return px

def platform_tile():
    px = blank(32, 32, (128, 128, 126, 255))
    for j in range(32):
        for i in range(32):
            if (i * 7 + j * 13) % 11 == 0:
                px[j][i] = (116, 116, 114, 255)
    rect(px, 0, 0, 32, 1, (104, 104, 102, 255))
    rect(px, 0, 0, 1, 32, (104, 104, 102, 255))
    return px

def pillar():
    px = blank(12, 40, T)
    rect(px, 2, 0, 8, 40, (50, 95, 70, 255))
    rect(px, 4, 4, 2, 32, (80, 130, 100, 255))
    rect(px, 0, 0, 12, 4, (38, 75, 55, 255))
    rect(px, 0, 36, 12, 4, (38, 75, 55, 255))
    return px

os.makedirs(OUT, exist_ok=True)
write_png("shop_floor.png", shop_floor_tile())
write_png("shop_wall.png", shop_wall_tile())
write_png("shelf.png", shelf())
write_png("counter.png", counter())
write_png("station_wall.png", station_wall_tile())
write_png("platform.png", platform_tile())
write_png("pillar.png", pillar())
write_png("building_c.png", brownstone())  # train / track / stairs / map_board: tools/gen_subway.py

random.seed(1)
write_wav("bark", sweep(420, 180, 0.09, 0.3) + sweep(380, 150, 0.12, 0.3))
write_wav("catch", sweep(600, 1300, 0.12))
write_wav("hurt", sweep(300, 90, 0.22, 0.2))
write_wav("buy", sweep(880, 880, 0.08) + sweep(1320, 1320, 0.12))
write_wav("levelup", sum((sweep(f, f, 0.1) for f in (523, 659, 784, 1047)), []))
write_wav("steam", sweep(100, 100, 0.6, 1.0, 0.35))
write_wav("subway", sweep(70, 50, 0.7, 0.5, 0.5))
write_wav("pickup", sweep(1000, 1500, 0.06, 0.0, 0.4))
write_png("steam.png", grid(STEAM, STEAM_PAL))
write_png("treat.png", grid(TREAT, TREAT_PAL))
write_png("road.png", road_tile())
write_png("road_dash.png", road_dash_tile())
write_png("sidewalk.png", sidewalk_tile())
write_png("grass.png", grass_tile())
write_png("building_a.png", building(64, 96, (140, 100, 90, 255), (95, 115, 145, 255)))
write_png("building_b.png", building(64, 112, (120, 125, 135, 255), (100, 120, 150, 255)))
write_png("purina.png", purina_bag())
print("done")
