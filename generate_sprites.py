"""Generate simple pixel-art sprite PNGs for Korean Fantasy TD.
Uses only Python built-ins (struct, zlib) — no PIL needed.
Run once: python generate_sprites.py
"""
import struct, zlib, os

ASSETS = os.path.join(os.path.dirname(__file__), "assets")
os.makedirs(ASSETS, exist_ok=True)

def write_png(path, width, height, pixels):
    """Write RGBA PNG. pixels = list of rows, each row = list of (R,G,B,A) tuples."""
    def chunk(ctype, data):
        c = ctype + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    raw = b""
    for row in pixels:
        raw += b"\x00"  # filter: none
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

# ── Colors ──
T = (0, 0, 0, 0)  # transparent
# Hero
HERO_BLUE = (50, 90, 200, 255)
HERO_BLUE_LIGHT = (80, 120, 230, 255)
HERO_BLUE_DARK = (30, 60, 150, 255)
HERO_GOLD = (230, 200, 50, 255)
HERO_GOLD_DARK = (180, 150, 30, 255)
HERO_SKIN = (220, 185, 150, 255)
HERO_SWORD = (200, 200, 210, 255)
HERO_SWORD_EDGE = (240, 240, 250, 255)
# Enemy
ENEMY_RED = (200, 40, 40, 255)
ENEMY_RED_LIGHT = (230, 70, 60, 255)
ENEMY_RED_DARK = (140, 20, 20, 255)
ENEMY_HORN = (180, 160, 80, 255)
ENEMY_EYE = (255, 220, 50, 255)
# Tower
TOWER_STONE = (100, 110, 130, 255)
TOWER_STONE_LIGHT = (130, 140, 160, 255)
TOWER_STONE_DARK = (70, 75, 90, 255)
TOWER_ROOF = (60, 80, 160, 255)
TOWER_ROOF_LIGHT = (80, 100, 190, 255)
# Archer
ARCHER_GREEN = (50, 140, 60, 255)
ARCHER_GREEN_LIGHT = (70, 170, 80, 255)
ARCHER_GREEN_DARK = (30, 100, 40, 255)
ARCHER_BOW = (140, 90, 40, 255)
ARCHER_STRING = (200, 200, 180, 255)
# Wall
WALL_BROWN = (140, 115, 90, 255)
WALL_BROWN_LIGHT = (165, 140, 110, 255)
WALL_BROWN_DARK = (100, 80, 60, 255)
WALL_MORTAR = (170, 160, 140, 255)
# Rock
ROCK_GRAY = (130, 130, 135, 255)
ROCK_GRAY_LIGHT = (160, 160, 165, 255)
ROCK_GRAY_DARK = (90, 90, 95, 255)
ROCK_HIGHLIGHT = (180, 180, 185, 255)
# Projectile
ARROW_GOLD = (255, 200, 50, 255)
ARROW_BRIGHT = (255, 240, 150, 255)
ARROW_SHAFT = (160, 120, 60, 255)

# ── HERO (32x32) ──
def gen_hero():
    g = make_grid(32, 32)
    # Shadow
    fill_diamond(g, 16, 28, 8, 3, (0,0,0,60))
    # Body - armor
    fill_diamond(g, 16, 20, 7, 8, HERO_BLUE)
    fill_diamond(g, 16, 19, 6, 6, HERO_BLUE_LIGHT)
    # Armor details
    fill_rect(g, 14, 15, 18, 15, HERO_BLUE_DARK)
    fill_rect(g, 13, 18, 19, 18, HERO_BLUE_DARK)
    # Head
    fill_circle(g, 16, 10, 4, HERO_SKIN)
    # Helmet
    fill_rect(g, 12, 6, 20, 8, HERO_GOLD)
    fill_rect(g, 13, 6, 19, 7, HERO_GOLD_DARK)
    set_px(g, 16, 5, HERO_GOLD)
    set_px(g, 16, 4, HERO_GOLD)  # helmet spike
    # Eyes
    set_px(g, 14, 10, (40, 40, 60, 255))
    set_px(g, 18, 10, (40, 40, 60, 255))
    # Sword (right side)
    for i in range(8):
        set_px(g, 24, 12+i, HERO_SWORD)
        set_px(g, 25, 12+i, HERO_SWORD_EDGE if i < 5 else HERO_SWORD)
    # Sword guard
    fill_rect(g, 23, 19, 26, 19, HERO_GOLD)
    # Sword handle
    set_px(g, 24, 20, WALL_BROWN)
    set_px(g, 24, 21, WALL_BROWN)
    # Shield (left side)
    fill_rect(g, 7, 15, 10, 21, HERO_BLUE_DARK)
    fill_rect(g, 8, 16, 9, 20, HERO_BLUE)
    set_px(g, 8, 18, HERO_GOLD)
    set_px(g, 9, 18, HERO_GOLD)
    return g

