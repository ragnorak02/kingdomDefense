"""Generate enhanced pixel-art sprite PNGs for Korean Fantasy TD — V2.
Produces animated sprite sheets (horizontal strips), textured tiles, and
improved static sprites. Uses only Python built-ins (struct, zlib).

Run: python generate_sprites_v2.py
"""
import struct, zlib, os, math, random

random.seed(42)  # Deterministic output

ASSETS = os.path.join(os.path.dirname(__file__), "assets")
os.makedirs(ASSETS, exist_ok=True)

# ── PNG writer (from generate_sprites.py) ──

def write_png(path, width, height, pixels):
    """Write RGBA PNG. pixels = list of rows, each row = list of (R,G,B,A) tuples."""
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

# ── Drawing helpers ──

def make_grid(w, h, fill=(0,0,0,0)):
    return [[fill for _ in range(w)] for _ in range(h)]

def get_px(grid, x, y):
    if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
        return grid[y][x]
    return (0, 0, 0, 0)

def set_px(grid, x, y, color):
    if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
        grid[y][x] = color

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def blend_px(base, overlay):
    """Alpha-blend overlay onto base."""
    br, bg, bb, ba = base
    or_, og, ob, oa = overlay
    if oa == 0:
        return base
    if oa == 255 or ba == 0:
        return overlay
    af = oa / 255.0
    bf = (ba / 255.0) * (1 - af)
    out_a = af + bf
    if out_a == 0:
        return (0, 0, 0, 0)
    r = int((or_ * af + br * bf) / out_a)
    g = int((og * af + bg * bf) / out_a)
    b = int((ob * af + bb * bf) / out_a)
    return (clamp(r,0,255), clamp(g,0,255), clamp(b,0,255), clamp(int(out_a*255),0,255))

def set_px_blend(grid, x, y, color):
    if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
        grid[y][x] = blend_px(grid[y][x], color)

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

def outline_diamond(grid, cx, cy, hw, hh, color):
    for y in range(cy-hh, cy+hh+1):
        dy = abs(y - cy)
        xspan = int(hw * (1.0 - dy / hh)) if hh > 0 else hw
        set_px(grid, cx-xspan, y, color)
        set_px(grid, cx+xspan, y, color)
    for x in range(cx-hw, cx+hw+1):
        dx = abs(x - cx)
        yspan = int(hh * (1.0 - dx / hw)) if hw > 0 else hh
        set_px(grid, x, cy-yspan, color)
        set_px(grid, x, cy+yspan, color)

def draw_line(grid, x0, y0, x1, y1, color):
    """Bresenham line."""
    dx = abs(x1 - x0)
    dy = abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    while True:
        set_px(grid, x0, y0, color)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy

def noise_fill(grid, x1, y1, x2, y2, base_color, variation=15):
    """Fill rect with slight color noise for texture."""
    r0, g0, b0, a0 = base_color
    for y in range(y1, y2+1):
        for x in range(x1, x2+1):
            v = random.randint(-variation, variation)
            c = (clamp(r0+v,0,255), clamp(g0+v,0,255), clamp(b0+v,0,255), a0)
            set_px(grid, x, y, c)

def noise_fill_diamond(grid, cx, cy, hw, hh, base_color, variation=12):
    """Fill diamond shape with color noise."""
    r0, g0, b0, a0 = base_color
    for y in range(cy-hh, cy+hh+1):
        dy = abs(y - cy)
        xspan = int(hw * (1.0 - dy / hh)) if hh > 0 else hw
        for x in range(cx-xspan, cx+xspan+1):
            v = random.randint(-variation, variation)
            set_px(grid, x, y, (clamp(r0+v,0,255), clamp(g0+v,0,255), clamp(b0+v,0,255), a0))

def shift_color(color, dr=0, dg=0, db=0, da=0):
    r, g, b, a = color
    return (clamp(r+dr,0,255), clamp(g+dg,0,255), clamp(b+db,0,255), clamp(a+da,0,255))

def make_spritesheet(frames, fw, fh):
    """Stitch list of frame grids (each fw x fh) into horizontal strip."""
    n = len(frames)
    sheet = make_grid(fw * n, fh)
    for fi, frame in enumerate(frames):
        ox = fi * fw
        for y in range(fh):
            for x in range(fw):
                sheet[y][ox + x] = frame[y][x]
    return sheet

def copy_frame(src):
    """Deep copy a pixel grid."""
    return [row[:] for row in src]

# ── Colors ──
T = (0, 0, 0, 0)
HERO_BLUE = (50, 90, 200, 255)
HERO_BLUE_LIGHT = (80, 120, 230, 255)
HERO_BLUE_DARK = (30, 60, 150, 255)
HERO_GOLD = (230, 200, 50, 255)
HERO_GOLD_DARK = (180, 150, 30, 255)
HERO_SKIN = (220, 185, 150, 255)
HERO_SWORD = (200, 200, 210, 255)
HERO_SWORD_EDGE = (240, 240, 250, 255)
ENEMY_RED = (200, 40, 40, 255)
ENEMY_RED_LIGHT = (230, 70, 60, 255)
ENEMY_RED_DARK = (140, 20, 20, 255)
ENEMY_HORN = (180, 160, 80, 255)
ENEMY_EYE = (255, 220, 50, 255)
TOWER_STONE = (100, 110, 130, 255)
TOWER_STONE_LIGHT = (130, 140, 160, 255)
TOWER_STONE_DARK = (70, 75, 90, 255)
TOWER_ROOF = (60, 80, 160, 255)
TOWER_ROOF_LIGHT = (80, 100, 190, 255)
ARCHER_GREEN = (50, 140, 60, 255)
ARCHER_GREEN_LIGHT = (70, 170, 80, 255)
ARCHER_GREEN_DARK = (30, 100, 40, 255)
ARCHER_BOW = (140, 90, 40, 255)
ARCHER_STRING = (200, 200, 180, 255)
WALL_BROWN = (140, 115, 90, 255)
WALL_BROWN_LIGHT = (165, 140, 110, 255)
WALL_BROWN_DARK = (100, 80, 60, 255)
WALL_MORTAR = (170, 160, 140, 255)
ROCK_GRAY = (130, 130, 135, 255)
ROCK_GRAY_LIGHT = (160, 160, 165, 255)
ROCK_GRAY_DARK = (90, 90, 95, 255)
ROCK_HIGHLIGHT = (180, 180, 185, 255)
ARROW_GOLD = (255, 200, 50, 255)
ARROW_BRIGHT = (255, 240, 150, 255)
ARROW_SHAFT = (160, 120, 60, 255)
# Enemy-type colors
ORC_GREEN = (60, 110, 50, 255)
ORC_GREEN_LIGHT = (80, 140, 65, 255)
ORC_GREEN_DARK = (40, 75, 35, 255)
SWIFT_PURPLE = (100, 50, 140, 255)
SWIFT_PURPLE_LIGHT = (130, 70, 170, 255)
SWIFT_PURPLE_DARK = (80, 40, 120, 255)
DEMON_RED = (120, 25, 25, 255)
DEMON_RED_LIGHT = (160, 35, 35, 255)
DEMON_RED_DARK = (90, 15, 15, 255)

