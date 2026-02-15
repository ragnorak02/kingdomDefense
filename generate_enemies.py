"""Generate enemy type sprite PNGs for Korean Fantasy TD."""
import struct, zlib, os

ASSETS = os.path.join(os.path.dirname(__file__), "assets")
os.makedirs(ASSETS, exist_ok=True)

def write_png(path, width, height, pixels):
    def chunk(ctype, data):
        c = ctype + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
    raw = b""
    for row in pixels:
        raw += b"\x00"
        for r, g, b, a in row:
            raw += struct.pack("BBBB", r, g, b, a)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(raw)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))
    print(f"  Created {path}")

def make_grid(w, h, fill=(0,0,0,0)):
    return [[fill for _ in range(w)] for _ in range(h)]

def set_px(grid, x, y, color):
    if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
        grid[y][x] = color

def fill_rect(grid, x1, y1, x2, y2, color):
    for y in range(y1, y2+1):
        for x in range(x1, x2+1):
            set_px(grid, x, y, color)

def fill_circle(grid, cx, cy, r, color):
    for y in range(cy-r, cy+r+1):
        for x in range(cx-r, cx+r+1):
            if (x-cx)**2 + (y-cy)**2 <= r*r:
                set_px(grid, x, y, color)

def fill_diamond(grid, cx, cy, hw, hh, color):
    for y in range(cy-hh, cy+hh+1):
        dy = abs(y - cy)
        xspan = int(hw * (1.0 - dy / hh)) if hh > 0 else hw
        for x in range(cx-xspan, cx+xspan+1):
            set_px(grid, x, y, color)

# ── ORC (32x32) — bulky green brute ──
def gen_orc():
    g = make_grid(32, 32)
    # Shadow (wider — he's big)
    fill_diamond(g, 16, 29, 9, 3, (0,0,0,60))
    # Body (wide and stocky)
    fill_diamond(g, 16, 21, 8, 8, (60, 110, 50, 255))
    fill_diamond(g, 16, 20, 7, 6, (80, 140, 65, 255))
    # Armor plate
    fill_rect(g, 12, 16, 20, 20, (80, 80, 70, 255))
    fill_rect(g, 13, 17, 19, 19, (100, 95, 80, 255))
    # Dark underside
    fill_rect(g, 10, 25, 22, 27, (40, 75, 35, 255))
    # Head (large, square-ish)
    fill_circle(g, 16, 10, 5, (60, 110, 50, 255))
    fill_circle(g, 16, 10, 4, (75, 130, 60, 255))
    # Tusks
    set_px(g, 13, 13, (220, 210, 180, 255))
    set_px(g, 13, 14, (220, 210, 180, 255))
    set_px(g, 19, 13, (220, 210, 180, 255))
    set_px(g, 19, 14, (220, 210, 180, 255))
    # Eyes (angry)
    set_px(g, 14, 9, (200, 50, 30, 255))
    set_px(g, 18, 9, (200, 50, 30, 255))
    # Brow
    fill_rect(g, 13, 7, 15, 8, (50, 90, 40, 255))
    fill_rect(g, 17, 7, 19, 8, (50, 90, 40, 255))
    # Club (right side)
    fill_rect(g, 24, 12, 26, 22, (100, 70, 40, 255))
    fill_rect(g, 23, 10, 27, 12, (120, 85, 50, 255))
    # Spikes on club
    set_px(g, 23, 9, (150, 150, 150, 255))
    set_px(g, 27, 9, (150, 150, 150, 255))
    set_px(g, 28, 11, (150, 150, 150, 255))
    return g