# ── ENEMY (32x32) ──
def gen_enemy():
    g = make_grid(32, 32)
    # Shadow
    fill_diamond(g, 16, 28, 7, 3, (0,0,0,60))
    # Body
    fill_diamond(g, 16, 21, 6, 7, ENEMY_RED)
    fill_diamond(g, 16, 20, 5, 5, ENEMY_RED_LIGHT)
    # Dark underside
    fill_rect(g, 12, 24, 20, 26, ENEMY_RED_DARK)
    # Head
    fill_circle(g, 16, 12, 4, ENEMY_RED)
    fill_circle(g, 16, 11, 3, ENEMY_RED_LIGHT)
    # Horns
    set_px(g, 12, 8, ENEMY_HORN)
    set_px(g, 11, 7, ENEMY_HORN)
    set_px(g, 20, 8, ENEMY_HORN)
    set_px(g, 21, 7, ENEMY_HORN)
    # Eyes (glowing)
    set_px(g, 14, 11, ENEMY_EYE)
    set_px(g, 18, 11, ENEMY_EYE)
    set_px(g, 15, 12, (200, 180, 40, 255))
    set_px(g, 17, 12, (200, 180, 40, 255))
    # Mouth
    set_px(g, 15, 14, ENEMY_RED_DARK)
    set_px(g, 16, 14, ENEMY_RED_DARK)
    set_px(g, 17, 14, ENEMY_RED_DARK)
    # Arms/claws
    set_px(g, 8, 19, ENEMY_RED_DARK)
    set_px(g, 9, 18, ENEMY_RED_DARK)
    set_px(g, 23, 18, ENEMY_RED_DARK)
    set_px(g, 24, 19, ENEMY_RED_DARK)
    return g

# ── ARCHER TOWER (32x48) ──
def gen_tower():
    g = make_grid(32, 48)
    # Shadow
    fill_diamond(g, 16, 44, 10, 3, (0,0,0,60))
    # Base platform
    fill_diamond(g, 16, 40, 12, 5, TOWER_STONE_DARK)
    fill_diamond(g, 16, 39, 11, 4, TOWER_STONE)
    # Tower body
    fill_rect(g, 10, 14, 22, 38, TOWER_STONE)
    fill_rect(g, 11, 14, 21, 37, TOWER_STONE_LIGHT)
    # Stone brick lines
    for y in [18, 22, 26, 30, 34]:
        fill_rect(g, 10, y, 22, y, TOWER_STONE_DARK)
    for y in [20, 24, 28, 32]:
        set_px(g, 16, y, TOWER_STONE_DARK)
    # Window
    fill_rect(g, 14, 27, 18, 30, (30, 30, 50, 255))
    fill_rect(g, 15, 28, 17, 29, (20, 20, 40, 255))
    # Battlement top
    fill_rect(g, 8, 12, 24, 15, TOWER_STONE)
    for x in [8, 10, 14, 18, 22]:
        fill_rect(g, x, 10, x+1, 12, TOWER_STONE)
    # Roof accent
    fill_rect(g, 12, 10, 20, 11, TOWER_ROOF)
    fill_rect(g, 14, 8, 18, 10, TOWER_ROOF)
    fill_rect(g, 15, 7, 17, 8, TOWER_ROOF_LIGHT)
    # Archer on top (small)
    fill_circle(g, 16, 5, 2, HERO_SKIN)
    fill_rect(g, 14, 7, 18, 9, ARCHER_GREEN)
    return g