# ═══════════════════════════════════════════════════════════════════
# HERO SPRITE SHEETS
# ═══════════════════════════════════════════════════════════════════

def _hero_base():
    """Base hero frame — returns 32x32 grid."""
    g = make_grid(32, 32)
    fill_diamond(g, 16, 28, 8, 3, (0,0,0,60))
    fill_diamond(g, 16, 20, 7, 8, HERO_BLUE)
    fill_diamond(g, 16, 19, 6, 6, HERO_BLUE_LIGHT)
    fill_rect(g, 14, 15, 18, 15, HERO_BLUE_DARK)
    fill_rect(g, 13, 18, 19, 18, HERO_BLUE_DARK)
    fill_circle(g, 16, 10, 4, HERO_SKIN)
    fill_rect(g, 12, 6, 20, 8, HERO_GOLD)
    fill_rect(g, 13, 6, 19, 7, HERO_GOLD_DARK)
    set_px(g, 16, 5, HERO_GOLD)
    set_px(g, 16, 4, HERO_GOLD)
    set_px(g, 14, 10, (40, 40, 60, 255))
    set_px(g, 18, 10, (40, 40, 60, 255))
    # Sword
    for i in range(8):
        set_px(g, 24, 12+i, HERO_SWORD)
        set_px(g, 25, 12+i, HERO_SWORD_EDGE if i < 5 else HERO_SWORD)
    fill_rect(g, 23, 19, 26, 19, HERO_GOLD)
    set_px(g, 24, 20, WALL_BROWN)
    set_px(g, 24, 21, WALL_BROWN)
    # Shield
    fill_rect(g, 7, 15, 10, 21, HERO_BLUE_DARK)
    fill_rect(g, 8, 16, 9, 20, HERO_BLUE)
    set_px(g, 8, 18, HERO_GOLD)
    set_px(g, 9, 18, HERO_GOLD)
    return g

def gen_hero_idle():
    """4-frame idle: subtle breathing (body shifts 1px) + cloak flutter."""
    frames = []
    base = _hero_base()
    offsets = [0, 0, -1, 0]  # body y-shift per frame
    cloak_alphas = [200, 180, 160, 180]
    for fi in range(4):
        f = copy_frame(base)
        dy = offsets[fi]
        # Shift body slightly by modifying shadow
        if dy != 0:
            fill_diamond(f, 16, 28+dy, 8, 3, (0,0,0,60))
        # Cloak flutter — vary a pixel on the cloak edge
        ca = cloak_alphas[fi]
        set_px(f, 7, 22, (HERO_BLUE_DARK[0], HERO_BLUE_DARK[1], HERO_BLUE_DARK[2], ca))
        set_px(f, 21, 22, (HERO_BLUE_DARK[0], HERO_BLUE_DARK[1], HERO_BLUE_DARK[2], ca))
        # Subtle chest highlight shimmer
        if fi in [1, 3]:
            set_px(f, 16, 17, shift_color(HERO_BLUE_LIGHT, 15, 15, 15))
        frames.append(f)
    return frames

def gen_hero_walk():
    """4-frame walk cycle: leg movement + arm/body bob."""
    frames = []
    leg_offsets = [(0, 0), (1, -1), (0, 0), (-1, 1)]  # (left_leg_dy, right_leg_dy)
    body_bob = [0, -1, 0, -1]
    for fi in range(4):
        f = _hero_base()
        bob = body_bob[fi]
        ll, rl = leg_offsets[fi]
        # Left leg
        set_px(f, 14, 26+ll, HERO_BLUE_DARK)
        set_px(f, 14, 27+ll, HERO_BLUE_DARK)
        # Right leg
        set_px(f, 18, 26+rl, HERO_BLUE_DARK)
        set_px(f, 18, 27+rl, HERO_BLUE_DARK)
        # Body bob — shift helmet spike
        if bob != 0:
            set_px(f, 16, 4, T)
            set_px(f, 16, 4+bob, HERO_GOLD)
        # Arm swing — move sword slightly
        if fi in [1, 3]:
            set_px(f, 24, 12, T)
            set_px(f, 25, 12, T)
            set_px(f, 24, 11, HERO_SWORD)
            set_px(f, 25, 11, HERO_SWORD_EDGE)
        frames.append(f)
    return frames

