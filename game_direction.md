# Korean Fantasy TD — Game Direction

## Concept
An isometric tower defense game with Korean fantasy theming. Players place defensive structures during planning phases and actively defend with a hero character during waves. The core twist: no fixed enemy path — players shape routes by placing walls and rocks, but can never fully block all paths.

## Core Loop
```
PLANNING (30s) → WAVE (enemies spawn, hero + towers defend) → BREAK (stats) → repeat
```
Victory after wave 10. Defeat if base HP reaches 0.

## Pillars
1. **Path shaping** — player-built walls define the enemy route, adding a layer of strategy beyond tower placement
2. **Active hero** — the player isn't passive; direct WASD control of a sword-wielding, spell-casting hero
3. **Data-driven balance** — all tuning lives in Constants.gd for rapid iteration
4. **Zero external assets** — procedural audio, Python-generated sprites, fully self-contained

## Build Items
| Item | Cost | Notes |
|------|------|-------|
| Wall | 10g | Blocks path, cheap |
| Rock | 20g | Blocks path, sturdier visual |
| Archer Tower | 80g | Ranged, auto-targets, 3 upgrade levels |
| Ground Archer | 40g | Cheaper ranged unit, 3 upgrade levels |

Upgrades cost 60% / 100% of base price for levels 2 / 3. 50% refund on removal.

## Enemy Roster
| Type | HP Mult | Speed Mult | Damage | Notes |
|------|---------|------------|--------|-------|
| Goblin | 1.0x | 1.0x | 1 | Standard |
| Orc | 2.5x | 0.65x | 2 | Tanky, slow |
| Swift | 0.5x | 1.8x | 1 | Fast, fragile |
| Demon | 5.0x | 0.5x | 3 | Boss-tier |

Per wave: +30% HP, +5% speed. 10 configured waves, infinite scaling beyond.

## Hero
- **Movement:** WASD, speed 150
- **Sword:** 25 dmg, 0.4s cooldown, 40 range
- **Fireball:** 30 mana, 40 dmg, 50 AoE radius
- **Ice Blast:** 25 mana, 15 dmg, 0.4x slow for 3s
- **Mana:** 100 max, 5/sec regen

## Phase Roadmap

### Phase 1 — Core Systems (COMPLETE)
- [x] Isometric grid (20x14) with coordinate conversion
- [x] AStar2D pathfinding with path-blocking validation
- [x] Phase state machine (PLANNING → WAVE → BREAK → GAME_OVER/VICTORY)
- [x] Hero movement, sword attack, 2 spells
- [x] 4 enemy types with wave-based scaling
- [x] 2 tower types with 3-level upgrade system
- [x] Build/remove/upgrade system with gold economy
- [x] Full UI (HUD, build panel, phase panels)
- [x] Procedural audio (13 SFX, no external files)
- [x] Camera zoom/pan controls
- [x] Keyboard + Xbox controller support
- [x] Python sprite generation scripts
- [x] Test suite (headless + runtime)

### Phase 2 — Content & Polish (NEXT)
- [ ] Additional tower types (magic tower, splash tower)
- [ ] More enemy types and wave variety
- [ ] Hero progression (level-up, stat growth)
- [ ] Real art assets replacing generated sprites
- [ ] Music and ambient audio
- [ ] Particle effects and juice
- [ ] Main menu / settings screen

### Phase 3 — Expansion (FUTURE)
- [ ] Multiple maps with different terrain
- [ ] Boss waves with unique mechanics
- [ ] Save/load system
- [ ] Difficulty settings
- [ ] Challenge modes (endless, speed run)

## Technical Constraints
- Godot 4.6+ with GL Compatibility renderer
- GDScript only, no class_name declarations
- All drawing via `_draw()` + `queue_redraw()`
- All balance tuning in Constants.gd autoload
- 1280x720 base resolution, canvas_items stretch

## Dev Log

### 2026-02-17 — Graphics Pass V1
Upgraded all placeholder visuals from static PNGs + programmatic `_draw()` to animated sprites and textured tiles:
- **Grid**: Flat colored polygons → textured isometric tile PNGs (grass variants, spawn, goal)
- **Hero**: Static Sprite2D → AnimatedSprite2D with idle (4f), walk (4f), attack (3f) animations
- **Enemies**: Static Sprite2D → AnimatedSprite2D with walk (4f) per type (goblin, orc, swift, demon)
- **Fireball**: Programmatic circles → AnimatedSprite2D with fly (3f) and explode (4f) animations
- **Attack arc**: Wedge polygon → animated slash sprite (3f crescent arc)
- **HP bars**: Enhanced with black border, gradient highlight
- **Upgrade stars**: Circles → 5-pointed star polygons with bright center
- **Static sprites**: Improved detail/shading on tower, archer, wall, rock, arrow
- All sprites generated via `generate_sprites_v2.py` (pure Python, no dependencies)
- All 148 tests pass unchanged — zero gameplay logic modifications