# ── GROUND ARCHER (32x32) ──
def gen_archer():
    g = make_grid(32, 32)
    # Shadow
    fill_diamond(g, 16, 28, 7, 3, (0,0,0,60))
    # Body (green cloak)
    fill_diamond(g, 16, 21, 6, 7, ARCHER_GREEN)
    fill_diamond(g, 16, 20, 5, 5, ARCHER_GREEN_LIGHT)
    # Dark underside
    fill_rect(g, 12, 24, 20, 26, ARCHER_GREEN_DARK)
    # Head
    fill_circle(g, 16, 11, 4, HERO_SKIN)
    # Hood
    fill_rect(g, 12, 7, 20, 9, ARCHER_GREEN_DARK)
    fill_rect(g, 13, 7, 19, 8, ARCHER_GREEN)
    set_px(g, 16, 6, ARCHER_GREEN)
    # Eyes
    set_px(g, 14, 11, (40, 60, 40, 255))
    set_px(g, 18, 11, (40, 60, 40, 255))
    # Bow (right side)
    for i in range(10):
        set_px(g, 24, 10+i, ARCHER_BOW)
    set_px(g, 25, 11, ARCHER_BOW)
    set_px(g, 25, 18, ARCHER_BOW)
    # Bowstring
    for i in range(8):
        set_px(g, 23, 11+i, ARCHER_STRING)
    # Quiver (back, left side)
    fill_rect(g, 8, 13, 9, 20, WALL_BROWN)
    set_px(g, 8, 12, ARROW_GOLD)
    set_px(g, 9, 12, ARROW_GOLD)
    return g

# ── WALL (32x24, isometric) ──
def gen_wall():
    g = make_grid(32, 24)
    # Isometric wall block - front face
    fill_rect(g, 6, 4, 26, 18, WALL_BROWN)
    fill_rect(g, 7, 5, 25, 17, WALL_BROWN_LIGHT)
    # Brick pattern
    for y in [7, 11, 15]:
        fill_rect(g, 6, y, 26, y, WALL_MORTAR)
    for y in [9, 13]:
        set_px(g, 16, y, WALL_MORTAR)
    for y in [7, 11, 15]:
        set_px(g, 11, y+1, WALL_MORTAR)
        set_px(g, 21, y+1, WALL_MORTAR)
    # Top face (lighter)
    fill_rect(g, 6, 2, 26, 4, WALL_BROWN_LIGHT)
    fill_rect(g, 7, 2, 25, 3, (180, 155, 125, 255))
    # Dark edges
    fill_rect(g, 6, 2, 6, 18, WALL_BROWN_DARK)
    fill_rect(g, 26, 2, 26, 18, WALL_BROWN_DARK)
    return g

# ── ROCK (32x24, isometric) ──
def gen_rock():
    g = make_grid(32, 24)
    # Shadow
    fill_diamond(g, 16, 20, 12, 3, (0,0,0,50))
    # Main rock body
    fill_circle(g, 16, 13, 10, ROCK_GRAY)
    fill_circle(g, 15, 12, 8, ROCK_GRAY_LIGHT)
    # Highlight
    fill_circle(g, 13, 9, 3, ROCK_HIGHLIGHT)
    # Dark crevices
    set_px(g, 18, 14, ROCK_GRAY_DARK)
    set_px(g, 19, 15, ROCK_GRAY_DARK)
    set_px(g, 20, 14, ROCK_GRAY_DARK)
    set_px(g, 12, 16, ROCK_GRAY_DARK)
    set_px(g, 13, 17, ROCK_GRAY_DARK)
    # Moss accents
    set_px(g, 10, 15, (60, 100, 50, 255))
    set_px(g, 11, 16, (60, 100, 50, 255))
    set_px(g, 22, 12, (60, 100, 50, 255))
    return g