def gen_hero_attack():
    """3-frame attack: sword swing arc."""
    frames = []
    for fi in range(3):
        f = _hero_base()
        # Clear default sword position
        for i in range(8):
            set_px(f, 24, 12+i, T)
            set_px(f, 25, 12+i, T)
        fill_rect(f, 23, 19, 26, 19, T)
        set_px(f, 24, 20, T)
        set_px(f, 24, 21, T)
        if fi == 0:
            # Wind-up: sword raised high
            for i in range(6):
                set_px(f, 22+i, 6, HERO_SWORD)
                set_px(f, 22+i, 7, HERO_SWORD_EDGE if i < 4 else HERO_SWORD)
            set_px(f, 21, 7, HERO_GOLD)
        elif fi == 1:
            # Mid-swing: sword diagonal
            for i in range(7):
                set_px(f, 20+i, 10+i, HERO_SWORD_EDGE)
                set_px(f, 21+i, 10+i, HERO_SWORD)
            set_px(f, 20, 11, HERO_GOLD)
        else:
            # Follow-through: sword low-right
            for i in range(6):
                set_px(f, 22+i, 22, HERO_SWORD)
                set_px(f, 22+i, 21, HERO_SWORD_EDGE if i < 4 else HERO_SWORD)
            set_px(f, 21, 22, HERO_GOLD)
        frames.append(f)
    return frames

# ═══════════════════════════════════════════════════════════════════
# ENEMY SPRITE SHEETS
# ═══════════════════════════════════════════════════════════════════

def _goblin_base():
    """Base goblin frame."""
    g = make_grid(32, 32)
    fill_diamond(g, 16, 28, 7, 3, (0,0,0,60))
    fill_diamond(g, 16, 21, 6, 7, ENEMY_RED)
    fill_diamond(g, 16, 20, 5, 5, ENEMY_RED_LIGHT)
    fill_rect(g, 12, 24, 20, 26, ENEMY_RED_DARK)
    fill_circle(g, 16, 12, 4, ENEMY_RED)
    fill_circle(g, 16, 11, 3, ENEMY_RED_LIGHT)
    set_px(g, 12, 8, ENEMY_HORN)
    set_px(g, 11, 7, ENEMY_HORN)
    set_px(g, 20, 8, ENEMY_HORN)
    set_px(g, 21, 7, ENEMY_HORN)
    set_px(g, 14, 11, ENEMY_EYE)
    set_px(g, 18, 11, ENEMY_EYE)
    set_px(g, 15, 12, (200, 180, 40, 255))
    set_px(g, 17, 12, (200, 180, 40, 255))
    set_px(g, 15, 14, ENEMY_RED_DARK)
    set_px(g, 16, 14, ENEMY_RED_DARK)
    set_px(g, 17, 14, ENEMY_RED_DARK)
    set_px(g, 8, 19, ENEMY_RED_DARK)
    set_px(g, 9, 18, ENEMY_RED_DARK)
    set_px(g, 23, 18, ENEMY_RED_DARK)
    set_px(g, 24, 19, ENEMY_RED_DARK)
    return g

def gen_goblin_walk():
    """4-frame bouncing walk."""
    frames = []
    bob = [0, -1, 0, -1]
    arm_swing = [(8, 24), (7, 25), (8, 24), (9, 23)]
    for fi in range(4):
        f = _goblin_base()
        by = bob[fi]
        # Leg animation
        if fi % 2 == 0:
            set_px(f, 14, 27, ENEMY_RED_DARK)
            set_px(f, 18, 26, ENEMY_RED_DARK)
        else:
            set_px(f, 14, 26, ENEMY_RED_DARK)
            set_px(f, 18, 27, ENEMY_RED_DARK)
        # Arm swing
        lx, rx = arm_swing[fi]
        set_px(f, lx, 19+by, ENEMY_RED_DARK)
        set_px(f, rx, 18+by, ENEMY_RED_DARK)
        # Body bob on shadow
        if by != 0:
            fill_diamond(f, 16, 28+by, 7, 3, (0,0,0,60))
        frames.append(f)
    return frames

def _orc_base():
    """Base orc frame."""
    g = make_grid(32, 32)
    fill_diamond(g, 16, 29, 9, 3, (0,0,0,60))
    fill_diamond(g, 16, 21, 8, 8, ORC_GREEN)
    fill_diamond(g, 16, 20, 7, 6, ORC_GREEN_LIGHT)
    fill_rect(g, 12, 16, 20, 20, (80, 80, 70, 255))
    fill_rect(g, 13, 17, 19, 19, (100, 95, 80, 255))
    fill_rect(g, 10, 25, 22, 27, ORC_GREEN_DARK)
    fill_circle(g, 16, 10, 5, ORC_GREEN)
    fill_circle(g, 16, 10, 4, ORC_GREEN_LIGHT)
    set_px(g, 13, 13, (220, 210, 180, 255))
    set_px(g, 13, 14, (220, 210, 180, 255))
    set_px(g, 19, 13, (220, 210, 180, 255))
    set_px(g, 19, 14, (220, 210, 180, 255))
    set_px(g, 14, 9, (200, 50, 30, 255))
    set_px(g, 18, 9, (200, 50, 30, 255))
    fill_rect(g, 13, 7, 15, 8, (50, 90, 40, 255))
    fill_rect(g, 17, 7, 19, 8, (50, 90, 40, 255))
    fill_rect(g, 24, 12, 26, 22, (100, 70, 40, 255))
    fill_rect(g, 23, 10, 27, 12, (120, 85, 50, 255))
    set_px(g, 23, 9, (150, 150, 150, 255))
    set_px(g, 27, 9, (150, 150, 150, 255))
    set_px(g, 28, 11, (150, 150, 150, 255))
    return g

