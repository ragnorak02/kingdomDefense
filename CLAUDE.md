# Korean Fantasy TD (kingdomDefense)

## Environment
- Godot 4.6+
- Renderer: GL Compatibility
- Viewport: 1280x720 (stretch mode: canvas_items)
- Project path: `Z:\Development\Games\kingdomDefense`

## Project Structure

### Autoloads
- `Constants` → `res://scripts/Constants.gd` — All game constants, enums, helper functions
- `AudioManager` → `res://scripts/AudioManager.gd` — Procedural audio generation (no external audio files)

### Core Scripts
- `scripts/GameManager.gd` — Phase state machine (PLANNING → WAVE → BREAK → GAME_OVER/VICTORY)
- `scripts/GridManager.gd` — Isometric grid (20x14, 64x32px tiles), AStar2D pathfinding, occupancy
- `scripts/BuildManager.gd` — Build item placement, validation, removal, upgrades
- `scripts/EnemyManager.gd` — Wave spawning, enemy tracking, lifecycle
- `scripts/UIManager.gd` — All HUD panels/labels/buttons (extends CanvasLayer)
- `scripts/Constants.gd` — Grid config, economy, tower/hero/enemy stats, wave configs, coordinate conversion

### Entity Scripts
- `scripts/Hero.gd` — Player character: WASD movement, sword attack, magic spells (Fireball, Ice Blast)
- `scripts/Enemy.gd` — Enemy pathfinding, HP, damage; 4 types (Goblin, Orc, Swift, Demon)
- `scripts/ArcherTower.gd` — Tower defense unit, 3-level upgrade system
- `scripts/GroundArcher.gd` — Ground archer unit, 3-level upgrade system
- `scripts/Projectile.gd` — Arrow projectile, homing or last-known-position tracking
- `scripts/Fireball.gd` — Spell projectile, AoE explosion on contact or max range

### Utility Scripts
- `scripts/CameraController.gd` — Zoom (mouse wheel 0.5-2.0x), pan (middle drag), HOME reset

### Scenes
- `scenes/Main.tscn` — Root scene with all managers, Hero, containers, UIManager
- `scenes/Enemy.tscn` — Enemy instance template
- `scenes/Projectile.tscn` — Arrow projectile
- `scenes/ArcherTower.tscn` — Tower structure
- `scenes/GroundArcher.tscn` — Ground archer structure
- `scenes/Fireball.tscn` — Spell projectile

## Architecture Patterns

### Phase State Machine
`GameManager.gd` uses `enum Phase`: PLANNING (30s countdown + gold income) → WAVE (enemies spawn, hero + towers defend) → BREAK (wave clear stats) → loops. GAME_OVER if base HP reaches 0, VICTORY after wave 10.

### Isometric Grid
- 20x14 tiles, origin at (640, 80), 64px wide x 32px tall
- `Constants.grid_to_world()` / `Constants.world_to_grid()` for coordinate conversion
- 3 spawn points on left edge (y=3,7,11), goal at right (x=19, y=7)
- AStar2D rebuilt on every grid change; cannot fully block spawn→goal

### Build System
- Items: Wall (10g), Rock (20g), Archer Tower (80g), Ground Archer (40g)
- 3-level upgrades: cost ratios [0, 0.6, 1.0] of base; damage/range/rate scale up
- 50% refund on removal
- `would_block_all_paths` validation prevents complete path blocking

### Hero Combat
- Speed 150, Attack 25 dmg, 0.4s cooldown, 40 range
- Magic: 100 mana, 5/sec regen
- Fireball: 30 mana, 40 dmg, 50 AoE radius
- Ice Blast: 25 mana, 15 dmg, 0.4x slow for 3s

### Enemy Scaling
- Base: 40 HP, 60 speed
- Per wave: +30% HP, +5% speed
- 10 configured waves; infinite scaling beyond wave 10

### Procedural Audio
`AudioManager.gd` generates all SFX using AudioStreamWAV (sine wave tones + noise, exponential decay). No external audio files. 8 concurrent AudioStreamPlayers, 13 sound types.

### Input
| Action | Keys | Gamepad |
|--------|------|---------|
| Move | WASD | Left Stick |
| Hero Attack | Space | A Button |
| Toggle Build | Shift | Y Button |
| Start Wave | Enter | Start |
| Place Item | Left Click | Button 0 |
| Cancel Build | Right Click | B Button |
| Cycle Spell | Q | Button 9 |
| Cast Spell | E | Button 10 |
| Pause | Escape | Start |

## Test Framework
- `tests/test_build.gd` — Headless: data validation, coordinate conversion, upgrade costs, wave configs
- `tests/test_runtime.gd` — In-scene: initial state, gold spend/refund, phase transitions, pathfinding
- `tests/TestRuntime.tscn` — Scene for runtime tests
- Run headless: `godot --headless --script res://tests/test_build.gd`

## Current Repo State (Auto-Detected)
- 14 GDScript files, 6 scenes
- All core systems implemented: grid, pathfinding, build, hero, enemies, towers, waves, UI
- 4 enemy types, 2 tower types, 2 spells, 10 configured waves + infinite scaling
- 13 PNG sprites (generated via Python: `generate_sprites.py`, `generate_enemies.py`)
- README.txt present (82 lines, controls + gameplay + balance guide)
- No class_name declarations — all files use direct extends
- `.gitignore` covers `.godot/` only