# ── SWIFT (32x32) — slim purple assassin ──
def gen_swift():
    g = make_grid(32, 32)
    # Shadow (narrow)
    fill_diamond(g, 16, 28, 6, 2, (0,0,0,50))
    # Body (slim)
    fill_diamond(g, 16, 21, 5, 7, (100, 50, 140, 255))
    fill_diamond(g, 16, 20, 4, 5, (130, 70, 170, 255))
    # Cloak/scarf trailing
    set_px(g, 10, 18, (80, 40, 120, 200))
    set_px(g, 9, 19, (80, 40, 120, 180))
    set_px(g, 8, 20, (80, 40, 120, 140))
    set_px(g, 22, 18, (80, 40, 120, 200))
    set_px(g, 23, 19, (80, 40, 120, 180))
    set_px(g, 24, 20, (80, 40, 120, 140))
    # Head (hooded)
    fill_circle(g, 16, 11, 3, (100, 50, 140, 255))
    fill_circle(g, 16, 11, 2, (130, 70, 170, 255))
    # Hood peak
    set_px(g, 16, 7, (90, 45, 130, 255))
    set_px(g, 15, 8, (90, 45, 130, 255))
    set_px(g, 17, 8, (90, 45, 130, 255))
    # Eyes (glowing)
    set_px(g, 14, 11, (200, 100, 255, 255))
    set_px(g, 18, 11, (200, 100, 255, 255))
    # Speed lines
    set_px(g, 6, 15, (130, 70, 170, 80))
    set_px(g, 5, 16, (130, 70, 170, 60))
    set_px(g, 4, 17, (130, 70, 170, 40))
    set_px(g, 6, 20, (130, 70, 170, 80))
    set_px(g, 5, 21, (130, 70, 170, 60))
    # Daggers
    set_px(g, 22, 15, (180, 180, 200, 255))
    set_px(g, 23, 14, (200, 200, 220, 255))
    set_px(g, 10, 15, (180, 180, 200, 255))
    set_px(g, 9, 14, (200, 200, 220, 255))
    return g

# ── DEMON (32x32) — large dark red boss ──
def gen_demon():
    g = make_grid(32, 32)
    # Shadow (large)
    fill_diamond(g, 16, 29, 10, 3, (0,0,0,80))
    # Body (large, dark)
    fill_diamond(g, 16, 20, 9, 9, (120, 25, 25, 255))
    fill_diamond(g, 16, 19, 8, 7, (160, 35, 35, 255))
    # Dark armor plates
    fill_rect(g, 10, 16, 22, 22, (80, 15, 15, 255))
    fill_rect(g, 11, 17, 21, 21, (100, 20, 20, 255))
    # Underside
    fill_rect(g, 9, 25, 23, 28, (90, 15, 15, 255))
    # Head (demonic)
    fill_circle(g, 16, 9, 5, (120, 25, 25, 255))
    fill_circle(g, 16, 9, 4, (150, 30, 30, 255))
    # Horns (large, curving)
    set_px(g, 10, 7, (180, 160, 80, 255))
    set_px(g, 9, 5, (180, 160, 80, 255))
    set_px(g, 8, 4, (200, 180, 90, 255))
    set_px(g, 8, 3, (200, 180, 90, 255))
    set_px(g, 22, 7, (180, 160, 80, 255))
    set_px(g, 23, 5, (180, 160, 80, 255))
    set_px(g, 24, 4, (200, 180, 90, 255))
    set_px(g, 24, 3, (200, 180, 90, 255))
    # Eyes (burning)
    set_px(g, 14, 8, (255, 100, 0, 255))
    set_px(g, 13, 8, (255, 180, 0, 255))
    set_px(g, 18, 8, (255, 100, 0, 255))
    set_px(g, 19, 8, (255, 180, 0, 255))
    # Mouth (flame)
    set_px(g, 15, 12, (255, 150, 0, 255))
    set_px(g, 16, 12, (255, 200, 0, 255))
    set_px(g, 17, 12, (255, 150, 0, 255))
    set_px(g, 16, 13, (255, 100, 0, 200))
    # Wings (small, vestigial)
    for i in range(4):
        set_px(g, 5-i, 12+i, (100, 20, 20, 200-i*40))
        set_px(g, 27+i, 12+i, (100, 20, 20, 200-i*40))
    for i in range(3):
        set_px(g, 6-i, 11+i, (80, 15, 15, 180-i*40))
        set_px(g, 26+i, 11+i, (80, 15, 15, 180-i*40))
    # Tail
    set_px(g, 16, 29, (100, 20, 20, 200))
    set_px(g, 17, 30, (100, 20, 20, 180))
    set_px(g, 18, 30, (100, 20, 20, 150))
    set_px(g, 19, 31, (120, 30, 30, 120))
    return g

print("Generating enemy type sprites...")
write_png(os.path.join(ASSETS, "enemy_orc.png"), 32, 32, gen_orc())
write_png(os.path.join(ASSETS, "enemy_swift.png"), 32, 32, gen_swift())
write_png(os.path.join(ASSETS, "enemy_demon.png"), 32, 32, gen_demon())
print("Done!")