def gen_orc_walk():
    """4-frame heavy stomp walk."""
    frames = []
    body_bob = [0, -1, 0, 1]
    for fi in range(4):
        f = _orc_base()
        by = body_bob[fi]
        # Stomp legs — alternating
        if fi % 2 == 0:
            fill_rect(f, 12, 27, 14, 28, ORC_GREEN_DARK)
            fill_rect(f, 18, 26, 20, 27, ORC_GREEN_DARK)
        else:
            fill_rect(f, 12, 26, 14, 27, ORC_GREEN_DARK)
            fill_rect(f, 18, 27, 20, 28, ORC_GREEN_DARK)
        # Club swing
        if fi == 1:
            set_px(f, 24, 11, T)
            fill_rect(f, 23, 9, 27, 11, (120, 85, 50, 255))
        elif fi == 3:
            fill_rect(f, 24, 13, 26, 23, (100, 70, 40, 255))
        # Shadow adjust
        if by != 0:
            fill_diamond(f, 16, 29+by, 9, 3, (0,0,0,60))
        frames.append(f)
    return frames

def _swift_base():
    """Base swift frame."""
    g = make_grid(32, 32)
    fill_diamond(g, 16, 28, 6, 2, (0,0,0,50))
    fill_diamond(g, 16, 21, 5, 7, SWIFT_PURPLE)
    fill_diamond(g, 16, 20, 4, 5, SWIFT_PURPLE_LIGHT)
    set_px(g, 10, 18, (80, 40, 120, 200))
    set_px(g, 9, 19, (80, 40, 120, 180))
    set_px(g, 8, 20, (80, 40, 120, 140))
    set_px(g, 22, 18, (80, 40, 120, 200))
    set_px(g, 23, 19, (80, 40, 120, 180))
    set_px(g, 24, 20, (80, 40, 120, 140))
    fill_circle(g, 16, 11, 3, SWIFT_PURPLE)
    fill_circle(g, 16, 11, 2, SWIFT_PURPLE_LIGHT)
    set_px(g, 16, 7, (90, 45, 130, 255))
    set_px(g, 15, 8, (90, 45, 130, 255))
    set_px(g, 17, 8, (90, 45, 130, 255))
    set_px(g, 14, 11, (200, 100, 255, 255))
    set_px(g, 18, 11, (200, 100, 255, 255))
    set_px(g, 22, 15, (180, 180, 200, 255))
    set_px(g, 23, 14, (200, 200, 220, 255))
    set_px(g, 10, 15, (180, 180, 200, 255))
    set_px(g, 9, 14, (200, 200, 220, 255))
    return g

def gen_swift_walk():
    """4-frame lean-forward sprint."""
    frames = []
    lean = [0, 1, 0, -1]
    for fi in range(4):
        f = _swift_base()
        lx = lean[fi]
        # Speed trail varies per frame
        trail_alpha = [80, 50, 40, 60]
        for i in range(3):
            a1 = max(0, trail_alpha[fi] - i * 15)
            a2 = max(0, trail_alpha[fi] - i * 15)
            set_px(f, 5-i+lx, 15+i, (130, 70, 170, a1))
            set_px(f, 5-i+lx, 20+i, (130, 70, 170, a2))
        # Legs — fast alternation
        if fi % 2 == 0:
            set_px(f, 14, 26, SWIFT_PURPLE_DARK)
            set_px(f, 18, 27, SWIFT_PURPLE_DARK)
        else:
            set_px(f, 14, 27, SWIFT_PURPLE_DARK)
            set_px(f, 18, 26, SWIFT_PURPLE_DARK)
        # Scarf flutter
        ca = [200, 160, 140, 180][fi]
        set_px(f, 8+lx, 20, (80, 40, 120, ca))
        set_px(f, 24-lx, 20, (80, 40, 120, ca))
        frames.append(f)
    return frames

def _demon_base():
    """Base demon frame."""
    g = make_grid(32, 32)
    fill_diamond(g, 16, 29, 10, 3, (0,0,0,80))
    fill_diamond(g, 16, 20, 9, 9, DEMON_RED)
    fill_diamond(g, 16, 19, 8, 7, DEMON_RED_LIGHT)
    fill_rect(g, 10, 16, 22, 22, (80, 15, 15, 255))
    fill_rect(g, 11, 17, 21, 21, (100, 20, 20, 255))
    fill_rect(g, 9, 25, 23, 28, DEMON_RED_DARK)
    fill_circle(g, 16, 9, 5, DEMON_RED)
    fill_circle(g, 16, 9, 4, DEMON_RED_LIGHT)
    # Horns
    set_px(g, 10, 7, (180, 160, 80, 255))
    set_px(g, 9, 5, (180, 160, 80, 255))
    set_px(g, 8, 4, (200, 180, 90, 255))
    set_px(g, 8, 3, (200, 180, 90, 255))
    set_px(g, 22, 7, (180, 160, 80, 255))
    set_px(g, 23, 5, (180, 160, 80, 255))
    set_px(g, 24, 4, (200, 180, 90, 255))
    set_px(g, 24, 3, (200, 180, 90, 255))
    # Eyes
    set_px(g, 14, 8, (255, 100, 0, 255))
    set_px(g, 13, 8, (255, 180, 0, 255))
    set_px(g, 18, 8, (255, 100, 0, 255))
    set_px(g, 19, 8, (255, 180, 0, 255))
    # Mouth
    set_px(g, 15, 12, (255, 150, 0, 255))
    set_px(g, 16, 12, (255, 200, 0, 255))
    set_px(g, 17, 12, (255, 150, 0, 255))
    set_px(g, 16, 13, (255, 100, 0, 200))
    # Wings
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