# ── PROJECTILE / ARROW (16x16) ──
def gen_arrow():
    g = make_grid(16, 16)
    # Glow
    fill_circle(g, 8, 8, 5, (255, 200, 50, 40))
    fill_circle(g, 8, 8, 3, (255, 220, 100, 80))
    # Arrow body
    set_px(g, 6, 8, ARROW_SHAFT)
    set_px(g, 7, 8, ARROW_SHAFT)
    set_px(g, 8, 8, ARROW_GOLD)
    set_px(g, 9, 8, ARROW_GOLD)
    set_px(g, 10, 8, ARROW_BRIGHT)
    # Arrowhead
    set_px(g, 11, 7, ARROW_BRIGHT)
    set_px(g, 11, 8, ARROW_BRIGHT)
    set_px(g, 11, 9, ARROW_BRIGHT)
    set_px(g, 12, 8, ARROW_BRIGHT)
    # Fletching
    set_px(g, 5, 7, ARROW_SHAFT)
    set_px(g, 5, 9, ARROW_SHAFT)
    return g

# ── TILE HIGHLIGHT (64x32, isometric diamond) ──
def gen_highlight():
    w, h = 64, 32
    g = make_grid(w, h)
    hw, hh = w // 2, h // 2
    # Diamond outline with glow
    for y in range(h):
        dy = abs(y - hh)
        if hh == 0:
            continue
        xspan = int(hw * (1.0 - dy / hh))
        cx = hw
        for thickness in range(3):
            alpha = [200, 120, 60][thickness]
            color = (255, 255, 200, alpha)
            if xspan - thickness >= 0:
                set_px(g, cx - xspan + thickness, y, color)
                set_px(g, cx + xspan - thickness, y, color)
    # Fill with semi-transparent white
    for y in range(h):
        dy = abs(y - hh)
        xspan = int(hw * (1.0 - dy / hh))
        for x in range(hw - xspan + 3, hw + xspan - 2):
            set_px(g, x, y, (255, 255, 255, 35))
    return g

# ── SPAWN OVERLAY (64x32) ──
def gen_spawn():
    w, h = 64, 32
    g = make_grid(w, h)
    hw, hh = w // 2, h // 2
    for y in range(h):
        dy = abs(y - hh)
        xspan = int(hw * (1.0 - dy / hh))
        for x in range(hw - xspan, hw + xspan + 1):
            set_px(g, x, y, (200, 40, 40, 50))
    outline_diamond(g, hw, hh, hw-1, hh-1, (200, 40, 40, 100))
    return g

# ── GOAL OVERLAY (64x32) ──
def gen_goal():
    w, h = 64, 32
    g = make_grid(w, h)
    hw, hh = w // 2, h // 2
    for y in range(h):
        dy = abs(y - hh)
        xspan = int(hw * (1.0 - dy / hh))
        for x in range(hw - xspan, hw + xspan + 1):
            set_px(g, x, y, (230, 190, 50, 60))
    outline_diamond(g, hw, hh, hw-1, hh-1, (230, 190, 50, 120))
    return g

# ── Generate all ──
print("Generating sprites...")
write_png(os.path.join(ASSETS, "hero.png"), 32, 32, gen_hero())
write_png(os.path.join(ASSETS, "enemy.png"), 32, 32, gen_enemy())
write_png(os.path.join(ASSETS, "archer_tower.png"), 32, 48, gen_tower())
write_png(os.path.join(ASSETS, "ground_archer.png"), 32, 32, gen_archer())
write_png(os.path.join(ASSETS, "wall.png"), 32, 24, gen_wall())
write_png(os.path.join(ASSETS, "rock.png"), 32, 24, gen_rock())
write_png(os.path.join(ASSETS, "arrow.png"), 16, 16, gen_arrow())
write_png(os.path.join(ASSETS, "highlight.png"), 64, 32, gen_highlight())
write_png(os.path.join(ASSETS, "spawn_overlay.png"), 64, 32, gen_spawn())
write_png(os.path.join(ASSETS, "goal_overlay.png"), 64, 32, gen_goal())
print("Done! All sprites saved to assets/")