def gen_demon_walk():
    """4-frame ominous glide."""
    frames = []
    hover = [0, -1, -1, 0]
    wing_spread = [0, 1, 2, 1]
    for fi in range(4):
        f = _demon_base()
        by = hover[fi]
        ws = wing_spread[fi]
        # Glide bob
        if by != 0:
            fill_diamond(f, 16, 29+by, 10, 3, (0,0,0,80))
        # Wing flap — extend wing pixels
        for i in range(4+ws):
            a = max(0, 200 - i * 35)
            set_px(f, 5-i-ws, 12+i, (100, 20, 20, a))
            set_px(f, 27+i+ws, 12+i, (100, 20, 20, a))
        # Mouth flame flicker
        flame_colors = [(255,150,0,255), (255,200,0,255), (255,120,0,255), (255,180,0,255)]
        set_px(f, 16, 12, flame_colors[fi])
        # Tail sway
        tail_x = [16, 17, 18, 17]
        set_px(f, tail_x[fi], 29, (100, 20, 20, 200))
        frames.append(f)
    return frames

# ═══════════════════════════════════════════════════════════════════
# FIREBALL SPRITE SHEETS
# ═══════════════════════════════════════════════════════════════════

def gen_fireball_fly():
    """3-frame cycling flame shapes (32x32 each)."""
    frames = []
    for fi in range(3):
        f = make_grid(32, 32)
        cx, cy = 16, 16
        # Outer glow
        fill_circle(f, cx, cy, 8, (255, 100, 0, 60))
        # Main flame body — varies per frame
        if fi == 0:
            fill_circle(f, cx, cy, 5, (255, 120, 20, 200))
            fill_circle(f, cx, cy, 3, (255, 200, 50, 240))
            fill_circle(f, cx-1, cy-1, 1, (255, 255, 200, 255))
        elif fi == 1:
            fill_circle(f, cx, cy, 6, (255, 100, 10, 180))
            fill_circle(f, cx+1, cy, 3, (255, 180, 30, 230))
            fill_circle(f, cx, cy, 2, (255, 240, 100, 255))
        else:
            fill_circle(f, cx, cy, 5, (255, 130, 30, 190))
            fill_circle(f, cx-1, cy+1, 4, (255, 160, 40, 220))
            fill_circle(f, cx, cy, 2, (255, 220, 80, 250))
            fill_circle(f, cx, cy-1, 1, (255, 255, 200, 255))
        # Trailing sparks
        spark_offsets = [(-6,-2), (-7, 1), (-5, 3)]
        sx, sy = spark_offsets[fi]
        set_px(f, cx+sx, cy+sy, (255, 200, 50, 180))
        set_px(f, cx+sx-1, cy+sy+1, (255, 150, 0, 120))
        frames.append(f)
    return frames

def gen_fireball_explode():
    """4-frame blast expansion (48x48 each)."""
    frames = []
    sizes = [8, 16, 20, 22]
    alphas = [255, 220, 160, 80]
    for fi in range(4):
        f = make_grid(48, 48)
        cx, cy = 24, 24
        r = sizes[fi]
        a = alphas[fi]
        # Outer blast
        fill_circle(f, cx, cy, r, (255, 100, 0, int(a*0.3)))
        # Mid ring
        fill_circle(f, cx, cy, int(r*0.7), (255, 150, 30, int(a*0.5)))
        # Inner bright core
        fill_circle(f, cx, cy, int(r*0.35), (255, 220, 80, int(a*0.8)))
        fill_circle(f, cx, cy, int(r*0.15), (255, 255, 200, a))
        # Debris sparks
        if fi >= 1:
            for angle_i in range(6):
                angle = angle_i * (math.pi * 2 / 6) + fi * 0.3
                dist = r * 0.8
                sx = int(cx + math.cos(angle) * dist)
                sy = int(cy + math.sin(angle) * dist)
                set_px(f, sx, sy, (255, 200, 50, int(a*0.7)))
        frames.append(f)
    return frames

# ═══════════════════════════════════════════════════════════════════
# SLASH EFFECT SPRITE SHEET
# ═══════════════════════════════════════════════════════════════════

def gen_slash_effect():
    """3-frame crescent arc sweep (64x64 each)."""
    frames = []
    for fi in range(3):
        f = make_grid(64, 64)
        cx, cy = 32, 32
        # Draw crescent arc at different sweep angles
        sweep_progress = (fi + 1) / 3.0  # 0.33, 0.67, 1.0
        alpha = int(255 * (1.0 - fi * 0.25))
        arc_start = -math.pi * 0.5
        arc_end = arc_start + math.pi * 1.2 * sweep_progress
        outer_r = 24 + fi * 2
        inner_r = 16 + fi * 2
        for angle_step in range(60):
            angle = arc_start + (arc_end - arc_start) * angle_step / 59.0
            # Outer edge — bright
            ox = int(cx + math.cos(angle) * outer_r)
            oy = int(cy + math.sin(angle) * outer_r)
            set_px_blend(f, ox, oy, (255, 255, 220, alpha))
            set_px_blend(f, ox+1, oy, (255, 255, 220, int(alpha*0.5)))
            # Mid
            mr = (outer_r + inner_r) // 2
            mx = int(cx + math.cos(angle) * mr)
            my = int(cy + math.sin(angle) * mr)
            set_px_blend(f, mx, my, (255, 240, 180, int(alpha*0.7)))
            # Inner edge — dimmer
            ix = int(cx + math.cos(angle) * inner_r)
            iy = int(cy + math.sin(angle) * inner_r)
            set_px_blend(f, ix, iy, (255, 220, 130, int(alpha*0.4)))
        # Leading tip — extra bright
        tip_angle = arc_end
        tx = int(cx + math.cos(tip_angle) * outer_r)
        ty = int(cy + math.sin(tip_angle) * outer_r)
        fill_circle(f, tx, ty, 2, (255, 255, 255, alpha))
        frames.append(f)
    return frames

# ═══════════════════════════════════════════════════════════════════
# TILE TEXTURES
# ═══════════════════════════════════════════════════════════════════

def _iso_tile_mask(w, h):
    """Return set of (x,y) coords inside an iso diamond of w x h."""
    mask = set()
    hw, hh = w // 2, h // 2
    for y in range(h):
        dy = abs(y - hh)
        xspan = int(hw * (1.0 - dy / hh)) if hh > 0 else hw
        for x in range(hw - xspan, hw + xspan + 1):
            mask.add((x, y))
    return mask

def gen_tile_grass_1():
    """64x32 dark green isometric tile with grass tufts."""
    w, h = 64, 32
    g = make_grid(w, h)
    mask = _iso_tile_mask(w, h)
    base = (55, 80, 40, 210)
    for (x, y) in mask:
        if 0 <= x < w and 0 <= y < h:
            v = random.randint(-8, 8)
            g[y][x] = (clamp(base[0]+v,0,255), clamp(base[1]+v,0,255), clamp(base[2]+v,0,255), base[3])
    # Grass tufts — small bright spots
    tuft_positions = [(20, 10), (40, 8), (30, 20), (50, 14), (14, 18), (45, 22)]
    for tx, ty in tuft_positions:
        if (tx, ty) in mask:
            set_px(g, tx, ty, (70, 110, 50, 220))
            if (tx-1, ty-1) in mask:
                set_px(g, tx-1, ty-1, (65, 100, 45, 200))
    # Border
    hw, hh = w // 2, h // 2
    outline_diamond(g, hw, hh, hw-1, hh-1, (40, 55, 30, 140))
    return g

def gen_tile_grass_2():
    """64x32 slightly different green (checkerboard partner)."""
    w, h = 64, 32
    g = make_grid(w, h)
    mask = _iso_tile_mask(w, h)
    base = (60, 90, 48, 210)
    for (x, y) in mask:
        if 0 <= x < w and 0 <= y < h:
            v = random.randint(-8, 8)
            g[y][x] = (clamp(base[0]+v,0,255), clamp(base[1]+v,0,255), clamp(base[2]+v,0,255), base[3])
    # Slightly different tuft pattern
    tuft_positions = [(25, 12), (35, 6), (18, 22), (48, 16), (32, 24)]
    for tx, ty in tuft_positions:
        if (tx, ty) in mask:
            set_px(g, tx, ty, (80, 120, 55, 220))
            if (tx+1, ty-1) in mask:
                set_px(g, tx+1, ty-1, (75, 115, 50, 200))
    outline_diamond(g, w//2, h//2, w//2-1, h//2-1, (45, 60, 35, 140))
    return g

def gen_tile_spawn():
    """64x32 reddish earth with cracks."""
    w, h = 64, 32
    g = make_grid(w, h)
    mask = _iso_tile_mask(w, h)
    base = (120, 60, 45, 220)
    for (x, y) in mask:
        if 0 <= x < w and 0 <= y < h:
            v = random.randint(-10, 10)
            g[y][x] = (clamp(base[0]+v,0,255), clamp(base[1]+v//2,0,255), clamp(base[2]+v//2,0,255), base[3])
    # Cracks
    crack_color = (80, 35, 25, 200)
    for i in range(8):
        cx, cy = 20+i*2, 10+i
        if (cx, cy) in mask:
            set_px(g, cx, cy, crack_color)
    for i in range(6):
        cx, cy = 35+i, 14+i
        if (cx, cy) in mask:
            set_px(g, cx, cy, crack_color)
    # Red glow spots
    for tx, ty in [(28, 14), (38, 18)]:
        if (tx, ty) in mask:
            set_px(g, tx, ty, (180, 50, 30, 180))
    outline_diamond(g, w//2, h//2, w//2-1, h//2-1, (100, 40, 30, 160))
    return g

def gen_tile_goal():
    """64x32 golden paved stone."""
    w, h = 64, 32
    g = make_grid(w, h)
    mask = _iso_tile_mask(w, h)
    base = (180, 160, 80, 230)
    for (x, y) in mask:
        if 0 <= x < w and 0 <= y < h:
            v = random.randint(-10, 10)
            g[y][x] = (clamp(base[0]+v,0,255), clamp(base[1]+v,0,255), clamp(base[2]+v//2,0,255), base[3])
    # Stone grid pattern
    stone_line = (150, 130, 60, 180)
    for y in range(h):
        for x in range(w):
            if (x, y) in mask:
                if y == 10 or y == 22:
                    set_px(g, x, y, stone_line)
                if (x + y) % 12 == 0:
                    set_px(g, x, y, stone_line)
    # Gold highlights
    for tx, ty in [(22, 8), (42, 12), (30, 24)]:
        if (tx, ty) in mask:
            set_px(g, tx, ty, (230, 210, 100, 240))
    outline_diamond(g, w//2, h//2, w//2-1, h//2-1, (160, 140, 50, 180))
    return g

# ═══════════════════════════════════════════════════════════════════
# IMPROVED STATIC SPRITES (overwrite existing)
# ═══════════════════════════════════════════════════════════════════

def gen_archer_tower_v2():
    """32x48 improved tower with more detail and shading."""
    g = make_grid(32, 48)
    # Shadow
    fill_diamond(g, 16, 44, 10, 3, (0,0,0,60))
    # Base platform with noise
    noise_fill_diamond(g, 16, 40, 12, 5, TOWER_STONE_DARK, 8)
    noise_fill_diamond(g, 16, 39, 11, 4, TOWER_STONE, 6)
    # Tower body with subtle noise
    noise_fill(g, 10, 14, 22, 38, TOWER_STONE, 5)
    noise_fill(g, 11, 14, 21, 37, TOWER_STONE_LIGHT, 5)
    # Stone brick lines — thicker mortar
    for y in [18, 22, 26, 30, 34]:
        fill_rect(g, 10, y, 22, y, TOWER_STONE_DARK)
    for y in [20, 24, 28, 32]:
        set_px(g, 16, y, TOWER_STONE_DARK)
    # Left edge shadow
    for y in range(14, 39):
        set_px(g, 10, y, shift_color(TOWER_STONE_DARK, -10, -10, -10))
    # Window with glow
    fill_rect(g, 14, 27, 18, 30, (30, 30, 50, 255))
    fill_rect(g, 15, 28, 17, 29, (20, 20, 40, 255))
    set_px(g, 16, 28, (60, 50, 30, 200))  # candle glow
    set_px(g, 16, 29, (40, 35, 20, 150))
    # Battlement
    fill_rect(g, 8, 12, 24, 15, TOWER_STONE)
    for x in [8, 10, 14, 18, 22]:
        fill_rect(g, x, 10, x+1, 12, TOWER_STONE)
    # Roof
    fill_rect(g, 12, 10, 20, 11, TOWER_ROOF)
    fill_rect(g, 14, 8, 18, 10, TOWER_ROOF)
    fill_rect(g, 15, 7, 17, 8, TOWER_ROOF_LIGHT)
    # Roof highlight
    set_px(g, 15, 8, shift_color(TOWER_ROOF_LIGHT, 20, 20, 20))
    # Archer on top
    fill_circle(g, 16, 5, 2, HERO_SKIN)
    fill_rect(g, 14, 7, 18, 9, ARCHER_GREEN)
    set_px(g, 14, 7, ARCHER_GREEN_LIGHT)  # highlight
    return g

def gen_ground_archer_v2():
    """32x32 improved archer with detail."""
    g = make_grid(32, 32)
    fill_diamond(g, 16, 28, 7, 3, (0,0,0,60))
    # Body with noise for cloth texture
    noise_fill_diamond(g, 16, 21, 6, 7, ARCHER_GREEN, 8)
    noise_fill_diamond(g, 16, 20, 5, 5, ARCHER_GREEN_LIGHT, 6)
    fill_rect(g, 12, 24, 20, 26, ARCHER_GREEN_DARK)
    # Head
    fill_circle(g, 16, 11, 4, HERO_SKIN)
    # Hood with detail
    fill_rect(g, 12, 7, 20, 9, ARCHER_GREEN_DARK)
    fill_rect(g, 13, 7, 19, 8, ARCHER_GREEN)
    set_px(g, 16, 6, ARCHER_GREEN)
    set_px(g, 16, 7, ARCHER_GREEN_LIGHT)  # hood highlight
    # Eyes
    set_px(g, 14, 11, (40, 60, 40, 255))
    set_px(g, 18, 11, (40, 60, 40, 255))
    # Bow with detail
    for i in range(10):
        set_px(g, 24, 10+i, ARCHER_BOW)
    set_px(g, 25, 11, ARCHER_BOW)
    set_px(g, 25, 18, ARCHER_BOW)
    set_px(g, 25, 14, shift_color(ARCHER_BOW, 20, 10, 5))  # grip highlight
    # Bowstring
    for i in range(8):
        set_px(g, 23, 11+i, ARCHER_STRING)
    # Quiver with arrows
    fill_rect(g, 8, 13, 9, 20, WALL_BROWN)
    set_px(g, 8, 12, ARROW_GOLD)
    set_px(g, 9, 12, ARROW_GOLD)
    set_px(g, 8, 11, ARROW_BRIGHT)  # arrow tip
    # Belt
    fill_rect(g, 12, 21, 20, 21, WALL_BROWN_DARK)
    set_px(g, 16, 21, HERO_GOLD)  # belt buckle
    return g

def gen_wall_v2():
    """32x24 improved wall with more brick detail."""
    g = make_grid(32, 24)
    # Front face with noise
    noise_fill(g, 6, 4, 26, 18, WALL_BROWN, 8)
    noise_fill(g, 7, 5, 25, 17, WALL_BROWN_LIGHT, 6)
    # Brick pattern — more elaborate
    for y in [7, 11, 15]:
        fill_rect(g, 6, y, 26, y, WALL_MORTAR)
    for y in [9, 13]:
        set_px(g, 16, y, WALL_MORTAR)
    for y in [7, 11, 15]:
        set_px(g, 11, y+1, WALL_MORTAR)
        set_px(g, 21, y+1, WALL_MORTAR)
    # Individual brick shading
    set_px(g, 8, 6, shift_color(WALL_BROWN_LIGHT, 15, 12, 8))
    set_px(g, 18, 10, shift_color(WALL_BROWN_LIGHT, 15, 12, 8))
    set_px(g, 13, 14, shift_color(WALL_BROWN_LIGHT, 15, 12, 8))
    # Top face
    noise_fill(g, 6, 2, 26, 4, WALL_BROWN_LIGHT, 5)
    noise_fill(g, 7, 2, 25, 3, (180, 155, 125, 255), 5)
    # Dark edges
    for y in range(2, 19):
        set_px(g, 6, y, WALL_BROWN_DARK)
        set_px(g, 26, y, WALL_BROWN_DARK)
    # Bottom shadow
    fill_rect(g, 7, 18, 25, 18, shift_color(WALL_BROWN_DARK, -10, -10, -10))
    return g

def gen_rock_v2():
    """32x24 improved rock with more texture."""
    g = make_grid(32, 24)
    fill_diamond(g, 16, 20, 12, 3, (0,0,0,50))
    # Main rock with noise
    for y in range(3, 24):
        for x in range(6, 27):
            if (x-16)**2 + (y-13)**2 <= 100:
                v = random.randint(-10, 10)
                set_px(g, x, y, (clamp(ROCK_GRAY[0]+v,0,255), clamp(ROCK_GRAY[1]+v,0,255), clamp(ROCK_GRAY[2]+v,0,255), 255))
    # Lighter top
    for y in range(4, 18):
        for x in range(8, 24):
            if (x-15)**2 + (y-12)**2 <= 64:
                v = random.randint(-8, 8)
                set_px(g, x, y, (clamp(ROCK_GRAY_LIGHT[0]+v,0,255), clamp(ROCK_GRAY_LIGHT[1]+v,0,255), clamp(ROCK_GRAY_LIGHT[2]+v,0,255), 255))
    # Highlight
    fill_circle(g, 13, 9, 3, ROCK_HIGHLIGHT)
    set_px(g, 12, 8, (200, 200, 205, 255))  # extra bright
    # Crevices
    draw_line(g, 18, 14, 21, 16, ROCK_GRAY_DARK)
    draw_line(g, 11, 15, 13, 18, ROCK_GRAY_DARK)
    # Moss
    set_px(g, 10, 15, (60, 100, 50, 255))
    set_px(g, 11, 16, (60, 100, 50, 255))
    set_px(g, 22, 12, (60, 100, 50, 255))
    set_px(g, 9, 16, (50, 90, 40, 200))
    return g

def gen_arrow_v2():
    """16x16 improved arrow with trail."""
    g = make_grid(16, 16)
    # Glow
    fill_circle(g, 8, 8, 5, (255, 200, 50, 40))
    fill_circle(g, 8, 8, 3, (255, 220, 100, 80))
    # Arrow body — thicker
    for x in range(5, 11):
        set_px(g, x, 8, ARROW_SHAFT)
        set_px(g, x, 7, (160, 120, 60, 60))  # slight thickness
    set_px(g, 9, 8, ARROW_GOLD)
    set_px(g, 10, 8, ARROW_BRIGHT)
    # Arrowhead — larger, triangle
    set_px(g, 11, 7, ARROW_BRIGHT)
    set_px(g, 11, 8, ARROW_BRIGHT)
    set_px(g, 11, 9, ARROW_BRIGHT)
    set_px(g, 12, 8, ARROW_BRIGHT)
    set_px(g, 13, 8, (255, 255, 200, 200))  # tip glow
    # Fletching — more visible
    set_px(g, 4, 6, ARROW_SHAFT)
    set_px(g, 4, 7, ARROW_SHAFT)
    set_px(g, 4, 9, ARROW_SHAFT)
    set_px(g, 4, 10, ARROW_SHAFT)
    set_px(g, 5, 7, ARROW_SHAFT)
    set_px(g, 5, 9, ARROW_SHAFT)
    # Trail
    set_px(g, 3, 8, (255, 200, 50, 60))
    set_px(g, 2, 8, (255, 200, 50, 30))
    return g

# ═══════════════════════════════════════════════════════════════════
# GENERATE ALL
# ═══════════════════════════════════════════════════════════════════

print("=" * 50)
print("Korean Fantasy TD — Sprite Generator V2")
print("=" * 50)

# ── Hero sprite sheets ──
print("\n[Hero Sprite Sheets]")
hero_idle = gen_hero_idle()
write_png(os.path.join(ASSETS, "hero_idle.png"), 128, 32, make_spritesheet(hero_idle, 32, 32))

hero_walk = gen_hero_walk()
write_png(os.path.join(ASSETS, "hero_walk.png"), 128, 32, make_spritesheet(hero_walk, 32, 32))

hero_attack = gen_hero_attack()
write_png(os.path.join(ASSETS, "hero_attack.png"), 96, 32, make_spritesheet(hero_attack, 32, 32))

# ── Enemy sprite sheets ──
print("\n[Enemy Sprite Sheets]")
goblin_walk = gen_goblin_walk()
write_png(os.path.join(ASSETS, "goblin_walk.png"), 128, 32, make_spritesheet(goblin_walk, 32, 32))

orc_walk = gen_orc_walk()
write_png(os.path.join(ASSETS, "orc_walk.png"), 128, 32, make_spritesheet(orc_walk, 32, 32))

swift_walk = gen_swift_walk()
write_png(os.path.join(ASSETS, "swift_walk.png"), 128, 32, make_spritesheet(swift_walk, 32, 32))

demon_walk = gen_demon_walk()
write_png(os.path.join(ASSETS, "demon_walk.png"), 128, 32, make_spritesheet(demon_walk, 32, 32))

# ── Fireball sprite sheets ──
print("\n[Fireball Sprite Sheets]")
fb_fly = gen_fireball_fly()
write_png(os.path.join(ASSETS, "fireball_fly.png"), 96, 32, make_spritesheet(fb_fly, 32, 32))

fb_explode = gen_fireball_explode()
write_png(os.path.join(ASSETS, "fireball_explode.png"), 192, 48, make_spritesheet(fb_explode, 48, 48))

# ── Slash effect ──
print("\n[Slash Effect]")
slash = gen_slash_effect()
write_png(os.path.join(ASSETS, "slash_effect.png"), 192, 64, make_spritesheet(slash, 64, 64))

# ── Tile textures ──
print("\n[Tile Textures]")
write_png(os.path.join(ASSETS, "tile_grass_1.png"), 64, 32, gen_tile_grass_1())
write_png(os.path.join(ASSETS, "tile_grass_2.png"), 64, 32, gen_tile_grass_2())
write_png(os.path.join(ASSETS, "tile_spawn.png"), 64, 32, gen_tile_spawn())
write_png(os.path.join(ASSETS, "tile_goal.png"), 64, 32, gen_tile_goal())

# ── Improved static sprites (overwrite existing) ──
print("\n[Improved Static Sprites]")
write_png(os.path.join(ASSETS, "archer_tower.png"), 32, 48, gen_archer_tower_v2())
write_png(os.path.join(ASSETS, "ground_archer.png"), 32, 32, gen_ground_archer_v2())
write_png(os.path.join(ASSETS, "wall.png"), 32, 24, gen_wall_v2())
write_png(os.path.join(ASSETS, "rock.png"), 32, 24, gen_rock_v2())
write_png(os.path.join(ASSETS, "arrow.png"), 16, 16, gen_arrow_v2())

print("\n" + "=" * 50)
print("Done! All V2 sprites saved to assets/")
print("=" * 50)
